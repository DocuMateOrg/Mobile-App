require('dotenv').config();
const express = require('express');
const PDFDocument = require('pdfkit');
const { Document, Packer, Paragraph, TextRun } = require('docx');
const cors = require('cors');
const { Pool } = require('pg'); // This is the PostgreSQL library

const app = express();
const PORT = process.env.PORT || 3000;

app.use(cors());
app.use(express.json());

// --- 1. CONNECT TO POSTGRESQL ---
// These credentials come from the .env file
const pool = new Pool({
    user: process.env.DB_USER,
    host: process.env.DB_HOST,
    database: process.env.DB_NAME,
    password: process.env.DB_PASSWORD,
    port: process.env.DB_PORT,
});

const fs = require('fs');
const logFile = 'server.log';
const log = (msg) => {
    const entry = `[${new Date().toISOString()}] ${msg}\n`;
    fs.appendFileSync(logFile, entry);
    console.log(msg);
};

// Prevent Node.js from crashing if the database connection drops unexpectedly
pool.on('error', (err, client) => {
    log(`Unexpected error on idle client: ${err.message}`);
});


// Auto-create the tables if they don't exist yet
const initDB = async () => {
    try {
        await pool.query(`
            CREATE TABLE IF NOT EXISTS folders (
                id SERIAL PRIMARY KEY,
                user_id VARCHAR(255) NOT NULL,
                name VARCHAR(255) NOT NULL,
                created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
            );
        `);
        
        await pool.query(`
            CREATE TABLE IF NOT EXISTS documents (
                id SERIAL PRIMARY KEY,
                user_id VARCHAR(255) NOT NULL,
                title VARCHAR(255) NOT NULL,
                content TEXT,
                local_image_path TEXT NOT NULL,
                folder_id INTEGER REFERENCES folders(id) ON DELETE SET NULL,
                created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
            );
        `);

        // If documents table already existed without folder_id, add it safely
        await pool.query(`
            ALTER TABLE documents 
            ADD COLUMN IF NOT EXISTS folder_id INTEGER REFERENCES folders(id) ON DELETE SET NULL;
        `);

        log("✅ Database tables ready.");
    } catch (err) {
        log(`Database Init Error: ${err.message}`);
    }
};
initDB();

// --- 2. THE SAVE ROUTE (Hits when you press Save) ---
app.post('/api/documents', async (req, res) => {
    try {
        let { userId, title, content, localImagePath, folderId } = req.body;
        userId = userId?.trim();
        
        if (!userId) return res.status(400).json({ error: "User ID required" });
        
        // Insert the data into PostgreSQL
        await pool.query(
            `INSERT INTO documents (user_id, title, content, local_image_path, folder_id) 
             VALUES ($1, $2, $3, $4, $5)`,
            [userId, title, content, localImagePath, folderId || null]
        );
        
        log(`📥 Saved to DB: ${title} for user ${userId}`);
        res.status(201).json({ message: "Document saved successfully!" });
    } catch (err) {
        log(`Database Save Error: ${err.message}`);
        res.status(500).json({ error: "Server error" });
    }
});

// --- 3. THE FETCH ROUTE (Hits when you open the Dashboard) ---
app.get('/api/documents/:userId', async (req, res) => {
    try {
        const userId = req.params.userId?.trim();
        const folderId = req.query.folderId;
        const search = req.query.search;
        
        if (!userId) return res.status(400).json({ error: "User ID required" });

        log(`[DEBUG] Fetching docs for UID: "${userId}"`);
        if (folderId) log(`[DEBUG] Filter by Folder: ${folderId}`);
        if (search) log(`[DEBUG] Filter by Search: "${search}"`);

        let queryStr = `SELECT * FROM documents WHERE user_id = $1`;
        let values = [userId];
        let paramCount = 2;

        if (folderId) {
            queryStr += ` AND folder_id = $${paramCount}`;
            values.push(folderId);
            paramCount++;
        }

        if (search) {
            // Split by space, keep words longer than 2 characters to filter out "the", "a", "is", etc.
            const searchWords = search.split(/\s+/).filter(word => word.length > 2);
            
            if (searchWords.length > 0) {
                let searchConditions = [];
                searchWords.forEach(word => {
                    searchConditions.push(`(title ILIKE $${paramCount} OR content ILIKE $${paramCount})`);
                    values.push(`%${word}%`);
                    paramCount++;
                });
                // Match ANY of the meaningful words (OR logic)
                queryStr += ` AND (${searchConditions.join(' OR ')})`;
            } else {
                // Fallback to exact match if words are too short
                queryStr += ` AND (title ILIKE $${paramCount} OR content ILIKE $${paramCount})`;
                values.push(`%${search}%`);
                paramCount++;
            }
        }

        queryStr += ` ORDER BY created_at DESC`;

        const result = await pool.query(queryStr, values);
        
        log(`📦 Found ${result.rows.length} documents for UID: "${userId}"`);
        
        res.status(200).json(result.rows);
    } catch (err) {
        log(`Database Fetch Error: ${err.message}`);
        res.status(500).json({ error: "Server error" });
    }
});

// --- 4. CREATE FOLDER ---
app.post('/api/folders', async (req, res) => {
    try {
        const { userId, name } = req.body;
        
        const result = await pool.query(
            `INSERT INTO folders (user_id, name) VALUES ($1, $2) RETURNING id, name`,
            [userId, name]
        );
        
        console.log("📁 Created folder:", name);
        res.status(201).json(result.rows[0]);
    } catch (err) {
        console.error("Database Folder Save Error:", err);
        res.status(500).json({ error: "Server error" });
    }
});

// --- 5. FETCH FOLDERS ---
app.get('/api/folders/:userId', async (req, res) => {
    try {
        const { userId } = req.params;
        
        const result = await pool.query(
            `SELECT * FROM folders WHERE user_id = $1 ORDER BY created_at DESC`,
            [userId]
        );
        
        res.status(200).json(result.rows);
    } catch (err) {
        console.error("Database Folder Fetch Error:", err);
        res.status(500).json({ error: "Server error" });
    }
});

// --- 6. DELETE DOCUMENT ---
app.delete('/api/documents/:id', async (req, res) => {
    try {
        const { id } = req.params;
        await pool.query(`DELETE FROM documents WHERE id = $1`, [id]);
        res.status(200).json({ message: "Document deleted" });
    } catch (err) {
        console.error("Database Delete Error:", err);
        res.status(500).json({ error: "Server error" });
    }
});

// --- 7. UPDATE DOCUMENT (Rename or Move) ---
app.put('/api/documents/:id', async (req, res) => {
    try {
        const { id } = req.params;
        const { title, folderId } = req.body;
        
        let query = 'UPDATE documents SET ';
        const values = [];
        let count = 1;

        if (title !== undefined) {
            query += `title = $${count} `;
            values.push(title);
            count++;
        }
        if (folderId !== undefined) {
            if (count > 1) query += ', ';
            query += `folder_id = $${count} `;
            // Allow folderId to be null to move out of a folder
            values.push(folderId === null ? null : folderId);
            count++;
        }
        
        if (values.length === 0) {
            return res.status(400).json({ error: "No fields to update" });
        }

        query += `WHERE id = $${count}`;
        values.push(id);

        await pool.query(query, values);
        res.status(200).json({ message: "Document updated" });
    } catch (err) {
        console.error("Database Update Error:", err);
        res.status(500).json({ error: "Server error" });
    }
});

// --- 6. EXPORT ROUTE (Convert to PDF/Word) ---
app.get('/api/documents/:id/export', async (req, res) => {
    try {
        const { id } = req.params;
        const { format } = req.query; // 'pdf' or 'docx'

        const result = await pool.query('SELECT * FROM documents WHERE id = $1', [id]);
        if (result.rows.length === 0) {
            return res.status(404).json({ error: "Document not found" });
        }

        const docData = result.rows[0];
        const fileName = `${docData.title.replace(/\s+/g, '_')}_${id}`;

        if (format === 'pdf') {
            const doc = new PDFDocument();
            res.setHeader('Content-Type', 'application/pdf');
            res.setHeader('Content-Disposition', `attachment; filename=${fileName}.pdf`);

            doc.pipe(res);
            doc.fontSize(20).text(docData.title, { align: 'center' });
            doc.moveDown();
            doc.fontSize(12).text(docData.content);
            doc.end();

        } else if (format === 'docx') {
            const doc = new Document({
                sections: [{
                    properties: {},
                    children: [
                        new Paragraph({
                            children: [
                                new TextRun({
                                    text: docData.title,
                                    bold: true,
                                    size: 32,
                                }),
                            ],
                        }),
                        new Paragraph({
                            children: [
                                new TextRun({
                                    text: "\n" + docData.content,
                                    size: 24,
                                }),
                            ],
                        }),
                    ],
                }],
            });

            const buffer = await Packer.toBuffer(doc);
            res.setHeader('Content-Type', 'application/vnd.openxmlformats-officedocument.wordprocessingml.document');
            res.setHeader('Content-Disposition', `attachment; filename=${fileName}.docx`);
            res.send(buffer);

        } else {
            res.status(400).json({ error: "Invalid format. Use 'pdf' or 'docx'." });
        }
    } catch (err) {
        log(`Export Error: ${err.message}`);
        res.status(500).json({ error: "Server error during export" });
    }
});

// --- START SERVER ---
app.listen(PORT, '0.0.0.0', () => {
    console.log(`🚀 DocuMate Backend running at http://0.0.0.0:${PORT}`);
});