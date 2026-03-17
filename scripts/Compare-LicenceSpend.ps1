<#
.SYNOPSIS
    Models M365 licence spend across three scenarios.

.DESCRIPTION
    Produces an executive comparison of licence costs: current state,
    all-E5, and an optimised E3 + targeted add-ons mix. All prices default
    to Microsoft list prices in GBP (annual commitment, early 2026).

.PARAMETER TotalUsers
    Total number of licensed users. Default: 1000.

.PARAMETER CurrentE5Users
    Number of users currently on E5. Default: 600.

.PARAMETER GenuineE5Need
    Number of users who genuinely need 3+ E5-exclusive feature areas. Default: 200.

.PARAMETER VoiceUsers
    Number of users requiring Teams Phone (PSTN calling). Default: 350.

.PARAMETER PowerBiUsers
    Number of users requiring Power BI Pro. Default: 150.

.PARAMETER CopilotUsers
    Number of users with Copilot for M365. Default: 100.

.EXAMPLE
    ./Compare-LicenceSpend.ps1 -TotalUsers 500 -CurrentE5Users 500 -GenuineE5Need 75

.EXAMPLE
    # Use your own CSP/EA pricing
    ./Compare-LicenceSpend.ps1 -E3Price 24.00 -E5Price 38.00

.NOTES
    Prices are Microsoft list prices as of early 2026. CSP and EA agreements
    typically offer 15-20% below list. The E3-to-E5 ratio remains approximately
    the same regardless of discount level.
#>

param(
    [int]$TotalUsers        = 1000,
    [int]$CurrentE5Users    = 600,
    [int]$GenuineE5Need     = 200,
    [int]$VoiceUsers        = 350,
    [int]$PowerBiUsers      = 150,
    [int]$CopilotUsers      = 100,
    [decimal]$E3Price       = 28.40,
    [decimal]$E5Price       = 45.00,
    [decimal]$EntraP2Price  = 7.20,
    [decimal]$MDEPrice      = 4.50,
    [decimal]$PhonePrice    = 7.40,
    [decimal]$PowerBiPrice  = 7.50,
    [decimal]$CopilotPrice  = 24.00
)

$currentE3 = $TotalUsers - $CurrentE5Users
$optimisedE3 = $TotalUsers - $GenuineE5Need
$e5Premium = $E5Price - $E3Price

# Scenario A: Current state
$currentSpend = ($CurrentE5Users * $E5Price) + ($currentE3 * $E3Price) + ($CopilotUsers * $CopilotPrice)

# Scenario B: All E5
$allE5Spend = ($TotalUsers * $E5Price) + ($CopilotUsers * $CopilotPrice)

# Scenario C: Optimised mix
$optimisedSpend =
    ($GenuineE5Need * $E5Price) +
    ($optimisedE3 * $E3Price) +
    ($optimisedE3 * $EntraP2Price) +          # Entra P2 for all E3 users
    ($optimisedE3 * $MDEPrice) +              # MDE P2 for all E3 users
    # Voice/BI: assumes E5 users absorb these needs first. Adjust if your
    # E5 cohort (e.g. security team) does not overlap with voice/BI users.
    ([math]::Max(0, $VoiceUsers - $GenuineE5Need) * $PhonePrice) +
    ([math]::Max(0, $PowerBiUsers - $GenuineE5Need) * $PowerBiPrice) +
    ($CopilotUsers * $CopilotPrice)

Write-Host ""
Write-Host "=== M365 Licence Spend Comparison ($TotalUsers users) ==="
Write-Host ""
Write-Host ("{0,-35} {1,15} {2,15}" -f "Scenario", "Monthly", "Annual")
Write-Host ("{0,-35} {1,15} {2,15}" -f ("-" * 35), ("-" * 15), ("-" * 15))
Write-Host ("{0,-35} {1,15} {2,15}" -f "Current state", "$('{0:N0}' -f $currentSpend)", "$('{0:N0}' -f ($currentSpend * 12))")
Write-Host ("{0,-35} {1,15} {2,15}" -f "All E5", "$('{0:N0}' -f $allE5Spend)", "$('{0:N0}' -f ($allE5Spend * 12))")
Write-Host ("{0,-35} {1,15} {2,15}" -f "Optimised E3 + add-ons", "$('{0:N0}' -f $optimisedSpend)", "$('{0:N0}' -f ($optimisedSpend * 12))")
Write-Host ""

$savingVsCurrent = ($currentSpend - $optimisedSpend) * 12
$savingVsAllE5 = ($allE5Spend - $optimisedSpend) * 12

Write-Host "E5 premium over E3:        $('{0:N2}' -f $e5Premium)/user/month"
Write-Host ""
Write-Host "Annual saving vs current:  $('{0:N0}' -f $savingVsCurrent)"
Write-Host "Annual saving vs all-E5:   $('{0:N0}' -f $savingVsAllE5)"
Write-Host ""
Write-Host "Breakpoint: E5 is cost-neutral when add-on costs exceed $('{0:N2}' -f $e5Premium)/user/month"
