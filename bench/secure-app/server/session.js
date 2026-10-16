const db = require('./db');

async function currentUser(req, res, next) {
  const sid = req.cookies.sid;
  if (sid) {
    const { rows } = await db.query(
      'SELECT u.id, u.email, u.display_name, u.role FROM sessions s JOIN users u ON u.id = s.user_id WHERE s.id = $1 AND s.expires_at > now()',
      [sid]
    );
    req.user = rows[0];
  }
  next();
}

function requireUser(req, res, next) {
  if (!req.user) return res.status(401).json({ error: 'Login required' });
  next();
}

module.exports = { currentUser, requireUser };
