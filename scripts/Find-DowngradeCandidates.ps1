<#
.SYNOPSIS
    Identifies E5 users who are candidates for downgrade to E3.

.DESCRIPTION
    Reads the output from Get-E5FeatureUsage.ps1 and flags users with fewer
    than the specified number of E5 plans enabled, or who have not signed in
    for the specified number of days.

.PARAMETER ReportPath
    Path to the E5 feature usage CSV. Defaults to $env:TEMP\E5FeatureUsage.csv.

.PARAMETER MinE5Plans
    Minimum number of E5 plans a user should have enabled to justify E5.
    Users below this threshold are flagged. Default: 2.

.PARAMETER InactiveDays
    Number of days since last sign-in to consider a user inactive. Default: 90.

.EXAMPLE
    ./Find-DowngradeCandidates.ps1 -MinE5Plans 3 -InactiveDays 60

.NOTES
    Run Get-E5FeatureUsage.ps1 first to generate the input report.
#>

param(
    [string]$ReportPath = "$env:TEMP\E5FeatureUsage.csv",
    [int]$MinE5Plans = 2,
    [int]$InactiveDays = 90
)

if (-not (Test-Path $ReportPath)) {
    Write-Error "Report not found at $ReportPath. Run Get-E5FeatureUsage.ps1 first."
    return
}

$e5Users = Import-Csv $ReportPath

$candidates = $e5Users | Where-Object {
    [int]$_.DaysSinceSignIn -ge $InactiveDays -or
    [int]$_.EnabledE5Plans -lt $MinE5Plans
} | Select-Object UPN, DisplayName, Department, DaysSinceSignIn, EnabledE5Plans,
    @{N="Reason"; E={
        $reasons = @()
        if ([int]$_.DaysSinceSignIn -ge $InactiveDays) {
            $reasons += "Inactive ($($_.DaysSinceSignIn) days)"
        }
        if ([int]$_.EnabledE5Plans -lt $MinE5Plans) {
            $reasons += "Only $($_.EnabledE5Plans) E5 plan(s) enabled"
        }
        $reasons -join "; "
    }}

$outputPath = "$env:TEMP\E5DowngradeCandidates.csv"
$candidates | Export-Csv $outputPath -NoTypeInformation

$monthlySaving = $candidates.Count * 16.60
Write-Host "`nDowngrade candidates: $($candidates.Count) of $($e5Users.Count) E5 users"
Write-Host "Estimated monthly saving: $('{0:C0}' -f $monthlySaving) (at list price delta of 16.60/user/month)"
Write-Host "Estimated annual saving:  $('{0:C0}' -f ($monthlySaving * 12))"
Write-Host "Report saved to: $outputPath"
Write-Host ""

$candidates | Sort-Object { [int]$_.EnabledE5Plans } |
    Format-Table UPN, Department, DaysSinceSignIn, EnabledE5Plans, Reason -AutoSize
