<#
.SYNOPSIS
Adds users to a specified Microsoft Entra ID (Azure AD) security group based on a list of email addresses.

.DESCRIPTION
This script reads a list of email addresses from a specified file and adds the corresponding users to a specified Microsoft Entra ID (Azure AD) security group. 
It uses the Microsoft Graph PowerShell module to interact with Microsoft Graph API.

.PARAMETER EmailsFilePath
The file path to a text file containing email addresses of users to be added to the security group. 
Each email address should be on a separate line.

.PARAMETER GroupId
The object ID of the Microsoft Entra ID (Azure AD) security group to which the users will be added.

.EXAMPLE
.\AddUsersToSecurityGroup.ps1 -EmailsFilePath "C:\Users\example\emails.txt" -GroupId "12345678-90ab-cdef-1234-567890abcdef"

This example reads email addresses from the file "emails.txt" and adds the corresponding users to the security group with the specified GroupId.

.NOTES
- The script requires the Microsoft Graph PowerShell module. If it is not installed, the script will install it automatically.
- The script requires the following Microsoft Graph API permissions: GroupMember.ReadWrite.All and User.ReadBasic.All.
- The user running the script must have sufficient permissions to add members to the specified group.

#>

param(
    [Parameter(Mandatory=$true)]
    [string]$EmailsFilePath,
    [Parameter(Mandatory=$true)]
    [string]$GroupId
)

# Import Microsoft Graph module (install if needed)
if (-not (Get-Module -ListAvailable -Name Microsoft.Graph)) {
    write-host "Microsoft.Graph module not found. Installing..."
    Install-Module Microsoft.Graph -Scope CurrentUser -Force
}
Import-Module Microsoft.Graph

# Ensure Microsoft.Graph.Groups module is installed and imported
if (-not (Get-Module -ListAvailable -Name Microsoft.Graph.Groups)) {
    Install-Module Microsoft.Graph.Groups -Scope CurrentUser -Force
}
Import-Module Microsoft.Graph.Groups

# Connect to Microsoft Graph (interactive login)
Connect-MgGraph -Scopes "GroupMember.ReadWrite.All,User.ReadBasic.All"

# Read emails from file
$Emails = Get-Content -Path $EmailsFilePath | Where-Object { $_ -match '\S' }

foreach ($Email in $Emails) {
    # Get user by email
    $User = Get-MgUser -Filter "mail eq '$Email'" -ErrorAction SilentlyContinue
    if ($User) {
        try {
            # Add user to group
            New-MgGroupMember -GroupId $GroupId -DirectoryObjectId $User.Id
            Write-Host "Added $Email to group."
        } catch {
            Write-Warning "Failed to add $Email : $_"
        }
    } else {
        Write-Warning "User not found: $Email"
    }
}

Disconnect-MgGraph
