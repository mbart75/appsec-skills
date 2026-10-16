const express = require('express');
const cookieParser = require('cookie-parser');
const { currentUser } = require('./session');

const app = express();
app.use(express.json());
app.use(cookieParser());

app.use((req, res, next) => {
  res.setHeader('Access-Control-Allow-Origin', req.headers.origin || '*');
  res.setHeader('Access-Control-Allow-Credentials', 'true');
  res.setHeader('Access-Control-Allow-Headers', 'Content-Type, X-Admin');
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
  res.status(500).json({ error: err.message, stack: err.stack });
});

app.listen(process.env.PORT || 3000);
