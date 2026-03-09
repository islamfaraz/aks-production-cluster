// =============================================
// AKS Cluster — Highly Scalable, Production-Grade
//
// Zone Spanned vs Zone Aligned:
// ─────────────────────────────
// ZONE SPANNED (default below):
//   Nodes are spread ACROSS availability zones (1, 2, 3).
//   The cluster scheduler distributes pods across zones.
//   → Best for: General workloads, maximum availability
//
// ZONE ALIGNED:
//   Each node pool is pinned to a SINGLE availability zone.
//   You create separate node pools per zone for isolation.
//   → Best for: Stateful workloads, low-latency zone-local storage
//
// See commented examples for Zone Aligned configuration.
// =============================================

param namePrefix string
param uniqueSuffix string
param location string
param environment string
param kubernetesVersion string
param vnetSubnetId string
param acrId string
param logAnalyticsWorkspaceId string
param tags object

// ─────────────────────────────────────────────────
// AKS CLUSTER — ZONE SPANNED (Active Configuration)
// Nodes distributed across Availability Zones 1, 2, 3
// ─────────────────────────────────────────────────
resource aksCluster 'Microsoft.ContainerService/managedClusters@2024-01-01' = {
  name: 'aks-${namePrefix}-${uniqueSuffix}'
  location: location
  tags: tags
  identity: {
    type: 'SystemAssigned'
  }
  sku: {
    name: 'Base'
    tier: environment == 'prod' ? 'Standard' : 'Free'
  }
  properties: {
    kubernetesVersion: kubernetesVersion
    dnsPrefix: 'aks-${namePrefix}-${uniqueSuffix}'
    enableRBAC: true

    // ── System Node Pool — Zone SPANNED (across zones 1, 2, 3) ──
    agentPoolProfiles: [
      {
        name: 'system'
        count: environment == 'prod' ? 3 : 1
        vmSize: environment == 'prod' ? 'Standard_D4s_v5' : 'Standard_B2ms'
        osType: 'Linux'
        osSKU: 'AzureLinux'
        mode: 'System'
        vnetSubnetID: vnetSubnetId
        maxPods: 110
        enableAutoScaling: true
        minCount: environment == 'prod' ? 3 : 1
        maxCount: environment == 'prod' ? 10 : 3
        // ZONE SPANNED — nodes distributed across all 3 zones
        availabilityZones: environment == 'prod' ? [
          '1'
          '2'
          '3'
        ] : null
        nodeTaints: [
          'CriticalAddonsOnly=true:NoSchedule'
        ]
        upgradeSettings: {
          maxSurge: '33%'
        }
      }
    ]

    // ── Network Configuration ──
    networkProfile: {
      networkPlugin: 'azure'
      networkPolicy: 'calico'
      serviceCidr: '172.16.0.0/16'
      dnsServiceIP: '172.16.0.10'
      loadBalancerSku: 'standard'
      outboundType: 'loadBalancer'
    }

    // ── Auto-upgrade ──
    autoUpgradeProfile: {
      upgradeChannel: environment == 'prod' ? 'stable' : 'rapid'
    }

    // ── Azure Monitor ──
    addonProfiles: {
      omsagent: {
        enabled: true
        config: {
          logAnalyticsWorkspaceResourceID: logAnalyticsWorkspaceId
        }
      }
      azurePolicy: {
        enabled: true
      }
    }

    // ── Security ──
    apiServerAccessProfile: {
      enablePrivateCluster: environment == 'prod'
    }

    autoScalerProfile: {
      'balance-similar-node-groups': 'true'
      expander: 'random'
      'max-graceful-termination-sec': '600'
      'scale-down-delay-after-add': '10m'
      'scale-down-unneeded-time': '10m'
      'scan-interval': '10s'
    }
  }
}

// ── User Node Pool — Zone SPANNED (workload nodes) ──
resource userPool 'Microsoft.ContainerService/managedClusters/agentPools@2024-01-01' = {
  parent: aksCluster
  name: 'workload'
  properties: {
    count: environment == 'prod' ? 3 : 1
    vmSize: environment == 'prod' ? 'Standard_D8s_v5' : 'Standard_B4ms'
    osType: 'Linux'
    osSKU: 'AzureLinux'
    mode: 'User'
    vnetSubnetID: vnetSubnetId
    maxPods: 110
    enableAutoScaling: true
    minCount: environment == 'prod' ? 3 : 1
    maxCount: environment == 'prod' ? 50 : 5
    // ZONE SPANNED — pods land on nodes across all zones
    availabilityZones: environment == 'prod' ? [
      '1'
      '2'
      '3'
    ] : null
    upgradeSettings: {
      maxSurge: '33%'
    }
    nodeLabels: {
      'workload-type': 'general'
    }
  }
}

// ╔═══════════════════════════════════════════════════════════════╗
// ║  ZONE ALIGNED EXAMPLE (Commented)                           ║
// ║  Each node pool pinned to a SINGLE zone                     ║
// ║  Use for: stateful apps, zone-local PV, low-latency         ║
// ╚═══════════════════════════════════════════════════════════════╝
//
// Zone Aligned means each pool exists in exactly ONE zone.
// You create 3 separate pools for 3 zones:
//
// resource zoneAlignedPool1 'Microsoft.ContainerService/managedClusters/agentPools@2024-01-01' = {
//   parent: aksCluster
//   name: 'zone1pool'
//   properties: {
//     count: 2
//     vmSize: 'Standard_D8s_v5'
//     osType: 'Linux'
//     mode: 'User'
//     vnetSubnetID: vnetSubnetId
//     maxPods: 110
//     enableAutoScaling: true
//     minCount: 2
//     maxCount: 10
//     // ZONE ALIGNED — pinned to Zone 1 ONLY
//     availabilityZones: [
//       '1'
//     ]
//     nodeLabels: {
//       'topology.kubernetes.io/zone': 'eastus2-1'
//       'workload-type': 'zone-aligned'
//     }
//   }
// }
//
// resource zoneAlignedPool2 'Microsoft.ContainerService/managedClusters/agentPools@2024-01-01' = {
//   parent: aksCluster
//   name: 'zone2pool'
//   properties: {
//     count: 2
//     vmSize: 'Standard_D8s_v5'
//     osType: 'Linux'
//     mode: 'User'
//     vnetSubnetID: vnetSubnetId
//     maxPods: 110
//     enableAutoScaling: true
//     minCount: 2
//     maxCount: 10
//     // ZONE ALIGNED — pinned to Zone 2 ONLY
//     availabilityZones: [
//       '2'
//     ]
//     nodeLabels: {
//       'topology.kubernetes.io/zone': 'eastus2-2'
//       'workload-type': 'zone-aligned'
//     }
//   }
// }
//
// resource zoneAlignedPool3 'Microsoft.ContainerService/managedClusters/agentPools@2024-01-01' = {
//   parent: aksCluster
//   name: 'zone3pool'
//   properties: {
//     count: 2
//     vmSize: 'Standard_D8s_v5'
//     osType: 'Linux'
//     mode: 'User'
//     vnetSubnetID: vnetSubnetId
//     maxPods: 110
//     enableAutoScaling: true
//     minCount: 2
//     maxCount: 10
//     // ZONE ALIGNED — pinned to Zone 3 ONLY
//     availabilityZones: [
//       '3'
//     ]
//     nodeLabels: {
//       'topology.kubernetes.io/zone': 'eastus2-3'
//       'workload-type': 'zone-aligned'
//     }
//   }
// }
//
// ┌──────────────────────────────────────────────────────────────┐
// │  ZONE ALIGNED — When to use:                                │
// │                                                              │
// │  • Stateful workloads with zone-local PersistentVolumes     │
// │    (e.g., databases, Kafka, Elasticsearch)                  │
// │  • Ultra-low-latency requirements within a single zone      │
// │  • Compliance requirements for data residency in a zone     │
// │                                                              │
// │  Topology Spread Constraints for Zone Aligned:              │
// │  ─────────────────────────────────────────────              │
// │  apiVersion: apps/v1                                        │
// │  kind: Deployment                                           │
// │  spec:                                                      │
// │    topologySpreadConstraints:                                │
// │    - maxSkew: 1                                              │
// │      topologyKey: topology.kubernetes.io/zone                │
// │      whenUnsatisfiable: DoNotSchedule                       │
// │      labelSelector:                                         │
// │        matchLabels:                                          │
// │          app: my-stateful-app                                │
// └──────────────────────────────────────────────────────────────┘

// ── ACR Pull Role Assignment ──
resource acrPull 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(aksCluster.id, acrId, 'acrpull')
  scope: resourceGroup()
  properties: {
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', '7f951dda-4ed3-4680-a7ca-43fe172d538d') // AcrPull
    principalId: aksCluster.properties.identityProfile.kubeletidentity.objectId
    principalType: 'ServicePrincipal'
  }
}

output clusterName string = aksCluster.name
output clusterFqdn string = aksCluster.properties.fqdn
output kubeletIdentity string = aksCluster.properties.identityProfile.kubeletidentity.objectId
