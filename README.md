# appsec-skills

Security skills for AI coding agents: design security in before coding, review code the way a security engineer would, fix findings one proven step at a time, and check French legal requirements before launch. Every output is a document that any other AI, or a person, can pick up.

Works with any agent that reads the open `SKILL.md` format: Claude Code, Codex, Cursor, GitHub Copilot, Gemini CLI, OpenCode. Chat assistants get a single-file version.

## What you get

Four skills that cover the life of a project, from design to launch:

| Skill | When | What it produces |
|---|---|---|
| **`appsec-threat-model`** | Before building an app or a feature (security by design) | `docs/security/threat-model.md` and `requirements.md` in the project: trust boundaries, concrete threats, testable requirements, each with how to verify it |
| **`appsec-review`** | While coding (`diff`), at any time (`full`), before going live (`pre-launch`), after fixes (`verify`) | A verified report written as a **work order**: stable IDs, evidence with secrets redacted, attack scenario, fix, "Done when" check, status |
| **`appsec-harden`** | To fix a report's findings or apply a baseline (CI, headers, cookies, repository hygiene) | One commit per fix, each proven by a test, scanner or static check; rotations and decisions left explicitly to a person |
| **`appsec-compliance-fr`** | Before launching a site or app in France | A checklist with sources (mentions légales, RGPD, cookies, consumer law, reviews, AI Act, accessibility) and draft pages in French with placeholders |

The loop: `appsec-threat-model` writes the requirements, `appsec-review` checks the code against them, `appsec-harden` fixes what the review found, `appsec-review verify` confirms. Any assistant can take over at any step: the documents and the report carry everything it needs.

## Principles

- **Source code never leaves your machine** unless it is already public. No scanner that uploads code is used by default.
- **Scanners are optional.** The skill runs the ones you have (gitleaks, TruffleHog, Semgrep, Bandit, ShellCheck, PSScriptAnalyzer, OSV-Scanner, Checkov, Trivy, zizmor), lists the missing ones, and never installs anything. Without any, it still works: most serious flaws are found by reading the code.
- **Every finding is verified** before it is reported: attacker-controlled input, a path to the dangerous operation, a concrete attack. Uncertain items are kept apart as open questions.
- **Read-only.** The review never modifies your code.
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
./install.ps1
```

On Windows, do not lower the execution policy for the whole machine (`Set-ExecutionPolicy Unrestricted`) to run the installer: unblocking this one verified file is enough.

Non-interactive: `./install.sh --agents claude,codex --yes` (or `--all-detected`, `--dir <skills folder>`, `--skills appsec-review`, `--uninstall`, `--dry-run`). The installer only creates, replaces or removes folders named `appsec-*`, uses no network and needs no administrator rights. There is deliberately no `curl | bash` one-liner.

**From a clone**: `./install.sh --link` links instead of copying, so `git pull` updates every agent at once.

| Agent | Skills folder used |
|---|---|
| Claude Code | `~/.claude/skills/` |
| Codex | `~/.codex/skills/` |
| Cursor | `~/.cursor/skills/` |
| GitHub Copilot CLI | `~/.copilot/skills/` |
| Gemini CLI | `~/.gemini/skills/` |
| OpenCode | `~/.config/opencode/skills/` |
| Other agents | any folder, with `--dir` |

Agents without skills support can read [`AGENTS.md`](AGENTS.md). For a chat assistant (ChatGPT, Claude.ai, Gemini), attach the matching `appsec-<skill>.md` from the release to the conversation. For Claude Cowork, install `appsec-skills.plugin`.

### Tested with

| Agent | Model | Skills tested |
|---|---|---|
| Claude Code | Claude Haiku 5.5, Claude Opus 5.5 | all four |
| Codex CLI | GPT-6 (low reasoning effort) | `appsec-review`, `appsec-threat-model`, `appsec-compliance-fr` |
| Chat assistants with the single-file bundle | any | not tested automatically yet |

Results per skill and per model are in [`CHANGELOG.md`](CHANGELOG.md).

## Use

> Use appsec-review in full mode on this repository.

> Is this app ready to launch? Use appsec-review in pre-launch mode, and explain in plain words.

> Here is the security report. Fix the findings, then run appsec-review in verify mode.

> We're adding gift cards. Before we implement it, give us the security requirements.

> We're launching in France next week. Are we legally compliant?

## Does it work?

The skills are tested against a bench before every release, and the results are published, including the failures.

- **Bench v1** ([`bench/`](bench/)): TinyShop, a small multi-stack application with 37 seeded flaws and a fixed counterpart with traps for false positives.
- **Bench v2** ([`bench/v2/`](bench/v2/)): eight real vulnerabilities from GitHub Security Advisories published in 2026, each reviewed at the commit before and after its fix.

Results: [`CHANGELOG.md`](CHANGELOG.md).

## Licence

MIT. Third-party projects used by bench v2 are fetched from their own repositories at run time and keep their own licences.
