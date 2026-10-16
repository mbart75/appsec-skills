# JavaScript and TypeScript (Node.js and front-end)

Sources: OWASP Node.js Security Cheat Sheet, OWASP Cross Site Scripting Prevention Cheat Sheet, framework security documentation (Express, Next.js, React).

## Server (Node.js, Express, Next.js, serverless functions)

| Check | Flaw | Expected |
|---|---|---|
| Query building | Template literals or `+` into SQL; raw query helpers with interpolation | Parameterised queries (`$1`, `?`), ORM query API |
| Command execution | `child_process.exec` with variables | `execFile`/`spawn` with argument arrays |
| Code evaluation | `eval`, `new Function`, `vm` as a sandbox | No dynamic code from input; `vm` is not a security boundary |
| Prototype pollution | Deep merge or `Object.assign` of request bodies into objects; `__proto__`, `constructor` keys accepted | Schema validation (zod, joi, ajv), `Object.create(null)`, maps |
| Validation | Request bodies used without type checks (`"1" * 2`, arrays where strings expected) | Schema validation at every entry point |
| Middleware order | Auth or rate limiting registered after the routes they should protect; static files served before auth | Security middleware first; review `app.use` order |
| Error handling | Error handler returning `err.stack` or `err.message` from the database | Generic message to the client, details in server logs |
| Next.js server actions and route handlers | Actions exported without auth checks (they are public endpoints); secrets read in client components; `NEXT_PUBLIC_` variables holding secrets | Auth and authorization inside every action; secrets only on the server |
| Async errors | Express 4 does not catch rejected promises in handlers (requests hang, process may crash) | Express 5, or an async wrapper, or try/catch |
| Headers and CORS | No security headers; reflected CORS | `helmet` with a real CSP; origin allow-list |
| Request limits | No body size limit, no timeouts | `express.json({ limit })`, timeouts, rate limits |

## Front-end (browser)

| Check | Flaw | Expected |
|---|---|---|
| DOM XSS | `innerHTML`, `outerHTML`, `insertAdjacentHTML`, `document.write`, `dangerouslySetInnerHTML`, `v-html` with data from the API, URL or storage | `textContent`, framework escaping, DOMPurify when HTML is needed |
| URL handling | `location = userValue`, `href` from data without scheme check | Allow-list `https:` and relative URLs |
| Secrets | API keys, service keys, private tokens in bundles or `config.js` | Only publishable keys; everything else behind the server |
| Authorization in the UI | Features hidden by `localStorage` flags or roles stored client-side | Server-side checks; the UI only reflects them |
| Storage | Session tokens in `localStorage` (readable by any XSS) | `HttpOnly` cookies where possible |
| `postMessage` | Listeners that do not check `event.origin` | Strict origin check |
| Third-party scripts | Unpinned CDN scripts, no SRI, tag managers loading arbitrary code | Pinned and integrity-checked, or self-hosted |
