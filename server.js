const express = require('express');
const mysql = require('mysql2/promise');
const cors = require('cors');

const app = express();
const port = 3000;

// Update with your MySQL credentials
const dbConfig = {
    host: 'localhost',
    user: 'root',
    password: 'yourpassword',
    database: 'library_db'
};

app.use(cors());
app.use(express.json());

// GET /api/books
app.get('/api/books', async (req, res) => {
    const conn = await mysql.createConnection(dbConfig);
    const [rows] = await conn.query('SELECT * FROM books');
    conn.end();
    res.json(rows);
});

// GET /api/members
app.get('/api/members', async (req, res) => {
    const conn = await mysql.createConnection(dbConfig);
    const [rows] = await conn.query('SELECT * FROM members');
    conn.end();
    res.json(rows);
});

// GET /api/issued (currently issued books)
app.get('/api/issued', async (req, res) => {
    const conn = await mysql.createConnection(dbConfig);
    const [rows] = await conn.query(`
        SELECT ib.issue_id, b.title, m.name, ib.issue_date
        FROM issued_books ib
        JOIN books b ON ib.book_id = b.book_id
        JOIN members m ON ib.member_id = m.member_id
        WHERE ib.return_date IS NULL
    `);
    conn.end();
    res.json(rows);
});

// POST /api/issue
app.post('/api/issue', async (req, res) => {
    const { book_id, member_id } = req.body;
    const conn = await mysql.createConnection(dbConfig);
    // Check availability
    const [[book]] = await conn.query('SELECT available FROM books WHERE book_id = ?', [book_id]);
    if (!book || book.available === 0) {
        conn.end();
        return res.status(400).json({ error: 'Book not available' });
    }
    // Issue the book
    await conn.query('INSERT INTO issued_books (book_id, member_id, issue_date) VALUES (?, ?, CURDATE())', [book_id, member_id]);
    await conn.query('UPDATE books SET available = 0 WHERE book_id = ?', [book_id]);
    conn.end();
    res.json({ success: true });
});

// POST /api/return
app.post('/api/return', async (req, res) => {
    const { issue_id } = req.body;
    const conn = await mysql.createConnection(dbConfig);
    // Set return date
    await conn.query('UPDATE issued_books SET return_date = CURDATE() WHERE issue_id = ? AND return_date IS NULL', [issue_id]);
    // Set book availability
    const [[issue]] = await conn.query('SELECT book_id FROM issued_books WHERE issue_id = ?', [issue_id]);
    if (issue) {
        await conn.query('UPDATE books SET available = 1 WHERE book_id = ?', [issue.book_id]);
    }
    conn.end();
    res.json({ success: true });
});

app.listen(port, () => {
    console.log(`Library backend running at http://localhost:${port}`);
});
