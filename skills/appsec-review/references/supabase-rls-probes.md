# Supabase RLS probes

Ready-to-paste verification probes for the authorized-tests phase of `live-target.md`, when the browser talks to Supabase directly. They check that row-level security isolates accounts. Read `live-target.md` first: the authorization, the test-account setup and the table that turns each result into a reading are there, not repeated here. Probes show behaviour for the accounts used; the policies themselves are checked with `supabase-rls.md`.

Rules of use:

- Run only with the owner's written authorization, inside its scope, from **test accounts** created by a person. Never with a real user's account.
- A **person** pastes each snippet into the browser console of the signed-in test session. Nothing secret is written in a snippet: the session token is read from the page's storage at run time, and the key is the public one shipped to every visitor.
- Reads return **counts only** (`HEAD` with `Prefer: count=exact`): no row leaves the server. Writes touch **test data only** and are undone at once.
- Each snippet prints a JSON result: copy it into the report's Test log.

Fill the placeholders before running: `<PROJECT_REF>` (the subdomain of `https://<PROJECT_REF>.supabase.co`), `<PUBLIC_KEY>` (the publishable or `anon` key from the page), `<TABLE>`, `<EXISTING_COLUMN>` (a column the table really has, such as `user_id`: probing a missing column returns `400`, a probe error, not a result), `<OWNER_COLUMN>`, `<PRIMARY_KEY>`, `<VICTIM_USER_ID>` (a test account that holds data in the table), and for probe D `<PROTECTED_FIELD>` and `<ELEVATED_VALUE>`.

## Setup: paste once per console

Defines the helpers the four probes use. The session key below is the supabase-js v2 default; if the page stores the session elsewhere, adjust `STORAGE_KEY`. Paste it again after switching account or reloading the page. A `401` on a request sent with the session means a missing or expired token: a probe error, not "blocked".

```js
window.probe = (() => {
  const PROJECT_REF = "<PROJECT_REF>";
  const PUBLIC_KEY = "<PUBLIC_KEY>";
  const STORAGE_KEY = `sb-${PROJECT_REF}-auth-token`;
  const BASE = `https://${PROJECT_REF}.supabase.co/rest/v1/`;
  const session = JSON.parse(localStorage.getItem(STORAGE_KEY) || "null");
  const token = session && (session.access_token || (session.currentSession || {}).access_token);
  const me = session && (session.user || {}).id;
  // The public key goes in `apikey` only: newer `sb_publishable_` keys are not JWTs and do not belong in Authorization.
  const headers = (asUser) => (asUser ? { apikey: PUBLIC_KEY, Authorization: `Bearer ${token}` } : { apikey: PUBLIC_KEY });
  const pause = () => new Promise((r) => setTimeout(r, 300)); // stay gentle with a live service
  const count = async (table, query, asUser = true) => {
    await pause();
    const r = await fetch(`${BASE}${table}?${query}`, { method: "HEAD", headers: { ...headers(asUser), Prefer: "count=exact" } });
    return { status: r.status, count: (r.headers.get("content-range") || "*/?").split("/")[1] };
  };
  if (!token) console.warn("No session found under", STORAGE_KEY, "- sign in as the test account first");
  if (session && session.expires_at && session.expires_at * 1000 < Date.now()) console.warn("Session expired: reload the signed-in page, then paste this setup again");
  return { BASE, me, headers, count, pause };
})();
```

## A. Read reach per table: session versus public key

**Objective**: for each table, how many rows the signed-in test account sees, and how many the public key alone sees.

```js
await (async () => {
  const tables = { "<TABLE>": "<EXISTING_COLUMN>" }; // add one entry per table: { table: existing column }
  const out = {};
  for (const [table, col] of Object.entries(tables)) {
    out[table] = { session: await probe.count(table, `select=${col}`, true), publicKey: await probe.count(table, `select=${col}`, false) };
  }
  console.log(JSON.stringify({ probe: "A read reach", account: probe.me, out }, null, 2));
})();
```

**Reading** (with the table in `live-target.md`): `publicKey` count above 0 on user data is an anonymous leak. A `session` count above the rows this account owns means the policy is too wide. `0` everywhere on a fresh account is inconclusive: run B with a victim that holds data.

## B. Another account's rows: unrelated user or role

**Objective**: whether an account with no link to the victim can read the victim's rows. Run it twice: first in the **victim's** session (the count must be above 0, or the result will be inconclusive), then in the **unrelated** account's session.

```js
await (async () => {
  const VICTIM = "<VICTIM_USER_ID>";
  const checks = [["<TABLE>", "<EXISTING_COLUMN>", "<OWNER_COLUMN>"]]; // [table, column to select, column holding the owner id]
  const out = {};
  for (const [table, col, owner] of checks) {
    out[table] = await probe.count(table, `select=${col}&${owner}=eq.${VICTIM}`, true);
  }
  console.log(JSON.stringify({ probe: "B other account", account: probe.me, victim: VICTIM, out }, null, 2));
})();
```

**Reading**: in the victim's session, a count of 0 means the probe cannot fail: add data first. In the unrelated session, any count above 0 is a cross-account leak (a finding); `0` while the victim holds data is a real "blocked".

## C. A write that must be refused, undone automatically

**Objective**: whether the account can insert a row it should not be allowed to create, for example a row owned by the victim, or a link row that grants itself access to the victim. If the insert succeeds, the snippet deletes **that row only**, by the primary key the server returned, and reports how many rows the undo removed.

```js
await (async () => {
  const TABLE = "<TABLE>", PRIMARY_KEY = "<PRIMARY_KEY>"; // the column that identifies one row, often "id"
  const row = { "<OWNER_COLUMN>": "<VICTIM_USER_ID>" /* , other required columns with harmless test values */ };
  const r = await fetch(probe.BASE + TABLE, {
    method: "POST",
    headers: { ...probe.headers(true), "Content-Type": "application/json", Prefer: "return=representation" },
    body: JSON.stringify(row),
  });
  const body = await r.json().catch(() => null);
  const out = { probe: "C refused write", account: probe.me, table: TABLE, status: r.status, inserted: r.status < 300, body };
  if (out.inserted) {
    const created = Array.isArray(body) && body.length === 1 ? body[0] : null;
    if (!created || created[PRIMARY_KEY] === undefined) {
      out.undo = "NOT DONE: no primary key in the response; delete the row by hand and list it under Test artefacts to remove";
    } else {
      await probe.pause();
      const d = await fetch(`${probe.BASE}${TABLE}?${PRIMARY_KEY}=eq.${encodeURIComponent(created[PRIMARY_KEY])}`, {
        method: "DELETE",
        headers: { ...probe.headers(true), Prefer: "return=representation" },
      });
      const removed = await d.json().catch(() => null);
      out.undo = { status: d.status, rowsRemoved: Array.isArray(removed) ? removed.length : "unknown" };
    }
  }
  console.log(JSON.stringify(out, null, 2));
})();
```

**Reading**: `403` or code `42501` is blocked. `201` is a finding, whatever the undo did. The undo must report `rowsRemoved: 1`; anything else (`0`, `unknown`, `NOT DONE`) means the test row may still be there: list it under *Test artefacts to remove*. A `400` usually means a required column is missing from `row`: a probe error, not a pass. The undo never deletes by the columns you sent, because a permissive policy would then delete every matching row, not just the test one.

## D. A protected field, judged on the returned row

**Objective**: whether the account can change a field it must not control on its own row, such as `role`, a plan, a verified flag or a price. The snippet reads the original value, attempts the change, judges by the row the server returns, and restores the original if it changed.

```js
await (async () => {
  const TABLE = "<TABLE>", KEY = "<OWNER_COLUMN>", FIELD = "<PROTECTED_FIELD>", ATTEMPT = "<ELEVATED_VALUE>";
  const own = `${KEY}=eq.${probe.me}`;
  const get = await fetch(`${probe.BASE}${TABLE}?select=${FIELD}&${own}`, { headers: probe.headers(true) });
  const current = await get.json().catch(() => null);
  if (!get.ok || !Array.isArray(current) || current.length !== 1) {
    return console.log(JSON.stringify({ probe: "D protected field", error: "probe error: own row not readable once", status: get.status, current }, null, 2));
  }
  const before = current[0][FIELD];
  if (String(before) === String(ATTEMPT)) {
    return console.log(JSON.stringify({ probe: "D protected field", error: "probe error: the account already holds the attempted value", before }, null, 2));
  }
  await probe.pause();
  const r = await fetch(`${probe.BASE}${TABLE}?${own}&select=${FIELD}`, {
    method: "PATCH",
    headers: { ...probe.headers(true), "Content-Type": "application/json", Prefer: "return=representation" },
    body: JSON.stringify({ [FIELD]: ATTEMPT }),
  });
  const rows = await r.json().catch(() => null);
  const after = Array.isArray(rows) && rows[0] ? rows[0][FIELD] : undefined;
  const out = { probe: "D protected field", account: probe.me, table: TABLE, field: FIELD, before, status: r.status, after, changed: after !== undefined && String(after) === String(ATTEMPT) };
  if (out.changed) {
    await probe.pause();
    const u = await fetch(`${probe.BASE}${TABLE}?${own}`, {
      method: "PATCH",
      headers: { ...probe.headers(true), "Content-Type": "application/json" },
      body: JSON.stringify({ [FIELD]: before }),
    });
    out.restoreStatus = u.status;
  }
  console.log(JSON.stringify(out, null, 2));
})();
```

**Reading**: judge by `after`, never by `status` alone. A `probe error` line means the account could not read its own row exactly once (wrong `KEY`, or no row), or already holds `ATTEMPT` (pick a value it does not have): fix the probe. `changed: true` is a finding (privilege escalation if the field is a role). `200` with `after` equal to `before` means the field was ignored: blocked, and worth a note (a `4xx` would be clearer). `200` with an empty array means the update matched no row the account may change: blocked by policy. If `restoreStatus` is not `2xx`, list the row under *Test artefacts to remove*.
