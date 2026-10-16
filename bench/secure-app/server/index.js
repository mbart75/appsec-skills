const express = require('express');
const helmet = require('helmet');
const cookieParser = require('cookie-parser');
const { currentUser } = require('./session');

const ALLOWED_ORIGINS = new Set(['https://tinyshop.example']);

const app = express();
app.use(
  helmet({
    contentSecurityPolicy: {
      directives: { 'connect-src': ["'self'", 'https://qzvtkmwbrlnhxpsd.supabase.co'] },
    },
  })
);
app.use(express.json({ limit: '100kb' }));
app.use(cookieParser());

app.use((req, res, next) => {
  const origin = req.headers.origin;
  if (origin && ALLOWED_ORIGINS.has(origin)) {
    res.setHeader('Access-Control-Allow-Origin', origin);
    res.setHeader('Access-Control-Allow-Credentials', 'true');
    res.setHeader('Access-Control-Allow-Headers', 'Content-Type');
  }
  res.setHeader('Vary', 'Origin');
  next();
});

app.use(currentUser);
app.use(express.static('public'));

app.use('/api/auth', require('./routes/auth'));
app.use('/api/products', require('./routes/products'));
app.use('/api/orders', require('./routes/orders'));
app.use('/api/uploads', require('./routes/uploads'));
app.use('/api/chat', require('./routes/chat'));
app.use('/api/admin', require('./routes/admin'));

app.use((err, req, res, next) => {
  console.error(err);
  res.status(500).json({ error: 'Internal error' });
});

app.listen(process.env.PORT || 3000);
