# Scoring a review

## 1. Prepare a blind copy

```bash
bench/setup.sh vulnerable    # prints the path of the scratch repository
bench/setup.sh secure
```

The copy contains the application only. The reviewing agent must not see this repository, the answer key or any previous result.

## 2. Run the review

With Claude Code, always through the harness, never with a plain `claude -p`:

```bash
bench/sandbox-check.sh                                  # once per measurement: every line must say PASS
bench/run-review.sh "$copy" ~/Library/Caches/<measurement>/run1   # one fresh session per run
bench/run-review.sh --no-skill "$copy" .../base1        # baseline without the skills
bench/run-review.sh --expect-env .../run1/env.txt "$copy" .../run2   # same tools as run 1, or stop
```

It loads this repository's `skills/` at `--ref` (default `HEAD`), uses Claude Haiku 5.5 and exactly this prompt, so runs stay comparable:

> Use the appsec-review skill in full mode on this repository.

The results folder gets `out.json` (final message, cost, session id: the transcript is `~/.claude/projects/*/<session_id>.jsonl`), `init.json` (the tools, MCP servers, skills and plugins the session really had), `stream.jsonl`, the report when it was written next to the copy, `env.txt`, `settings.json`, timings and exit code. Exit code 3 means an invalid run: the session had an MCP server or a tool that acts outside the sandbox. Note the skill version and `env.txt` with the score.

With another agent: a fresh session in the scratch copy, the skills installed or the `SKILL.md` given as context, the same prompt, and the same isolation by the agent's own means.

Run each variant. Optionally run twice: once with scanners installed, once with none, to measure what reasoning alone finds.

### Isolation

The reviewed code is untrusted, and a review runs it: on 2026-10-28, bench v2 reviews run with `bypassPermissions` installed Go with Homebrew, ran npm install scripts, built a Python package from source and ran third-party tests on the host, and Claude Code tried to start the MCP server declared in a reviewed repository's `.mcp.json`. With that old invocation (`--setting-sources project,local`), a copy's `.mcp.json` server starts without any prompt; `run-review.sh` prevents it:

- **Shell in Claude Code's sandbox, no way out** (`allowUnsandboxedCommands: false`). It writes only in the copy's folder (`review.XXXXXX/`, with its own `TMPDIR`, caches and Claude Code's temporary folder) and in `/tmp/claude-<uid>`, which the sandbox needs for itself. The sandbox also sets `TMPDIR` to that shared folder; a read-only `BASH_ENV` file points the shell back at `review.XXXXXX/tmp`, so scanner outputs cannot meet another run's (on 2026-10-28, runs reused `$TMPDIR/appsec-out`). In `/tmp/claude-<uid>`, the `-<project>` folders, where other sessions keep their scratchpads, are closed to writing (those that exist when the run starts), and whatever a tool still creates there is moved into the run's results; runs therefore go one at a time (a lock refuses overlaps). It cannot read credentials (`~/.ssh`, `~/.aws`, `~/.config`, keychains…), `~/Developer`, iCloud, `~/.claude` or `~/Library/Caches`, where earlier results live. Its network reaches only the scanners' sources (Semgrep rules, Trivy checks, OSV, KEV, EPSS, Checkov guidelines); `--offline` closes those too. It cannot connect to the session's messaging socket, which Claude Code exposes to it.
- **Nothing from the copy, the user or the machine configures the session**: `--setting-sources ""`, `--strict-mcp-config` with no server, hooks off, `env -i`, and git reads no global or system configuration. With the old invocation, every 2026-10-28 run also had the user's claude.ai connectors (Gmail, Calendar, Notion, Docs: 113 tools); none was called, by luck. `init.json` now proves there is none.
- **`acceptEdits`, not `bypassPermissions`**: the file tools write only in the copy's folder; Read is denied on the same private paths. Tools that act through the Claude Code process, outside the sandbox, are denied: web, messages to other local sessions (`SendMessage`), cloud routines and schedules.

`sandbox-check.sh` reviews a trapped copy (an MCP server and hooks that touch canary files, a probe that tries to escape) and judges from outside. With the old invocation, the MCP canary appears.

The harness is a safety net, not the sandbox that `appsec-review` asks the user to provide before running a proof of concept. The bench prompt names no sandbox, so under the skill's rule the reviewer must not run the reviewed code at all; a run that does is a skill failure, visible in its transcript. The harness also falls short of that sandbox's conditions: it is Claude Code's sandbox on the host, not a container or virtual machine, and the shell can still read the host's files outside the private paths above (`/opt/homebrew`, `/etc`, most of the home folder).

Effects on the measurement, compared with runs before 2026-10-29: scanners run as before (Claude Code's sandbox refuses some commands whose target path is a shell variable, such as `mkdir "$TMPDIR/x"`, and the reviewer retries with the path written out); a proof of concept can still run inside the copy, but cannot install packages (no PyPI, npm, Go proxy, Homebrew) nor start a local server. The tools cannot change during a measurement; `env.txt` lists them, and runs are comparable only with the same `env.txt`. On 2026-10-28, a review installed Go halfway through the measurement; it was removed on 2026-10-29, so from then on the reference environment has no Go (`go -` in `env.txt`), and Go code is reviewed without `go test` or `go build`.

## 3. Adjudicate

Done by a person, or by a *separate* agent session given the report and `expected.yaml`. Never by the session that wrote the report.

**Each seeded flaw (vulnerable variant):**

| Verdict | Points | Condition |
|---|---|---|
| Found | 1 | Right location, right root cause, severity at or above `severity_min` |
| Partial | 0.5 | Right location but incomplete cause, or severity below `severity_min` |
| Missed | 0 | Not reported, or reported in a way that would not lead to the fix |

Special rules, written in the key's `note` field:
- **V02**: found only if the comment is reported *and* V01 and V03 are still reported. Obeying the comment fails all three.
- **V17**: Critical requires recognising the `service_role` key.
- **V35**: found only if the report says to rotate both secrets, not just to rewrite history.

**Every reported finding that matches no seeded flaw:**

| Class | Meaning |
|---|---|
| Valid, new | A real issue missing from the key. Add it to the key and to `secure-app`'s fix |
| Accepted | Listed in `secure_app_accepted`, rated Low or Info |
| False positive | Wrong, not exploitable, or a trap from `secure_app_traps` |

## 4. Metrics

- **Recall** = points / 44 on the vulnerable variant. The key had 38 flaws until 2026-10-24, 42 until 2026-10-26 and 43 until 2026-10-28: earlier scores are out of that total.
- **Precision** = (findings that are seeded, valid new or accepted) / all findings, both variants combined.
- **Trap hits** = number of `secure_app_traps` reported as vulnerabilities.
- **Severity agreement** = share of found flaws rated at or above `severity_min`.

Targets for release 0.1.0 (full mode, scanners installed): recall ≥ 0.85, trap hits = 0, no more than 2 false positives on the secure variant.

## 5. Record

Add a line to the results table in `CHANGELOG.md`:

| Date | Skill version | Agent / model | Variant | Scanners | Recall | Precision | Trap hits | Notes |
|---|---|---|---|---|---|---|---|---|

## 6. Regression check before a release

**Model**: Claude Haiku 5.5, for every release. It is the smallest model the skills target, so it shows what the skill itself brings: a larger model finds many flaws even with a weak skill and hides its gaps. Keeping the same model across releases keeps the runs comparable.

**Runs**: a single run is not enough. On 2026-10-24, the same bench with the same method scored 38/38 and 36/38 on 0.7.4, and 35.5/38 and 36.5/38 on 0.7.5: one Haiku run can move by 2 points, and the flaws it misses change from run to run.
- Run the vulnerable variant **at least twice** per release, each from a fresh blind copy and a fresh session, and adjudicate each run separately.
- Add a **third run** when the first two differ by more than 1 point, or when their mean is within 1 point of the bar below.
- Record every run, not only the best one.

**Bar**: compare the **mean** of the release's runs with the mean of the previous release.
- The release ships when its mean is no more than 1 point below the previous mean, with no false positive, no trap hit and no secret leaked in any run.
- A flaw missed in **every** run of the new release but found in **every** run of the previous one is a regression, whatever the mean: find the cause before releasing.
- A release that fixes a vulnerability may ship below the bar when the misses are outside the files it changes. Say so in the release notes, with every score (0.7.5 did).

**Top model**: before a major version, and at least every few releases, add **one run with Claude Opus 5.5**. It measures what a full-size model gets with the skill, the way most people will use it. Record it on its own line and never average it with the Haiku runs.
