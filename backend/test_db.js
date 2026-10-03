const { Pool } = require('pg');
require('dotenv').config();

const pool = new Pool({
    user: process.env.DB_USER,
    host: process.env.DB_HOST,
    database: process.env.DB_NAME,
    password: process.env.DB_PASSWORD,
    port: process.env.DB_PORT,
});

async function test() {
    console.log("Testing connection with:", {
        user: process.env.DB_USER,
        host: process.env.DB_HOST,
        database: process.env.DB_NAME,
        port: process.env.DB_PORT,
    });
    try {
        const res = await pool.query('SELECT NOW()');
        console.log("Success:", res.rows[0]);
    } catch (err) {
        console.error("Connection Failed!");
        console.error("Error Object:", err);
        console.error("Error Message:", err.message);
        console.error("Error Stack:", err.stack);
    } finally {
        await pool.end();
    }
}

test();
