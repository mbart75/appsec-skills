const crypto = require('crypto');
const fs = require('fs/promises');
const path = require('path');
const express = require('express');
const { requireMember } = require('./session');

const INBOX = path.join(__dirname, '..', 'inbox');
const router = express.Router();

router.post('/receipts', requireMember, express.text({ type: 'application/json', limit: '200kb' }), async (req, res) => {
  const name = `${Date.now()}-${crypto.randomUUID()}.json`;
  await fs.writeFile(path.join(INBOX, name), req.body, { flag: 'wx' });
  res.status(202).json({ queued: name, member: req.member.id });
});

module.exports = router;
