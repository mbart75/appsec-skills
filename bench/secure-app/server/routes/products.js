const express = require('express');
const db = require('../db');
const { requireUser } = require('../session');

const router = express.Router();
const PREVIEW_HOSTS = new Set(['github.com', 'en.wikipedia.org', 'www.youtube.com']);

router.get('/', async (req, res) => {
  const search = typeof req.query.search === 'string' ? req.query.search.slice(0, 100) : '';
  const { rows } = await db.query(
    "SELECT id, name, price_cents FROM products WHERE name ILIKE '%' || $1 || '%' ORDER BY name LIMIT 50",
    [search]
  );
  res.json(rows);
});

router.get('/:id/reviews', async (req, res) => {
  const { rows } = await db.query('SELECT author, body FROM reviews WHERE product_id = $1', [req.params.id]);
  res.json(rows);
});

router.post('/:id/reviews', requireUser, async (req, res) => {
  const body = req.body.body;
  if (typeof body !== 'string' || body.length === 0 || body.length > 2000) {
    return res.status(400).json({ error: 'A review is 1 to 2000 characters' });
  }
  await db.query('INSERT INTO reviews (product_id, author, body) VALUES ($1, $2, $3)', [
    req.params.id,
    req.user.display_name,
    body,
  ]);
  res.status(201).end();
});

// Shows the title of a link pasted in a review. Only well-known hosts, HTTPS, no redirects.
router.get('/preview', requireUser, async (req, res) => {
  let url;
  try {
    url = new URL(req.query.url);
  } catch {
    return res.status(400).json({ error: 'Invalid URL' });
  }
  if (url.protocol !== 'https:' || url.port !== '' || !PREVIEW_HOSTS.has(url.hostname)) {
    return res.status(400).json({ error: 'Previews are limited to a few known sites' });
  }
  const response = await fetch(url, { redirect: 'error', signal: AbortSignal.timeout(3000) });
  const html = (await response.text()).slice(0, 200_000);
  const title = (html.match(/<title>(.*?)<\/title>/i) || [])[1] || '';
  res.json({ title: title.slice(0, 200) });
});

module.exports = router;
