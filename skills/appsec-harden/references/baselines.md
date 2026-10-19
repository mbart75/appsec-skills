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

## Shell, PowerShell, Python quick wins

| Change | Check |
|---|---|
| Bash: `set -euo pipefail`, quoted expansions, `"${VAR:?}"` before destructive commands, no `eval` on input | `shellcheck` clean |
| PowerShell: no `Invoke-Expression` on input, credentials from SecretManagement, no `-SkipCertificateCheck` | `Invoke-ScriptAnalyzer` clean for the changed rules |
| Python: `yaml.safe_load`, `subprocess` with argument lists, `secrets` for tokens | `bandit` clean for the changed rules |
