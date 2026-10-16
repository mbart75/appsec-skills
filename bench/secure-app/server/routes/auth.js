const crypto = require('crypto');
const argon2 = require('argon2');
const express = require('express');
const { rateLimit } = require('express-rate-limit');
const db = require('../db');
const { sendMail } = require('../mail');

const router = express.Router();

const authLimiter = rateLimit({ windowMs: 15 * 60 * 1000, limit: 10, standardHeaders: 'draft-8', legacyHeaders: false });
const SESSION_TTL_MS = 7 * 24 * 60 * 60 * 1000;
// Verified when the e-mail is unknown, so both cases take the same time.
const DUMMY_HASH = argon2.hash('timing-equaliser', { type: argon2.argon2id });

const sha256 = (value) => crypto.createHash('sha256').update(value).digest('hex');
const isEmail = (value) => typeof value === 'string' && value.length <= 254 && value.includes('@');
const isPassword = (value) => typeof value === 'string' && value.length >= 12 && value.length <= 256;

router.post('/register', authLimiter, async (req, res) => {
  const { email, password } = req.body;
  if (!isEmail(email) || !isPassword(password)) {
    return res.status(400).json({ error: 'A valid e-mail and a password of 12 to 256 characters are required' });
  }
  const hash = await argon2.hash(password, { type: argon2.argon2id });
  await db.query(
    'INSERT INTO users (email, password_hash, role) VALUES ($1, $2, $3) ON CONFLICT (email) DO NOTHING',
    [email.toLowerCase(), hash, 'customer']
  );
  // Same answer whether or not the address was already registered.
  res.status(201).json({ ok: true });
});

router.post('/login', authLimiter, async (req, res) => {
  const { email, password } = req.body;
  if (!isEmail(email) || typeof password !== 'string') return res.status(400).json({ error: 'Invalid request' });

  const { rows } = await db.query('SELECT id, password_hash FROM users WHERE email = $1', [email.toLowerCase()]);
  const valid = await argon2.verify(rows[0] ? rows[0].password_hash : await DUMMY_HASH, password);
  if (!rows[0] || !valid) return res.status(401).json({ error: 'Invalid e-mail or password' });

  const sid = crypto.randomUUID();
  await db.query("INSERT INTO sessions (id, user_id, expires_at) VALUES ($1, $2, now() + interval '7 days')", [
    sid,
    rows[0].id,
  ]);
  res.cookie('sid', sid, { httpOnly: true, secure: true, sameSite: 'lax', maxAge: SESSION_TTL_MS, path: '/' });
  res.json({ ok: true });
});

router.post('/forgot-password', authLimiter, async (req, res) => {
  const email = isEmail(req.body.email) ? req.body.email.toLowerCase() : '';
  const { rows } = await db.query('SELECT id FROM users WHERE email = $1', [email]);
  if (rows[0]) {
    const token = crypto.randomBytes(32).toString('base64url');
    await db.query(
      "UPDATE users SET reset_token_hash = $1, reset_expires_at = now() + interval '30 minutes' WHERE id = $2",
      [sha256(token), rows[0].id]
    );
    await sendMail(email, `Reset your password (link valid 30 minutes): https://tinyshop.example/reset?token=${token}`);
  }
  res.json({ ok: true });
});

router.post('/reset-password', authLimiter, async (req, res) => {
  const { token, password } = req.body;
  if (typeof token !== 'string' || !isPassword(password)) return res.status(400).json({ error: 'Invalid request' });

  const hash = await argon2.hash(password, { type: argon2.argon2id });
  const { rows } = await db.query(
    `UPDATE users SET password_hash = $1, reset_token_hash = NULL, reset_expires_at = NULL
     WHERE reset_token_hash = $2 AND reset_expires_at > now() RETURNING id`,
    [hash, sha256(token)]
  );
  if (!rows[0]) return res.status(400).json({ error: 'Invalid or expired link' });
  await db.query('DELETE FROM sessions WHERE user_id = $1', [rows[0].id]);
  res.json({ ok: true });
});

module.exports = router;
