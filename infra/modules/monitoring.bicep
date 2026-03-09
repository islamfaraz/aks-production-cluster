// =============================================
// Monitoring — Log Analytics + Container Insights
// =============================================

param namePrefix string
param uniqueSuffix string
param location string
param tags object

resource workspace 'Microsoft.OperationalInsights/workspaces@2022-10-01' = {
  name: 'log-${namePrefix}-${uniqueSuffix}'
  location: location
  tags: tags
  properties: {
    sku: {
      name: 'PerGB2018'
    }
    retentionInDays: 90
  }
}

output workspaceId string = workspace.id
output workspaceName string = workspace.name
