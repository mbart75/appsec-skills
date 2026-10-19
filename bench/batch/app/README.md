# Receiptly

Expense receipts for small teams. Members upload receipts as JSON exported from their banking app; a job imports them every five minutes.

- `server/upload.js`: `POST /receipts` (signed-in members) stores the uploaded file in `inbox/`.
- `jobs/import-receipts.js`: run by cron (`*/5 * * * * node jobs/import-receipts.js`), imports every file in `inbox/` into the database and moves it to `done/`.
