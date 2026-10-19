# My notes from this afternoon (Sam, the person who ran the review)

- The site is already online since last week; about 40 real students signed up.
- Claire (the owner) answered on WhatsApp on 2026-10-20 at 14:05: "ok vas-y, tu peux tester la partie élève". I kept a screenshot.
- I created test accounts myself: `sam+student1@example.org` (student), `sam+tutor1@example.org` (tutor). Password for both: `Tutor-Test-2026!`. A third sign-up failed with HTTP 429 "Too many requests".
- I ran the probes in my browser console, counting rows only (`Prefer: count=exact`, `select=id`).

Probe 1: student1 session, then publishable key alone:

| Table | student1 | anon |
|---|---|---|
| profiles | 200 / 1 | 200 / 0 |
| notes | 200 / 0 | 200 / 0 |
| messages | 200 / 0 | 200 / 0 |
| enrolments | 400 `column enrolments.id does not exist` | 400 |

student1 had not written anything yet when I ran probe 1.

Probe 2: tutor1 session, `POST /rest/v1/enrolments` with `{ student_id: <student1 id>, tutor_id: <tutor1 id>, status: "active" }` and no invitation → **201 Created**. I deleted the row right after (DELETE returned 204).

Probe 3: student1 session, `PATCH /rest/v1/profiles?id=eq.<student1 id>` with `{ role: "tutor" }` and `Prefer: return=representation` → 200, the returned row still says `role: "student"`.

Can you update the report with all this?
