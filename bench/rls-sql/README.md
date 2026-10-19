# Supabase SQL bench

Tests the Supabase SQL that the skills publish, on a throwaway local PostgreSQL:

- `01-supabase-sim.sql`: a minimal stand-in for a Supabase project (API roles `anon`, `authenticated`, `service_role`; `auth.uid()` and `auth.jwt()` read from request settings; Supabase's default grants).
- `02-baseline.sql`: the *Supabase RLS, safe baseline* of `appsec-harden`, on a generic schema (profiles, notes, links).
- `03-bad.sql`: misconfigurations the checklist must flag (a table without RLS, `with check (true)`, a `security definer` function without `search_path`, a view without `security_invoker`).
- `04-behaviour.sql`: each account plays its part (owner, unrelated account, grantee, staff with and without a second factor, public key); every check prints PASS or FAIL.
- `05-detection.sql`: the checklist's catalogue queries flag each misconfiguration and none of the baseline objects.
- `queries.txt`: every read-only query published in `supabase-rls.md` and `baselines.md`, verbatim; `run.sh` fails if one drifts from its document or does not run.

```bash
bash bench/rls-sql/run.sh        # PostgreSQL 15+ on PATH, or PG_BIN=<bin dir>
```

The database lives in a temporary folder, listens on a Unix socket only, and is deleted at the end. Run it after any change to Supabase SQL in the skills.

## Results

PostgreSQL 17.11, 2026-10-20: 28 behaviour and detection checks pass, 13 published queries in sync and running. Mutation check, to prove the bench can fail: granting `update` on the whole profile table fails checks 10 and 23; `with check (true)` on the notes insert policy fails 08 (and 16, 18 through the forged row); removing the `aal2` policy fails 15.
