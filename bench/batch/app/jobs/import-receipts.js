const fs = require('fs/promises');
const path = require('path');
const db = require('../server/db');

const INBOX = path.join(__dirname, '..', 'inbox');
const DONE = path.join(__dirname, '..', 'done');

async function importFile(name) {
  const receipt = JSON.parse(await fs.readFile(path.join(INBOX, name), 'utf8'));
  await db.query(
    'INSERT INTO receipts (member_id, merchant, amount_cents, spent_on) VALUES ($1, $2, $3, $4)',
    [receipt.memberId, String(receipt.merchant).slice(0, 200), Math.round(Number(receipt.amount) * 100), receipt.date],
  );
  await fs.rename(path.join(INBOX, name), path.join(DONE, name));
}

async function main() {
  const files = (await fs.readdir(INBOX)).filter((f) => f.endsWith('.json')).sort();
  for (const name of files) {
    await importFile(name);
  }
  await db.end();
}

main();
