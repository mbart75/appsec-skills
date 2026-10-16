# TinyShop

Small online shop: product catalogue, reviews, orders, a support chatbot and image thumbnails.

- `server/`: Express API (Node.js 22), Postgres hosted on Supabase
- `public/`: vanilla JavaScript front-end
- `worker/`: thumbnail generator (Python 3.12, ImageMagick), run every minute by cron
- `infra/`: Terraform for the uploads bucket and the application role
- `scripts/`: deployment and staff synchronisation
- `supabase/schema.sql`: database schema

```bash
npm install
DATABASE_URL=postgres://... LLM_API_KEY=... npm start
```
