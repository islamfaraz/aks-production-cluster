using '../main.bicep'

param environment = 'prod'
param location = 'eastus2'
param projectName = 'akscluster'
param kubernetesVersion = '1.29'
param tags = {
  Environment: 'prod'
  Project: 'AKSProductionCluster'
  ManagedBy: 'Bicep'
}
