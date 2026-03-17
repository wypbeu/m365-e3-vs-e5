# M365 E3 vs E5 Decision Framework

PowerShell scripts for analysing Microsoft 365 E5 feature usage and modelling optimised licence spend. Companion repository for [Microsoft 365 E3 vs E5: The Decision Framework for Architects](https://sbd.org.uk/blog/e3-vs-e5).

## What This Does

Connects to your M365 tenant via Graph API and:

- **Analyses E5 feature usage** per user (which E5-exclusive service plans are enabled and active)
- **Identifies downgrade candidates** (E5 users with few E5 plans enabled or inactive accounts)
- **Models optimised spend** comparing current state, all-E5, and an optimised E3 + add-ons mix

## Prerequisites

- PowerShell 7+
- [Microsoft Graph PowerShell SDK](https://learn.microsoft.com/en-us/powershell/microsoftgraph/installation) v2.x
- Entra ID permissions:
  - `User.Read.All`
  - `Directory.Read.All`
  - `AuditLog.Read.All`
  - `Reports.Read.All`
  - `Organization.Read.All`

> **Report privacy:** A Global Admin must disable user-level report obfuscation in **M365 Admin Centre > Settings > Org Settings > Reports** for the usage cross-reference to work. Without this, usage reports return hashed identifiers.

## Quick Start

```powershell
# Clone the repo
git clone https://github.com/wypbeu/m365-e3-vs-e5.git
cd m365-e3-vs-e5

# Connect to Graph (interactive)
Connect-MgGraph -Scopes "User.Read.All","Directory.Read.All","AuditLog.Read.All","Reports.Read.All","Organization.Read.All"

# Step 1: Analyse E5 feature usage
./scripts/Get-E5FeatureUsage.ps1

# Step 2: Identify downgrade candidates
./scripts/Find-DowngradeCandidates.ps1

# Step 3: Model optimised spend
./scripts/Compare-LicenceSpend.ps1 -TotalUsers 1000 -CurrentE5Users 600 -GenuineE5Need 200
```

## Scripts

| Script | Purpose |
|--------|---------|
| `Get-E5FeatureUsage.ps1` | Analyses which E5-exclusive service plans are enabled on each E5 user and cross-references against 90-day workload activity |
| `Find-DowngradeCandidates.ps1` | Identifies E5 users with fewer than N E5 plans enabled or inactive for 90+ days |
| `Compare-LicenceSpend.ps1` | Produces an executive comparison: current state vs all-E5 vs optimised E3 + add-ons mix |

## Related Posts

- [The M365 Licensing Audit Nobody Wants to Do](https://sbd.org.uk/blog/m365-licensing-audit) - run this first to establish your baseline
- [Microsoft Graph API for Architects](https://sbd.org.uk/blog/graph-api-architects) - foundational Graph API patterns
- [M365 Tenant Health Audit](https://sbd.org.uk/blog/m365-tenant-health) - ongoing governance automation

## Licence

MIT
