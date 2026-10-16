# APIs

Sources: OWASP API Security Top 10 2023, OWASP REST Security and GraphQL Cheat Sheets.

Read with `access-control.md` (API1 and API5 are authorization) and `auth.md` (API2).

| OWASP API 2023 | Check | Flaw |
|---|---|---|
| API1 Broken Object Level Authorization | Every id in a path, query or body is checked against the caller | `GET /orders/:id` returns any order |
| API2 Broken Authentication | Token validation, expiry, brute-force limits on every auth endpoint, including mobile and legacy ones | A `/v1/login` without the limits of `/v2/login` |
| API3 Broken Object Property Level Authorization | Responses list explicit fields; writes accept an allow-list of fields | `SELECT *` or full model returned; mass assignment of `role`, `price`, `owner_id` |
| API4 Unrestricted Resource Consumption | Pagination maximums, body size, upload size, timeouts, rate limits, cost of operations (SMS, e-mail, LLM) | `?limit=1000000`; unauthenticated endpoints that cost money per call |
| API5 Broken Function Level Authorization | Admin and internal routes require the right role on the server | Admin routes protected by obscurity or client-side checks |
| API6 Unrestricted Access to Sensitive Business Flows | Purchase, sign-up, referral, booking flows protected against automation | Bots buying stock or farming referral credits |
| API7 Server Side Request Forgery | User-supplied URLs fetched by the server | See `web-app.md` |
| API8 Security Misconfiguration | CORS, verbose errors, debug endpoints, default credentials, missing TLS | Swagger UI or GraphQL introspection exposing internal operations in production |
| API9 Improper Inventory Management | Old versions, staging and debug endpoints still deployed | `/api/v1` without the fixes of `/api/v2` |
| API10 Unsafe Consumption of APIs | Data from third-party APIs trusted without validation; webhooks without signature check | Webhook marks an order paid on an unsigned request |

GraphQL specifics: depth and complexity limits, authorization in every resolver (not only at the top query), introspection off in production when the schema is not public, batching limits against brute force.
