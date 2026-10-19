# Security review: TutorNote

| | |
|---|---|
| Date | 2026-10-20 |
| Commit | n/a (no source access). Deployed `index.html` of 2026-10-19 |
| Mode | pre-launch, black-box and passive |
| Scope | The public site `https://tutornote.example` as any visitor sees it: headers, TLS, the HTML page and its script, cookies before login, third parties. No account was created, no form was submitted, no request was sent to the backend API. Not covered: source, database policies, logged-in behaviour. |
| Reviewed by | appsec-review 0.2.1 |
| Scanners run | none (passive review) |
| Scanners missing | n/a |

## Verdict

The front end is careful (strict CSP, HSTS, output escaped). The browser talks directly to the Supabase database, so its row-level security policies are the only barrier between users; they could not be seen. **NO-GO for now**: answer Q1 to Q4 first.

| Critical | High | Medium | Low | Info |
|---|---|---|---|---|
| 0 | 0 | 1 | 1 | 0 |

## Summary

| ID | Severity | Title | Location | Status |
|---|---|---|---|---|
| APPSEC-001 | Medium | Anyone can sign up as a "tutor" | `index.html:812` | open |
| APPSEC-002 | Low | Raw database errors shown to users | `index.html:455` | open |

## Findings

### APPSEC-001 · Medium · Anyone can sign up as a "tutor"

- **Location**: `index.html:812` (role radio button), `index.html:640` (profile inserted with the chosen role)
- **Category**: CWE-269 · OWASP A01:2021
- **Confidence**: High
- **Status**: open

**Evidence**: `sb.from("profiles").insert({ id: user.id, role })`, `role` read from the sign-up form.

**Attack scenario**: A stranger signs up as a tutor under a real tutor's name and invites a student, who accepts.

**Impact**: A stranger reads a minor's school notes and messages.

**Fix**: Create profiles server-side with role `student`; verify tutors before granting tutor capabilities.

**Done when**: A self-declared tutor cannot invite anyone until verified.

### APPSEC-002 · Low · Raw database errors shown to users

- **Location**: `index.html:455`
- **Category**: CWE-209
- **Confidence**: High
- **Status**: open

**Evidence**: `toast("Erreur : " + e.message)`

**Attack scenario**: A curious user triggers errors and reads table and policy names.

**Impact**: Helps map the database.

**Fix**: Generic message on screen, detail to the console.

**Done when**: A forced error shows only the generic message.

## Open questions

- **Q1.** Is RLS enabled on every table (`profiles`, `notes`, `messages`, `enrolments`), with no access for the anonymous key?
- **Q2.** Can one student read another student's `notes` or `messages`?
- **Q3.** Can a tutor create an `enrolments` row (tutor ↔ student link) without the student accepting?
- **Q4.** Can a user change their own `role`?

## What is already done well

- Strict CSP, HSTS with preload, no secret in the page (publishable key only), consistent output escaping.

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
| none | 0 | n/a | n/a |
