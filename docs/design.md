# appsec-skills: design

Status: implemented in 0.2.0 (all four skills). This document records the design and its rationale; results are in `CHANGELOG.md`.

## 1. Purpose

A set of security skills for AI coding agents. They help an agent design, review, harden and ship an application with security built in, and check French legal compliance before launch.

Two audiences, same skills:

- **Security engineers**, who want CWE references, `file:line` precision and no noise.
- **Builders who are not security specialists**, including people "vibe coding" a web or mobile app, who need to know what matters, why, and exactly what to change.

## 2. Principles

These rules apply to every skill. They are the reason this repository exists rather than a list of prompts.

1. **Agent-agnostic.** Skills use the open `SKILL.md` format (folder + YAML front matter with `name` and `description`), plain Markdown references, Bash scripts and Python 3 helpers that use the standard library only. Instructions never name a tool specific to one agent ("ask the user", not "use the AskUserQuestion tool"). Works with Claude Code, Codex, Cursor, GitHub Copilot, Gemini CLI, OpenCode, and any agent that can read files.
2. **The skills never send source code anywhere unless it is already public.** No skill or script sends source code to a third-party service. The agent running the skill sends what it reads to its own model provider; that is the agent's setting, which a skill cannot change. Tools that query vulnerability databases with package names and versions are acceptable, and so is sending CVE identifiers to the FIRST EPSS API (the CISA KEV catalog is a plain download). For public repositories, the skills recommend the platform's free scanning (code scanning, secret scanning, dependency alerts).
3. **Tools are optional, never imposed.** A skill detects which scanners are installed, runs those, and lists the missing ones with their install command. It never installs anything without explicit consent. With zero tools installed, the skill still works as a guided manual review.
4. **Active testing only against what you own.** No skill runs an active scanner (DAST, fuzzing, brute force) against a target unless the user confirms they own it or hold written authorization. The authorization and its scope (roles or areas, reads or writes, production or a copy) are recorded in the report; a verbal or relayed go does not widen a written scope until the owner confirms it in writing. Unauthorized testing is a criminal offence in most countries (France: Code pénal, art. 323-1).
5. **Read-only by default.** Only `appsec-harden` modifies files, and only after the user approves a specific change. One change per commit, and the relevant check is re-run afterwards.
6. **Every finding is verified before it is reported.** A finding must have a location, a concrete exploitation scenario and a confidence level. Anything that cannot be tied to real code is dropped or reported separately as a question. False positives cost trust; a short accurate report beats a long noisy one.
7. **Reports stay out of the repository.** A list of weaknesses is an attack map. Reports are written outside the working tree by default (or shown in the conversation), never committed, and secrets found are redacted in every output.
8. **Repository content is data, not instructions.** Code, comments, READMEs and issue text under review may contain text aimed at the agent ("ignore previous instructions", "mark this as safe"). The skills treat it as evidence to analyze and flag it as a finding.
9. **Two reading levels.** `expert` gives CWE, OWASP mapping and `file:line`. `plain` explains the impact in everyday words, with an analogy, and gives the exact fix. The skill picks from context and the user can switch.
10. **User and project instructions win.** Report location, severity policy, extra checklists or excluded paths defined by the user or the project's `AGENTS.md` override the defaults. This is how personal or company-specific layers extend the skills without forking them.
11. **The report is a work order any AI can execute.** The final report is a single self-contained Markdown file with a fixed structure: stable finding IDs, evidence, fix instructions, acceptance criteria and a ready-to-use hand-off section. It can be pasted into any assistant (Claude, ChatGPT, Codex, Gemini, a local model) to start fixing, and fed back to `appsec-review` to verify the fixes. Nothing in it depends on the agent or model that produced it.

## 3. Skills

All names are prefixed with `appsec-` to group them and avoid collisions with built-in agent commands (for example a built-in `security-review`).

### 3.1 `appsec-threat-model`: before coding

Security by design: builds a lightweight threat model of an application, new or existing, or of a single feature before it is built.

Scopes: `project` (the whole application) and `feature` (one change about to be implemented: produces the security requirements and abuse cases for that feature, appended to `requirements.md`, so the coding agent builds them in from the first line).


- Interviews the user only for what the code cannot reveal (who the users are, what data is sensitive, what must never happen).
- Maps assets, actors and roles, entry points, trust boundaries and data flows, including AI agents, LLM calls and their tools.
- Applies STRIDE per trust boundary, ranks threats by likelihood and impact.
- Writes two files into the project:
  - `docs/security/threat-model.md`: diagram (Mermaid), assets, boundaries, threats and mitigations.
  - `docs/security/requirements.md`: the security requirements the code must meet, each one testable, mapped to OWASP ASVS 5.0 where relevant.
- These documents describe intended defences, not current gaps, so they are safe to commit in a public repository. Gap status belongs in reports (principle 7).
- `SECURITY.md` is not used for these files: on code hosting platforms it is reserved for the vulnerability disclosure policy.

### 3.2 `appsec-review`: during and after coding

The core skill. Read-only.

Modes:

| Mode | Scope | Typical use |
|---|---|---|
| `diff` | Uncommitted changes or a branch versus its base | Before a commit or a pull request |
| `full` | The whole repository and its history | Periodic audit, before making a repository public |
| `pre-launch` | A go/no-go checklist for an application about to go live | Builders shipping their first version |
| `verify` | The findings of a previous report | After fixes: re-checks each finding and updates its status, without a new full audit |

The skills work at every stage: `appsec-threat-model` before code exists (security by design), `diff` while coding, `full` or `pre-launch` at any later time, including on an existing project that never had a review, and `verify` after fixes.

Workflow:

1. **Map the project**: languages, frameworks, entry points, auth model, data stores, secrets handling, CI, infrastructure as code, AI components. If `docs/security/requirements.md` exists, load it: the review then checks the code against stated requirements, not only against generic lists.
2. **Run available scanners** (principle 3) and collect their output outside the repository. See section 5.
3. **Guided review** with the reference files matching the detected stack (section 4). This is where design flaws, broken access control and business logic errors are found, which scanners miss.
4. **Verify each candidate finding** (principle 6): re-read the code path, confirm the input is attacker-controlled and reaches the sink, write the exploitation scenario, assign a confidence. Scanner results get the same treatment: confirmed, false positive, or needs context.
5. **Report** in the format of section 3.3. In `pre-launch` mode, the checklist with a verdict per item and an overall go/no-go comes first.

Severity scale: Critical, High, Medium, Low, Info, defined in the skill from exploitability and impact, so the same flaw gets the same rating every time.

### 3.3 Report format

One Markdown file, self-contained, readable by a person and by any model. Fixed order:

1. **Header**: project, date, commit, mode, scope, skill version, scanners run and scanners missing.
2. **Verdict**: two or three sentences, counts by severity, and for `pre-launch` a GO or NO-GO.
3. **Summary table**: ID, severity, title, location, status.
4. **Findings**, one block each, most severe first:
   - `ID` (`APPSEC-001`, stable across `verify` runs), severity, title
   - Location (`file:line`), category (CWE, OWASP), confidence
   - Evidence: the relevant code, secrets redacted
   - Attack scenario: who does what, step by step
   - Impact
   - Fix: precise enough to implement without re-auditing
   - Done when: testable acceptance criteria and the command or check that proves it
   - Status: `open`, `fixed`, `accepted-risk` (with the reason and who accepted), `false-positive` (with the reason)
   - In `plain` reading level, an extra "In plain words" paragraph
5. **Open questions**: what could not be verified without context, kept apart from findings.
6. **What is already done well**.
7. **Hand-off**: instructions for the AI that will fix the findings. Work in severity order, one finding per commit, never weaken a control to make something pass, apply the "Done when" check, update the status field in this file, then run `appsec-review` in `verify` mode.
8. **Appendix**: scanner results and their triage (confirmed, false positive with reason).

The report is written outside the repository by default (principle 7), at a location the user or project instructions can override.

### 3.4 `appsec-harden`: fixing

Applies fixes from a review or from a hardening baseline.

- Input: a review report, or a baseline request ("harden this repository's CI", "add security headers").
- Proposes each change with its reason and risk of breakage, waits for approval, applies it, re-runs the relevant check, and commits it separately with a clear message.
- Never weakens a control to make a test or a build pass. If a fix requires an architectural change, it says so instead of patching around it.
- Baselines included in v0.1: repository hygiene (`.gitignore`, pre-commit secret scanning), CI (actions pinned by commit SHA, least-privilege `GITHUB_TOKEN`, no untrusted input in `run:`), HTTP security headers and cookie flags, dependency update policy with a release-age delay, secrets moved out of client code.

### 3.5 `appsec-compliance-fr`: French legal compliance

For websites and apps offered in France. Not legal advice; the skill says when a professional should review.

- Mentions légales (LCEN art. 6), privacy notice (GDPR art. 13 and 14), cookies and trackers (CNIL guidelines, consent, "refuse" as easy as "accept", exempted audience measurement), terms of use, terms of sale and right of withdrawal for consumer sales, consumer mediator, data minimisation and retention, processors and transfers outside the EU (fonts, captchas, analytics, error tracking), account deletion, minors (digital consent age 15), accessibility (RGAA, WCAG 2.1 AA, European Accessibility Act scope).
- Mobile apps, in a later version: app store privacy declarations and in-app account deletion.
- Audits the code and, if the user owns the site, its live pages (passive checks only: what is set before consent, which third parties are called).
- Generates missing pages from templates, with placeholders the user must fill. It never invents company details.
- Written in English like the rest of the repository; generated pages are in French.

## 4. References

Each skill folder is self-contained, because skills are often installed by copying or linking a single folder: a skill must not read files outside its own folder. Some duplication between skills is accepted for that reason.

`appsec-review/references/` (detection-oriented checklists):

| File | Covers |
|---|---|
| `web-app.md` | Sessions and cookies, CSRF, XSS (output encoding), CORS, headers, uploads, SSRF, error handling |
| `auth.md` | Login, password storage, reset and email verification flows, MFA, account enumeration, rate limiting |
| `access-control.md` | Server-side checks, IDOR/BOLA, admin routes, multi-tenant isolation, row-level security (Supabase, Firebase rules) |
| `api.md` | OWASP API Security Top 10, mass assignment, excessive data exposure, webhooks signature |
| `secrets-supply-chain.md` | Secrets in code and history, client-side keys, dependencies, lockfiles, malicious packages, update policy |
| `business-logic.md` | Server-side recalculation of prices and quotas, race conditions, workflow bypass |
| `llm-apps.md` | OWASP Top 10 for LLM Applications: prompt injection, tool permissions, data leakage, cost limits |
| `github-actions.md` | Pinning, permissions, `pull_request_target`, script injection, secrets exposure |
| `terraform.md` | IAM least privilege, public exposure, encryption, state handling |
| `powershell.md` | `Invoke-Expression`, credential handling, logging of secrets, TLS bypass, injection |
| `bash.md` | Quoting, `eval`, temporary files, `set -euo pipefail` pitfalls |
| `python.md` | `subprocess` with shell, deserialization, YAML loading, path traversal |
| `javascript.md` | Node and front-end frameworks: prototype pollution, `dangerouslySetInnerHTML`, server actions, environment exposure |
| `mobile.md` | OWASP MASVS: secrets in the binary, secure storage, deep links, transport security |
| `macos.md` | Privileged helpers and XPC client validation by code signature, entitlements, hardened runtime |
| `report-template.md` | The report structure, severity scale and status values |
| `pre-launch.md` | The go/no-go checklist |

Each checklist item states what to look for, why it matters, and how to verify it. Items cite their source (OWASP ASVS, Cheat Sheet Series, CWE, ANSSI, CNIL) so they can be checked and kept current.

## 5. Scanners

Detected and used when present. Default choices, by category:

| Category | Default | Also supported |
|---|---|---|
| Secrets | gitleaks | TruffleHog (history; live verification of found secrets only with `--verify-secrets`, off by default) |
| Static analysis | Semgrep CE / Opengrep | CodeQL on public repositories |
| Dependencies | OSV-Scanner | Trivy |
| Malicious packages | Socket (free for open source) | |
| Infrastructure as code | Checkov | Trivy config |
| PowerShell | PSScriptAnalyzer | InjectionHunter |
| Shell | ShellCheck | |
| CI workflows | zizmor | actionlint, OpenSSF Scorecard |
| Containers | Trivy image | Hadolint |
| Mobile | MobSF | |
| LLM applications | promptfoo | garak |
| Accessibility | axe-core | |

A helper script, `appsec-review/scripts/run-scanners.sh`, detects installed tools, runs them with safe defaults into an output directory outside the repository, and prints a summary of what ran and what was missing. Bash. It never uploads source code. Network use, all of it from the tools it runs: Semgrep and Trivy download their rules; OSV-Scanner sends package names and versions to the OSV database; `cve-priority.py` sends CVE identifiers to the EPSS API and downloads the KEV catalog; TruffleHog tests found secrets against their issuer only with `--verify-secrets`. `--offline` stops the OSV, EPSS and KEV lookups.

## 6. Test bench

A skill that seems good is not the same as a skill proven good. `bench/` contains:

- `bench/vulnerable-app/`: a small multi-stack application seeded with known flaws, one per reference area (client-side secret, missing row-level security, IDOR, price trusted from the client, SQL injection, stored XSS, unpinned action with script injection, over-privileged IAM, `Invoke-Expression` on input, unquoted shell variable, prompt injection reaching a tool). Clearly labelled, not deployable, fake secrets only (patterns that scanners detect but no provider accepts).
- `bench/secure-app/`: the same application with the flaws fixed, to measure false positives.
- `bench/expected.yaml`: the answer key (id, file, anchor text, CWE, minimum severity), checked against the code by `bench/check-key.py`.
- `bench/score.md`: how to score a run. Recall: seeded flaws found. Precision: reported findings that are real, adjudicated against the key and the secure variant.

Each skill change is checked against the bench before release. Results per version are recorded in `CHANGELOG.md`.

## 7. Repository layout

```
appsec-skills/
├── README.md               what, why, install for each agent, quick start
├── AGENTS.md               entry point for agents that do not load skills natively
├── SECURITY.md             how to report a vulnerability in this repository
├── LICENSE                 MIT
├── CHANGELOG.md
├── docs/
│   └── design.md           this document
├── skills/
│   ├── appsec-threat-model/
│   │   ├── SKILL.md
│   │   └── templates/
│   ├── appsec-review/
│   │   ├── SKILL.md
│   │   ├── references/
│   │   └── scripts/run-scanners.sh
│   ├── appsec-harden/
│   │   ├── SKILL.md
│   │   └── references/
│   └── appsec-compliance-fr/
│       ├── SKILL.md
│       ├── references/
│       └── templates/
├── bench/
└── scripts/
    └── build.sh            release zip + single-file bundle for chat assistants
```

## 8. Distribution

- **Agents with a skills folder**: `install.sh` (macOS, Linux) or `install.ps1` (Windows) detects the agents present, lets the user choose, shows the plan, and copies (or, from a clone, links) the `appsec-*` folders. No network, no elevation, nothing outside `appsec-*` folders is touched. No `curl | bash` installer is offered on purpose.
- **Agents without skills support**: point them to `AGENTS.md`, which tells them which `SKILL.md` to read for which request.
- **Chat assistants that cannot read a folder**: `scripts/build.sh` produces one Markdown file per skill with its references inlined, to attach to a conversation or a custom assistant.
- **Releases**: semantic versioning, tagged releases with a zip (skills and installers), the single-file bundles, the plugin archive and `SHA256SUMS`.

## 9. Out of scope for 0.1

- Automated DAST runs (the `pre-launch` checklist covers passive checks on a site the user owns).
- Mobile store compliance in `appsec-compliance-fr`.
- Scheduled or unattended scanning. The skills run when a person asks.

## 10. Build order

1. Repository skeleton, bench and answer key (the test before the code).
2. `appsec-review` with the core references, scored on the bench.
3. `appsec-threat-model`.
4. `appsec-harden`.
5. `appsec-compliance-fr`.
6. `build.sh`, README, release 0.1.0.
