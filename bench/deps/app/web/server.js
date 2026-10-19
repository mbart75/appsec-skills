const express = require('express');
const path = require('path');
const _ = require('lodash');
const config = require('./config.json');

const app = express();
app.set('view engine', 'ejs');
app.set('views', path.join(__dirname, 'views'));
app.use(express.json({ limit: '100kb' }));
app.use(express.static(path.join(__dirname, 'public')));

// Notes are kept in memory in this demo; each one holds rich text written by the user.
const notes = [];

app.get('/api/notes', (req, res) => {
  res.json(notes);
});

app.post('/api/notes', (req, res) => {
  const html = String(_.get(req.body, 'html', '')).slice(0, 5000);
  notes.push({ id: notes.length + 1, html });
  res.status(201).json({ id: notes.length });
});

// Printable invoice: every query parameter becomes a template variable (number, customer, amount, ...).
app.get('/invoice', (req, res) => {
  res.render('invoice', { margin: _.get(config, 'pdf.margin', 10), ...req.query });
});

// Proxy to the report service; the browser's User-Agent is forwarded for the audit log.
app.get('/reports/monthly', async (req, res) => {
  const month = /^\d{4}-\d{2}$/.test(String(req.query.month)) ? req.query.month : '';
  const upstream = await fetch(`${_.get(config, 'reports.url')}/reports/monthly?month=${month}`, {
    headers: { 'User-Agent': req.get('User-Agent') || '' },
  });
  res.status(upstream.status).type('application/json').send(await upstream.text());
});

app.listen(_.get(config, 'server.port', 3000));
