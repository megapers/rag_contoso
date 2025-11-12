@description('The name of the Container App')
param containerAppName string = 'ca-rag-contoso-${uniqueString(resourceGroup().id)}'

@description('The name of the Container App Environment')
param environmentName string = 'cae-rag-contoso-${uniqueString(resourceGroup().id)}'

@description('Location for all resources')
param location string = resourceGroup().location

@description('Container image to deploy')
param containerImage string = 'ghcr.io/megapers/rag_contoso:latest'

@description('PostgreSQL server FQDN')
param postgresServerFqdn string

@description('PostgreSQL admin password')
@secure()
param postgresAdminPassword string

@description('Azure AI Search endpoint')
param searchServiceEndpoint string

@description('Azure AI Search admin key')
@secure()
param searchServiceKey string

@description('LLM API key (e.g., OpenAI, Perplexity, etc.)')
@secure()
param llmApiKey string = ''

@description('CPU cores for the container')
param cpuCores string = '0.25'

@description('Memory size for the container')
param memorySize string = '0.5Gi'

@description('Minimum number of replicas')
param minReplicas int = 0

@description('Maximum number of replicas')
param maxReplicas int = 1

@description('Tags for the resources')
param tags object = {
  Environment: 'Production'
  Project: 'RAG-Contoso'
  ManagedBy: 'Bicep'
}

// Log Analytics Workspace for Container App Environment
resource logAnalytics 'Microsoft.OperationalInsights/workspaces@2022-10-01' = {
  name: 'log-${containerAppName}'
  location: location
  tags: tags
  properties: {
    sku: {
      name: 'PerGB2018'
    }
    retentionInDays: 30
  }
}

// Container App Environment
resource containerAppEnvironment 'Microsoft.App/managedEnvironments@2023-05-01' = {
  name: environmentName
  location: location
  tags: tags
  properties: {
    appLogsConfiguration: {
      destination: 'log-analytics'
      logAnalyticsConfiguration: {
        customerId: logAnalytics.properties.customerId
        sharedKey: logAnalytics.listKeys().primarySharedKey
      }
    }
  }
}

// Container App
resource containerApp 'Microsoft.App/containerApps@2023-05-01' = {
  name: containerAppName
  location: location
  tags: tags
  properties: {
    managedEnvironmentId: containerAppEnvironment.id
    configuration: {
      ingress: {
        external: true
        targetPort: 8080
        allowInsecure: false
        traffic: [
          {
            latestRevision: true
            weight: 100
          }
        ]
      }
      secrets: [
        {
          name: 'postgres-password'
          value: postgresAdminPassword
        }
        {
          name: 'search-key'
          value: searchServiceKey
        }
        {
          name: 'llm-api-key'
          value: llmApiKey
        }
      ]
    }
    template: {
      containers: [
        {
          name: 'rag-contoso-backend'
          image: containerImage
          resources: {
            cpu: json(cpuCores)
            memory: memorySize
          }
          env: [
            {
              name: 'ASPNETCORE_ENVIRONMENT'
              value: 'Production'
            }
            {
              name: 'ASPNETCORE_URLS'
              value: 'http://+:8080'
            }
            {
              name: 'USE_POSTGRESQL'
              value: 'true'
            }
            {
              name: 'ConnectionStrings__PostgresConnection'
              value: 'Server=${postgresServerFqdn};Database=ContosoRetailDW;User Id=pgadmin;Password=${postgresAdminPassword};SSL Mode=Require;Trust Server Certificate=true;'
            }
            {
              name: 'AzureAISearch__Endpoint'
              value: searchServiceEndpoint
            }
            {
              name: 'AzureAISearch__ApiKey'
              secretRef: 'search-key'
            }
            {
              name: 'AzureAISearch__IndexName'
              value: 'contoso-sales-index'
            }
            {
              name: 'LlmApi__ApiKey'
              secretRef: 'llm-api-key'
            }
          ]
        }
      ]
      scale: {
        minReplicas: minReplicas
        maxReplicas: maxReplicas
        rules: [
          {
            name: 'http-scaling'
            http: {
              metadata: {
                concurrentRequests: '10'
              }
            }
          }
        ]
      }
    }
  }
}

@description('The FQDN of the Container App')
output containerAppFqdn string = containerApp.properties.configuration.ingress.fqdn

@description('The URL of the Container App')
output containerAppUrl string = 'https://${containerApp.properties.configuration.ingress.fqdn}'

@description('The name of the Container App')
output containerAppName string = containerApp.name

@description('The name of the Container App Environment')
output environmentName string = containerAppEnvironment.name
