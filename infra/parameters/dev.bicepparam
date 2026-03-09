using '../main.bicep'

param environment = 'dev'
param location = 'eastus2'
param projectName = 'akscluster'
param kubernetesVersion = '1.29'
param tags = {
  Environment: 'dev'
  Project: 'AKSProductionCluster'
  ManagedBy: 'Bicep'
}
