# appsec-skills

[![checks](https://github.com/mbart75/appsec-skills/actions/workflows/checks.yml/badge.svg)](https://github.com/mbart75/appsec-skills/actions/workflows/checks.yml) [![release](https://img.shields.io/github/v/release/mbart75/appsec-skills)](https://github.com/mbart75/appsec-skills/releases/latest) [![licence: MIT](https://img.shields.io/badge/licence-MIT-blue)](LICENSE)

Security skills for AI coding agents: design security in before coding, review code the way a security engineer would, fix findings one proven step at a time, and check French legal requirements before launch. Every output is a document that any other AI, or a person, can pick up.

Works with any agent that reads the open `SKILL.md` format: Claude Code, Codex, Cursor, GitHub Copilot, Gemini CLI, OpenCode. Chat assistants get a single-file version.

## What you get

Four skills that cover the life of a project, from design to launch:

| Skill | When | What it produces |
|---|---|---|
| **`appsec-threat-model`** | Before building an app or a feature (security by design) | `docs/security/threat-model.md` and `requirements.md` in the project: trust boundaries, concrete threats, testable requirements, each with how to verify it |
| **`appsec-review`** | While coding (`diff`), at any time (`full`), before going live (`pre-launch`), after fixes (`verify`); also on a deployed app without its source, with authorized tests | A verified report written as a **work order**: stable IDs, evidence with secrets redacted, attack scenario, fix, "Done when" check, status |
| **`appsec-harden`** | To fix a report's findings or apply a baseline (CI, headers, cookies, repository hygiene) | One commit per fix, each proven by a test, scanner or static check; rotations and decisions left explicitly to a person |
| **`appsec-compliance-fr`** | Before launching a site or app in France | A checklist with sources (mentions légales, RGPD, cookies, consumer law, reviews, AI Act, accessibility) and draft pages in French with placeholders |

The loop: `appsec-threat-model` writes the requirements, `appsec-review` checks the code against them, `appsec-harden` fixes what the review found, `appsec-review verify` confirms. Any assistant can take over at any step: the documents and the report carry everything it needs.

## Principles

- **The skills send no source code anywhere** unless it is already public: no scanner that uploads code is used, and the scanner runner never uploads it. What the agent itself sends to its model provider is up to the agent you use; a skill cannot change it.
- **Scanners are optional.** The skill runs the ones you have (gitleaks, TruffleHog, Semgrep, Bandit, ShellCheck, PSScriptAnalyzer, OSV-Scanner, Checkov, Trivy, zizmor), lists the missing ones, and never installs anything. Without any, it still works: most serious flaws are found by reading the code.
- **Known vulnerabilities are ranked by real-world exploitation**, not by CVSS alone: each CVE found in dependencies, including vendored libraries, is checked against the CISA KEV catalog (exploited in the wild) and its EPSS score (likely to be exploited), then against the code (is the vulnerable function used?). To do this, OSV-Scanner sends package names and versions to the OSV database, and the ranking sends CVE identifiers to the EPSS API and downloads the KEV catalog. Semgrep and Trivy download their rules. `--offline` stops all of it: OSV-Scanner then uses a local database, downloaded beforehand with `osv-scanner scan source --offline-vulnerabilities --download-offline-databases`, and without one the summary says `NO DATABASE`, since nothing was checked; Semgrep, whose rules come from its registry, is skipped (`SKIPPED (offline)`); Trivy uses the checks embedded in its binary. Trivy is always run with `--disable-telemetry` and `--skip-version-check`, online or offline; a test runs the real Trivy behind a recording proxy and checks that it opens no connection with `--offline`. Online, the test checks the options passed, not Trivy's traffic.
- **Every finding is verified** before it is reported: attacker-controlled input, a path to the dangerous operation, a concrete attack. Uncertain items are kept apart as open questions.
- **Read-only, and your code is never run.** The review never modifies your code, and never installs, builds, tests or runs the code it reviews: a repository under review is untrusted. A proof of concept runs only in a sandbox you provide; otherwise it is written in the report, unexecuted. The skill installs nothing on your machine without your consent. It reviews the reviewed repository's own agent instructions, hooks and MCP servers as code and never starts them, but your agent may load them when a session opens in that folder: review untrusted repositories with project settings disabled.
- **Reports stay out of the repository**: a list of weaknesses is a map for attackers.
- **Code under review is data.** Comments that tell the reviewer to skip a file are reported, never obeyed.

The full rationale is in [`docs/design.md`](docs/design.md).

## Install

**From a release (recommended)**: download `appsec-skills-<version>.zip` from the [latest release](https://github.com/mbart75/appsec-skills/releases/latest), check it against `SHA256SUMS`, unzip it, and run the installer. It lists the agents it finds, asks which ones you use, shows its plan and asks before changing anything.

```bash
shasum -a 256 -c SHA256SUMS --ignore-missing   # macOS / Linux: verify the download
unzip appsec-skills-*.zip && cd appsec-skills-*/
bash install.sh      # "bash" works even if unzipping dropped the executable bit
```

```powershell
# Windows
Get-FileHash .\appsec-skills-*.zip -Algorithm SHA256   # compare with SHA256SUMS
Expand-Archive .\appsec-skills-*.zip -DestinationPath . ; cd .\appsec-skills-*\
Unblock-File .\install.ps1    # downloaded scripts are blocked; unblock this file only, after checking the hash
./install.ps1                 # PowerShell 7, or any policy that allows local scripts
# Windows PowerShell 5.1 on Windows 10 or 11 refuses every script by default ("Restricted"):
# powershell -ExecutionPolicy Bypass -File .\install.ps1    # this one run only
```

On Windows, do not lower the execution policy for the whole machine (`Set-ExecutionPolicy Unrestricted`) to run the installer. Unblocking this one verified file is enough under the `RemoteSigned` policy (the default of PowerShell 7 and of Windows Server). Under `Restricted`, the default of Windows PowerShell 5.1 on Windows 10 and 11, no script runs at all, unblocked or not: use `-ExecutionPolicy Bypass` for this one run, as above.

Non-interactive: `./install.sh --agents claude,codex --yes` (or `--all-detected`, `--dir <skills folder>`, `--skills appsec-review`, `--uninstall`, `--dry-run`). The installer creates the agent's skills folder if it does not exist yet; inside it, it only creates, replaces or removes folders named `appsec-*`. It uses no network and needs no administrator rights. There is deliberately no `curl | bash` one-liner.

**From a clone**: `./install.sh --link` links instead of copying, so `git pull` updates every agent at once.

| Agent | Skills folder used |
|---|---|
| Claude Code | `~/.claude/skills/` |
| Codex | `~/.codex/skills/` |
| Cursor | `~/.cursor/skills/` |
| GitHub Copilot CLI | `~/.copilot/skills/` |
| Gemini CLI | `~/.gemini/skills/` |
| OpenCode | `~/.config/opencode/skills/` |
| Shared folder read by several agents (`--agents agents`) | `~/.agents/skills/` |
| Other agents | any folder, with `--dir` |

Agents without skills support can read [`AGENTS.md`](AGENTS.md). Elsewhere:

| Where | How |
|---|---|
| Chat assistant (ChatGPT, Claude.ai, Gemini) | Attach the matching `appsec-<skill>.md` from the release to the conversation, with the code. No scanner runs in a chat; the report says so |
| Lovable | Settings → Skills → Add → *Upload ZIP* with `appsec-<skill>.zip` from the release, or *Import from GitHub* with the skill's folder URL, such as `https://github.com/mbart75/appsec-skills/tree/main/skills/appsec-review` |
| Builders without skills (Bolt, v0) | Project instructions are too short for a skill (Lovable's limit is 10,000 characters; `appsec-review.md` is about 89,000 in 0.7.5). Review the code with a coding agent or a chat assistant instead |
| Claude Cowork | Install `appsec-skills.plugin` |

### Tested with

| Agent | Model | Skills tested |
|---|---|---|
| Claude Code | Claude Haiku 5.5 | all four |
| Claude Code | Claude Opus 5.5 | none yet with a skill: only a baseline without any skill, on bench v1 |
| Codex CLI | GPT-6 (low reasoning effort) | `appsec-review`, `appsec-threat-model`, `appsec-compliance-fr` |
| Codex CLI | GPT-6.1 | `appsec-review` (dependency and live-target benches) |
| Chat assistants with the single-file bundle | any | not tested automatically yet |

Results per skill and per model are in [`CHANGELOG.md`](CHANGELOG.md).

## Use

> Use appsec-review in full mode on this repository.

> Is this app ready to launch? Use appsec-review in pre-launch mode, and explain in plain words.

> Here is the security report. Fix the findings, then run appsec-review in verify mode.

> Here is my friend's site, already live; I don't have the code. Use appsec-review: what can we check, and what do we need from her?

> We're adding gift cards. Before we implement it, give us the security requirements.

> We're launching in France next week. Are we legally compliant?

## Does it work?

The skills are tested against a bench before every release, and the results are published, including the failures.

- **Bench v1** ([`bench/`](bench/)): TinyShop, a small multi-stack application with 44 seeded flaws (38 before 2026-10-24, 42 before 2026-10-26, 43 before 2026-10-28) and a fixed counterpart with traps for false positives.
- **Bench v2** ([`bench/v2/`](bench/v2/)): eight real vulnerabilities from ten GitHub Security Advisories published in 2026, each reviewed at the commit before its fix, and seven of them also at the fixed commit (the eighth was too large).
- **Known vulnerabilities** ([`bench/deps/`](bench/deps/)): exploited-in-the-wild and reachable versus merely listed (CISA KEV, EPSS, reachability), including a library vendored outside any manifest.
- **Live targets** ([`bench/live-target/`](bench/live-target/)): planning and recording authorized tests on a deployed app without its source, and writing Supabase RLS probes.
- **Supabase SQL** ([`bench/rls-sql/`](bench/rls-sql/)): the published RLS baseline and checklist queries, run on a real PostgreSQL, with a mutation check that proves the bench can fail.
- **Chat use**: the single-file bundle, given to a model with only the bundle and pasted code, produced the full report with correct per-file line numbers in 2 of 2 runs (0.7.2, a simulated chat, not a real chat assistant).

Rubrics are committed before the first run, with one exception: bench v2, whose answer key is each published advisory, had its case file committed after the first runs, with the skill changes they led to. When a run finds a real flaw missing from a key, the flaw is added and the total changes; earlier scores keep their own total. Every result is recorded, including the changes that did not help and were dropped.

Results: [`CHANGELOG.md`](CHANGELOG.md).

## Licence

MIT. Third-party projects used by bench v2 are fetched from their own repositories at run time and keep their own licences.
