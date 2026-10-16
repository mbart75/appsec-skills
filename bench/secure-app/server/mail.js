// Sends transactional e-mails through the provider's HTTP API.
async function sendMail(to, text) {
  await fetch('https://mail.provider.example/v1/send', {
    method: 'POST',
    headers: { Authorization: `Bearer ${process.env.MAIL_API_KEY}`, 'Content-Type': 'application/json' },
    body: JSON.stringify({ from: 'no-reply@tinyshop.example', to, text }),
  });
}

module.exports = { sendMail };
