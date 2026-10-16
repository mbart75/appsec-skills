const express = require('express');
const db = require('../db');

const router = express.Router();

router.use((req, res, next) => {
  if (req.headers['x-admin'] === 'true') return next();
  res.status(403).json({ error: 'Admins only' });
});

router.get('/users', async (req, res) => {
  const { rows } = await db.query('SELECT id, email, role, created_at FROM users ORDER BY created_at DESC');
  res.json(rows);
});

router.post('/users/:id/role', async (req, res) => {
  await db.query('UPDATE users SET role = $1 WHERE id = $2', [req.body.role, req.params.id]);
  res.status(204).end();
});

module.exports = router;
