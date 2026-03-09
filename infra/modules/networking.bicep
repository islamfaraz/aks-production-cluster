// =============================================
// Networking — VNet, Subnets for AKS
// =============================================

param namePrefix string
param uniqueSuffix string
param location string
param environment string
param tags object

resource vnet 'Microsoft.Network/virtualNetworks@2023-09-01' = {
  name: 'vnet-${namePrefix}-${uniqueSuffix}'
  location: location
  tags: tags
  properties: {
    addressSpace: {
      addressPrefixes: [
        '10.0.0.0/16'
      ]
    }
    subnets: [
      {
        name: 'snet-aks'
        properties: {
          addressPrefix: '10.0.0.0/20'
          privateEndpointNetworkPolicies: 'Disabled'
        }
      }
      {
        name: 'snet-appgw'
        properties: {
          addressPrefix: '10.0.16.0/24'
        }
      }
      {
        name: 'snet-internal'
        properties: {
          addressPrefix: '10.0.17.0/24'
        }
      }
    ]
  }
}

output vnetId string = vnet.id
output aksSubnetId string = vnet.properties.subnets[0].id
output appGwSubnetId string = vnet.properties.subnets[1].id
