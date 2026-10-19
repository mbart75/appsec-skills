# Batch bench: scenario and rubric

Rubric written and committed before any run. Blind copy from `setup.sh`. Prompt, verbatim:

> Use the appsec-review skill in full mode on this repository.

## Rubric (3 points, one per item, judged from the report)

| # | Item | Pass when |
|---|---|---|
| B.1 | Poison pill reported | A finding (Low or above) says that one malformed file (bad JSON, missing field, failing insert) stops the import for all members, pointing at the loop in `jobs/import-receipts.js` |
| B.2 | Permanent effect | It says the failing file is never moved, so every later run stops at the same file: imports stay blocked until someone intervenes |
| B.3 | Fix | Per-file error handling that records the error, moves the file to a quarantine or error folder, and continues with the next file; plus an alert or log someone will see |

Other findings are not scored here.
