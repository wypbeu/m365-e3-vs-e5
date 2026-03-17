<#
.SYNOPSIS
    Analyses E5-exclusive service plan usage per user.

.DESCRIPTION
    Connects to Microsoft Graph and identifies which E5-exclusive service plans
    are enabled on each E5-licensed user, cross-referencing against 90-day
    workload activity data. Exports results to CSV for downstream analysis.

.PARAMETER OutputPath
    Path to write the CSV report. Defaults to $env:TEMP\E5FeatureUsage.csv.

.EXAMPLE
    Connect-MgGraph -Scopes "User.Read.All","Directory.Read.All","AuditLog.Read.All","Reports.Read.All","Organization.Read.All"
    ./Get-E5FeatureUsage.ps1

.NOTES
    Requires Microsoft Graph PowerShell SDK v2.x and PowerShell 7+.
    Run Connect-MgGraph before executing this script.
#>

param(
    [string]$OutputPath = "$env:TEMP\E5FeatureUsage.csv"
)

# E5-exclusive service plan GUIDs
# Validate against your tenant before production use:
#   Get-MgSubscribedSku | Select-Object -ExpandProperty ServicePlans | Sort-Object ServicePlanName
# Microsoft occasionally changes plan GUIDs between SKU versions.
$e5ServicePlans = @{
    "8e0c0a52-6a6c-4d40-8370-dd62790dcd70" = "Defender for Office 365 P2"
    "871d91ec-ec1a-452b-a83f-bd76c7d770ef" = "Defender for Endpoint P2"
    "eec0eb4f-6444-4f95-aba0-50c24d67f998" = "Entra ID P2"
    "2f442157-a11c-46b9-ae5b-6e39ff4e5849" = "Audit Premium"
    "b1188c4c-1b36-4018-b48b-ee07604f6feb" = "Insider Risk Management"
    "41781fb2-bc02-4b7c-bd55-b576c07bb09d" = "eDiscovery Premium"
    "4828c8ec-dc2e-4779-b502-87ac9ce28ab7" = "Power BI Pro"
    "57ff2da0-773e-42df-b2af-ffb7a2317929" = "Teams Phone System"
}

# Resolve E5 SKU IDs
# SPE_E5 = M365 E5 (unified), ENTERPRISEPREMIUM = legacy O365 E5
# Add your tenant's E5 variants here if needed (e.g. M365EDU_A5_FACULTY)
$skus = Get-MgSubscribedSku -All
$e5SkuIds = ($skus | Where-Object {
    $_.SkuPartNumber -in @("SPE_E5", "ENTERPRISEPREMIUM")
}).SkuId

if (-not $e5SkuIds) {
    Write-Warning "No E5 SKUs found in tenant. Check Get-MgSubscribedSku output."
    return
}

Write-Host "Found E5 SKU IDs: $($e5SkuIds -join ', ')"

# Get all users with licence details
$users = Get-MgUser -All -Property "Id,DisplayName,UserPrincipalName,AssignedLicenses,SignInActivity,Department" `
    -ConsistencyLevel eventual -CountVariable userCount

# Filter to E5 users
$e5Users = $users | Where-Object {
    ($_.AssignedLicenses.SkuId | Where-Object { $_ -in $e5SkuIds } | Measure-Object).Count -gt 0
}

Write-Host "Total users: $userCount | E5 users: $($e5Users.Count)"

# Pull 90-day usage report
$usagePath = "$env:TEMP\M365Usage_E5.csv"
Invoke-MgGraphRequest -Uri "https://graph.microsoft.com/v1.0/reports/getOffice365ActiveUserDetail(period='D90')" `
    -OutputFilePath $usagePath
$usageData = Import-Csv $usagePath

$results = foreach ($user in $e5Users) {
    $licence = $user.AssignedLicenses | Where-Object { $_.SkuId -in $e5SkuIds } | Select-Object -First 1
    if (-not $licence) { continue }

    # Count enabled E5 service plans
    $enabledCount = 0
    $enabledPlans = @()
    foreach ($planId in $e5ServicePlans.Keys) {
        if ($licence.DisabledPlans -notcontains $planId) {
            $enabledCount++
            $enabledPlans += $e5ServicePlans[$planId]
        }
    }

    $lastSignIn = $user.SignInActivity.LastSignInDateTime
    $daysSinceSignIn = if ($lastSignIn) {
        [math]::Round(((Get-Date) - [datetime]$lastSignIn).TotalDays, 0)
    } else { 9999 }

    $activity = $usageData | Where-Object { $_.'User Principal Name' -eq $user.UserPrincipalName }

    [PSCustomObject]@{
        UPN                = $user.UserPrincipalName
        DisplayName        = $user.DisplayName
        Department         = $user.Department
        DaysSinceSignIn    = $daysSinceSignIn
        EnabledE5Plans     = $enabledCount
        EnabledPlanNames   = ($enabledPlans -join "; ")
        ExchangeActive     = $activity.'Exchange Last Activity Date'
        TeamsActive        = $activity.'Teams Last Activity Date'
    }
}

$results | Export-Csv $OutputPath -NoTypeInformation
Write-Host "`nE5 users analysed: $($results.Count)"
Write-Host "Report saved to: $OutputPath"
Write-Host "`nE5 plan distribution:"
$results | Group-Object EnabledE5Plans | Sort-Object { [int]$_.Name } |
    ForEach-Object { Write-Host "  $($_.Name) E5 plans enabled: $($_.Count) users" }
