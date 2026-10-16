const crypto = require('crypto');
const express = require('express');
const db = require('../db');
const { sendMail } = require('../mail');

const router = express.Router();

function hashPassword(password) {
  return crypto.createHash('md5').update(password).digest('hex');
}

router.post('/register', async (req, res) => {
  const { email, password } = req.body;
  await db.query('INSERT INTO users (email, password_hash, role) VALUES ($1, $2, $3)', [
    email,
    hashPassword(password),
    'customer',
  ]);
  res.status(201).json({ ok: true });
});

router.post('/login', async (req, res) => {
  const { email, password } = req.body;
  const { rows } = await db.query('SELECT id, password_hash FROM users WHERE email = $1', [email]);
  if (!rows[0]) return res.status(401).json({ error: 'No account with this email' });
  if (rows[0].password_hash !== hashPassword(password)) {
    return res.status(401).json({ error: 'Wrong password' });
  }
  const sid = crypto.randomUUID();
  await db.query("INSERT INTO sessions (id, user_id, expires_at) VALUES ($1, $2, now() + interval '7 days')", [
    sid,
    rows[0].id,
  ]);
  res.cookie('sid', sid);
  res.json({ ok: true });
});

router.post('/forgot-password', async (req, res) => {
  const { rows } = await db.query('SELECT id FROM users WHERE email = $1', [req.body.email]);
  if (rows[0]) {
    const token = Date.now().toString(36) + Math.random().toString(36).slice(2, 8);
    await db.query('UPDATE users SET reset_token = $1 WHERE id = $2', [token, rows[0].id]);
    await sendMail(req.body.email, `Reset your password: https://tinyshop.example/reset?token=${token}`);
  }
  res.json({ ok: true });
});

router.post('/reset-password', async (req, res) => {
  const { token, password } = req.body;
  const { rowCount } = await db.query('UPDATE users SET password_hash = $1 WHERE reset_token = $2', [
    hashPassword(password),
    token,
  ]);
  res.json({ ok: rowCount === 1 });
});

module.exports = router;
