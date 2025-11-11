@description('The name of the Azure AI Search service')
param searchServiceName string = 'aisearch-${uniqueString(resourceGroup().id)}'

@description('Location for the Azure AI Search service')
param location string = resourceGroup().location

@description('SKU tier for Azure AI Search')
@allowed([
  'free'
  'basic'
  'standard'
])
param sku string = 'free'

@description('Tags to apply to the resource')
param tags object = {
  Environment: 'Development'
  Project: 'ProductSales-RAG'
}

resource searchService 'Microsoft.Search/searchServices@2023-11-01' = {
  name: searchServiceName
  location: location
  tags: tags
  sku: {
    name: sku
  }
  properties: {
    replicaCount: 1
    partitionCount: 1
    hostingMode: 'default'
    publicNetworkAccess: 'enabled'
  }
}

@description('The name of the search service')
output searchServiceName string = searchService.name

@description('The endpoint URL of the search service')
output searchServiceEndpoint string = 'https://${searchService.name}.search.windows.net'

@description('The resource ID of the search service')
output searchServiceId string = searchService.id
