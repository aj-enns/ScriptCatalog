# ScriptCatalog

This repository is a collection of scripts designed for Developer Advocates to streamline and automate common activities. The initial focus is on scripts related to GitHub Copilot, but the catalog will expand to cover a broader range of developer advocacy tasks over time.

## Purpose
- Provide reusable automation and productivity scripts for Developer Advocates
- Share best practices and common workflows
- Help new and experienced advocates leverage tools like GitHub Copilot

## Getting Started
Scripts are organized by topic in subfolders. See each script's documentation for usage instructions.

## Recent Changes
- Added a common `.gitignore` for typical development environments.
- Refactored `ADO/FindingCollectionContributors.ps1` to report unique commit contributors across all projects and repos, removing team member listing.
- Added `EntraID/AddUsersToSecurityGroup.ps1` to read a file of emails and add users to an Entra ID (Azure AD) security group. Now uses `New-MgGroupMember` for compatibility with the latest Microsoft Graph module.
- Updated PowerShell launch configuration to debug the currently open file.

---

Contributions and suggestions are welcome!