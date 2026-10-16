# Web application

Sources: OWASP ASVS 5.0 V1 (Encoding and Sanitization), V3 (Web Frontend Security), V5 (File Handling), V13 (Configuration), V16 (Security Logging and Error Handling); OWASP Cheat Sheets: Cross Site Scripting Prevention, SQL Injection Prevention, Server Side Request Forgery Prevention, File Upload, HTTP Headers, CORS.

## Injection: find the source, follow it to the sink

An injection exists when attacker-controlled data reaches an interpreter without being kept as data. Name both ends.

| Sink | Flaw | Expected |
|---|---|---|
| SQL | String concatenation or template literals into a query | Bound parameters or a query builder; identifiers from an allow-list |
| NoSQL | Request objects passed as filters (`{ $ne: null }`) | Type checks; explicit fields |
| OS commands | `exec`, `system`, `shell=True`, backticks with user data | Argument arrays, no shell; allow-listed values |
| HTML (XSS) | `innerHTML`, `outerHTML`, `document.write`, `dangerouslySetInnerHTML`, `v-html`, unescaped template output | Text APIs (`textContent`), framework auto-escaping, sanitiser (DOMPurify) only when HTML is required |
| URLs | `href`/`src` from user data (`javascript:` URLs), open redirects | Scheme allow-list; redirect targets from an allow-list |
| Templates | User data compiled as a template (SSTI) | Data passed as variables only |
| Deserialization | `pickle`, `yaml.load`, Java/PHP native deserialization of untrusted data | Safe loaders, plain JSON, signed payloads |

"Sanitising input" is not the defence for XSS: encoding at output, for the context where the data lands, is.

## Server-side request forgery

Any feature that fetches a URL chosen by a user (link previews, webhooks, imports, image proxies, PDF renderers, OAuth and JWKS discovery URLs) can reach internal services and cloud metadata (`169.254.169.254`). Expected: allow-list of hosts, HTTPS only, timeouts and size limits, and every one of these checks applied correctly:

| Check | Bypass when it is done wrong |
|---|---|
| The address is validated **and the connection goes to that same address** | Validating the result of one DNS lookup, then letting the HTTP client resolve the name again, is a time-of-check to time-of-use gap: a DNS rebinding server answers a public IP to the check and an internal IP to the connection. The fix pins the validated IP (custom `lookup`/agent, or connect by IP with the original `Host` header and SNI) |
| Every resolved address is checked, not only the first | A name with several A/AAAA records passes on the first and connects to another |
| Each redirect hop is re-validated | A public URL redirects to an internal one; `redirect: 'follow'` never shows it to the check |
| The deny-list is complete | `0.0.0.0/8`, `::`, IPv4-mapped IPv6 (`::ffff:127.0.0.1`), `fc00::/7`, `fe80::/10`, decimal and octal IPv4 forms, `localhost` subdomains |
| The protection is on by default | An opt-in safety option that callers forget to set |

A deny-list alone is a weak finding, not a fix. When the code has an SSRF defence, test each row against it: the defence existing is where the interesting flaws start.

## Files

| Check | Flaw | Expected |
|---|---|---|
| Path traversal | `path.join(dir, userInput)`, `open(base + name)` | Generated names; or resolve and verify the result stays inside the base directory |
| Upload type | Extension or `Content-Type` trusted | Allow-list plus content check (magic bytes); store outside the web root |
| Upload size and count | No limit | Size limit, quotas |
| Processing | Uploaded files fed to ImageMagick, LibreOffice, ffmpeg, unzip | Sandboxed workers, explicit format, decompression limits (zip bombs, zip slip) |
| Serving | User files served from the application origin | Separate domain or `Content-Disposition: attachment` and correct `Content-Type` |

## Browser security configuration

| Check | Expected |
|---|---|
| CORS | Allow-list of origins. Reflecting `Origin` with `Access-Control-Allow-Credentials: true` lets any site read authenticated responses: Medium to High |
| Security headers | `Content-Security-Policy`, `Strict-Transport-Security`, `X-Content-Type-Options: nosniff`, `frame-ancestors` (or `X-Frame-Options`), `Referrer-Policy` |
| HTTPS | Enforced; HSTS on production |
| Third-party scripts | Pinned versions, Subresource Integrity on CDN scripts, minimal set |

## Errors and logging

- Responses never include stack traces, SQL errors, internal paths or versions.
- Security events (logins, failures, permission denials, admin actions) are logged without passwords, tokens or full personal data.
- Errors fail closed: an exception in an authorization check denies.

## Personal data in responses

APIs often return more than the screen shows (`SELECT *`, full user objects, e-mails of other users next to their content). Check what each public or cross-user response contains. Exposure of other users' personal data is a finding even without an injection (GDPR data minimisation).
