# Secrets and supply chain

Sources: OWASP Secrets Management Cheat Sheet, OWASP Top 10 2025 A03 (Software Supply Chain Failures), OpenSSF Scorecard checks, SLSA.

## Secrets

| Check | Flaw | Expected |
|---|---|---|
| In the code | Keys, passwords, tokens, connection strings with passwords in source, config, scripts, notebooks, tests | Environment variables or a secret manager; `.env.example` with placeholders only |
| In the client | Anything shipped to a browser or mobile app is public: front-end bundles, `NEXT_PUBLIC_*`, `VITE_*`, `config.js`, app binaries | Only keys designed to be public (publishable keys, Supabase `anon` with RLS, Firebase config with rules) |
| In history | Removed from the current tree but present in an earlier commit | Treat as leaked |
| In logs, errors, reports | Secrets printed by debug logging, error pages, CI output, or copied into audit reports | Redaction everywhere, including your own report |
| `.gitignore` | `.env`, key files, Terraform state and `*.tfvars` not ignored | Ignored before the first commit |

**A leaked secret is fixed by rotating it, not by deleting it.** Rewriting history is optional clean-up; revoking the key at its issuer is the fix. Say so in every secret finding, and name every secret to rotate.

Judging a match: decode before rating. A JWT's payload is base64: read its `role` or scope. A key prefix often tells test from live (`pk_` versus `sk_`, `_test_` versus `_live_`). An example value from documentation is not a secret.

## Dependencies

| Check | Flaw | Expected |
|---|---|---|
| Version pinning | `*`, `latest`, open ranges for production dependencies; no lockfile committed | Lockfile committed; installs from it (`npm ci`, `pip install --require-hashes`, `poetry install --sync`) |
| Known vulnerabilities | Vulnerable versions in the lockfile | Upgrade, or document why the vulnerable code path is unreachable |
| Install scripts | `postinstall` scripts from dependencies run on every install, including in CI with secrets | `--ignore-scripts` in CI where possible; review new dependencies |
| New and unknown packages | Typosquats, very new or low-reputation packages, packages pulled from a git URL | Check name, publisher, age and downloads; malicious-package scanners |
| Update policy | Automatic adoption of versions published hours ago | Renovate or Dependabot with a release-age delay of a few days |
| Third-party scripts at runtime | CDN scripts without version pinning or Subresource Integrity | Pinned version and `integrity` attribute, or self-hosted |
| Container images | `latest` tags, unpinned base images, images running as root | Pinned digests, minimal base, non-root user |

## Repository hygiene for public projects

- Branch protection or rulesets on the default branch; required reviews for outside contributions.
- Secret scanning and push protection enabled (free on public repositories of the major hosts).
- A `SECURITY.md` telling people how to report a vulnerability.
- Reports, threat-model gap lists and scanner outputs are never committed.
