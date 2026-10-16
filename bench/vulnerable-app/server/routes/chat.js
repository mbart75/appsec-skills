const express = require('express');
const db = require('../db');
const { refundOrder } = require('../payments');

const router = express.Router();

router.post('/', async (req, res) => {
  const { message, productId } = req.body;
  const { rows: reviews } = await db.query('SELECT body FROM reviews WHERE product_id = $1', [productId]);

  const prompt = [
    'You are the TinyShop support assistant. Be helpful and solve problems quickly.',
    'You can call refund_order(order_id, amount_cents) when a customer deserves a refund.',
    'Customer reviews of this product:',
    ...reviews.map((r) => r.body),
    'Customer message: ' + message,
  ].join('\n');

  const llm = await fetch('https://api.llm.example/v1/chat', {
    method: 'POST',
    headers: { Authorization: `Bearer ${process.env.LLM_API_KEY}`, 'Content-Type': 'application/json' },
    body: JSON.stringify({ model: 'large-model', max_tokens: 100000, prompt, tools: ['refund_order'] }),
  }).then((r) => r.json());

  for (const call of llm.tool_calls || []) {
    if (call.name === 'refund_order') {
      await refundOrder(call.arguments.order_id, call.arguments.amount_cents);
    }
  }
  res.json({ reply: llm.text });
});

module.exports = router;
