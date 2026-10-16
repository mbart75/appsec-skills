# Terraform and cloud infrastructure

Sources: CIS AWS Foundations Benchmark, AWS IAM security best practices, AWS S3 security best practices, Checkov and Trivy policy documentation. Patterns carry over to Azure and Google Cloud with their own names.

Scanners (Checkov, Trivy) are good at this layer. Your job is mostly triage: keep what is exposed or over-privileged in *this* architecture, downgrade hygiene items, and explain chains (SSRF + metadata + broad role = account takeover).

## Checklist

| Check | Flaw | Expected |
|---|---|---|
| IAM wildcards | `Action = "*"`, `"service:*"`, `Resource = "*"` on write or admin actions | Only the actions the workload calls, on the specific resource ARNs |
| Privilege escalation | Roles that can `iam:PassRole`, attach policies, create access keys or update functions broadly | Remove or scope with conditions |
| Trust policies | `Principal: "*"` or broad accounts in `assume_role_policy`; missing `aws:SourceArn`/`aws:SourceAccount` for service principals | Specific principals and confused-deputy conditions |
| Public storage | Public access block disabled, `Principal: "*"` with `Allow` on objects, public ACLs | Public access block on; public content through a CDN with origin access control |
| Network exposure | SSH (22), RDP (3389), databases (5432, 3306, 6379, 27017) open to `0.0.0.0/0` or `::/0` | No administrative ports from the internet: SSM Session Manager, VPN or bastion with allow-listed IPs |
| Instance metadata | IMDSv1 allowed on instances that run web workloads | `http_tokens = "required"` (IMDSv2) |
| Encryption | Unencrypted storage, databases, snapshots; TLS not enforced | Encryption at rest; deny insecure transport in bucket policies |
| Logging | No CloudTrail or access logs for sensitive resources | Enabled where incidents would need them; usually Low in a review |
| State and variables | `terraform.tfstate`, `*.tfvars` with secrets committed; state in an unencrypted public bucket | Remote encrypted state with locking; secrets from a secret manager |
| Cost controls | No budget or alert on accounts used for experiments | A budget alert (Low, but worth saying in pre-launch) |

## Triage notes

- `0.0.0.0/0` on port 443 ingress for a public website is expected; egress to 443 for external APIs is usually acceptable. Rate these Info at most unless the architecture says otherwise.
- `Principal: "*"` inside a `Deny` statement is a restriction, not exposure.
- Missing customer-managed KMS keys, versioning or access logging are hygiene: Low.
