const db = require('./db');

const SESSION_ID = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;

async function currentUser(req, res, next) {
  const sid = req.cookies.sid;
  // Anything but a session id is ignored: the uuid column would reject it and fail the request.
  if (typeof sid === 'string' && SESSION_ID.test(sid)) {
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
