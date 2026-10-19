# Access control

Broken access control is the most common serious flaw in web applications (OWASP A01:2025) and scanners almost never find it: it is the absence of a check, not the presence of a bad function. Find it by asking, for every operation, *who is allowed to do this, and where is that enforced?*

Sources: OWASP ASVS 5.0 V8 (Authorization), OWASP Authorization Cheat Sheet, OWASP API Security Top 10 2023 (API1, API3, API5).

## Method

1. List every entry point that reads or changes data: HTTP routes, RPC and server actions, GraphQL resolvers, queue consumers, scheduled jobs, webhooks, direct database access from the client (Supabase, Firebase).
2. For each, write down the rule in one sentence ("a customer reads only their own orders", "only admins change roles").
3. Find where the code enforces it. It must be **on the server**, on **every** request, from **server-side identity** (the session or a verified token), never from something the client sends.

## Checklist

| Check | What a flaw looks like | Verify |
|---|---|---|
| Object ownership (IDOR/BOLA) | `SELECT ... WHERE id = $1` with the id from the URL and no owner condition | The query or a guard ties the object to `req.user` (`AND user_id = $2`), or a policy does |
| Function-level authorization | Admin routes checked by a header, a cookie flag, a hidden button or `localStorage` | The server reads the role from its own session or database |
| Role and privilege changes | Any user can set `role`, `is_admin`, `plan`, `price` through a generic update (mass assignment) | Updates use an explicit allow-list of fields |
| Client-side gates | UI hides admin features; the API behind them is open | Call the API without the UI condition: it must refuse |
| Multi-tenant isolation | Tenant id taken from the request body or subdomain without checking membership | Tenant derived from the authenticated identity |
| Direct database access from the browser | Supabase/Firebase used from the front-end | See *Row-level security* below |
| Indirect references | Sequential ids leaking volume or enabling enumeration | Ownership check is the fix; random ids alone are not access control |
| Files and exports | Download or export endpoints that take a path or id | Same ownership check as the data they contain |
| Background and async paths | Jobs, webhooks and queues trusting the caller | Webhooks verify a signature; jobs re-check permissions for the user they act for |

## Row-level security (Supabase, Postgres, Firebase)

When the browser talks to the database directly, the database *is* the API, and its policies are the only access control.

- **Which key ships to the browser?** Decode the JWT payload (base64) and read `role`. `anon` is meant to be public. **`service_role` bypasses every policy: in client code it is Critical**, whatever else is configured.
- **RLS enabled on every table** in exposed schemas: `alter table ... enable row level security`. A table without it is fully readable and writable with the anon key.
- **RLS enabled with no policy denies everything** to `anon` and `authenticated`. That is safe, not a gap. Do not report it as "missing policies".
- **Policies with `using (true)`** on anything but public data (a product catalogue) expose every row. Ownership policies compare to `auth.uid()`.
- `for update` and `for insert` need `with check`, not only `using`, or a user can write rows they cannot read.
- Server code connecting with the owner or `service_role` role bypasses RLS: then the server code must do the checks itself.
- Firebase: rules like `allow read, write: if true;` or `if request.auth != null` (any logged-in user) on user data are the same flaw.
- Supabase: the full list of what to verify in the policies, each with the query that answers it, is in `supabase-rls.md`.

## Reporting

Name the operation, the rule it should enforce, and the request an attacker sends: "As customer A, `GET /api/orders/1042` returns customer B's order including address". Rate by the data or action exposed: other users' personal data or money movement is High; full admin or full database is Critical.
