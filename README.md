TLS Scanner for Azure Resources

Overview

This script is designed to scan Azure resources across multiple subscriptions to check for TLS settings and determine compliance with TLS 1.2 security standards. The script outputs a structured CSV report summarizing the TLS versions of various Azure services, highlighting resources that require manual investigation or remediation.

Features

Iterates through all Azure subscriptions and checks for various resource types.

Queries TLS settings for each resource and determines compliance with TLS 1.2.

Handles missing resources gracefully and logs relevant details.

Outputs structured results to a CSV file for further analysis.

Provides warnings for resources with unknown TLS settings.

Suppresses unnecessary warnings from Azure CLI for cleaner output.

Prerequisites

Before running the script, ensure the following prerequisites are met:

Install Azure CLI (Installation Guide).

Login to Azure using:

az login

Ensure you have the necessary permissions to list and query the required Azure resources.

PowerShell should be installed on your system.

If running locally, ensure execution policy allows scripts to be executed:

Set-ExecutionPolicy RemoteSigned -Scope CurrentUser

Configuration

Before running the script, you may need to configure certain paths and variables:

Output File Path

By default, the script saves the output CSV file to:

$OutputFile = "C:\output\tls_scan_report.csv"

If you want to change this location, update the $OutputFile variable accordingly.

Azure Login

Ensure you are logged into Azure before running the script. If running in an automated environment, ensure authentication is handled properly.

Azure Subscriptions

The script fetches all available subscriptions automatically:

$Subscriptions = az account list --query "[].{id:id, name:name}" -o json | ConvertFrom-Json

If you want to limit the scope to specific subscriptions, modify this section accordingly.

Usage

Running the Script

To execute the script:

.	ls_scan.ps1

or, if execution policy requires elevation:

powershell -ExecutionPolicy Bypass -File tls_scan.ps1

Expected Output

The script outputs a CSV file containing the following columns:

SubscriptionName - Name of the Azure subscription.

SubscriptionId - Unique ID of the subscription.

ResourceType - Type of Azure resource being scanned.

ResourceName - Name of the resource.

ResourceGroup - The resource group the resource belongs to.

MinimumTLSVersion - The detected minimum TLS version for the resource.

Status - Whether the resource is compliant (TLS 1.2) or non-compliant.

TenantId - Azure tenant ID.

Example Output:

SubscriptionName,SubscriptionId,ResourceType,ResourceName,ResourceGroup,MinimumTLSVersion,Status,TenantId
MySubscription,1234-5678-9101,AzureStorage,myStorageAccount,myResourceGroup,TLS1_2,Compliant,abcd-efgh-ijkl

Handling "Unknown" TLS Versions

If a resource returns an Unknown TLS version, the script logs a warning:

Write-Host "⚠️ WARNING: TLS version for $Name in $ResourceGroup is Unknown. Manual check required!" -ForegroundColor Yellow

You should manually review such cases to confirm compliance.

Supported Azure Services

The script scans the following Azure resources for TLS settings:

API Management Services

Azure Storage Accounts

Application Gateways

Application Insights Availability Tests

Static Web Apps

Azure Cache for Redis

Azure Cosmos DB

Azure Databases (MariaDB, MySQL, PostgreSQL, SQL Server, SQL Managed Instance, etc.)

Azure Front Door

Azure Key Vault

Azure Service Bus

Azure Traffic Manager

Azure Web Application Firewall

Azure IoT Hub

Event Grid and Event Hubs

Azure Synapse Analytics

Troubleshooting

No Output or Empty Report

Ensure you have permissions to access the required resources.

Run the script with Write-Host enabled to see verbose output.

"Unknown" TLS Versions

Some services might not expose their TLS version settings via Azure CLI.

Check manually via the Azure Portal if necessary.

Errors While Switching Subscriptions

If you encounter errors when switching subscriptions:

az account set --subscription <SubscriptionId>

Manually set the subscription and rerun the script for that specific subscription.

Next Steps

Review the tls_scan_report.csv file for compliance.

Implement necessary remediation steps for non-compliant resources.

Automate execution via Azure DevOps or Scheduled Tasks for periodic compliance checks.

Contributions

Feel free to contribute enhancements or bug fixes to improve this script!

License

This script is open-source and provided as-is without warranties. Use at your own risk.

Happy Scanning! 🚀

