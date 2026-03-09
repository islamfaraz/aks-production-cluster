// =============================================
// Azure Container Registry — Docker image store
// =============================================

param namePrefix string
param uniqueSuffix string
param location string
param environment string
param tags object

var acrName = replace('acr${namePrefix}${uniqueSuffix}', '-', '')

resource acr 'Microsoft.ContainerRegistry/registries@2023-07-01' = {
  name: acrName
  location: location
  tags: tags
  sku: {
    name: environment == 'prod' ? 'Premium' : 'Basic'
  }
  properties: {
    adminUserEnabled: false
    publicNetworkAccess: 'Enabled'
    zoneRedundancy: environment == 'prod' ? 'Enabled' : 'Disabled'
    policies: {
      retentionPolicy: {
        status: environment == 'prod' ? 'enabled' : 'disabled'
        days: 30
      }
    }
  }
}

output acrId string = acr.id
output acrName string = acr.name
output loginServer string = acr.properties.loginServer
