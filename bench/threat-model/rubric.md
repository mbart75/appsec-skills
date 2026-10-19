# Threat-model bench: rubric

One point per item met, judged from the files and the final answer. Written on 2026-10-19 before the first run.

## S1 (17 points)

Shape
1. The model is written to project files under `docs/security/` (not `SECURITY.md`, not only in chat).
2. A data-flow diagram shows the trust boundaries explicitly (browser, Vercel functions, Supabase, Stripe, Twilio, LLM API).
3. Assets are listed and include personal data, payment state, the admin account and the API keys.
4. Each threat names the boundary it crosses and a concrete scenario, not only a STRIDE category.
5. Requirements are testable: each one says how to verify it.
6. Requirements are traceable to threats (IDs or explicit links).
7. The committed documents describe intended defences, not a list of current gaps.
8. Unknowns are handled: a few targeted questions or stated assumptions, not a long interview that blocks.

Content
9. Supabase: the browser talks to the database, so row-level security on every table and the service key never in client code.
10. Stripe: the deposit amount is set server-side; payment status comes only from a signature-verified webhook, idempotent.
11. Refunds: only the owner can issue them, server-side authorization, amount capped by what was paid.
12. AI assistant: rescheduling goes through a server-side tool that checks the customer owns the appointment; content the assistant reads is treated as data (indirect prompt injection); no other capabilities.
13. Cost abuse: SMS pumping or toll fraud through Twilio, LLM spend; rate limits and caps.
14. Account takeover: MFA for the admin, and MFA on the developer's own accounts (Vercel, Supabase, Stripe, Twilio, domain).
15. Booking logic: double booking or slot hoarding races, cancellation and refund abuse.
16. Personal data: minimisation and retention (GDPR), or an explicit pointer to a compliance step.
17. Secrets: per-environment keys, test versus live keys, rotation.

## S2 (12 points)

Shape
1. The feature's requirements are added to the project's security documents (a feature section), without rewriting what exists.
2. Abuse cases are written from the attacker's side.
3. Requirements are testable, each with its verification.
4. The answer uses what already exists in the codebase (its auth, rate limiting, schema) rather than generic advice.

Content
5. Codes: generated with a CSPRNG, long enough not to be guessed, stored hashed, never logged.
6. Redemption brute force: rate limits per account and per IP, generic error messages.
7. Double spend: balance checks and deductions in one transaction with row locking (race between parallel checkouts).
8. Amounts: computed server-side, non-negative, partial use cannot create value (rounding, refunds).
9. Issuance only after a confirmed payment (webhook), idempotent.
10. Refund or chargeback of a gift card that has already been spent.
11. A code is a bearer secret: e-mail delivery risks, ability to revoke and reissue, balance lookup without leaking other codes.
12. Audit trail of issuance and every redemption.
