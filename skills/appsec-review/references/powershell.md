# PowerShell

Sources: PSScriptAnalyzer rules, Microsoft "PowerShell security features" and "Avoid using Invoke-Expression" guidance, Microsoft.PowerShell.SecretManagement documentation, InjectionHunter (Lee Holmes).

Scripts that administer endpoints, directories or tenants usually run with high privileges. A flaw in them is a flaw in the fleet.

| Check | Flaw | Expected |
|---|---|---|
| Code injection | `Invoke-Expression`, `iex`, `[scriptblock]::Create()`, `Add-Type` with caller or file content; string-built commands passed to `cmd /c` or `Start-Process` | Call cmdlets directly with parameters; validate with `[ValidateSet()]`, `[ValidatePattern()]`; build filters with `Where-Object` and variables |
| Hard-coded credentials | `ConvertTo-SecureString '...' -AsPlainText -Force`, passwords or tokens in variables, API keys in scripts | `Get-Secret` (SecretManagement), Windows Credential Manager, a vault; `Export-Clixml` only for the same user on the same machine (DPAPI) |
| Credential exposure | Secrets in `Write-Verbose`/`Write-Host`, transcripts, `-Debug` output, exception messages; `SecureString` converted back to plain text and stored | Never log secrets; keep `PSCredential` objects |
| TLS | `-SkipCertificateCheck`, `ServerCertificateValidationCallback = { $true }`, forcing old protocols | Valid certificates; trust the internal CA properly |
| Remote execution | `Invoke-Command`/`Enter-PSSession` with CredSSP or broad `TrustedHosts` | Kerberos, JEA endpoints with constrained roles |
| Downloads | `iwr ... | iex`, running downloaded scripts without verifying origin | Pinned versions, signature or hash check, `Install-PSResource` from a trusted repository |
| Execution policy | Treated as a security boundary, or `-ExecutionPolicy Bypass` used to "fix" signing | Execution policy is a safety net, not a control; sign scripts (Authenticode) where policy requires it |
| Error handling | `-ErrorAction SilentlyContinue` around security-relevant steps; continuing after a failed check | `$ErrorActionPreference = 'Stop'` and explicit handling: fail closed |
| Personal data in output | E-mails, usernames, device data written to logs or CSVs left in shared folders | Minimal identifiers; protected output locations |
| Module and file paths | Writable paths in `$env:PSModulePath`, scripts run from user-writable directories as admin | Protected locations for anything run with privileges |

Scanner notes: PSScriptAnalyzer flags `Invoke-Expression` and `ConvertTo-SecureString -AsPlainText`, but not `-SkipCertificateCheck` or logging of secrets: those need reading. `PSUseDeclaredVarsMoreThanAssignments` next to an `Invoke-Expression` string is a side effect, not a separate finding.
