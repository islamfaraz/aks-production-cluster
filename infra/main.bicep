// =============================================
// AKS Production Cluster — Main Orchestrator
// Zone-Spanned cluster with ACR, sample app
// =============================================

targetScope = 'resourceGroup'

@description('Deployment environment')
@allowed(['dev', 'staging', 'prod'])
param environment string

@description('Azure region')
param location string = resourceGroup().location

@description('Project name for resource naming')
param projectName string = 'akscluster'

@description('AKS Kubernetes version')
param kubernetesVersion string = '1.29'

@description('Tags for all resources')
param tags object = {}

var uniqueSuffix = substring(uniqueString(resourceGroup().id, projectName), 0, 6)
var namePrefix = '${projectName}-${environment}'

// ── Networking ──
module networking 'modules/networking.bicep' = {
  name: 'networking-${uniqueSuffix}'
  params: {
    namePrefix: namePrefix
    uniqueSuffix: uniqueSuffix
    location: location
    tags: tags
  }
}

// ── Azure Container Registry ──
module acr 'modules/acr.bicep' = {
  name: 'acr-${uniqueSuffix}'
  params: {
    namePrefix: namePrefix
    uniqueSuffix: uniqueSuffix
    location: location
    environment: environment
    tags: tags
  }
}

// ── AKS Cluster ──
module aks 'modules/aks.bicep' = {
  name: 'aks-${uniqueSuffix}'
  params: {
    namePrefix: namePrefix
    uniqueSuffix: uniqueSuffix
    location: location
    environment: environment
    kubernetesVersion: kubernetesVersion
    vnetSubnetId: networking.outputs.aksSubnetId
    acrId: acr.outputs.acrId
    logAnalyticsWorkspaceId: monitoring.outputs.workspaceId
    tags: tags
  }
}

// ── Monitoring ──
module monitoring 'modules/monitoring.bicep' = {
  name: 'monitoring-${uniqueSuffix}'
  params: {
    namePrefix: namePrefix
    uniqueSuffix: uniqueSuffix
    location: location
    tags: tags
  }
}

// ── Outputs ──
output aksClusterName string = aks.outputs.clusterName
output aksClusterFqdn string = aks.outputs.clusterFqdn
output acrLoginServer string = acr.outputs.loginServer
output acrName string = acr.outputs.acrName
