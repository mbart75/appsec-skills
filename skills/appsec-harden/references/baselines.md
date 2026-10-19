# Hardening baselines

Each baseline is a list of changes. Apply only the items that fit the project; each item is a change in the loop of `SKILL.md`, with its own check.

## GitHub Actions workflows

| Change | Check |
|---|---|
| Untrusted triggers: replace `pull_request_target` with `pull_request` for any job that checks out or runs PR code | Workflow no longer references the PR head in a `pull_request_target` job |
| Untrusted values (`github.event.*.title`, `body`, `head_ref`, comment bodies, commit messages) move from `${{ }}` inside `run:` to `env:`, used as quoted shell variables | `zizmor` reports no `template-injection` |
| Top-level `permissions: contents: read`; widen per job only where needed | `zizmor` reports no `excessive-permissions` |
| Every action pinned to a full commit SHA with the version in a comment, SHAs looked up, never typed from memory | `zizmor` reports no `unpinned-uses`; each SHA resolves with `gh api repos/<owner>/<repo>/commits/<sha>` |
| Third-party actions that cannot be verified (no repository, no release) are removed or replaced, not pinned blindly | Listed in the final answer |
| `persist-credentials: false` on `actions/checkout` unless a later step pushes | `zizmor` reports no `artipacked` |
| Secrets only in jobs that never run untrusted code; deployments behind protected environments | Review of each `secrets.` reference |
| Dependency installs in CI use the lockfile and skip install scripts where possible (`npm ci --ignore-scripts`) | Workflow text |

Tooling: `zizmor --offline <workflow files>` (static audits), `actionlint`.

## HTTP security headers and cookies

| Change | Check |
|---|---|
| `Content-Security-Policy` without `unsafe-inline` for scripts where feasible; `frame-ancestors 'none'` or `'self'` | Response headers in a test or `curl -sI` against a local run |
| `Strict-Transport-Security` on HTTPS deployments | Same |
| `X-Content-Type-Options: nosniff`, `Referrer-Policy: strict-origin-when-cross-origin` or stricter | Same |
| Session cookies: `HttpOnly`, `Secure`, `SameSite=Lax` or `Strict`, scoped `Path`, no broad `Domain` | Code and a test asserting the `Set-Cookie` attributes |
| CORS: explicit origin allow-list, credentials only for listed origins | Test with an unlisted `Origin`: no `Access-Control-Allow-Origin` |
| Error responses without stack traces or internal messages | Test or code review of the error handler |

Framework helpers when present: `helmet` (Express), `next.config.js` headers, Django `SECURE_*` settings, Flask-Talisman.

## Repository hygiene

| Change | Check |
|---|---|
| `.gitignore` covers `.env*` (except `.env.example`), key files, Terraform state and variables, local tooling folders | `git check-ignore -v` on sample paths |
| Secret scanning before commit (`gitleaks` pre-commit hook or CI step) | `gitleaks detect` runs clean on the repository |
| `SECURITY.md` with a private reporting route | File present |
| Lockfile committed; installs from it | `npm ci` / `pip install --require-hashes` / equivalent succeeds |
| Dependency updates with a release-age delay (Renovate `minimumReleaseAge`, Dependabot `cooldown`) | Configuration file |

## Secrets in code

| Change | Check |
|---|---|
| Secret removed from code and read from the environment or a secret manager; `.env.example` gets a placeholder | `gitleaks` on the working tree is clean |
| Owner told which secret to rotate, where, and that it remains in git history | Final answer lists it under "left for a person" |
| History rewrite only if the owner asks, after rotation | Not done by default |

## Supabase RLS, safe baseline

For an app whose browser talks to Supabase directly. Write each change as a SQL migration (`supabase/migrations/`), apply it locally first (`supabase db reset`), and keep the policy tests with the code (`supabase test db` with pgTAP when the project has it). What to look for in existing policies is in `appsec-review/references/supabase-rls.md`.

| Change | Check |
|---|---|
| RLS enabled **and forced** on every table in an exposed schema: `alter table public.<table> enable row level security;` then `alter table public.<table> force row level security;` (forced also applies to the table owner) | `select relname, relrowsecurity, relforcerowsecurity from pg_class where relnamespace = 'public'::regnamespace and relkind = 'r';` both `true` on every row |
| Default deny, then one policy per operation and per role: `for select`, `for insert`, `for update`, `for delete`, each `to authenticated` (or `to anon` only for data meant to be public); no `for all`, no `using (true)` on user data | `select tablename, cmd, roles, permissive from pg_policies where schemaname = 'public' order by 1, 2;` one row per table, command and role, nothing wider than intended |
| Ownership on both sides: `using ((select auth.uid()) = <owner_column>)` on select, update and delete; `with check ((select auth.uid()) = <owner_column>)` on insert and update. The owner column is `not null default auth.uid()` | Same query with `qual` and `with_check`; a probe as another account (`supabase-rls-probes.md`, B and C) is refused |
| Privileged fields (`role`, `status`, `plan`, verified flags) out of the user's reach, with an **explicit refusal**: either a `before insert or update` trigger that sets the default on insert and raises an exception when a non-privileged caller changes the field, or column privileges (`revoke update on public.<table> from authenticated;` then `grant update (<editable columns>) on public.<table> to authenticated;`; revoking one column alone does not override a table-wide grant). Prefer a refused request over a `200` that silently ignores the field | `select grantee, column_name, privilege_type from information_schema.column_privileges where table_schema = 'public' and table_name = '<table>';` no `UPDATE` on privileged columns for `authenticated` or `anon`; probe D returns a `4xx` |
| Profiles created by the server, not the browser: a trigger on `auth.users` inserts the profile with the default role; no client `insert` policy on the profile table | Sign-up of a test account sending a privileged role gets the default role |
| Access to another account's data only through a relation row that the **data owner** creates or activates: the related account's `select` policy is `using (exists (select 1 from public.<links> l where l.<owner_column> = <table>.<owner_column> and l.<grantee_column> = (select auth.uid()) and l.status = 'active'))`; on the link table, `insert` and the `update` that sets `status` are allowed only with `with check (<owner_column> = (select auth.uid()))` | Probe C as the related account (creating or activating its own link) is refused; probe B before activation returns `0` |
| `security definer` only when needed, and hardened: `set search_path = ''` with schema-qualified names; caller identity from `auth.uid()`, never a parameter; returns only the needed columns; `revoke execute on function public.<fn>(<args>) from public, anon;` then `grant execute ... to authenticated;` where intended; keep such functions out of exposed schemas when the client does not call them | `select p.proname, p.proconfig from pg_proc p join pg_namespace n on n.oid = p.pronamespace where n.nspname = 'public' and p.prosecdef;` every `proconfig` sets `search_path`; `information_schema.routine_privileges` shows no unintended `EXECUTE` |
| Views in exposed schemas created `with (security_invoker = true)` | `select relname, reloptions from pg_class where relnamespace = 'public'::regnamespace and relkind = 'v';` |
| Second factor for sensitive roles: TOTP MFA enabled in Auth, and a `restrictive` policy on the tables those roles reach that requires `(select auth.jwt() ->> 'aal') = 'aal2'` for them | A session of that role without the second factor reads `0` rows (probe B) |
| Size and shape limits on client-written columns: `alter table public.<table> add constraint <table>_data_size check (octet_length(<column>::text) <= <limit>);` and `jsonb_typeof(<column>) = 'object'` where the shape matters | An oversized insert is refused with code `23514` |
| Auth settings (dashboard, left to a person if you have no access): minimum password length 12 or more, leaked-password protection on, e-mail confirmation on, a dedicated SMTP sender for production (the built-in one is rate-limited and meant for testing), rate limits kept | Values noted in the final answer; a 9-character password is refused at sign-up |

Tooling: the dashboard's Security Advisor (RLS disabled, mutable `search_path`, `security definer` views), pgTAP for policy tests.

After hardening, replay the probes of `appsec-review/references/supabase-rls-probes.md` from the same test accounts, then run `appsec-review` in `verify` mode on the report.

## Shell, PowerShell, Python quick wins

| Change | Check |
|---|---|
| Bash: `set -euo pipefail`, quoted expansions, `"${VAR:?}"` before destructive commands, no `eval` on input | `shellcheck` clean |
| PowerShell: no `Invoke-Expression` on input, credentials from SecretManagement, no `-SkipCertificateCheck` | `Invoke-ScriptAnalyzer` clean for the changed rules |
| Python: `yaml.safe_load`, `subprocess` with argument lists, `secrets` for tokens | `bandit` clean for the changed rules |
