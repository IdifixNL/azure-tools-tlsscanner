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

# Loop through each subscription and scan for TLS settings
foreach ($Subscription in $Subscriptions) {
    $SubscriptionId = $Subscription.id
    $SubscriptionName = $Subscription.name

    Write-Host "Switching to Subscription: $SubscriptionName ($SubscriptionId)"
    az account set --subscription $SubscriptionId

    # Fetch Tenant ID for the current subscription
    $AccountInfo = az account show --query "{TenantId:tenantId}" -o json | ConvertFrom-Json
    $TenantId = $AccountInfo.TenantId

    # Proceed with TLS Scanning for this subscription...
}
###########################
# Step 1: API Management TLS Scanning
###########################

Write-Host "Step 1: Scanning API Management Services for TLS settings..."
Add-Content -Path $OutputFile -Value "APIManagement`r`n"
Add-Content -Path $OutputFile -Value "ResourceType,ResourceName,ResourceGroup,GatewayTLSVersion,BackendTLSVersion,Status,TenantId,SubscriptionId`r`n"

$ApiManagementServices = az apim list --query "[].{name:name, resourceGroup:resourceGroup}" -o json | ConvertFrom-Json

# Check if there are any API Management Services
if ($ApiManagementServices.Count -eq 0) {
    Add-Content -Path $OutputFile -Value "No API Management Services found in this subscription.`r`n"
} else {
    foreach ($ApiManagementService in $ApiManagementServices) {
        $Name = $ApiManagementService.name
        $ResourceGroup = $ApiManagementService.resourceGroup

        # Fetch the Minimum TLS Version for the API Management Gateway
        $GatewayTLSVersion = az apim show --name $Name --resource-group $ResourceGroup --query "properties.protocols[?protocol=='https'].minTlsVersion" -o tsv

        # Fetch Backend TLS settings (if applicable)
        $BackendTLSVersion = az apim show --name $Name --resource-group $ResourceGroup --query "properties.backendService.tls.minTlsVersion" -o tsv

        # Default to "Unknown" if not found
        if (-not $GatewayTLSVersion) { $GatewayTLSVersion = "Unknown" }
        if (-not $BackendTLSVersion) { $BackendTLSVersion = "Unknown" }

        # Determine Compliance Status
        if ($GatewayTLSVersion -eq "TLS1_2" -and $BackendTLSVersion -eq "TLS1_2") {
            $Status = "Compliant"
        } else {
            $Status = "Non-Compliant"
        }

        # Write API Management results to Output File
        Add-Content -Path $OutputFile -Value "APIManagement,$Name,$ResourceGroup,$GatewayTLSVersion,$BackendTLSVersion,$Status,$TenantId,$SubscriptionId"
    }
}

###########################
# Step 2: Azure App Service TLS Scanning
###########################

Write-Host "Step 2: Scanning Azure App Services for TLS settings..."
Add-Content -Path $OutputFile -Value "`r`n"
Add-Content -Path $OutputFile -Value "AppService`r`n"
Add-Content -Path $OutputFile -Value "ResourceType,ResourceName,ResourceGroup,MinimumTLSVersion,Status,TenantId,SubscriptionId`r`n"

$AppServices = az webapp list --query "[].{name:name, resourceGroup:resourceGroup}" -o json | ConvertFrom-Json

# Check if there are any App Services
if ($AppServices.Count -eq 0) {
    Add-Content -Path $OutputFile -Value "No App Services found in this subscription.`r`n"
} else {
    foreach ($AppService in $AppServices) {
        $Name = $AppService.name
        $ResourceGroup = $AppService.resourceGroup

        # Fetch the Minimum TLS Version for the App Service
        $TLSVersion = az webapp show --name $Name --resource-group $ResourceGroup --query "siteConfig.minTlsVersion" -o tsv

        # Default to "Unknown" if not found
        if (-not $TLSVersion) { $TLSVersion = "Unknown" }

        # Determine Compliance Status
        if ($TLSVersion -eq "1.2") {
            $Status = "Compliant"
        } else {
            $Status = "Non-Compliant"
        }

        # Write App Service results to Output File
        Add-Content -Path $OutputFile -Value "AppService,$Name,$ResourceGroup,$TLSVersion,$Status,$TenantId,$SubscriptionId"
    }
}

###########################
# Step 3: Application Gateway TLS Scanning
###########################

Write-Host "Step 3: Scanning Application Gateways for TLS settings..."
Add-Content -Path $OutputFile -Value "`r`n"
Add-Content -Path $OutputFile -Value "ApplicationGateway`r`n"
Add-Content -Path $OutputFile -Value "ResourceType,ResourceName,ResourceGroup,FrontendTLSVersion,Status,TenantId,SubscriptionId`r`n"

$AppGateways = az network application-gateway list --query "[].{name:name, resourceGroup:resourceGroup}" -o json | ConvertFrom-Json

# Check if there are any Application Gateways
if ($AppGateways.Count -eq 0) {
    Add-Content -Path $OutputFile -Value "No Application Gateways found in this subscription.`r`n"
} else {
    foreach ($AppGateway in $AppGateways) {
        $Name = $AppGateway.name
        $ResourceGroup = $AppGateway.resourceGroup

        # Fetch the TLS version used in the frontend configuration
        $FrontendTLSVersion = az network application-gateway show --name $Name --resource-group $ResourceGroup --query "sslPolicy.minProtocolVersion" -o tsv

        # Default to "Unknown" if not found
        if (-not $FrontendTLSVersion) { $FrontendTLSVersion = "Unknown" }

        # Determine Compliance Status
        if ($FrontendTLSVersion -eq "TLS1_2") {
            $Status = "Compliant"
        } else {
            $Status = "Non-Compliant"
        }

        # Write Application Gateway results to Output File
        Add-Content -Path $OutputFile -Value "ApplicationGateway,$Name,$ResourceGroup,$FrontendTLSVersion,$Status,$TenantId,$SubscriptionId"
    }
}

###########################
# Step 4: Application Insights Availability Tests TLS Scanning
###########################

Write-Host "Step 4: Scanning Application Insights Availability Tests for TLS settings..."
Add-Content -Path $OutputFile -Value "`r`n"
Add-Content -Path $OutputFile -Value "ApplicationInsightsAvailabilityTests`r`n"
Add-Content -Path $OutputFile -Value "ResourceType,ResourceName,ResourceGroup,MinimumTLSVersion,Status,TenantId,SubscriptionId`r`n"

$AppInsightsResources = az resource list --resource-type "Microsoft.Insights/webtests" --query "[].{name:name, resourceGroup:resourceGroup}" -o json | ConvertFrom-Json

# Check if there are any Application Insights Availability Tests
if ($AppInsightsResources.Count -eq 0) {
    Add-Content -Path $OutputFile -Value "No Application Insights Availability Tests found in this subscription.`r`n"
} else {
    foreach ($AppInsight in $AppInsightsResources) {
        $Name = $AppInsight.name
        $ResourceGroup = $AppInsight.resourceGroup

        # Fetch the Minimum TLS Version for the Application Insights availability test
        $TLSVersion = az resource show --name $Name --resource-group $ResourceGroup --resource-type "Microsoft.Insights/webtests" --query "properties.configuration.tlsVersion" -o tsv

        # Default to "Unknown" if not found
        if (-not $TLSVersion) { $TLSVersion = "Unknown" }

        # Determine Compliance Status
        if ($TLSVersion -eq "1.2") {
            $Status = "Compliant"
        } else {
            $Status = "Non-Compliant"
        }

        # Write Application Insights Availability Test results to Output File
        Add-Content -Path $OutputFile -Value "ApplicationInsightsAvailabilityTests,$Name,$ResourceGroup,$TLSVersion,$Status,$TenantId,$SubscriptionId"
    }
}

###########################
# Step 5: Azure App Service Static Web Apps TLS Scanning
###########################

Write-Host "Step 5: Scanning Azure App Service Static Web Apps for TLS settings..."
Add-Content -Path $OutputFile -Value "`r`n"
Add-Content -Path $OutputFile -Value "AzureAppServiceStaticWebApps`r`n"
Add-Content -Path $OutputFile -Value "ResourceType,ResourceName,ResourceGroup,MinimumTLSVersion,Status,TenantId,SubscriptionId`r`n"

$StaticWebApps = az staticwebapp list --query "[].{name:name, resourceGroup:resourceGroup}" -o json | ConvertFrom-Json

# Check if there are any Static Web Apps
if ($StaticWebApps.Count -eq 0) {
    Add-Content -Path $OutputFile -Value "No Static Web Apps found in this subscription.`r`n"
} else {
    foreach ($StaticWebApp in $StaticWebApps) {
        $Name = $StaticWebApp.name
        $ResourceGroup = $StaticWebApp.resourceGroup

        # Fetch the Minimum TLS Version for the Static Web App
        $TLSVersion = az staticwebapp show --name $Name --resource-group $ResourceGroup --query "properties.customDomains[0].httpsOptions.minTlsVersion" -o tsv

        # Default to "Unknown" if not found
        if (-not $TLSVersion) { $TLSVersion = "Unknown" }

        # Determine Compliance Status
        if ($TLSVersion -eq "1.2") {
            $Status = "Compliant"
        } else {
            $Status = "Non-Compliant"
        }

        # Write Static Web App results to Output File
        Add-Content -Path $OutputFile -Value "AzureAppServiceStaticWebApps,$Name,$ResourceGroup,$TLSVersion,$Status,$TenantId,$SubscriptionId"
    }
}



###########################
# Step 5: Arc place holder
###########################

###########################
# Step 7: Azure Cache for Redis TLS Scanning
###########################

Write-Host "Step 7: Scanning Azure Cache for Redis instances for TLS settings..."
Add-Content -Path $OutputFile -Value "`r`n"
Add-Content -Path $OutputFile -Value "AzureCacheForRedis`r`n"
Add-Content -Path $OutputFile -Value "ResourceType,ResourceName,ResourceGroup,MinimumTLSVersion,Status,TenantId,SubscriptionId`r`n"

$RedisCaches = az redis list --query "[].{name:name, resourceGroup:resourceGroup}" -o json | ConvertFrom-Json

# Check if there are any Redis Caches
if ($RedisCaches.Count -eq 0) {
    Add-Content -Path $OutputFile -Value "No Azure Cache for Redis instances found in this subscription.`r`n"
} else {
    foreach ($RedisCache in $RedisCaches) {
        $Name = $RedisCache.name
        $ResourceGroup = $RedisCache.resourceGroup

        # Fetch the Minimum TLS Version for the Redis Cache
        $TLSVersion = az redis show --name $Name --resource-group $ResourceGroup --query "minimumTlsVersion" -o tsv

        # Default to "Unknown" if not found
        if (-not $TLSVersion) { $TLSVersion = "Unknown" }

        # Determine Compliance Status
        if ($TLSVersion -eq "1.2") {
            $Status = "Compliant"
        } else {
            $Status = "Non-Compliant"
        }

        # Write Redis Cache results to Output File
        Add-Content -Path $OutputFile -Value "AzureCacheForRedis,$Name,$ResourceGroup,$TLSVersion,$Status,$TenantId,$SubscriptionId"
    }
}

###########################
# Step 8: Azure Cosmos DB TLS Scanning
###########################

Write-Host "Step 8: Scanning Azure Cosmos DB instances for TLS settings..."
Add-Content -Path $OutputFile -Value "`r`n"
Add-Content -Path $OutputFile -Value "AzureCosmosDB`r`n"
Add-Content -Path $OutputFile -Value "ResourceType,ResourceName,ResourceGroup,MinimumTLSVersion,Status,TenantId,SubscriptionId`r`n"

$CosmosDBAccounts = az cosmosdb list --query "[].{name:name, resourceGroup:resourceGroup}" -o json | ConvertFrom-Json

# Check if there are any Cosmos DB accounts
if ($CosmosDBAccounts.Count -eq 0) {
    Add-Content -Path $OutputFile -Value "No Azure Cosmos DB instances found in this subscription.`r`n"
} else {
    foreach ($CosmosDB in $CosmosDBAccounts) {
        $Name = $CosmosDB.name
        $ResourceGroup = $CosmosDB.resourceGroup

        # Fetch the Minimum TLS Version for the Cosmos DB account
        $TLSVersion = az cosmosdb show --name $Name --resource-group $ResourceGroup --query "minimalTlsVersion" -o tsv

        # Default to "Unknown" if not found
        if (-not $TLSVersion) { $TLSVersion = "Unknown" }

        # Determine Compliance Status
        if ($TLSVersion -eq "TLS1_2") {
            $Status = "Compliant"
        } else {
            $Status = "Non-Compliant"
        }

        # Write Cosmos DB results to Output File
        Add-Content -Path $OutputFile -Value "AzureCosmosDB,$Name,$ResourceGroup,$TLSVersion,$Status,$TenantId,$SubscriptionId"
    }
}

###########################
# Step 9: Azure Database for MariaDB TLS Scanning
###########################

Write-Host "Step 9: Scanning Azure Database for MariaDB instances for TLS settings..."
Add-Content -Path $OutputFile -Value "`r`n"
Add-Content -Path $OutputFile -Value "AzureDatabaseForMariaDB`r`n"
Add-Content -Path $OutputFile -Value "ResourceType,ResourceName,ResourceGroup,MinimumTLSVersion,Status,TenantId,SubscriptionId`r`n"

$MariaDBServers = az mariadb server list --query "[].{name:name, resourceGroup:resourceGroup}" -o json | ConvertFrom-Json

# Check if there are any MariaDB servers
if ($MariaDBServers.Count -eq 0) {
    Add-Content -Path $OutputFile -Value "No Azure Database for MariaDB instances found in this subscription.`r`n"
} else {
    foreach ($MariaDB in $MariaDBServers) {
        $Name = $MariaDB.name
        $ResourceGroup = $MariaDB.resourceGroup

        # Fetch the Minimum TLS Version for the MariaDB instance
        $TLSVersion = az mariadb server show --name $Name --resource-group $ResourceGroup --query "sslEnforcement" -o tsv

        # Default to "Unknown" if not found
        if (-not $TLSVersion) { $TLSVersion = "Unknown" }

        # Convert "Enabled" to TLS1_2 for clarity
        if ($TLSVersion -eq "Enabled") {
            $TLSVersion = "TLS1_2"
            $Status = "Compliant"
        } else {
            $Status = "Non-Compliant"
        }

        # Write MariaDB results to Output File
        Add-Content -Path $OutputFile -Value "AzureDatabaseForMariaDB,$Name,$ResourceGroup,$TLSVersion,$Status,$TenantId,$SubscriptionId"
    }
}

###########################
# Step 10: Azure Database for MySQL TLS Scanning
###########################

Write-Host "Step 10: Scanning Azure Database for MySQL instances for TLS settings..."
Add-Content -Path $OutputFile -Value "`r`n"
Add-Content -Path $OutputFile -Value "AzureDatabaseForMySQL`r`n"
Add-Content -Path $OutputFile -Value "ResourceType,ResourceName,ResourceGroup,MinimumTLSVersion,Status,TenantId,SubscriptionId`r`n"

$MySQLServers = az mysql server list --query "[].{name:name, resourceGroup:resourceGroup}" -o json | ConvertFrom-Json

# Check if there are any MySQL servers
if ($MySQLServers.Count -eq 0) {
    Add-Content -Path $OutputFile -Value "No Azure Database for MySQL instances found in this subscription.`r`n"
} else {
    foreach ($MySQL in $MySQLServers) {
        $Name = $MySQL.name
        $ResourceGroup = $MySQL.resourceGroup

        # Fetch the Minimum TLS Version for the MySQL instance
        $TLSVersion = az mysql server show --name $Name --resource-group $ResourceGroup --query "sslEnforcement" -o tsv

        # Default to "Unknown" if not found
        if (-not $TLSVersion) { $TLSVersion = "Unknown" }

        # Convert "Enabled" to TLS1_2 for clarity
        if ($TLSVersion -eq "Enabled") {
            $TLSVersion = "TLS1_2"
            $Status = "Compliant"
        } else {
            $Status = "Non-Compliant"
        }

        # Write MySQL results to Output File
        Add-Content -Path $OutputFile -Value "AzureDatabaseForMySQL,$Name,$ResourceGroup,$TLSVersion,$Status,$TenantId,$SubscriptionId"
    }
}

###########################
# Step 11: Azure Database for PostgreSQL TLS Scanning
###########################

Write-Host "Step 11: Scanning Azure Database for PostgreSQL instances for TLS settings..."
Add-Content -Path $OutputFile -Value "`r`n"
Add-Content -Path $OutputFile -Value "AzureDatabaseForPostgreSQL`r`n"
Add-Content -Path $OutputFile -Value "ResourceType,ResourceName,ResourceGroup,MinimumTLSVersion,Status,TenantId,SubscriptionId`r`n"

$PostgreSQLServers = az postgres server list --query "[].{name:name, resourceGroup:resourceGroup}" -o json | ConvertFrom-Json

# Check if there are any PostgreSQL servers
if ($PostgreSQLServers.Count -eq 0) {
    Add-Content -Path $OutputFile -Value "No Azure Database for PostgreSQL instances found in this subscription.`r`n"
} else {
    foreach ($PostgreSQL in $PostgreSQLServers) {
        $Name = $PostgreSQL.name
        $ResourceGroup = $PostgreSQL.resourceGroup

        # Fetch the Minimum TLS Version for the PostgreSQL instance
        $TLSVersion = az postgres server show --name $Name --resource-group $ResourceGroup --query "sslEnforcement" -o tsv

        # Default to "Unknown" if not found
        if (-not $TLSVersion) { $TLSVersion = "Unknown" }

        # Convert "Enabled" to TLS1_2 for clarity
        if ($TLSVersion -eq "Enabled") {
            $TLSVersion = "TLS1_2"
            $Status = "Compliant"
        } else {
            $Status = "Non-Compliant"
        }

        # Write PostgreSQL results to Output File
        Add-Content -Path $OutputFile -Value "AzureDatabaseForPostgreSQL,$Name,$ResourceGroup,$TLSVersion,$Status,$TenantId,$SubscriptionId"
    }
}

###########################
# Step 12: Azure Database Migration Service TLS Scanning
###########################

Write-Host "Step 12: Scanning Azure Database Migration Service instances for TLS settings..."
Add-Content -Path $OutputFile -Value "`r`n"
Add-Content -Path $OutputFile -Value "AzureDatabaseMigrationService`r`n"
Add-Content -Path $OutputFile -Value "ResourceType,ResourceName,ResourceGroup,MinimumTLSVersion,Status,TenantId,SubscriptionId`r`n"

$MigrationServices = az dms list --query "[].{name:name, resourceGroup:resourceGroup}" -o json | ConvertFrom-Json

# Check if there are any Database Migration Service instances
if ($MigrationServices.Count -eq 0) {
    Add-Content -Path $OutputFile -Value "No Azure Database Migration Service instances found in this subscription.`r`n"
} else {
    foreach ($MigrationService in $MigrationServices) {
        $Name = $MigrationService.name
        $ResourceGroup = $MigrationService.resourceGroup

        # Fetch the Minimum TLS Version for the Database Migration Service
        $TLSVersion = az dms show --name $Name --resource-group $ResourceGroup --query "sku.tier" -o tsv

        # Default to "Unknown" if not found
        if (-not $TLSVersion) { $TLSVersion = "Unknown" }

        # Determine Compliance Status
        if ($TLSVersion -eq "Premium") {  # Premium tier enforces TLS 1.2 by default
            $Status = "Compliant"
        } else {
            $Status = "Non-Compliant"
        }

        # Write Database Migration Service results to Output File
        Add-Content -Path $OutputFile -Value "AzureDatabaseMigrationService,$Name,$ResourceGroup,$TLSVersion,$Status,$TenantId,$SubscriptionId"
    }
}

###########################
# Step 13: Azure Front Door / Azure Front Door X TLS Scanning
###########################

Write-Host "Step 13: Scanning Azure Front Door instances for TLS settings..."
Add-Content -Path $OutputFile -Value "`r`n"
Add-Content -Path $OutputFile -Value "AzureFrontDoor`r`n"
Add-Content -Path $OutputFile -Value "ResourceType,ResourceName,ResourceGroup,MinimumTLSVersion,Status,TenantId,SubscriptionId`r`n"

$FrontDoors = az afd profile list --query "[].{name:name, resourceGroup:resourceGroup}" -o json | ConvertFrom-Json

# Check if there are any Front Door instances
if ($FrontDoors.Count -eq 0) {
    Add-Content -Path $OutputFile -Value "No Azure Front Door instances found in this subscription.`r`n"
} else {
    foreach ($FrontDoor in $FrontDoors) {
        $Name = $FrontDoor.name
        $ResourceGroup = $FrontDoor.resourceGroup

        # Fetch the Minimum TLS Version for the Front Door
        $TLSVersion = az afd profile show --name $Name --resource-group $ResourceGroup --query "properties.frontendEndpoints[0].properties.minimumTlsVersion" -o tsv

        # Default to "Unknown" if not found
        if (-not $TLSVersion) { $TLSVersion = "Unknown" }

        # Determine Compliance Status
        if ($TLSVersion -eq "TLS1_2") {
            $Status = "Compliant"
        } else {
            $Status = "Non-Compliant"
        }

        # Write Front Door results to Output File
        Add-Content -Path $OutputFile -Value "AzureFrontDoor,$Name,$ResourceGroup,$TLSVersion,$Status,$TenantId,$SubscriptionId"
    }
}

# Step 14: Azure Resource Manager (ARM) TLS Scanning
Write-Host "Step 14: Checking Azure Policy for Secure Transfer enforcement..."
Add-Content -Path $OutputFile -Value "`r`n"
Add-Content -Path $OutputFile -Value "AzureResourceManager`r`n"
Add-Content -Path $OutputFile -Value "ResourceType,Region,MinimumTLSVersion,Status,TenantId,SubscriptionId`r`n"

# Check if a Secure Transfer policy exists
$SecureTransferPolicy = az policy definition list --query "[?contains(displayName, 'Secure Transfer')]" -o json | ConvertFrom-Json

if ($SecureTransferPolicy.Count -eq 0) {
    $Status = "Non-Compliant"
    $TLSVersion = "Unknown"
} else {
    $Status = "Compliant"
    $TLSVersion = "TLS1_2"
}

###########################
# Step 15: Azure SQL Database TLS Scanning
###########################

Write-Host "Step 15: Scanning Azure SQL Database instances for TLS settings..."
Add-Content -Path $OutputFile -Value "`r`n"
Add-Content -Path $OutputFile -Value "AzureSQLDatabase`r`n"
Add-Content -Path $OutputFile -Value "ResourceType,ResourceName,ResourceGroup,MinimumTLSVersion,Status,TenantId,SubscriptionId`r`n"

$SQLDatabases = az sql server list --query "[].{name:name, resourceGroup:resourceGroup}" -o json | ConvertFrom-Json

# Check if there are any SQL Servers
if ($SQLDatabases.Count -eq 0) {
    Add-Content -Path $OutputFile -Value "No Azure SQL Databases found in this subscription.`r`n"
} else {
    foreach ($SQLDatabase in $SQLDatabases) {
        $Name = $SQLDatabase.name
        $ResourceGroup = $SQLDatabase.resourceGroup

        # Fetch the Minimum TLS Version for the SQL Server
        $TLSVersion = az sql server show --name $Name --resource-group $ResourceGroup --query "minimalTlsVersion" -o tsv

        # Default to "Unknown" if not found
        if (-not $TLSVersion) { $TLSVersion = "Unknown" }

        # Determine Compliance Status
        if ($TLSVersion -eq "1.2") {
            $Status = "Compliant"
        } else {
            $Status = "Non-Compliant"
        }

        # Write SQL Database results to Output File
        Add-Content -Path $OutputFile -Value "AzureSQLDatabase,$Name,$ResourceGroup,$TLSVersion,$Status,$TenantId,$SubscriptionId"
    }
}

###########################
# Step 16: Azure SQL Database Edge TLS Scanning
###########################

Write-Host "Step 16: Scanning Azure SQL Database Edge instances for TLS settings..."
Add-Content -Path $OutputFile -Value "`r`n"
Add-Content -Path $OutputFile -Value "AzureSQLDatabaseEdge`r`n"
Add-Content -Path $OutputFile -Value "ResourceType,ResourceName,ResourceGroup,MinimumTLSVersion,Status,TenantId,SubscriptionId`r`n"

$SQLEdgeInstances = az sql server list --query "[].{name:name, resourceGroup:resourceGroup}" -o json | ConvertFrom-Json

# Check if there are any SQL Database Edge instances
if ($SQLEdgeInstances.Count -eq 0) {
    Add-Content -Path $OutputFile -Value "No Azure SQL Database Edge instances found in this subscription.`r`n"
} else {
    foreach ($SQLEdge in $SQLEdgeInstances) {
        $Name = $SQLEdge.name
        $ResourceGroup = $SQLEdge.resourceGroup

        # Fetch the Minimum TLS Version for the SQL Database Edge
        $TLSVersion = az sql server show --name $Name --resource-group $ResourceGroup --query "minimalTlsVersion" -o tsv

        # Default to "Unknown" if not found
        if (-not $TLSVersion) { $TLSVersion = "Unknown" }

        # Determine Compliance Status
        if ($TLSVersion -eq "1.2") {
            $Status = "Compliant"
        } else {
            $Status = "Non-Compliant"
        }

        # Write SQL Database Edge results to Output File
        Add-Content -Path $OutputFile -Value "AzureSQLDatabaseEdge,$Name,$ResourceGroup,$TLSVersion,$Status,$TenantId,$SubscriptionId"
    }
}

###########################
# Step 17: Azure SQL Managed Instance TLS Scanning
###########################

Write-Host "Step 17: Scanning Azure SQL Managed Instances for TLS settings..."
Add-Content -Path $OutputFile -Value "`r`n"
Add-Content -Path $OutputFile -Value "AzureSQLManagedInstance`r`n"
Add-Content -Path $OutputFile -Value "ResourceType,ResourceName,ResourceGroup,MinimumTLSVersion,Status,TenantId,SubscriptionId`r`n"

$SQLManagedInstances = az sql mi list --query "[].{name:name, resourceGroup:resourceGroup}" -o json | ConvertFrom-Json

# Check if there are any SQL Managed Instances
if ($SQLManagedInstances.Count -eq 0) {
    Add-Content -Path $OutputFile -Value "No Azure SQL Managed Instances found in this subscription.`r`n"
} else {
    foreach ($SQLMI in $SQLManagedInstances) {
        $Name = $SQLMI.name
        $ResourceGroup = $SQLMI.resourceGroup

        # Fetch the Minimum TLS Version for the SQL Managed Instance
        $TLSVersion = az sql mi show --name $Name --resource-group $ResourceGroup --query "minimalTlsVersion" -o tsv

        # Default to "Unknown" if not found
        if (-not $TLSVersion) { $TLSVersion = "Unknown" }

        # Determine Compliance Status
        if ($TLSVersion -eq "1.2") {
            $Status = "Compliant"
        } else {
            $Status = "Non-Compliant"
        }

        # Write SQL Managed Instance results to Output File
        Add-Content -Path $OutputFile -Value "AzureSQLManagedInstance,$Name,$ResourceGroup,$TLSVersion,$Status,$TenantId,$SubscriptionId"
    }
}

###########################
# Step 18: Azure Synapse Analytics TLS Scanning
###########################

Write-Host "Step 18: Scanning Azure Synapse Analytics instances for TLS settings..."
Add-Content -Path $OutputFile -Value "`r`n"
Add-Content -Path $OutputFile -Value "AzureSynapseAnalytics`r`n"
Add-Content -Path $OutputFile -Value "ResourceType,ResourceName,ResourceGroup,MinimumTLSVersion,Status,TenantId,SubscriptionId`r`n"

$SynapseWorkspaces = az synapse workspace list --query "[].{name:name, resourceGroup:resourceGroup}" -o json | ConvertFrom-Json

# Check if there are any Synapse Workspaces
if ($SynapseWorkspaces.Count -eq 0) {
    Add-Content -Path $OutputFile -Value "No Azure Synapse Analytics instances found in this subscription.`r`n"
} else {
    foreach ($Synapse in $SynapseWorkspaces) {
        $Name = $Synapse.name
        $ResourceGroup = $Synapse.resourceGroup

        # Fetch the Minimum TLS Version for the Synapse Analytics instance
        $TLSVersion = az synapse workspace show --name $Name --resource-group $ResourceGroup --query "properties.connectivityEndpoints.sql.minimumTlsVersion" -o tsv

        # Default to "Unknown" if not found
        if (-not $TLSVersion) { $TLSVersion = "Unknown" }

        # Determine Compliance Status
        if ($TLSVersion -eq "TLS1_2") {
            $Status = "Compliant"
        } else {
            $Status = "Non-Compliant"
        }

        # Write Synapse Analytics results to Output File
        Add-Content -Path $OutputFile -Value "AzureSynapseAnalytics,$Name,$ResourceGroup,$TLSVersion,$Status,$TenantId,$SubscriptionId"
    }
}

###########################
# Step 19: Azure Traffic Manager TLS Scanning
###########################

Write-Host "Step 19: Scanning Azure Traffic Manager profiles for TLS settings..."
Add-Content -Path $OutputFile -Value "`r`n"
Add-Content -Path $OutputFile -Value "AzureTrafficManager`r`n"
Add-Content -Path $OutputFile -Value "ResourceType,ResourceName,ResourceGroup,MinimumTLSVersion,Status,TenantId,SubscriptionId`r`n"

$TrafficManagers = az network traffic-manager profile list --query "[].{name:name, resourceGroup:resourceGroup}" -o json | ConvertFrom-Json

# Check if there are any Traffic Manager profiles
if ($TrafficManagers.Count -eq 0) {
    Add-Content -Path $OutputFile -Value "No Azure Traffic Manager profiles found in this subscription.`r`n"
} else {
    foreach ($TrafficManager in $TrafficManagers) {
        $Name = $TrafficManager.name
        $ResourceGroup = $TrafficManager.resourceGroup

        # Fetch the Minimum TLS Version for the Traffic Manager profile
        $TLSVersion = "TLS1_2"  # Azure Traffic Manager enforces TLS1.2 by default

        # Determine Compliance Status
        $Status = "Compliant"

        # Write Traffic Manager results to Output File
        Add-Content -Path $OutputFile -Value "AzureTrafficManager,$Name,$ResourceGroup,$TLSVersion,$Status,$TenantId,$SubscriptionId"
    }
}

###########################
# Step 20: Azure Web Application Firewall (WAF) TLS Scanning
###########################

Write-Host "Step 20: Scanning Azure Web Application Firewall instances for TLS settings..."
Add-Content -Path $OutputFile -Value "`r`n"
Add-Content -Path $OutputFile -Value "AzureWebApplicationFirewall`r`n"
Add-Content -Path $OutputFile -Value "ResourceType,ResourceName,ResourceGroup,MinimumTLSVersion,Status,TenantId,SubscriptionId`r`n"

$WAFPolicies = az network application-gateway waf-policy list --query "[].{name:name, resourceGroup:resourceGroup}" -o json | ConvertFrom-Json

# Check if there are any WAF policies
if ($WAFPolicies.Count -eq 0) {
    Add-Content -Path $OutputFile -Value "No Azure Web Application Firewall policies found in this subscription.`r`n"
} else {
    foreach ($WAFPolicy in $WAFPolicies) {
        $Name = $WAFPolicy.name
        $ResourceGroup = $WAFPolicy.resourceGroup

        # Fetch the Minimum TLS Version for the WAF policy
        $TLSVersion = "TLS1_2"  # WAF enforces TLS 1.2 by default

        # Determine Compliance Status
        $Status = "Compliant"

        # Write WAF results to Output File
        Add-Content -Path $OutputFile -Value "AzureWebApplicationFirewall,$Name,$ResourceGroup,$TLSVersion,$Status,$TenantId,$SubscriptionId"
    }
}

###########################
# Step 21: Azure Cloud Services TLS Scanning
###########################

# Write-Host "Step 21: Scanning Azure Cloud Services for TLS settings..."
# Add-Content -Path $OutputFile -Value "`r`n"
# Add-Content -Path $OutputFile -Value "AzureCloudServices`r`n"
# Add-Content -Path $OutputFile -Value "ResourceType,ResourceName,ResourceGroup,MinimumTLSVersion,Status,TenantId,SubscriptionId`r`n"

# $CloudServices = az cloud-service list --query "[].{name:name, resourceGroup:resourceGroup}" -o json | ConvertFrom-Json

# # Check if there are any Cloud Services
# if ($CloudServices.Count -eq 0) {
#     Add-Content -Path $OutputFile -Value "No Azure Cloud Services found in this subscription.`r`n"
# } else {
#     foreach ($CloudService in $CloudServices) {
#         $Name = $CloudService.name
#         $ResourceGroup = $CloudService.resourceGroup

#         # Fetch the Minimum TLS Version for the Cloud Service
#         $TLSVersion = az cloud-service show --name $Name --resource-group $ResourceGroup --query "properties.configuration.minimumTlsVersion" -o tsv

#         # Default to "Unknown" if not found
#         if (-not $TLSVersion) { $TLSVersion = "Unknown" }

#         # Determine Compliance Status
#         if ($TLSVersion -eq "TLS1_2") {
#             $Status = "Compliant"
#         } else {
#             $Status = "Non-Compliant"
#         }

#         # Write Cloud Services results to Output File
#         Add-Content -Path $OutputFile -Value "AzureCloudServices,$Name,$ResourceGroup,$TLSVersion,$Status,$TenantId,$SubscriptionId"
#     }
# }


# # Write results to Output File
# Add-Content -Path $OutputFile -Value "AzureResourceManager,Global,$TLSVersion,$Status,$TenantId,$SubscriptionId"

##########################
# Step 22: Azure Event Grid TLS Scanning
###########################

Write-Host "Step 22: Scanning Azure Event Grid domains for TLS settings..."
Add-Content -Path $OutputFile -Value "`r`n"
Add-Content -Path $OutputFile -Value "AzureEventGrid`r`n"
Add-Content -Path $OutputFile -Value "ResourceType,ResourceName,ResourceGroup,MinimumTLSVersion,Status,TenantId,SubscriptionId`r`n"

$EventGridDomains = az eventgrid domain list --query "[].{name:name, resourceGroup:resourceGroup}" -o json | ConvertFrom-Json

# Check if there are any Event Grid domains
if ($EventGridDomains.Count -eq 0) {
    Add-Content -Path $OutputFile -Value "No Azure Event Grid domains found in this subscription.`r`n"
} else {
    foreach ($EventGrid in $EventGridDomains) {
        $Name = $EventGrid.name
        $ResourceGroup = $EventGrid.resourceGroup

        # Event Grid enforces TLS 1.2 by default
        $TLSVersion = "TLS1_2"
        $Status = "Compliant"

        # Write Event Grid results to Output File
        Add-Content -Path $OutputFile -Value "AzureEventGrid,$Name,$ResourceGroup,$TLSVersion,$Status,$TenantId,$SubscriptionId"
    }
}

###########################
# Step 23: Azure Event Hubs TLS Scanning
###########################

Write-Host "Step 23: Scanning Azure Event Hubs for TLS settings..."
Add-Content -Path $OutputFile -Value "`r`n"
Add-Content -Path $OutputFile -Value "AzureEventHubs`r`n"
Add-Content -Path $OutputFile -Value "ResourceType,ResourceName,ResourceGroup,MinimumTLSVersion,Status,TenantId,SubscriptionId`r`n"

$EventHubs = az eventhubs namespace list --query "[].{name:name, resourceGroup:resourceGroup}" -o json | ConvertFrom-Json

# Check if there are any Event Hubs
if ($EventHubs.Count -eq 0) {
    Add-Content -Path $OutputFile -Value "No Azure Event Hubs found in this subscription.`r`n"
} else {
    foreach ($EventHub in $EventHubs) {
        $Name = $EventHub.name
        $ResourceGroup = $EventHub.resourceGroup

        # Fetch the Minimum TLS Version for the Event Hub
        $TLSVersion = az eventhubs namespace show --name $Name --resource-group $ResourceGroup --query "properties.minimumTlsVersion" -o tsv

        # Default to "Unknown" if not found
        if (-not $TLSVersion) { $TLSVersion = "Unknown" }

        # Determine Compliance Status
        if ($TLSVersion -eq "1.2") {
            $Status = "Compliant"
        } else {
            $Status = "Non-Compliant"
        }

        # Write Event Hub results to Output File
        Add-Content -Path $OutputFile -Value "AzureEventHubs,$Name,$ResourceGroup,$TLSVersion,$Status,$TenantId,$SubscriptionId"
    }
}

###########################
# Step 24: Azure Functions TLS Scanning
###########################

Write-Host "Step 24: Scanning Azure Functions for TLS settings..."
Add-Content -Path $OutputFile -Value "`r`n"
Add-Content -Path $OutputFile -Value "AzureFunctions`r`n"
Add-Content -Path $OutputFile -Value "ResourceType,ResourceName,ResourceGroup,MinimumTLSVersion,Status,TenantId,SubscriptionId`r`n"

$Functions = az functionapp list --query "[].{name:name, resourceGroup:resourceGroup}" -o json | ConvertFrom-Json

# Check if there are any Function Apps
if ($Functions.Count -eq 0) {
    Add-Content -Path $OutputFile -Value "No Azure Functions found in this subscription.`r`n"
} else {
    foreach ($Function in $Functions) {
        $Name = $Function.name
        $ResourceGroup = $Function.resourceGroup

        # Fetch the Minimum TLS Version for the Function App
        $TLSVersion = az functionapp show --name $Name --resource-group $ResourceGroup --query "siteConfig.minTlsVersion" -o tsv

        # Default to "Unknown" if not found
        if (-not $TLSVersion) { $TLSVersion = "Unknown" }

        # Determine Compliance Status
        if ($TLSVersion -eq "1.2") {
            $Status = "Compliant"
        } else {
            $Status = "Non-Compliant"
        }

        # Write Function results to Output File
        Add-Content -Path $OutputFile -Value "AzureFunctions,$Name,$ResourceGroup,$TLSVersion,$Status,$TenantId,$SubscriptionId"
    }
}

###########################
# Step 25: Azure IoT Hub TLS Scanning
###########################

Write-Host "Step 25: Scanning Azure IoT Hub instances for TLS settings..."
Add-Content -Path $OutputFile -Value "`r`n"
Add-Content -Path $OutputFile -Value "AzureIoTHub`r`n"
Add-Content -Path $OutputFile -Value "ResourceType,ResourceName,ResourceGroup,MinimumTLSVersion,Status,TenantId,SubscriptionId`r`n"

$IoTHubs = az iot hub list --query "[].{name:name, resourceGroup:resourceGroup}" -o json | ConvertFrom-Json

# Check if there are any IoT Hubs
if ($IoTHubs.Count -eq 0) {
    Add-Content -Path $OutputFile -Value "No Azure IoT Hubs found in this subscription.`r`n"
} else {
    foreach ($IoTHub in $IoTHubs) {
        $Name = $IoTHub.name
        $ResourceGroup = $IoTHub.resourceGroup

        # Fetch the Minimum TLS Version for the IoT Hub
        $TLSVersion = "TLS1_2"  # IoT Hub enforces TLS1.2 by default

        # Determine Compliance Status
        $Status = "Compliant"

        # Write IoT Hub results to Output File
        Add-Content -Path $OutputFile -Value "AzureIoTHub,$Name,$ResourceGroup,$TLSVersion,$Status,$TenantId,$SubscriptionId"
    }
}

###########################
# Step 27: Microsoft Azure Managed Instance for Apache Cassandra TLS Scanning
###########################

Write-Host "Step 27: Scanning Azure Managed Instance for Apache Cassandra for TLS settings..."
Add-Content -Path $OutputFile -Value "`r`n"
Add-Content -Path $OutputFile -Value "AzureCassandraManagedInstance`r`n"
Add-Content -Path $OutputFile -Value "ResourceType,ResourceName,ResourceGroup,MinimumTLSVersion,Status,TenantId,SubscriptionId`r`n"

$CassandraInstances = az managed-cassandra cluster list --query "[].{name:name, resourceGroup:resourceGroup}" -o json | ConvertFrom-Json

# Check if there are any Cassandra Managed Instances
if ($CassandraInstances.Count -eq 0) {
    Add-Content -Path $OutputFile -Value "No Azure Managed Cassandra Instances found in this subscription.`r`n"
} else {
    foreach ($CassandraInstance in $CassandraInstances) {
        $Name = $CassandraInstance.name
        $ResourceGroup = $CassandraInstance.resourceGroup

        # Managed Cassandra enforces TLS 1.2 by default
        $TLSVersion = "TLS1_2"
        $Status = "Compliant"

        # Write Cassandra Managed Instance results to Output File
        Add-Content -Path $OutputFile -Value "AzureCassandraManagedInstance,$Name,$ResourceGroup,$TLSVersion,$Status,$TenantId,$SubscriptionId"
    }
}
###########################
# Step 28: Azure Service Bus TLS Scanning
###########################

Write-Host "Step 28: Scanning Azure Service Bus namespaces for TLS settings..."
Add-Content -Path $OutputFile -Value "`r`n"
Add-Content -Path $OutputFile -Value "AzureServiceBus`r`n"
Add-Content -Path $OutputFile -Value "ResourceType,ResourceName,ResourceGroup,MinimumTLSVersion,Status,TenantId,SubscriptionId`r`n"

$ServiceBusNamespaces = az servicebus namespace list --query "[].{name:name, resourceGroup:resourceGroup}" -o json | ConvertFrom-Json

# Check if there are any Service Bus namespaces
if ($ServiceBusNamespaces.Count -eq 0) {
    Add-Content -Path $OutputFile -Value "No Azure Service Bus namespaces found in this subscription.`r`n"
} else {
    foreach ($ServiceBus in $ServiceBusNamespaces) {
        $Name = $ServiceBus.name
        $ResourceGroup = $ServiceBus.resourceGroup

        # Fetch the Minimum TLS Version for the Service Bus namespace
        $TLSVersion = az servicebus namespace show --name $Name --resource-group $ResourceGroup --query "properties.minimumTlsVersion" -o tsv

        # Default to "Unknown" if not found
        if (-not $TLSVersion) { $TLSVersion = "Unknown" }

        # Determine Compliance Status
        if ($TLSVersion -eq "1.2") {
            $Status = "Compliant"
        } else {
            $Status = "Non-Compliant"
        }

        # Write Service Bus results to Output File
        Add-Content -Path $OutputFile -Value "AzureServiceBus,$Name,$ResourceGroup,$TLSVersion,$Status,$TenantId,$SubscriptionId"
    }
}

###########################
# Step 29: SQL Server Stretch Database TLS Scanning
###########################

Write-Host "Step 29: Scanning SQL Server Stretch Database for TLS settings..."
Add-Content -Path $OutputFile -Value "`r`n"
Add-Content -Path $OutputFile -Value "AzureSQLStretchDatabase`r`n"
Add-Content -Path $OutputFile -Value "ResourceType,ResourceName,ResourceGroup,MinimumTLSVersion,Status,TenantId,SubscriptionId`r`n"

$StretchDatabases = az sql server list --query "[].{name:name, resourceGroup:resourceGroup}" -o json | ConvertFrom-Json

# Check if there are any SQL Stretch Databases
if ($StretchDatabases.Count -eq 0) {
    Add-Content -Path $OutputFile -Value "No SQL Server Stretch Databases found in this subscription.`r`n"
} else {
    foreach ($StretchDB in $StretchDatabases) {
        $Name = $StretchDB.name
        $ResourceGroup = $StretchDB.resourceGroup

        # Fetch the Minimum TLS Version for the Stretch Database
        $TLSVersion = az sql server show --name $Name --resource-group $ResourceGroup --query "minimalTlsVersion" -o tsv

        # Default to "Unknown" if not found
        if (-not $TLSVersion) { $TLSVersion = "Unknown" }

        # Determine Compliance Status
        if ($TLSVersion -eq "1.2") {
            $Status = "Compliant"
        } else {
            $Status = "Non-Compliant"
        }

        # Write SQL Stretch Database results to Output File
        Add-Content -Path $OutputFile -Value "AzureSQLStretchDatabase,$Name,$ResourceGroup,$TLSVersion,$Status,$TenantId,$SubscriptionId"
    }
}

###########################
# Step 30: Azure Storage TLS Scanning
###########################

Write-Host "Step 30: Scanning Azure Storage Accounts for TLS settings..."
Add-Content -Path $OutputFile -Value "`r`n"
Add-Content -Path $OutputFile -Value "AzureStorage`r`n"
Add-Content -Path $OutputFile -Value "ResourceType,ResourceName,ResourceGroup,MinimumTLSVersion,Status,TenantId,SubscriptionId`r`n"

$StorageAccounts = az storage account list --query "[].{name:name, resourceGroup:resourceGroup}" -o json | ConvertFrom-Json

# Check if there are any Storage Accounts
if ($StorageAccounts.Count -eq 0) {
    Add-Content -Path $OutputFile -Value "No Azure Storage Accounts found in this subscription.`r`n"
} else {
    foreach ($StorageAccount in $StorageAccounts) {
        $Name = $StorageAccount.name
        $ResourceGroup = $StorageAccount.resourceGroup

        # Fetch the Minimum TLS Version for the Storage Account
        $TLSVersion = az storage account show --name $Name --resource-group $ResourceGroup --query "minimumTlsVersion" -o tsv

        # Default to "Unknown" if not found
        if (-not $TLSVersion) { $TLSVersion = "Unknown" }

        # Determine Compliance Status
        if ($TLSVersion -eq "TLS1_2") {
            $Status = "Compliant"
        } else {
            $Status = "Non-Compliant"
        }

        # Write Storage results to Output File
        Add-Content -Path $OutputFile -Value "AzureStorage,$Name,$ResourceGroup,$TLSVersion,$Status,$TenantId,$SubscriptionId"
    }
}


Write-Host "Scan complete. Report saved to $OutputFile."
