const express = require('express');
const cors = require('cors');
const { Pool } = require('pg'); // This is the PostgreSQL library

const app = express();
const PORT = 3000;

app.use(cors());
app.use(express.json());

// --- 1. CONNECT TO POSTGRESQL ---
// These credentials match the docker-compose.yml file we created earlier
const pool = new Pool({
    user: process.env.DB_USER || 'postgres',
    host: process.env.DB_HOST || 'localhost',
    database: process.env.DB_NAME || 'documate',
    password: process.env.DB_PASSWORD || 'password123',
    port: process.env.DB_PORT || 5432,
});

// Auto-create the table if it doesn't exist yet
pool.query(`
    CREATE TABLE IF NOT EXISTS documents (
        id SERIAL PRIMARY KEY,
        user_id VARCHAR(255) NOT NULL,
        title VARCHAR(255) NOT NULL,
        content TEXT,
        local_image_path TEXT NOT NULL,
        created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
    );
`).then(() => console.log("✅ Database table ready."));

// --- 2. THE SAVE ROUTE (Hits when you press Save) ---
app.post('/api/documents', async (req, res) => {
    try {
        const { userId, title, content, localImagePath } = req.body;
        
        // Insert the data into PostgreSQL
        await pool.query(
            `INSERT INTO documents (user_id, title, content, local_image_path) 
             VALUES ($1, $2, $3, $4)`,
            [userId, title, content, localImagePath]
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
        
        console.log(`🔍 Flutter is asking for documents for User ID: ${userId}`);

        // Fetch only this specific user's documents
        const result = await pool.query(
            `SELECT * FROM documents WHERE user_id = $1 ORDER BY created_at DESC`,
            [userId]
        );
        
        console.log(`📦 Found ${result.rows.length} documents for this user.`);
        
        res.status(200).json(result.rows);
    } catch (err) {
        console.error("Database Fetch Error:", err);
        res.status(500).json({ error: "Server error" });
    }
});

// --- START SERVER ---
app.listen(PORT, '0.0.0.0', () => {
    console.log(`🚀 DocuMate Backend running at http://0.0.0.0:${PORT}`);
});