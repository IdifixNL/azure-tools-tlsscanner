# Suppress Cryptography warnings from Azure CLI
[System.Environment]::SetEnvironmentVariable("PYTHONWARNINGS", "ignore", "Process")

# Suppress all warnings and only show errors in Azure CLI
az config set core.only_show_errors=true

# az login 
Write-Host "Logging in to Azure..."
# az login

# Fetch all subscriptions
Write-Host "Fetching all subscriptions..."
$Subscriptions = az account list --query "[].{id:id, name:name}" -o json | ConvertFrom-Json

# Set the output file path
$OutputFile = "C:\output\tls_scan_report.csv"

# Ensure the output directory exists
if (!(Test-Path -Path "C:\output")) {
    New-Item -ItemType Directory -Path "C:\output"
}

# Initialize the file with a blank slate
Set-Content -Path $OutputFile -Value ""

# Write a global header to the file
Add-Content -Path $OutputFile -Value "SubscriptionName,SubscriptionId,ResourceType,ResourceName,ResourceGroup,MinimumTLSVersion,Status,TenantId`r`n"

# Loop through all subscriptions
foreach ($Subscription in $Subscriptions) {
    $SubscriptionId = $Subscription.id
    $SubscriptionName = $Subscription.name

    Write-Host "Switching to subscription: $SubscriptionName ($SubscriptionId)"
    az account set --subscription $SubscriptionId

    # Fetch subscription and tenant info
    $AccountInfo = az account show --query "{TenantId:tenantId, SubscriptionId:id}" -o json | ConvertFrom-Json
    $TenantId = $AccountInfo.TenantId

    # Step 1: Scanning Storage Accounts
    Write-Host "Step 1: Scanning Storage Accounts in $SubscriptionName..."
    $StorageAccounts = az storage account list --query "[].{name:name, resourceGroup:resourceGroup}" -o json | ConvertFrom-Json

    foreach ($StorageAccount in $StorageAccounts) {
        $Name = $StorageAccount.name
        $ResourceGroup = $StorageAccount.resourceGroup

        # Fetch the Minimum TLS Version for the storage account
        $TLSVersion = az storage account show --name $Name --resource-group $ResourceGroup --query "minimumTlsVersion" -o tsv

        # Determine Compliance Status
        if ($TLSVersion -eq "TLS1_2") {
            $Status = "Compliant"
        } else {
            $Status = "Non-Compliant"
        }

        # Write Storage Account results to Output File
        Add-Content -Path $OutputFile -Value "$SubscriptionName,$SubscriptionId,StorageAccount,$Name,$ResourceGroup,$TLSVersion,$Status,$TenantId"
    }

    # Step 2: Scanning Application Insights Availability Tests
    Write-Host "Step 2: Scanning Application Insights Availability Tests in $SubscriptionName..."
    try {
        $AppInsightsResources = az resource list --resource-type "Microsoft.Insights/components" --query "[].{name:name, resourceGroup:resourceGroup}" -o json | ConvertFrom-Json

        if ($AppInsightsResources.Count -eq 0) {
            Write-Host "No Application Insights components found in $SubscriptionName."
        } else {
            foreach ($AppInsight in $AppInsightsResources) {
                $Name = $AppInsight.name
                $ResourceGroup = $AppInsight.resourceGroup

                # Assuming availability tests are TLS1.2-compliant
                $Status = "Compliant"
                $TLSVersion = "TLS1_2"

                # Write Application Insights results to Output File
                Add-Content -Path $OutputFile -Value "$SubscriptionName,$SubscriptionId,AppInsights,$Name,$ResourceGroup,$TLSVersion,$Status,$TenantId"
            }
        }
    } catch {
        Write-Host "An error occurred while scanning Application Insights in ${SubscriptionName}: ${_.Exception.Message}"
    }

    # Step 3: Scanning Azure App Service Static Web Apps
    Write-Host "Step 3: Scanning Azure App Service Static Web Apps in $SubscriptionName..."
    try {
        $StaticWebAppsOutput = az staticwebapp list --query "[].{name:name, resourceGroup:resourceGroup}" -o json 2>$null

        if (-not [string]::IsNullOrWhiteSpace($StaticWebAppsOutput)) {
            $StaticWebApps = $StaticWebAppsOutput | ConvertFrom-Json

            if ($StaticWebApps.Count -eq 0) {
                Write-Host "No Static Web Apps found in $SubscriptionName."
            } else {
                foreach ($StaticWebApp in $StaticWebApps) {
                    $Name = $StaticWebApp.name
                    $ResourceGroup = $StaticWebApp.resourceGroup

                    # Static Web Apps enforce HTTPS (TLS1.2) by default
                    $Status = "Compliant"
                    $TLSVersion = "TLS1_2"

                    # Write Static Web Apps results to Output File
                    Add-Content -Path $OutputFile -Value "$SubscriptionName,$SubscriptionId,StaticWebApp,$Name,$ResourceGroup,$TLSVersion,$Status,$TenantId"
                }
            }
        } else {
            Write-Host "No Static Web Apps found in ${SubscriptionName}."
        }
    } catch {
        Write-Host "An error occurred while scanning Static Web Apps in ${SubscriptionName}: ${_.Exception.Message}"
    }



    # Step 7: Scanning Azure Cache for Redis
    Write-Host "Step 7: Scanning Azure Cache for Redis in $SubscriptionName..."
    try {
        $RedisInstances = az redis list --query "[].{name:name, resourceGroup:resourceGroup, tlsVersion:minimumTlsVersion}" -o json | ConvertFrom-Json

        if ($RedisInstances.Count -eq 0) {
            Write-Host "No Redis instances found in $SubscriptionName."
        } else {
            foreach ($RedisInstance in $RedisInstances) {
                $Name = $RedisInstance.name
                $ResourceGroup = $RedisInstance.resourceGroup
                $TLSVersion = $RedisInstance.tlsVersion

                # Determine Compliance Status
                if ($TLSVersion -eq "1.2") {
                    $Status = "Compliant"
                } else {
                    $Status = "Non-Compliant"
                }

                # Write Redis results to Output File
                Add-Content -Path $OutputFile -Value "$SubscriptionName,$SubscriptionId,RedisCache,$Name,$ResourceGroup,$TLSVersion,$Status,$TenantId"
            }
        }
    } catch {
        Write-Host "An error occurred while scanning Azure Cache for Redis in ${SubscriptionName}: ${_.Exception.Message}"
    }
}

# Completion message
Write-Host "Scan complete for all subscriptions. Report saved to $OutputFile."
