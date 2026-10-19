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

Rating rules that prevent under-rating:

- **A bypass of a security control is at least Medium** when the control is documented, configured or relied on as a boundary (an allow-list, a "secure mode", a permission setting, an approval step), even if, in the default configuration, the attacker could reach the same power another way. Deployments that enable the control rely on it.
- **A flaw reachable through a public API, an exported function or a documented option** is rated for the callers who use it as documented, not only for this repository's own call sites.
- **Rate the worst realistic deployment**, not the most favourable one, and say which deployment the rating assumes.
- **Known vulnerabilities in dependencies** follow the triage table in `secrets-supply-chain.md`: known exploited (KEV) and reachable is never below High and comes first in the fix order; not reachable is Low at most.

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
| Authorization | <live target only: who, date, channel, scope (roles or areas, reads or writes, production or copy)> |
| Testing | <live target only: passive only, or authorized tests on <dates>, see Test log> |

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
- **Known vulnerability**: <only in findings about a dependency, otherwise leave the line out: CVE · in CISA KEV yes (added <date>) / no · EPSS <score> (<date>) · fixed in <first fixed version>, recommended <current version>>
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

<live target only>
## Test log

| Date | Account (role) | Request | Result | Reading |
|---|---|---|---|---|
| <date> | <test account, role> | <exact method, path, filter, body> | <status, count or returned row> | <blocked / leak / inconclusive / probe error, and the finding or question it decides> |

## Test artefacts to remove

- <test account address or id, role: delete from production> (never a password)
- <rows created by tests and not already removed>
</live target only>

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
