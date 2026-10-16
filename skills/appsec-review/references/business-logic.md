# Business logic

Logic flaws are correct code doing the wrong thing: every function works, and the attacker still gets something for free. No scanner finds them. Find them by asking *what does the business lose if a user lies, repeats, reorders or races?*

Sources: OWASP ASVS 5.0 V2 (Validation and Business Logic), CWE-840 (Business Logic Errors).

## Never trust the client with a business fact

| The client sends... | The server must... |
|---|---|
| A price, total, discount, shipping cost, tax | Recompute it from its own catalogue and rules |
| A quantity, amount, duration | Check type, sign, range and maximum (negative quantities refund money) |
| A role, plan, credit balance, "is_paid", "verified" | Read it from its own records only |
| A step in a workflow ("payment done") | Confirm it from the source of truth (payment provider webhook with signature) |
| A user id, tenant id, owner id | Derive it from the session (see `access-control.md`) |

## Checklist

| Check | What a flaw looks like |
|---|---|
| Price and total | `total = req.body.price * qty`; discount codes validated client-side |
| Numeric abuse | Negative or zero quantities, huge values, floats where integers are expected, integer overflow |
| Workflow bypass | Calling step 3 without steps 1 and 2: order marked paid without payment, account used before e-mail verification |
| Replay and idempotency | The same coupon, gift card, refund or reward applied twice; no idempotency key on payment callbacks |
| Race conditions | Check-then-act on balances, stock, coupon usage or seat counts without a transaction or lock (two requests at once both pass the check) |
| Limits per user | Free trial, referral bonus or quota reset by creating new accounts; no per-account or per-payment-method limit |
| Refunds and cancellations | Refund larger than the amount paid, refund of someone else's order, refund issued by an automated agent without review |
| Webhooks | Payment or provider callbacks accepted without signature verification or timestamp check |
| Costly operations | Actions that cost the operator money (SMS, e-mail, LLM calls, file processing) without authentication, quota or cap |

## How to verify

Write the attacker's request: "`POST /api/checkout` with `{\"productId\": 7, \"quantity\": 1, \"price\": 0.01}` creates an order for a 499 € item at 0.01 €". If you cannot write that request from the code, it is an open question, not a finding.

Rate by money or trust lost: direct financial loss or free goods at scale is High or Critical; abuse limited to one account and easily detected is Medium or Low.
