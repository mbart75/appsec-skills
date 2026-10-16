const fs = require('fs');
const path = require('path');
const express = require('express');
const { requireUser } = require('../session');

const router = express.Router();
const UPLOAD_DIR = path.join(__dirname, '..', '..', 'uploads');

router.post('/', requireUser, express.raw({ type: '*/*', limit: '50mb' }), (req, res) => {
  const target = path.join(UPLOAD_DIR, req.query.name);
  fs.writeFileSync(target, req.body);
  res.status(201).json({ path: '/uploads/' + req.query.name });
});

module.exports = router;
