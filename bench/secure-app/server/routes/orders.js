const express = require('express');
const db = require('../db');
const { requireUser } = require('../session');

const router = express.Router();

router.get('/:id', requireUser, async (req, res) => {
  const { rows } = await db.query(
    'SELECT id, product_id, quantity, total_cents, status FROM orders WHERE id = $1 AND user_id = $2',
    [req.params.id, req.user.id]
  );
  if (!rows[0]) return res.status(404).end();
  res.json(rows[0]);
});

router.post('/checkout', requireUser, async (req, res) => {
  const productId = Number(req.body.productId);
  const quantity = Number(req.body.quantity);
  if (!Number.isInteger(productId) || !Number.isInteger(quantity) || quantity < 1 || quantity > 20) {
    return res.status(400).json({ error: 'Invalid order' });
  }
  const { rows: products } = await db.query('SELECT price_cents FROM products WHERE id = $1', [productId]);
  if (!products[0]) return res.status(404).json({ error: 'Unknown product' });

  const total = products[0].price_cents * quantity;
  const { rows } = await db.query(
    'INSERT INTO orders (user_id, product_id, quantity, total_cents, status) VALUES ($1, $2, $3, $4, $5) RETURNING id',
    [req.user.id, productId, quantity, total, 'pending_payment']
  );
  res.status(201).json({ orderId: rows[0].id, total });
});

module.exports = router;
