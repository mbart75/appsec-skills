#Requires -Modules Microsoft.PowerShell.SecretManagement
<#
.SYNOPSIS
    Syncs TinyShop staff accounts from the HR API into the staff directory.
.EXAMPLE
    ./Sync-Users.ps1 -Department IT
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory)]
    [ValidateSet('IT', 'Support', 'Logistics')]
    [string]$Department
)

$ErrorActionPreference = 'Stop'

# Both secrets live in the local secret vault, never in the script.
$hrCredential = Get-Secret -Name 'TinyShopHrSync'
$directoryToken = Get-Secret -Name 'TinyShopDirectoryToken'

$staff = Invoke-RestMethod -Uri 'https://hr.tinyshop.example/api/staff' -Credential $hrCredential
$selected = $staff | Where-Object { $_.Department -eq $Department }

foreach ($member in $selected) {
    Write-Verbose "Syncing staff member $($member.Id)"
    Invoke-RestMethod -Method Post -Uri 'https://directory.tinyshop.example/api/staff' `
        -Authentication Bearer -Token $directoryToken `
        -Body ($member | ConvertTo-Json) -ContentType 'application/json'
}
