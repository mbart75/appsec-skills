// Thin wrapper around the payment provider.
async function refundOrder(orderId, amountCents) {
  await fetch('https://payments.provider.example/v1/refunds', {
    method: 'POST',
    headers: { Authorization: `Bearer ${process.env.PAYMENTS_API_KEY}`, 'Content-Type': 'application/json' },
    body: JSON.stringify({ order: orderId, amount: amountCents }),
  });
}

module.exports = { refundOrder };
