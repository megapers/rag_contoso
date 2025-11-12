@description('The name of the PostgreSQL Flexible Server')
param serverName string = 'pg-rag-contoso-${uniqueString(resourceGroup().id)}'

@description('The administrator login username for the server')
param administratorLogin string = 'pgadmin'

@description('The administrator login password for the server')
@secure()
param administratorLoginPassword string

@description('The name of the database to create')
param databaseName string = 'ContosoRetailDW'

@description('Location for all resources')
param location string = resourceGroup().location

@description('PostgreSQL Server version')
@allowed([
  '16'
  '15'
  '14'
  '13'
])
param postgresVersion string = '16'

@description('The tier of the compute')
@allowed([
  'Burstable'
  'GeneralPurpose'
  'MemoryOptimized'
])
param skuTier string = 'Burstable'

@description('The name of the sku (VM size)')
param skuName string = 'Standard_B1ms'

@description('Storage size in GB')
@minValue(32)
@maxValue(32768)
param storageSizeGB int = 32

@description('Backup retention days')
@minValue(7)
@maxValue(35)
param backupRetentionDays int = 7

@description('Enable Geo-Redundant Backup')
param geoRedundantBackup string = 'Disabled'

@description('Enable High Availability')
param highAvailability string = 'Disabled'

@description('IP addresses allowed to connect to the server (0.0.0.0 means all Azure services)')
param allowedIpAddresses array = [
  {
    name: 'AllowAllAzureServices'
    startIpAddress: '0.0.0.0'
    endIpAddress: '0.0.0.0'
  }
]

@description('Tags for the resources')
param tags object = {
  Environment: 'Demo'
  Project: 'RAG-Contoso'
  CostCenter: 'Free-Tier'
}

resource postgresServer 'Microsoft.DBforPostgreSQL/flexibleServers@2023-03-01-preview' = {
  name: serverName
  location: location
  tags: tags
  sku: {
    name: skuName
    tier: skuTier
  }
  properties: {
    administratorLogin: administratorLogin
    administratorLoginPassword: administratorLoginPassword
    version: postgresVersion
    storage: {
      storageSizeGB: storageSizeGB
      autoGrow: 'Enabled'
    }
    backup: {
      backupRetentionDays: backupRetentionDays
      geoRedundantBackup: geoRedundantBackup
    }
    highAvailability: {
      mode: highAvailability
    }
  }
}

resource firewallRules 'Microsoft.DBforPostgreSQL/flexibleServers/firewallRules@2023-03-01-preview' = [for rule in allowedIpAddresses: {
  parent: postgresServer
  name: rule.name
  properties: {
    startIpAddress: rule.startIpAddress
    endIpAddress: rule.endIpAddress
  }
}]

resource database 'Microsoft.DBforPostgreSQL/flexibleServers/databases@2023-03-01-preview' = {
  parent: postgresServer
  name: databaseName
  properties: {
    charset: 'UTF8'
    collation: 'en_US.utf8'
  }
}

@description('The fully qualified domain name of the PostgreSQL server')
output serverFqdn string = postgresServer.properties.fullyQualifiedDomainName

@description('The name of the PostgreSQL server')
output serverName string = postgresServer.name

@description('The name of the database')
output databaseName string = database.name

@description('Connection string template (replace <password> with actual password)')
output connectionStringTemplate string = 'Server=${postgresServer.properties.fullyQualifiedDomainName};Database=${databaseName};User Id=${administratorLogin};Password=<password>;SSL Mode=Require;Trust Server Certificate=true;'
