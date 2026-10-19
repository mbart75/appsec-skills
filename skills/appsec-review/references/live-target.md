# Live target: a deployed application without its source

Use when the review has a URL but no repository, or when tests are run against a running system. Black-box results can show that isolation fails; they can never prove that it holds. Always ask for the code or an export of the access rules (for Supabase: `pg_policies` and the RLS flag of each table) as the definitive answer.

## Phases, in this order

| Phase | What | Needs |
|---|---|---|
| 1. Passive | What any visitor's browser receives: response headers, TLS, the HTML and every shipped script (read them: routes, table names, roles, keys), source maps, cookies and storage before consent, third-party requests, `robots.txt`, `/.well-known/security.txt`. Decode any key found (a Supabase JWT `role` of `service_role` in the browser is Critical). Note the version of every shipped library (banner comment, file name, `jQuery.fn.jquery` in the console) and check it with `<this skill's folder>/scripts/cve-priority.py <out_dir> --package` | Nothing: this is ordinary browsing. Start here while authorization and code are requested |
| 2. Authorized tests | Signed-in requests and crafted requests to the API, with test accounts | The owner's written authorization, with an explicit scope (below) |
| 3. Code or policies | The definitive check of everything phases 1 and 2 could not prove (for Supabase: `supabase-rls.md`) | Read access to the repository, or the exported rules |

## Authorization

- Written (message, e-mail), from the owner, before phase 2. Record in the report: who, when, channel, and the exact scope: which roles or areas, reads only or writes too, production or a copy.
- Stay inside the scope. A test outside it is not run; if one was run, the report says so and the owner is told before anything else.
- A **person** (the user or the owner) creates the test accounts and signs in. Never use real users' accounts. The agent writes the probes; if it cannot send them, the person pastes them into the signed-in browser console.
- Never degrade the live service: no scanners, fuzzing or brute force; a few requests per check. A `429` means stop and wait.

## Probes that can fail

A probe that cannot fail proves nothing. Set up before probing:

- a **victim** test account that holds data in every table probed (create a record, a note, a message first);
- an **unrelated** test account per role (another user of the same role, a privileged role not linked to the victim).

Then:

- **Reads: count only, filtered on the victim**: `HEAD /rest/v1/<table>?select=<existing column>&<owner column>=eq.<victim id>` with `Prefer: count=exact`; read the total in `Content-Range`. No rows leave the server.
- **Writes: test data only, undone at once**: request `Prefer: return=representation`, then delete or revert, and log both.

| Observed | Meaning |
|---|---|
| `200`, count `0`, victim holds data | Read blocked: a real result |
| `200`, count `0`, table empty for everyone probed | **Inconclusive**: RLS working and RLS absent look the same |
| `200`, count `> 0` from an unrelated account or the anonymous key | Data leak: a finding |
| `400` / `404` (unknown column or table) | **Probe error**, not a result: fix the probe and re-run |
| `401` / `403`, or Postgres code `42501` | Blocked by policy |
| `201` on a write that should be refused | The control is missing: a finding |
| `200` on a write, returned row unchanged | Field ignored: blocked, note it (a `4xx` would be clearer). Judge writes by the returned or re-read row, never by the status alone |
| `429` | Rate limit: stop |

For a Supabase back end, `supabase-rls-probes.md` has these probes ready to paste into the console: read reach per table, another account's rows, a refused write and a protected field, each undoing its own writes.

## Report

Follow `report-template.md`, with the live-target rows and sections filled:

- The header describes the **final** state of the review. When a phase is added, rewrite Mode, Scope, Testing and the Verdict; never leave an earlier "passive only" or "no account created" in place.
- A confirmed result is a **finding with an ID**, or the answer to an open question. A test log alone changes nothing for whoever executes the report.
- If the application is **already live with real users**, the verdict says what to do now (contain, stop promotion, fix first), not only "before launch".
- **Test log**: one row per probe: date, account and role, exact request, result, reading. Precise enough for a `verify` run to repeat it.
- **Test artefacts to remove**: every test account (address or id, never a password) and every row it created, for the owner to delete from production.
