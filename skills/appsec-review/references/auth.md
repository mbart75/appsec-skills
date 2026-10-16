# Authentication and sessions

Sources: OWASP ASVS 5.0 V6 (Authentication) and V7 (Session Management), OWASP Authentication, Password Storage, Forgot Password and Session Management Cheat Sheets, NIST SP 800-63B.

First question: **is authentication hand-written?** A managed provider (Supabase Auth, Auth0, Clerk, Firebase Auth, Cognito, an OIDC library) removes most of this list. Hand-written login code deserves the full checklist.

## Passwords

| Check | Flaw | Expected |
|---|---|---|
| Storage | Plain text, reversible encryption, MD5, SHA-1, SHA-256 without a slow KDF, no salt | Argon2id, scrypt or bcrypt with library defaults or stronger |
| Comparison | `===` on hashes or secrets | The library's verify function (constant time) |
| Policy | No minimum length, or arbitrary composition rules | Minimum 8 (12 or more recommended), maximum at least 64, no forced composition, check against breached passwords if possible |
| Enumeration | Different messages, status codes or timings for "unknown account" and "wrong password", on login, registration and reset | One generic answer; same work done in both branches |
| Brute force | No rate limit or lockout on login, reset and verification endpoints | Limits per IP *and* per account; behind a proxy, the client IP must come from a trusted hop |

## Password reset and e-mail verification

| Check | Flaw | Expected |
|---|---|---|
| Token randomness | `Math.random`, timestamps, ids, short codes | At least 128 bits from a CSPRNG (`crypto.randomBytes`, `secrets.token_urlsafe`) |
| Token storage | Stored in clear | Stored hashed, compared by hash |
| Lifetime and reuse | No expiry; still valid after use | Short expiry (15 to 60 minutes), single use, invalidated on success |
| Link construction | Reset URL built from the `Host` header | Fixed, configured base URL |
| After reset | Existing sessions kept | All sessions of the account revoked |
| E-mail ownership | Account usable without proving the address | Verification before sensitive use |

## Sessions and tokens

| Check | Flaw | Expected |
|---|---|---|
| Session id | Predictable, short, or reused across logins | CSPRNG, at least 128 bits, new id at login and privilege change |
| Cookie flags | Missing `HttpOnly`, `Secure`, `SameSite` | All three; `SameSite=Lax` or `Strict`; scoped `Path` and no broad `Domain` |
| Expiry | No server-side expiry; logout only clears the cookie | Idle and absolute timeouts enforced on the server; logout deletes the server session |
| JWT | `alg: none` accepted, signature not verified, secret hard-coded or weak, no `exp`, tokens in `localStorage` holding broad rights | Verified signature with a fixed algorithm, short expiry, revocation strategy |
| CSRF | Cookie-authenticated state changes reachable cross-site (forms, `SameSite=None`, permissive CORS) | `SameSite`, CSRF tokens for form posts, strict CORS |

## MFA and privileged accounts

- Admin and staff accounts should require MFA. Report its absence as a hardening finding, with severity depending on what admins can do.
- The developers' own accounts (code host, cloud, database, domain registrar, CI) are the real keys to the application: recommend MFA there in pre-launch mode.

## How to verify

Name the request and the outcome: "`POST /api/auth/forgot-password` then guessing tokens built from `Date.now()` and `Math.random()` allows resetting any account's password; tokens never expire and stay valid after use".
