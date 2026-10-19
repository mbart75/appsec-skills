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
| Known vulnerabilities | Vulnerable versions in a lockfile, a vendored file or an image | Triage below |
| Install scripts | `postinstall` scripts from dependencies run on every install, including in CI with secrets | `--ignore-scripts` in CI where possible; review new dependencies |
| New and unknown packages | Typosquats, very new or low-reputation packages, packages pulled from a git URL | Check name, publisher, age and downloads; malicious-package scanners |
| Update policy | Automatic adoption of versions published hours ago | Renovate or Dependabot with a release-age delay of a few days |
| Third-party scripts at runtime | CDN scripts without version pinning or Subresource Integrity | Pinned version and `integrity` attribute, or self-hosted |
| Container images | `latest` tags, unpinned base images, images running as root | Pinned digests, minimal base, non-root user |

## Known vulnerabilities: triage

A list of CVEs is not a list of findings. Three questions decide each one: is it exploited in the wild, is it likely to be, and does this code reach it.

1. **Inventory what ships**, not only lockfiles. OSV-Scanner reads manifests and lockfiles; it does not see vendored or copied libraries (`vendor/`, `public/`, `static/`, a `*.min.js` with a version banner, a copied jar). Read their version from the banner or file name and add them: `python3 -I <this skill's folder>/scripts/cve-priority.py <out_dir> --package npm:jquery@3.4.1`.
2. **Exploitation data**: `run-scanners.sh` runs `cve-priority.py`, which writes `cve-priority.md`: each advisory with whether it is in the CISA **KEV** catalog (known exploited in the wild) and its **EPSS** score (probability of exploitation in the next 30 days), known exploited first. If it could not run, say so in the report.
3. **Reachability**, per advisory: read what the advisory says is vulnerable (a function, an option, a parser, a feature), find whether the code uses it, and whether input an attacker controls gets there. A sanitiser in front of the library does not make it unreachable when the advisory is about bypassing that kind of sanitiser (jQuery `.html()` after DOMPurify).
4. **Rate**:

| Situation | Rating |
|---|---|
| Reachable and in KEV | Rate the impact as for any finding, never below High; Critical when it gives code execution or full data access without an account. **First in the fix order** |
| Reachable, not in KEV | Rate the impact as for any finding; among findings of the same severity, the higher EPSS comes first |
| In KEV, reachability not established | At least Medium; what would decide reachability goes to Open questions |
| Not reachable: the vulnerable function or feature is not used | Low at most, whatever its CVSS or EPSS, with the reason written; the upgrade is still recommended |

Rate the worst realistic deployment: do not lower a reachable known-exploited flaw because of hardening you cannot see (a recent runtime, a WAF); write that condition as an open question instead.

5. **In each dependency finding**, fill the *Known vulnerability* line of the template: CVE, KEV yes or no (with the date added), EPSS score and date, the first fixed version and the recommended current one. One upgrade often closes several advisories: list them.

## Repository hygiene for public projects

- Branch protection or rulesets on the default branch; required reviews for outside contributions.
- Secret scanning and push protection enabled (free on public repositories of the major hosts).
- A `SECURITY.md` telling people how to report a vulnerability.
- Reports, threat-model gap lists and scanner outputs are never committed.
