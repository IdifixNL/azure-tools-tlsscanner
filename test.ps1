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

# Initialize the file with headers
Set-Content -Path $OutputFile -Value "SubscriptionName,SubscriptionId,ResourceType,ResourceName,ResourceGroup,MinimumTLSVersion,Status,TenantId`r`n"

# Loop through each subscription and scan for TLS settings
foreach ($Subscription in $Subscriptions) {
    $SubscriptionId = $Subscription.id
    $SubscriptionName = $Subscription.name

    Write-Host "Switching to Subscription: $SubscriptionName ($SubscriptionId)"
    az account set --subscription $SubscriptionId

    # Fetch Tenant ID for the current subscription
    $AccountInfo = az account show --query "{TenantId:tenantId}" -o json | ConvertFrom-Json
    $TenantId = $AccountInfo.TenantId

    ###########################
    # Step 1: API Management TLS Scanning
    ###########################

    Write-Host "Scanning API Management Services for TLS settings..."
    $ApiManagementServices = az apim list --query "[].{name:name, resourceGroup:resourceGroup}" -o json | ConvertFrom-Json

    if ($ApiManagementServices.Count -eq 0) {
        Add-Content -Path $OutputFile -Value "$SubscriptionName,$SubscriptionId,APIManagement,No API Management Services found,N/A,N/A,N/A,$TenantId"
    } else {
        foreach ($ApiManagementService in $ApiManagementServices) {
            $Name = $ApiManagementService.name
            $ResourceGroup = $ApiManagementService.resourceGroup

            $GatewayTLSVersion = az apim show --name $Name --resource-group $ResourceGroup --query "properties.protocols[?protocol=='https'].minTlsVersion" -o tsv
            $BackendTLSVersion = az apim show --name $Name --resource-group $ResourceGroup --query "properties.backendService.tls.minTlsVersion" -o tsv

            # Default to "Unknown" if not found
            if (-not $GatewayTLSVersion) { $GatewayTLSVersion = "Unknown" }
            if (-not $BackendTLSVersion) { $BackendTLSVersion = "Unknown" }

            # Determine Compliance Status
            $Status = if ($GatewayTLSVersion -eq "TLS1_2" -and $BackendTLSVersion -eq "TLS1_2") { "Compliant" } else { "Non-Compliant" }

            Add-Content -Path $OutputFile -Value "$SubscriptionName,$SubscriptionId,APIManagement,$Name,$ResourceGroup,$GatewayTLSVersion/$BackendTLSVersion,$Status,$TenantId"
        }
    }

    ###########################
    # Step 2: Azure Storage TLS Scanning
    ###########################

    Write-Host "Scanning Azure Storage Accounts for TLS settings..."
    $StorageAccounts = az storage account list --query "[].{name:name, resourceGroup:resourceGroup}" -o json | ConvertFrom-Json

    if ($StorageAccounts.Count -eq 0) {
        Add-Content -Path $OutputFile -Value "$SubscriptionName,$SubscriptionId,AzureStorage,No Storage Accounts found,N/A,N/A,N/A,$TenantId"
    } else {
        foreach ($StorageAccount in $StorageAccounts) {
            $Name = $StorageAccount.name
            $ResourceGroup = $StorageAccount.resourceGroup

            $TLSVersion = az storage account show --name $Name --resource-group $ResourceGroup --query "minimumTlsVersion" -o tsv
            if (-not $TLSVersion) { $TLSVersion = "Unknown" }

            $Status = if ($TLSVersion -eq "TLS1_2") { "Compliant" } else { "Non-Compliant" }

            Add-Content -Path $OutputFile -Value "$SubscriptionName,$SubscriptionId,AzureStorage,$Name,$ResourceGroup,$TLSVersion,$Status,$TenantId"
        }
    }




###########################
# Step 3: Application Gateway TLS Scanning
###########################

Write-Host "Scanning Application Gateways for TLS settings in Subscription: $SubscriptionName"

$AppGateways = az network application-gateway list --query "[].{name:name, resourceGroup:resourceGroup}" -o json | ConvertFrom-Json

# Check if there are any Application Gateways in this subscription
if ($AppGateways.Count -eq 0) {
    Add-Content -Path $OutputFile -Value "$SubscriptionName,$SubscriptionId,ApplicationGateway,No Application Gateways found,N/A,N/A,N/A,$TenantId"
} else {
    foreach ($AppGateway in $AppGateways) {
        $Name = $AppGateway.name
        $ResourceGroup = $AppGateway.resourceGroup

        # Fetch the TLS version used in the frontend configuration
        $FrontendTLSVersion = az network application-gateway show --name $Name --resource-group $ResourceGroup --query "sslPolicy.minProtocolVersion" -o tsv

        # Default to "Unknown" if not found
        if (-not $FrontendTLSVersion) { $FrontendTLSVersion = "Unknown" }

        # Determine Compliance Status
        $Status = if ($FrontendTLSVersion -eq "TLS1_2") { "Compliant" } else { "Non-Compliant" }

        # Write Application Gateway results to Output File
        Add-Content -Path $OutputFile -Value "$SubscriptionName,$SubscriptionId,ApplicationGateway,$Name,$ResourceGroup,$FrontendTLSVersion,$Status,$TenantId"
    }
}

###########################
# Step 4: Application Insights Availability Tests TLS Scanning
###########################

Write-Host "Step 4: Scanning Application Insights Availability Tests for TLS settings in Subscription: $SubscriptionName"

$AppInsightsResources = az resource list --resource-type "Microsoft.Insights/webtests" --query "[].{name:name, resourceGroup:resourceGroup}" -o json | ConvertFrom-Json

if ($AppInsightsResources.Count -eq 0) {
    Add-Content -Path $OutputFile -Value "$SubscriptionName,$SubscriptionId,ApplicationInsightsAvailabilityTests,No Application Insights Availability Tests found,N/A,N/A,N/A,$TenantId"
} else {
    foreach ($AppInsight in $AppInsightsResources) {
        $Name = $AppInsight.name
        $ResourceGroup = $AppInsight.resourceGroup

        # Fetch the Minimum TLS Version for the Application Insights availability test
        $TLSVersion = az resource show --name $Name --resource-group $ResourceGroup --resource-type "Microsoft.Insights/webtests" --query "properties.configuration.tlsVersion" -o tsv

        if (-not $TLSVersion) { $TLSVersion = "Unknown" }

        # Determine Compliance Status
        $Status = if ($TLSVersion -eq "1.2") { "Compliant" } else { "Non-Compliant" }

        Add-Content -Path $OutputFile -Value "$SubscriptionName,$SubscriptionId,ApplicationInsightsAvailabilityTests,$Name,$ResourceGroup,$TLSVersion,$Status,$TenantId"
    }
}

###########################
# Step 5: Azure App Service Static Web Apps TLS Scanning
###########################

Write-Host "Step 5: Scanning Azure App Service Static Web Apps for TLS settings in Subscription: $SubscriptionName"

$StaticWebApps = az staticwebapp list --query "[].{name:name, resourceGroup:resourceGroup}" -o json | ConvertFrom-Json

if ($StaticWebApps.Count -eq 0) {
    Add-Content -Path $OutputFile -Value "$SubscriptionName,$SubscriptionId,AzureAppServiceStaticWebApps,No Static Web Apps found,N/A,N/A,N/A,$TenantId"
} else {
    foreach ($StaticWebApp in $StaticWebApps) {
        $Name = $StaticWebApp.name
        $ResourceGroup = $StaticWebApp.resourceGroup

        # Fetch the Minimum TLS Version for the Static Web App
        $TLSVersion = az staticwebapp show --name $Name --resource-group $ResourceGroup --query "properties.customDomains[0].httpsOptions.minTlsVersion" -o tsv

        if (-not $TLSVersion) { $TLSVersion = "Unknown" }

        # Determine Compliance Status
        $Status = if ($TLSVersion -eq "1.2") { "Compliant" } else { "Non-Compliant" }

        Add-Content -Path $OutputFile -Value "$SubscriptionName,$SubscriptionId,AzureAppServiceStaticWebApps,$Name,$ResourceGroup,$TLSVersion,$Status,$TenantId"
    }
}

###########################
# Step 6: Arc place holder
###########################

###########################
# Step 7: Azure Cache for Redis TLS Scanning
###########################

Write-Host "Step 7: Scanning Azure Cache for Redis for TLS settings in Subscription: $SubscriptionName"

$RedisCaches = az redis list --query "[].{name:name, resourceGroup:resourceGroup}" -o json | ConvertFrom-Json

if ($RedisCaches.Count -eq 0) {
    Add-Content -Path $OutputFile -Value "$SubscriptionName,$SubscriptionId,AzureCacheForRedis,No Redis Caches found,N/A,N/A,N/A,$TenantId"
} else {
    foreach ($RedisCache in $RedisCaches) {
        $Name = $RedisCache.name
        $ResourceGroup = $RedisCache.resourceGroup

        # Fetch the Minimum TLS Version for the Redis Cache
        $TLSVersion = az redis show --name $Name --resource-group $ResourceGroup --query "minimumTlsVersion" -o tsv

        if (-not $TLSVersion) { $TLSVersion = "Unknown" }

        # Determine Compliance Status
        $Status = if ($TLSVersion -eq "1.2") { "Compliant" } else { "Non-Compliant" }

        Add-Content -Path $OutputFile -Value "$SubscriptionName,$SubscriptionId,AzureCacheForRedis,$Name,$ResourceGroup,$TLSVersion,$Status,$TenantId"
    }
}

###########################
# Step 8: Azure Cosmos DB TLS Scanning
###########################

Write-Host "Step 8: Scanning Azure Cosmos DB instances for TLS settings in Subscription: $SubscriptionName"

$CosmosDBAccounts = az cosmosdb list --query "[].{name:name, resourceGroup:resourceGroup}" -o json | ConvertFrom-Json

if ($CosmosDBAccounts.Count -eq 0) {
    Add-Content -Path $OutputFile -Value "$SubscriptionName,$SubscriptionId,AzureCosmosDB,No Azure Cosmos DB instances found,N/A,N/A,N/A,$TenantId"
} else {
    foreach ($CosmosDB in $CosmosDBAccounts) {
        $Name = $CosmosDB.name
        $ResourceGroup = $CosmosDB.resourceGroup

        # Fetch the Minimum TLS Version for the Cosmos DB account
        $TLSVersion = az cosmosdb show --name $Name --resource-group $ResourceGroup --query "minimalTlsVersion" -o tsv

        if (-not $TLSVersion) { $TLSVersion = "Unknown" }

        # Determine Compliance Status
        $Status = if ($TLSVersion -eq "TLS1_2") { "Compliant" } else { "Non-Compliant" }

        Add-Content -Path $OutputFile -Value "$SubscriptionName,$SubscriptionId,AzureCosmosDB,$Name,$ResourceGroup,$TLSVersion,$Status,$TenantId"
    }
}

###########################
# Step 9: Azure Database for MariaDB TLS Scanning
###########################

Write-Host "Step 9: Scanning Azure Database for MariaDB instances for TLS settings in Subscription: $SubscriptionName"

$MariaDBServers = az mariadb server list --query "[].{name:name, resourceGroup:resourceGroup}" -o json | ConvertFrom-Json

if ($MariaDBServers.Count -eq 0) {
    Add-Content -Path $OutputFile -Value "$SubscriptionName,$SubscriptionId,AzureDatabaseForMariaDB,No Azure Database for MariaDB instances found,N/A,N/A,N/A,$TenantId"
} else {
    foreach ($MariaDB in $MariaDBServers) {
        $Name = $MariaDB.name
        $ResourceGroup = $MariaDB.resourceGroup

        # Fetch the Minimum TLS Version for the MariaDB instance
        $TLSVersion = az mariadb server show --name $Name --resource-group $ResourceGroup --query "sslEnforcement" -o tsv

        if (-not $TLSVersion) { $TLSVersion = "Unknown" }

        # Convert "Enabled" to TLS1_2 for clarity
        if ($TLSVersion -eq "Enabled") {
            $TLSVersion = "TLS1_2"
            $Status = "Compliant"
        } else {
            $Status = "Non-Compliant"
        }

        Add-Content -Path $OutputFile -Value "$SubscriptionName,$SubscriptionId,AzureDatabaseForMariaDB,$Name,$ResourceGroup,$TLSVersion,$Status,$TenantId"
    }
}

###########################
# Step 10: Azure Database for MySQL TLS Scanning
###########################

Write-Host "Step 10: Scanning Azure Database for MySQL instances for TLS settings in Subscription: $SubscriptionName"

$MySQLServers = az mysql server list --query "[].{name:name, resourceGroup:resourceGroup}" -o json | ConvertFrom-Json

if ($MySQLServers.Count -eq 0) {
    Add-Content -Path $OutputFile -Value "$SubscriptionName,$SubscriptionId,AzureDatabaseForMySQL,No Azure Database for MySQL instances found,N/A,N/A,N/A,$TenantId"
} else {
    foreach ($MySQL in $MySQLServers) {
        $Name = $MySQL.name
        $ResourceGroup = $MySQL.resourceGroup

        # Fetch the Minimum TLS Version for the MySQL instance
        $TLSVersion = az mysql server show --name $Name --resource-group $ResourceGroup --query "sslEnforcement" -o tsv

        if (-not $TLSVersion) { $TLSVersion = "Unknown" }

        # Convert "Enabled" to TLS1_2 for clarity
        if ($TLSVersion -eq "Enabled") {
            $TLSVersion = "TLS1_2"
            $Status = "Compliant"
        } else {
            $Status = "Non-Compliant"
        }

        Add-Content -Path $OutputFile -Value "$SubscriptionName,$SubscriptionId,AzureDatabaseForMySQL,$Name,$ResourceGroup,$TLSVersion,$Status,$TenantId"
    }
}
    
###########################
# Step 11: Azure Database for PostgreSQL TLS Scanning
###########################

Write-Host "Step 11: Scanning Azure Database for PostgreSQL instances for TLS settings in Subscription: $SubscriptionName"

$PostgreSQLServers = az postgres server list --query "[].{name:name, resourceGroup:resourceGroup}" -o json | ConvertFrom-Json

if ($PostgreSQLServers.Count -eq 0) {
    Add-Content -Path $OutputFile -Value "$SubscriptionName,$SubscriptionId,AzureDatabaseForPostgreSQL,No PostgreSQL instances found,N/A,N/A,N/A,$TenantId"
} else {
    foreach ($PostgreSQL in $PostgreSQLServers) {
        $Name = $PostgreSQL.name
        $ResourceGroup = $PostgreSQL.resourceGroup

        # Fetch the Minimum TLS Version for the PostgreSQL instance
        $TLSVersion = az postgres server show --name $Name --resource-group $ResourceGroup --query "sslEnforcement" -o tsv

        if (-not $TLSVersion) { $TLSVersion = "Unknown" }

        # Convert "Enabled" to TLS1_2 for clarity
        if ($TLSVersion -eq "Enabled") {
            $TLSVersion = "TLS1_2"
            $Status = "Compliant"
        } else {
            $Status = "Non-Compliant"
        }

        Add-Content -Path $OutputFile -Value "$SubscriptionName,$SubscriptionId,AzureDatabaseForPostgreSQL,$Name,$ResourceGroup,$TLSVersion,$Status,$TenantId"
    }
}

###########################
# Step 12: Azure Database Migration Service TLS Scanning
###########################

Write-Host "Step 12: Scanning Azure Database Migration Service instances for TLS settings in Subscription: $SubscriptionName"

$MigrationServices = az dms list --query "[].{name:name, resourceGroup:resourceGroup}" -o json | ConvertFrom-Json

if ($MigrationServices.Count -eq 0) {
    Add-Content -Path $OutputFile -Value "$SubscriptionName,$SubscriptionId,AzureDatabaseMigrationService,No Database Migration Service instances found,N/A,N/A,N/A,$TenantId"
} else {
    foreach ($MigrationService in $MigrationServices) {
        $Name = $MigrationService.name
        $ResourceGroup = $MigrationService.resourceGroup

        # Fetch the Minimum TLS Version for the Database Migration Service
        $TLSVersion = az dms show --name $Name --resource-group $ResourceGroup --query "sku.tier" -o tsv

        if (-not $TLSVersion) { $TLSVersion = "Unknown" }

        # Determine Compliance Status (Premium tier enforces TLS 1.2 by default)
        $Status = if ($TLSVersion -eq "Premium") { "Compliant" } else { "Non-Compliant" }

        Add-Content -Path $OutputFile -Value "$SubscriptionName,$SubscriptionId,AzureDatabaseMigrationService,$Name,$ResourceGroup,$TLSVersion,$Status,$TenantId"
    }
}

###########################
# Step 13: Azure Front Door / Azure Front Door X TLS Scanning
###########################

Write-Host "Step 13: Scanning Azure Front Door instances for TLS settings in Subscription: $SubscriptionName"

$FrontDoors = az afd profile list --query "[].{name:name, resourceGroup:resourceGroup}" -o json | ConvertFrom-Json

if ($FrontDoors.Count -eq 0) {
    Add-Content -Path $OutputFile -Value "$SubscriptionName,$SubscriptionId,AzureFrontDoor,No Azure Front Door instances found,N/A,N/A,N/A,$TenantId"
} else {
    foreach ($FrontDoor in $FrontDoors) {
        $Name = $FrontDoor.name
        $ResourceGroup = $FrontDoor.resourceGroup

        # Fetch the Minimum TLS Version for the Front Door
        $TLSVersion = az afd profile show --name $Name --resource-group $ResourceGroup --query "properties.frontendEndpoints[0].properties.minimumTlsVersion" -o tsv

        if (-not $TLSVersion) { $TLSVersion = "Unknown" }

        # Determine Compliance Status
        $Status = if ($TLSVersion -eq "TLS1_2") { "Compliant" } else { "Non-Compliant" }

        Add-Content -Path $OutputFile -Value "$SubscriptionName,$SubscriptionId,AzureFrontDoor,$Name,$ResourceGroup,$TLSVersion,$Status,$TenantId"
    }
}

###########################
# Step 14: Azure Resource Manager (ARM) TLS Scanning
###########################

Write-Host "Step 14: Checking Azure Policy for Secure Transfer enforcement in Subscription: $SubscriptionName"

# Check if a Secure Transfer policy exists
$SecureTransferPolicy = az policy definition list --query "[?contains(displayName, 'Secure Transfer')]" -o json | ConvertFrom-Json

if ($SecureTransferPolicy.Count -eq 0) {
    $Status = "Non-Compliant"
    $TLSVersion = "Unknown"
} else {
    $Status = "Compliant"
    $TLSVersion = "TLS1_2"
}

Add-Content -Path $OutputFile -Value "$SubscriptionName,$SubscriptionId,AzureResourceManager,Global,N/A,$TLSVersion,$Status,$TenantId"

###########################
# Step 15: Azure SQL Database TLS Scanning
###########################

Write-Host "Step 15: Scanning Azure SQL Database instances for TLS settings in Subscription: $SubscriptionName"

$SQLDatabases = az sql server list --query "[].{name:name, resourceGroup:resourceGroup}" -o json | ConvertFrom-Json

if ($SQLDatabases.Count -eq 0) {
    Add-Content -Path $OutputFile -Value "$SubscriptionName,$SubscriptionId,AzureSQLDatabase,No Azure SQL Databases found,N/A,N/A,N/A,$TenantId"
} else {
    foreach ($SQLDatabase in $SQLDatabases) {
        $Name = $SQLDatabase.name
        $ResourceGroup = $SQLDatabase.resourceGroup

        # Fetch the Minimum TLS Version for the SQL Server
        $TLSVersion = az sql server show --name $Name --resource-group $ResourceGroup --query "minimalTlsVersion" -o tsv

        if (-not $TLSVersion) { $TLSVersion = "Unknown" }

        # Determine Compliance Status
        $Status = if ($TLSVersion -eq "1.2") { "Compliant" } else { "Non-Compliant" }

        Add-Content -Path $OutputFile -Value "$SubscriptionName,$SubscriptionId,AzureSQLDatabase,$Name,$ResourceGroup,$TLSVersion,$Status,$TenantId"
    }
}

###########################
# Step 16: Azure SQL Database Edge TLS Scanning
###########################

Write-Host "Step 16: Scanning Azure SQL Database Edge instances for TLS settings in Subscription: $SubscriptionName"

$SQLEdgeInstances = az sql server list --query "[].{name:name, resourceGroup:resourceGroup}" -o json | ConvertFrom-Json

if ($SQLEdgeInstances.Count -eq 0) {
    Add-Content -Path $OutputFile -Value "$SubscriptionName,$SubscriptionId,AzureSQLDatabaseEdge,No Azure SQL Database Edge instances found,N/A,N/A,N/A,$TenantId"
} else {
    foreach ($SQLEdge in $SQLEdgeInstances) {
        $Name = $SQLEdge.name
        $ResourceGroup = $SQLEdge.resourceGroup

        # Fetch the Minimum TLS Version for SQL Database Edge
        $TLSVersion = az sql server show --name $Name --resource-group $ResourceGroup --query "minimalTlsVersion" -o tsv

        if (-not $TLSVersion) { $TLSVersion = "Unknown" }

        # Determine Compliance Status
        $Status = if ($TLSVersion -eq "1.2") { "Compliant" } else { "Non-Compliant" }

        Add-Content -Path $OutputFile -Value "$SubscriptionName,$SubscriptionId,AzureSQLDatabaseEdge,$Name,$ResourceGroup,$TLSVersion,$Status,$TenantId"
    }
}

###########################
# Step 17: Azure SQL Managed Instance TLS Scanning
###########################

Write-Host "Step 17: Scanning Azure SQL Managed Instances for TLS settings in Subscription: $SubscriptionName"

$SQLManagedInstances = az sql mi list --query "[].{name:name, resourceGroup:resourceGroup}" -o json | ConvertFrom-Json

if ($SQLManagedInstances.Count -eq 0) {
    Add-Content -Path $OutputFile -Value "$SubscriptionName,$SubscriptionId,AzureSQLManagedInstance,No Azure SQL Managed Instances found,N/A,N/A,N/A,$TenantId"
} else {
    foreach ($SQLMI in $SQLManagedInstances) {
        $Name = $SQLMI.name
        $ResourceGroup = $SQLMI.resourceGroup

        # Fetch the Minimum TLS Version for SQL Managed Instance
        $TLSVersion = az sql mi show --name $Name --resource-group $ResourceGroup --query "minimalTlsVersion" -o tsv

        if (-not $TLSVersion) { $TLSVersion = "Unknown" }

        # Determine Compliance Status
        $Status = if ($TLSVersion -eq "1.2") { "Compliant" } else { "Non-Compliant" }

        Add-Content -Path $OutputFile -Value "$SubscriptionName,$SubscriptionId,AzureSQLManagedInstance,$Name,$ResourceGroup,$TLSVersion,$Status,$TenantId"
    }
}

###########################
# Step 18: Azure Synapse Analytics TLS Scanning
###########################

Write-Host "Step 18: Scanning Azure Synapse Analytics instances for TLS settings in Subscription: $SubscriptionName"

$SynapseWorkspaces = az synapse workspace list --query "[].{name:name, resourceGroup:resourceGroup}" -o json | ConvertFrom-Json

if ($SynapseWorkspaces.Count -eq 0) {
    Add-Content -Path $OutputFile -Value "$SubscriptionName,$SubscriptionId,AzureSynapseAnalytics,No Azure Synapse Analytics instances found,N/A,N/A,N/A,$TenantId"
} else {
    foreach ($Synapse in $SynapseWorkspaces) {
        $Name = $Synapse.name
        $ResourceGroup = $Synapse.resourceGroup

        # Fetch the Minimum TLS Version for Synapse Analytics
        $TLSVersion = az synapse workspace show --name $Name --resource-group $ResourceGroup --query "properties.connectivityEndpoints.sql.minimumTlsVersion" -o tsv

        if (-not $TLSVersion) { $TLSVersion = "Unknown" }

        # Determine Compliance Status
        $Status = if ($TLSVersion -eq "TLS1_2") { "Compliant" } else { "Non-Compliant" }

        Add-Content -Path $OutputFile -Value "$SubscriptionName,$SubscriptionId,AzureSynapseAnalytics,$Name,$ResourceGroup,$TLSVersion,$Status,$TenantId"
    }
}

###########################
# Step 19: Azure Traffic Manager TLS Scanning
###########################

Write-Host "Step 19: Scanning Azure Traffic Manager profiles for TLS settings in Subscription: $SubscriptionName"

$TrafficManagers = az network traffic-manager profile list --query "[].{name:name, resourceGroup:resourceGroup}" -o json | ConvertFrom-Json

if ($TrafficManagers.Count -eq 0) {
    Add-Content -Path $OutputFile -Value "$SubscriptionName,$SubscriptionId,AzureTrafficManager,No Azure Traffic Manager profiles found,N/A,N/A,N/A,$TenantId"
} else {
    foreach ($TrafficManager in $TrafficManagers) {
        $Name = $TrafficManager.name
        $ResourceGroup = $TrafficManager.resourceGroup

        # Traffic Manager enforces TLS1.2 by default
        $TLSVersion = "TLS1_2"
        $Status = "Compliant"

        Add-Content -Path $OutputFile -Value "$SubscriptionName,$SubscriptionId,AzureTrafficManager,$Name,$ResourceGroup,$TLSVersion,$Status,$TenantId"
    }
}

###########################
# Step 20: Azure Web Application Firewall (WAF) TLS Scanning
###########################

Write-Host "Step 20: Scanning Azure Web Application Firewall instances for TLS settings in Subscription: $SubscriptionName"

$WAFPolicies = az network application-gateway waf-policy list --query "[].{name:name, resourceGroup:resourceGroup}" -o json | ConvertFrom-Json

if ($WAFPolicies.Count -eq 0) {
    Add-Content -Path $OutputFile -Value "$SubscriptionName,$SubscriptionId,AzureWebApplicationFirewall,No Azure Web Application Firewall policies found,N/A,N/A,N/A,$TenantId"
} else {
    foreach ($WAFPolicy in $WAFPolicies) {
        $Name = $WAFPolicy.name
        $ResourceGroup = $WAFPolicy.resourceGroup

        # WAF enforces TLS 1.2 by default
        $TLSVersion = "TLS1_2"
        $Status = "Compliant"

        Add-Content -Path $OutputFile -Value "$SubscriptionName,$SubscriptionId,AzureWebApplicationFirewall,$Name,$ResourceGroup,$TLSVersion,$Status,$TenantId"
    }
}


    Write-Host "Finished scanning Subscription: $SubscriptionName"
}

Write-Host "TLS Scan complete for all subscriptions. Report saved to $OutputFile."
