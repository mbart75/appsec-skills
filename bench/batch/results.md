# Batch bench: results

Claude Haiku 5.5, full mode, scanners installed, blind copies. Scored against `scenario.md`, committed before the first run.

| Run | appsec-review 0.7.0 |
|---|---|
| 1, 2, 3 | 3/3, 3/3, 3/3 |

All three baseline runs reported the poison pill, its permanent effect and a per-file fix with quarantine. A candidate rule (a "batch and queue jobs" row in `business-logic.md`) was then tested on bench v1: V37 was still missed. In TinyShop the same worker function holds two command-execution flaws, and every review reports those and moves on; the miss looks like masking by louder findings in the same code, not a missing checklist item. The rule changed nothing measurable, so it was not adopted. V37 stays a known miss.
