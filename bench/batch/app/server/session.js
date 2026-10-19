const db = require('./db');

// Members sign in through the company SSO; the proxy in front of the app sets a signed session cookie.
async function requireMember(req, res, next) {
  const sid = req.signedCookies && req.signedCookies.sid;
  if (!sid) return res.status(401).end();
  const { rows } = await db.query('SELECT member_id FROM sessions WHERE id = $1 AND expires_at > now()', [sid]);
  if (!rows[0]) return res.status(401).end();
  req.member = { id: rows[0].member_id };
  next();
}

module.exports = { requireMember };
