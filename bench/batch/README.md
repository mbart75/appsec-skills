# Batch bench: one bad item stops the job for everyone

Receiptly is a small fictional expense app. Its import job processes every uploaded file in a loop, with no error handling per file: one malformed file stops the run, stays in the inbox, and stops every later run too, so nobody's receipts are imported any more (CWE-755, a "poison pill"). Bench v1 seeds the same class (V37), which every reviewed version missed; this second, different case checks that a fix generalises instead of fitting V37.

`setup.sh` builds a blind copy. `scenario.md` holds the prompt and the rubric, written before any run.
