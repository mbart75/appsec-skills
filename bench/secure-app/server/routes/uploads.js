const crypto = require('crypto');
const fs = require('fs');
const path = require('path');
const express = require('express');
const db = require('../db');
const { requireUser } = require('../session');

const router = express.Router();
// User files live outside the deployed tree: scripts/deploy.sh replaces everything in it.
const UPLOAD_DIR = process.env.UPLOAD_DIR || '/var/lib/tinyshop/uploads';
const TYPES = {
  'image/png': { ext: '.png', magic: [0x89, 0x50, 0x4e, 0x47] },
  'image/jpeg': { ext: '.jpg', magic: [0xff, 0xd8, 0xff] },
};

router.post('/', requireUser, express.raw({ type: Object.keys(TYPES), limit: '5mb' }), async (req, res) => {
  const mime = Object.keys(TYPES).find((type) => req.is(type));
  const type = mime && TYPES[mime];
  if (!type || !Buffer.isBuffer(req.body) || !type.magic.every((byte, i) => req.body[i] === byte)) {
    return res.status(415).json({ error: 'PNG or JPEG images only' });
  }
  // The stored name is generated: the client never chooses a path.
  const name = crypto.randomUUID() + type.ext;
  await fs.promises.writeFile(path.join(UPLOAD_DIR, name), req.body, { flag: 'wx' });
  await db.query('INSERT INTO uploads (name, user_id) VALUES ($1, $2)', [name, req.user.id]);
  res.status(201).json({ name });
});

module.exports = router;
