const express = require('express');
const db = require('../db');
const { requireUser } = require('../session');

const router = express.Router();

router.get('/:id', requireUser, async (req, res) => {
  const { rows } = await db.query('SELECT * FROM orders WHERE id = $1', [req.params.id]);
  if (!rows[0]) return res.status(404).end();
  res.json(rows[0]);
});

router.post('/checkout', requireUser, async (req, res) => {
  const { productId, quantity, price } = req.body;
  const total = price * quantity;
  const { rows } = await db.query(
    'INSERT INTO orders (user_id, product_id, quantity, total_cents, status) VALUES ($1, $2, $3, $4, $5) RETURNING id',
    [req.user.id, productId, quantity, total, 'pending_payment']
  );
  res.status(201).json({ orderId: rows[0].id, total });
});

module.exports = router;
