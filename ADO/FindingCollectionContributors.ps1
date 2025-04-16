<#
.SYNOPSIS
Retrieves a list of unique contributors across all projects and repositories in an Azure DevOps organization.

.DESCRIPTION
This script connects to an Azure DevOps organization using a Personal Access Token (PAT) and retrieves all projects and their associated repositories. 
It then fetches the recent commits for each repository and extracts unique contributors (authors) based on their name and email address. 
Finally, it outputs a list of unique contributors across all projects and repositories.

.PARAMETER OrganizationName
The name of the Azure DevOps organization to query.

.PARAMETER FileOutputCsv
Optional. The path to a CSV file where the unique contributors' emails will be written.

.NOTES
- The script requires a Personal Access Token (PAT) to authenticate with Azure DevOps. 
    The PAT must be stored in the environment variable `AZURE_DEVOPS_PAT`.
- The script uses the Azure DevOps REST API (version 7.0) to fetch data.
- Ensure that the PAT has sufficient permissions to access the organization, projects, and repositories.

.EXAMPLE
.\FindingCollectionContributors.ps1 -OrganizationName "MyOrganization"

This example retrieves the unique contributors for all projects and repositories in the Azure DevOps organization "MyOrganization".

.EXAMPLE
.\FindingCollectionContributors.ps1 -OrganizationName "MyOrganization" -FileOutputCsv "contributors.csv"

This example retrieves the unique contributors for all projects and repositories in the Azure DevOps organization "MyOrganization" and writes their emails to "contributors.csv".

.OUTPUTS
- Writes the list of unique contributors to the console, grouped by project and repository.
- Outputs a summary of all unique contributors across all projects and repositories.
- Optionally writes the unique contributors' emails to a specified CSV file.

#>
param(
    [Parameter(Mandatory=$true)]
    [string]$OrganizationName,
    [Parameter(Mandatory=$true)]
    [string]$FileOutputCsv
)

# Build organization URL
$OrganizationUrl = "https://dev.azure.com/$OrganizationName"

# Get PAT from environment variable
$PAT = $env:AZURE_DEVOPS_PAT
if (-not $PAT) {
    Write-Error "Personal Access Token (AZURE_DEVOPS_PAT) not found in environment variables."
    exit 1
}

# Encode PAT for Authorization header
$Base64AuthInfo = [Convert]::ToBase64String([Text.Encoding]::ASCII.GetBytes(":$($PAT)"))

# Get all projects in the organization
$ProjectsUrl = "$OrganizationUrl/_apis/projects?api-version=7.0"
$ProjectsResponse = Invoke-RestMethod -Uri $ProjectsUrl -Headers @{Authorization = "Basic $Base64AuthInfo"}
$Projects = $ProjectsResponse.value

# Store unique contributors
$AllContributors = @{}

foreach ($Project in $Projects) {
    Write-Host "Project: $($Project.name)"
    # List repositories in the project
    $ReposUrl = "$OrganizationUrl/$($Project.name)/_apis/git/repositories?api-version=7.0"
    $ReposResponse = Invoke-RestMethod -Uri $ReposUrl -Headers @{Authorization = "Basic $Base64AuthInfo"}
    $Repos = $ReposResponse.value

    foreach ($Repo in $Repos) {
        Write-Host "  Repository: $($Repo.name)"
        # Get recent commits (default top 100)
        $CommitsUrl = "$OrganizationUrl/$($Project.name)/_apis/git/repositories/$($Repo.id)/commits?api-version=7.0"
        $CommitsResponse = Invoke-RestMethod -Uri $CommitsUrl -Headers @{Authorization = "Basic $Base64AuthInfo"}
        $Commits = $CommitsResponse.value

        # Get unique authors for this repo
        $Authors = $Commits | Select-Object -ExpandProperty author | Select-Object -Property name, email | Sort-Object -Unique
        foreach ($Author in $Authors) {
            $key = "$($Author.name)|$($Author.email)"
            if (-not $AllContributors.ContainsKey($key)) {
                $AllContributors[$key] = $Author
            }
            Write-Host "    Repo Contributor: $($Author.name) <$($Author.email)>"
        }
    }
}

Write-Host "\n=== Unique Contributors Across All Projects and Repos ==="
$AllContributors.Values | Sort-Object name | ForEach-Object { Write-Host ("{0} <{1}>" -f $_.name, $_.email) }

# Write emails to CSV if parameter is provided
if ($FileOutputCsv) {
    $Emails = $AllContributors.Values | Select-Object -ExpandProperty email | Sort-Object -Unique
    $Emails | Set-Content -Path $FileOutputCsv
    Write-Host "\nContributor emails written to $FileOutputCsv"
}