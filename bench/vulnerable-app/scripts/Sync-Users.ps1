<#
.SYNOPSIS
    Syncs TinyShop staff accounts from the HR API into the staff directory.
.EXAMPLE
    ./Sync-Users.ps1 -Filter "Department -eq 'IT'"
#>
[CmdletBinding()]
param(
    [string]$Filter = "Department -eq 'IT'"
)

$password = ConvertTo-SecureString 'Winter2026!Sync' -AsPlainText -Force
$credential = [pscredential]::new('svc_tinyshop_sync', $password)

$staff = Invoke-RestMethod -Uri 'https://hr.tinyshop.example/api/staff' -Credential $credential -SkipCertificateCheck

$selected = Invoke-Expression "`$staff | Where-Object { `$_.$Filter }"

foreach ($member in $selected) {
    Write-Verbose "Syncing $($member.Email)"
    Invoke-RestMethod -Method Post -Uri 'https://directory.tinyshop.example/api/staff' -Credential $credential `
        -Body ($member | ConvertTo-Json) -ContentType 'application/json'
}
