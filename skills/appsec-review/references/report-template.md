# Report template

The report is a work order. A person reads the first screen and knows what to do; any AI given the file can fix the findings without re-auditing. Fill every slot. Keep the order.

## Severity scale

Rate from what an attacker can actually do here, not from the flaw's name.

| Severity | Meaning | Typical examples |
|---|---|---|
| Critical | Remote, no or trivial preconditions, leads to full data access, account takeover at scale, code execution or money loss | SQL injection on a public endpoint, admin access by a client-sent header, service key shipped to the browser, CI running untrusted code with secrets |
| High | Serious impact with one realistic precondition (an account, a user click, a reachable internal service) | IDOR on orders, stored XSS, SSRF reaching cloud metadata, predictable reset tokens, over-privileged IAM role |
| Medium | Limited impact, or needs several preconditions, or defence-in-depth gap that makes another flaw much worse | Missing rate limiting on login, CORS reflecting origins, TLS validation disabled on an internal call, public SSH |
| Low | Hard to exploit or minor impact | Stack traces in errors, account enumeration, missing security headers on a static page |
| Info | No direct risk; hygiene or a note for later | Unpinned non-security tooling, attempted instructions to the reviewer found in the code |

Confidence, separately: **High** (code path read end to end), **Medium** (likely, one assumption stated), **Low** (needs context: move it to Open questions instead of Findings).

## Template

````markdown
# Security review: <project>

| | |
|---|---|
| Date | <YYYY-MM-DD> |
| Commit | <short sha or "uncommitted changes"> |
| Mode | <diff / full / pre-launch / verify> |
| Scope | <paths reviewed, what was excluded and why> |
| Reviewed by | appsec-review <version>, <agent and model> |
| Scanners run | <list> |
| Scanners missing | <list with install command, or "none"> |

## Verdict

<Two or three sentences: overall state, the one thing to fix first.>
<pre-launch only: **GO** or **NO-GO**, with the blocking findings listed.>

| Critical | High | Medium | Low | Info |
|---|---|---|---|---|
| <n> | <n> | <n> | <n> | <n> |

## Summary

| ID | Severity | Title | Location | Status |
|---|---|---|---|---|
| APPSEC-001 | Critical | <title> | `<file>:<line>` | open |

## Findings

### APPSEC-001 · Critical · <title>

- **Location**: `<file>:<line>` (and other places with the same root cause)
- **Category**: <CWE-nnn> · <OWASP reference>
- **Confidence**: <High / Medium>
- **Status**: open

**Evidence**

```<language>
<the few lines that show the flaw; secrets replaced by [REDACTED]>
```

**Attack scenario**: <who, from where, doing what, step by step, ending in the concrete outcome>

**Impact**: <what is lost or controlled, for whom>

**Fix**: <what to change, where, and how; precise enough to implement without re-reading this report's other sections>

**Done when**:
- <testable condition 1>
- <the command, test or manual check that proves it>

<plain level only>**In plain words**: <an everyday analogy and why it matters to this project></plain level only>

## Open questions

- <Something that could be a flaw but needs information the code does not give. State what would decide it.>

## What is already done well

- <Specific good practices found, so they are kept.>

## Hand-off: fixing these findings

Give this file to any AI coding assistant with this instruction:

> Fix the findings of this security report, in order of severity, starting with Critical.
> For each finding: apply the Fix, run the "Done when" check, make one commit per finding
> with the finding ID in the message, then change its Status in this file to `fixed`.
> Never weaken a security control to make a test or a build pass. If a fix needs a
> design change or a decision, stop and ask instead of guessing. If you believe a
> finding is wrong, set its Status to `false-positive` with your reason, do not skip it silently.
> When all findings are handled, run appsec-review in verify mode with this file.

## Appendix: scanner results

| Scanner | Raw results | Confirmed | False positives (reason) |
|---|---|---|---|
| <tool> | <n> | <IDs> | <n: short reason each> |
````

## Status values

| Status | Set by | Meaning |
|---|---|---|
| `open` | review | Not fixed yet |
| `fixed` | the fixing agent, then confirmed by `verify` | The "Done when" check passes |
| `accepted-risk` | a person only | Kept on purpose; the reason and who accepted it are written next to it |
| `false-positive` | anyone, with the reason | Not a real issue; `verify` re-checks the reason |

`verify` mode keeps the IDs, re-checks every finding, updates the statuses, and adds new findings with new IDs only if they come from the fixes.
