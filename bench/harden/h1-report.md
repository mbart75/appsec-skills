# Security review: tinyshop

| | |
|---|---|
| Date | 2026-10-19 |
| Mode | full (excerpt: three findings) |

## Summary

| ID | Severity | Title | Location | Status |
|---|---|---|---|---|
| APPSEC-A | Critical | SQL injection in product search | `server/routes/products.js:12-14` | open |
| APPSEC-B | Medium | Session cookie without HttpOnly, Secure, SameSite | `server/routes/auth.js` (`res.cookie('sid', sid)`) | open |
| APPSEC-C | Critical | Supabase service_role key shipped to the browser | `public/config.js:4` | open |

## Findings

### APPSEC-A · Critical · SQL injection in product search

- **Location**: `server/routes/products.js:12-14`
- **Status**: open

**Fix**: Use a bound parameter: `WHERE name ILIKE '%' || $1 || '%'` with `[search]`. Limit `search` to a string of at most 100 characters.

**Done when**: the query uses `$1`; `grep -n "+ search +" server/routes/products.js` returns nothing.

### APPSEC-B · Medium · Session cookie without HttpOnly, Secure, SameSite

- **Location**: `server/routes/auth.js`, `res.cookie('sid', sid)`
- **Status**: open

**Fix**: `res.cookie('sid', sid, { httpOnly: true, secure: true, sameSite: 'lax', maxAge: 7 * 24 * 60 * 60 * 1000, path: '/' })`.

**Done when**: the cookie call sets the three flags.

### APPSEC-C · Critical · Supabase service_role key shipped to the browser

- **Location**: `public/config.js:4`
- **Status**: open

**Fix**: Replace the key in `public/config.js` with the project's anon key (to be provided by the owner; use a placeholder `REPLACE_WITH_ANON_KEY` until then), make sure row-level security covers every table, and **rotate the service_role key** in the Supabase dashboard: it is public as long as it was ever deployed.

**Done when**: no `service_role` JWT remains in `public/`; the owner confirms rotation.

## Hand-off

> Fix the findings of this security report, in order of severity. One commit per finding with the finding ID in the message, then change its Status in this file to `fixed`. Never weaken a security control. Rotation is done by the owner.
