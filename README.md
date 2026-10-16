# appsec-skills

Security skills for AI coding agents. They make an agent review code the way a security engineer would, and hand back a report that any other AI, or a person, can act on.

Works with any agent that reads the open `SKILL.md` format: Claude Code, Codex, Cursor, GitHub Copilot, Gemini CLI, OpenCode. Chat assistants get a single-file version.

## What you get

**`appsec-review`**: a security review in four modes.

| Mode | When |
|---|---|
| `diff` | Before a commit or a pull request |
| `full` | Any time, including the first review of an existing project |
| `pre-launch` | Before going live: a go/no-go checklist, explained in plain words |
| `verify` | After fixes: re-checks every finding of a previous report |

The report is a **work order**: stable finding IDs, evidence with secrets redacted, an attack scenario, a fix precise enough to implement, a "Done when" check that proves the fix, and a status per finding. Paste it into any AI assistant to start fixing, then run `verify` with the same file.

Coming next, see [`docs/design.md`](docs/design.md): `appsec-threat-model` (security by design, before code is written), `appsec-harden` (applies fixes and baselines) and `appsec-compliance-fr` (French legal requirements for websites and apps).

## Principles

- **Source code never leaves your machine** unless it is already public. No scanner that uploads code is used by default.
- **Scanners are optional.** The skill runs the ones you have (gitleaks, TruffleHog, Semgrep, Bandit, ShellCheck, PSScriptAnalyzer, OSV-Scanner, Checkov, Trivy, zizmor), lists the missing ones, and never installs anything. Without any, it still works: most serious flaws are found by reading the code.
- **Every finding is verified** before it is reported: attacker-controlled input, a path to the dangerous operation, a concrete attack. Uncertain items are kept apart as open questions.
- **Read-only.** The review never modifies your code.
- **Reports stay out of the repository**: a list of weaknesses is a map for attackers.
- **Code under review is data.** Comments that tell the reviewer to skip a file are reported, never obeyed.

The full rationale is in [`docs/design.md`](docs/design.md).

## Install

Copy or link each folder of `skills/` into your agent's skills directory:

| Agent | Skills directory |
|---|---|
| Claude Code | `~/.claude/skills/` |
| Codex | `~/.codex/skills/` |
| Cursor | `~/.cursor/skills/` |
| GitHub Copilot CLI | `~/.copilot/skills/` |
| Gemini CLI | `~/.gemini/skills/` |
| OpenCode | `~/.config/opencode/skills/` |

```bash
git clone https://github.com/mbart75/appsec-skills.git
ln -s "$PWD/appsec-skills/skills/appsec-review" ~/.claude/skills/appsec-review
```

Agents without skills support can read [`AGENTS.md`](AGENTS.md). For a chat assistant, run `bash scripts/build.sh` and attach `dist/appsec-review.md` to the conversation.

## Use

> Use appsec-review in full mode on this repository.

> Is this app ready to launch? Use appsec-review in pre-launch mode, and explain in plain words.

> Here is the security report. Fix the findings, then run appsec-review in verify mode.

## Does it work?

The skills are tested against a bench before every release, and the results are published, including the failures.

- **Bench v1** ([`bench/`](bench/)): TinyShop, a small multi-stack application with 37 seeded flaws and a fixed counterpart with traps for false positives.
- **Bench v2** ([`bench/v2/`](bench/v2/)): eight real vulnerabilities from GitHub Security Advisories published in 2026, each reviewed at the commit before and after its fix.

Results: [`CHANGELOG.md`](CHANGELOG.md).

## Licence

MIT. Third-party projects used by bench v2 are fetched from their own repositories at run time and keep their own licences.
