# Threat catalogue by component

A prompt list, not a checklist to copy: keep only what applies, and write each threat as a concrete scenario for this system. Requirement patterns are phrased as behaviour so they can be verified.

Sources: OWASP ASVS 5.0, OWASP Top 10 2025, OWASP API Security Top 10 2023, OWASP Top 10 for LLM Applications 2025, OWASP MASVS 2.

## Browser front-end

| Threat | Requirement pattern |
|---|---|
| Secrets or privileged keys in the bundle | Only keys designed to be public ship to the client; a build check fails on known secret patterns |
| Authorization enforced only in the UI | Every action is authorized on the server; UI state never grants rights |
| XSS through user content or URLs | Output encoding by default; HTML from users only through a sanitiser; strict CSP |
| Third-party scripts | Minimal set, pinned, integrity-checked or self-hosted |

## API and server functions

| Threat | Requirement pattern |
|---|---|
| IDOR: acting on another user's object by changing an id | Every read and write by id checks ownership from the session |
| Mass assignment of role, price, status, owner | Writes accept an explicit allow-list of fields |
| Client-supplied business facts (price, total, status) | The server recomputes every amount and status from its own data |
| Server functions or actions exposed as public endpoints | Each one authenticates and authorizes itself |
| Resource exhaustion | Body size limits, pagination maximums, timeouts, rate limits |

## Authentication and sessions

| Threat | Requirement pattern |
|---|---|
| Credential stuffing, brute force, enumeration | Rate limits per account and per IP; identical responses for unknown accounts |
| Reset and verification token abuse | Random, hashed, short-lived, single-use tokens; sessions revoked after reset |
| Role stored where users can write it | Roles live in server-controlled storage only |
| Admin takeover | MFA for admin and staff; step-up for sensitive actions |

## Database reachable from the client (Supabase, Firebase)

| Threat | Requirement pattern |
|---|---|
| Table without row-level security, or permissive policies | RLS on every exposed table; policies tied to the authenticated user; a CI check lists tables without RLS |
| Service or admin key in client code | Privileged keys only on the server |
| Writes to fields the user must not control | Column grants, `with check` policies or server functions for writes |

## Payments

| Threat | Requirement pattern |
|---|---|
| Amount set by the client | Amounts computed server-side from configuration |
| Paid status from a redirect page | Status changes only from a signature-verified, idempotent webhook |
| Refund abuse | Refunds by authorized roles only, capped by what was captured, audited, idempotent |
| Card testing and fraud | Provider fraud tools, velocity limits, 3-D Secure |
| Stored value (credits, gift cards, wallets) | Atomic balance updates in one transaction, append-only ledger, reconciliation |

## Messaging: e-mail, SMS, push

| Threat | Requirement pattern |
|---|---|
| Cost abuse (SMS pumping to premium numbers, mass sending) | Sending only for verified recipients, rate limits per account and per destination, geographic restrictions, spend alerts |
| Relay: sending to arbitrary addresses or numbers | Recipients come from verified account data, never from the request |
| Sensitive data or secrets in message bodies and links | Minimal content; links carry opaque, expiring tokens |
| Forged inbound callbacks | Provider signatures verified |

## AI features (assistants, agents, tools)

| Threat | Requirement pattern |
|---|---|
| Direct and indirect prompt injection steering tools | Every tool authorizes on the server with the caller's identity; the model never supplies the user id |
| Excessive agency | Tool allow-list limited to the feature; money and irreversible actions need human confirmation the model cannot give |
| Data leakage through the context | Only data the current user may see enters the prompt; no secrets; assume the system prompt leaks |
| Output used as code, HTML, URLs | Model output encoded or validated like user input; no remote images or links that could exfiltrate |
| Unbounded consumption | Per-user quotas, token and tool-call limits, provider spending cap |

## Files and uploads

| Threat | Requirement pattern |
|---|---|
| Path traversal, overwrite | Generated names; storage outside the web root |
| Malicious content to processors | Type allow-list with content check, size limits, sandboxed processing |
| Public buckets | Private by default; signed, expiring URLs |

## Background jobs, cron, webhooks

| Threat | Requirement pattern |
|---|---|
| Anyone triggers a job endpoint | Job endpoints require a secret or platform authentication |
| Replay and duplicates | Idempotency keys and unique constraints |
| Jobs acting with full privileges for any user | Jobs re-check permissions for the user they act for |

## Admin back office

| Threat | Requirement pattern |
|---|---|
| Insider or compromised admin | Least-privilege roles, dual control for money adjustments, append-only audit log |
| Bulk data export | Step-up authentication, logging, rate limits |

## Development and deployment (often forgotten)

| Threat | Requirement pattern |
|---|---|
| Takeover of developer accounts (code host, hosting, database, payment and AI dashboards, domain registrar, DNS) | MFA on every one of these accounts; recovery codes stored offline |
| Production secrets in preview or test environments | Separate keys per environment; test keys outside production |
| Leaked secret | Rotation procedure, tested; secret scanning with push protection |
| Supply chain | Lockfile, pinned CI actions, review of new dependencies, update delay |
| Lost data | Backups with a tested restore |

## Personal data

| Threat | Requirement pattern |
|---|---|
| Over-collection, indefinite retention | Collect only what the feature needs; a retention period per data type; deletion and export flows |
| Personal data in logs, analytics, error tracking, prompts | Redaction before logging; processors under contract |
| Special categories (health, minors) | Explicit decision and consent flow before collecting |

Legal pages and French requirements are covered by `appsec-compliance-fr`.
