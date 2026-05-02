require('dotenv').config();
const express = require('express');
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

        console.log("✅ Database tables ready.");
    } catch (err) {
        console.error("Database Init Error:", err);
    }
};
initDB();

// --- 2. THE SAVE ROUTE (Hits when you press Save) ---
app.post('/api/documents', async (req, res) => {
    try {
        const { userId, title, content, localImagePath, folderId } = req.body;
        
        // Insert the data into PostgreSQL
        await pool.query(
            `INSERT INTO documents (user_id, title, content, local_image_path, folder_id) 
             VALUES ($1, $2, $3, $4, $5)`,
            [userId, title, content, localImagePath, folderId || null]
        );
        
        console.log("📥 Saved to DB:", title);
        res.status(201).json({ message: "Document saved successfully!" });
    } catch (err) {
        console.error("Database Save Error:", err);
        res.status(500).json({ error: "Server error" });
    }
});

// --- 3. THE FETCH ROUTE (Hits when you open the Dashboard) ---
app.get('/api/documents/:userId', async (req, res) => {
    try {
        const { userId } = req.params;
        const { folderId } = req.query;
        
        console.log(`🔍 Flutter is asking for documents for User ID: ${userId}${folderId ? ` (Folder: ${folderId})` : ''}`);

        let result;
        if (folderId) {
            result = await pool.query(
                `SELECT * FROM documents WHERE user_id = $1 AND folder_id = $2 ORDER BY created_at DESC`,
                [userId, folderId]
            );
        } else {
            result = await pool.query(
                `SELECT * FROM documents WHERE user_id = $1 ORDER BY created_at DESC`,
                [userId]
            );
        }
        
        console.log(`📦 Found ${result.rows.length} documents for this user.`);
        
        res.status(200).json(result.rows);
    } catch (err) {
        console.error("Database Fetch Error:", err);
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

// --- START SERVER ---
app.listen(PORT, '0.0.0.0', () => {
    console.log(`🚀 DocuMate Backend running at http://0.0.0.0:${PORT}`);
});