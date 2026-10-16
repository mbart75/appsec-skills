# Pre-launch checklist

For an application about to go live, often built quickly or with AI help. Each item gets a verdict: **pass**, **fail** (with the finding ID), **n/a**, or **unknown** (with what is needed to decide). Any Critical or High failure means **NO-GO**.

Explain each failed item in plain words: the people launching may not be security specialists.

## Secrets and keys

1. No secret in the code, the history or the front-end bundle; only keys designed to be public ship to the browser or the app.
2. Every secret that was ever committed or shared has been rotated.
3. Development and production use different keys, databases and accounts.

## Accounts and access

4. Login, registration and password reset are safe: slow password hashing (or a managed auth provider), generic error messages, rate limits, single-use expiring reset links.
5. Every request that reads or changes data checks, on the server, that this user may do it (no access to other accounts by changing an id).
6. Admin features are protected on the server, and admin accounts use MFA.
7. Database access from the browser is locked by row-level security or rules, on every table.
8. The developers' own accounts (code host, hosting, database, domain registrar, payment provider, AI provider) use MFA.

## Data handling

9. Inputs are validated on the server; queries are parameterised; user content is encoded when displayed.
10. Prices, totals, quotas and statuses are computed by the server, never taken from the client.
11. Uploaded files are restricted in type and size and stored under generated names.
12. Responses contain only the data the screen needs; no personal data of other users.
13. Only the personal data the product needs is collected (see `appsec-compliance-fr` for the legal pages).

## Platform

14. HTTPS everywhere with HSTS; security headers set; CORS limited to known origins.
15. Error messages shown to users contain no technical details.
16. Dependencies are pinned with a committed lockfile and have no known critical vulnerability.
17. Costs are capped: AI provider spending limit, per-user quotas on expensive actions, cloud budget alert.
18. Backups exist and a restore has been tested.
19. Logs record security events without passwords or tokens, and someone will see an alert.

## AI features (if any)

20. The model cannot perform sensitive actions (payments, refunds, deletions, messages) without server-side authorization and, for anything costly or irreversible, human confirmation.
21. Content written by other users or fetched from outside is treated as data, never as instructions.

## Mobile app (if any)

22. No secret in the app binary; tokens in Keychain or Keystore; the backend enforces every rule (see `mobile.md`).
