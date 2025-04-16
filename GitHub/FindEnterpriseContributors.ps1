<#
.SYNOPSIS
Fetches organizations, repositories, and contributors from a GitHub Enterprise instance or user organizations.

.DESCRIPTION
This script interacts with the GitHub API to retrieve information about organizations, repositories, and contributors. 
It supports pagination for large datasets and collects unique contributors across all repositories.

.PARAMETER $token
The GitHub personal access token used for authentication. Ensure the token has the necessary permissions to access the API.
repo, read:org, read:enterprise (And authorise the organizations)
Store this in your environment variables as GITHUB_TOKEN for security. and restart VSCode

.PARAMETER $enterprise
The name of the GitHub Enterprise instance. For example, "mycompany". If not using GitHub Enterprise, the script will attempt to list organizations the user belongs to.

.PARAMETER $headers
A hashtable containing the headers required for API requests, including authorization and content type.

.PARAMETER $FileOutputCsv
Optional parameter. If provided, writes each unique contributor's email to a new line in the specified file after processing all contributors.

.FUNCTION Get-OrgRepositories
Fetches all repositories for a given organization. Supports pagination to handle large numbers of repositories.

.PARAMETER orgName
The name of the organization for which repositories are being fetched.

.PARAMETER headers
The headers used for API requests.

.OUTPUTS
Returns an array of repositories for the specified organization.

.FUNCTION Get-RepoContributors
Fetches all contributors for a given repository. Supports pagination to handle large numbers of contributors.

.PARAMETER repoFullName
The full name of the repository (e.g., "org/repo").

.PARAMETER headers
The headers used for API requests.

.OUTPUTS
Returns an array of contributors for the specified repository.

.NOTES
- Ensure the GitHub token has sufficient permissions to access the enterprise or user organizations.
- The script uses the GitHub API version "2022-11-28".
- The script handles errors gracefully and provides debug output for troubleshooting.

.EXAMPLE
# Example usage:
# Set the enterprise name
$enterprise = "your_enterprise_name"

# Run the script to fetch organizations, repositories, and contributors
# The script will output the results to the console.

.EXAMPLE
# If the enterprise name is incorrect or the token lacks permissions, the script will attempt to list organizations the user belongs to:
$enterprise = "invalid_enterprise_name"

# The script will fallback to listing user organizations and their repositories.

.OUTPUTS
- List of organizations and their repositories.
- List of unique contributors across all repositories.

#>

param(
    [Parameter(Mandatory=$true)]
    [string]$enterprise,  # e.g., "mycompany"
    [Parameter(Mandatory=$true)]
    [string]$FileOutputCsv
)
# Set your GitHub token and enterprise name
$token = $env:GITHUB_TOKEN

#print the $token and enterprise name
Write-Host "Enterprise: $enterprise"

# GitHub API URL - Fixed the URL format
$apiUrl = "https://api.github.com/enterprises/$enterprise/orgs"

# Add debug output to show the URL being accessed
Write-Host "Using API URL: $apiUrl"

# Headers for authorization
$headers = @{
    Authorization = "Bearer $token"
    Accept        = "application/vnd.github+json"
    "X-GitHub-Api-Version" = "2022-11-28"
    "User-Agent" = "PowerShell-Script"
}


# Function to get repositories for an organization
function Get-OrgRepositories {
    param (
        [string]$orgName,
        [hashtable]$headers
    )
    
    $repos = @()
    $page = 1
    
    do {
        $repoUrl = "https://api.github.com/orgs/$orgName/repos?per_page=100&page=$page"
        Write-Host "Fetching repositories for organization $orgName (page $page)..."
        
        try {
            $repoResponse = Invoke-RestMethod -Uri $repoUrl -Headers $headers -Method Get -ErrorAction Stop
            $repos += $repoResponse
            
            Write-Host "Found $($repoResponse.Count) repositories on page $page for organization $orgName"
            $page++ 
        }
        catch {
            Write-Host "Error fetching repositories for $orgName : $_"
            break
        }
    } while ($repoResponse -and $repoResponse.Count -gt 0)
    
    return $repos
}

function Get-RepoContributors {
    param (
        [string]$repoFullName,
        [hashtable]$headers
    )
    $contributors = @()
    $page = 1
    do {
        $url = "https://api.github.com/repos/$repoFullName/contributors?per_page=100&page=$page"
        try {
            $response = Invoke-RestMethod -Uri $url -Headers $headers -Method Get -ErrorAction Stop
            $contributors += $response
            $page++
        } catch {
            Write-Host "Error fetching contributors for $repoFullName : $_"
            break
        }
    } while ($response -and $response.Count -gt 0)
    return $contributors
}

# Pagination support
$orgs = @()
$page = 1

do {
    $url = "$apiUrl?per_page=100&page=$page"
    Write-Host "Fetching page $page from $url"
    
    try {
        $response = Invoke-RestMethod -Uri $url -Headers $headers -Method Get -ErrorAction Stop
        $orgs += $response
        
        Write-Host "Found $($response.Count) organizations on page $page"
        $page++
    }
    catch {
        Write-Host "Error: $_"
        Write-Host "Response: $($_.ErrorDetails.Message)"
        break
    }
} while ($response -and $response.Count -gt 0)

# Collect unique contributors
$uniqueContributors = @{}
$uniqueContributorEmails = @{}

# Output results
if ($orgs.Count -gt 0) {
    Write-Host "Total organizations found: $($orgs.Count)"
    $orgs | Select-Object login, id, description
    
    # Fetch repositories for each organization
    Write-Host "`n=== Repositories by Organization ==="
    foreach ($org in $orgs) {
        $orgRepos = Get-OrgRepositories -orgName $org.login -headers $headers
        Write-Host "`nOrganization: $($org.login) - $($orgRepos.Count) repositories found"
        $orgRepos | Select-Object name, html_url, description | Format-Table -AutoSize

        foreach ($repo in $orgRepos) {
            $contributors = Get-RepoContributors -repoFullName $repo.full_name -headers $headers
            foreach ($contributor in $contributors) {
                $uniqueContributors[$contributor.login] = $true
                if ($contributor.email -and $contributor.email -ne "") {
                    $uniqueContributorEmails[$contributor.email] = $true
                }
                # Try to get the user's public email from the GitHub API if not already present
                if (-not $uniqueContributorEmails.ContainsKey($contributor.login)) {
                    $userUrl = "https://api.github.com/users/$($contributor.login)"
                    try {
                        $userResponse = Invoke-RestMethod -Uri $userUrl -Headers $headers -Method Get -ErrorAction Stop
                        if ($userResponse.email -and $userResponse.email -ne "") {
                            $uniqueContributorEmails[$userResponse.email] = $true
                        }
                    } catch {
                        Write-Host "Could not fetch public email for $($contributor.login)"
                    }
                }
            }
        }
    }
}
else {
    Write-Host "No organizations found. This could be because:"
    Write-Host "1. The enterprise name '$enterprise' is incorrect"
    Write-Host "2. Your token doesn't have sufficient permissions"
    Write-Host "3. You're not using GitHub Enterprise or don't have enterprise access"
    
    Write-Host "`nTrying to list organizations you belong to instead..."
    try {
        $userOrgsUrl = "https://api.github.com/user/orgs"
        $userOrgs = Invoke-RestMethod -Uri $userOrgsUrl -Headers $headers -Method Get -ErrorAction Stop
        
        if ($userOrgs.Count -gt 0) {
            Write-Host "Found $($userOrgs.Count) organizations you belong to:"
            $userOrgs | Select-Object login, id, description
            
            # Fetch repositories for each user organization
            Write-Host "`n=== Repositories by Organization ==="
            foreach ($org in $userOrgs) {
                $orgRepos = Get-OrgRepositories -orgName $org.login -headers $headers
                Write-Host "`nOrganization: $($org.login) - $($orgRepos.Count) repositories found"
                $orgRepos | Select-Object name, html_url, description | Format-Table -AutoSize

                foreach ($repo in $orgRepos) {
                    $contributors = Get-RepoContributors -repoFullName $repo.full_name -headers $headers
                    foreach ($contributor in $contributors) {
                        $uniqueContributors[$contributor.login] = $true
                        if ($contributor.email -and $contributor.email -ne "") {
                            $uniqueContributorEmails[$contributor.email] = $true
                        }
                        # Try to get the user's public email from the GitHub API if not already present
                        if (-not $uniqueContributorEmails.ContainsKey($contributor.login)) {
                            $userUrl = "https://api.github.com/users/$($contributor.login)"
                            try {
                                $userResponse = Invoke-RestMethod -Uri $userUrl -Headers $headers -Method Get -ErrorAction Stop
                                if ($userResponse.email -and $userResponse.email -ne "") {
                                    $uniqueContributorEmails[$userResponse.email] = $true
                                }
                            } catch {
                                Write-Host "Could not fetch public email for $($contributor.login)"
                            }
                        }
                    }
                }
            }
        } else {
            Write-Host "No organizations found that you belong to."
        }
    }
    catch {
        Write-Host "Error fetching user organizations: $_"
    }

    foreach ($repo in $orgRepos) {
        Write-Host "`nRepository: $($repo.name)"
        $contributors = Get-RepoContributors -repoFullName $repo.full_name -headers $headers
        if ($contributors.Count -gt 0) {
            Write-Host "Contributors:"
            $contributors | Select-Object login, contributions, email | Format-Table -AutoSize
        } else {
            Write-Host "No contributors found."
        }
    }
}

# Print unique contributors
Write-Host "`n=== Unique Contributors Across All Orgs and Repos ==="
$uniqueContributors.Keys | Sort-Object | ForEach-Object { Write-Host $_ }

# Write emails to CSV if parameter is provided
if ($FileOutputCsv) {
    $uniqueContributorEmails.Keys | Sort-Object | Set-Content -Path $FileOutputCsv
    Write-Host "`nContributor emails written to $FileOutputCsv"
}

