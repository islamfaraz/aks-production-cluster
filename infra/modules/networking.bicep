// =============================================
// Networking — VNet, Subnets for AKS
// =============================================

param namePrefix string
param uniqueSuffix string
param location string
param tags object

// ── Network Security Groups ──
resource aksNsg 'Microsoft.Network/networkSecurityGroups@2023-09-01' = {
  name: 'nsg-aks-${namePrefix}-${uniqueSuffix}'
  location: location
  tags: tags
  properties: {
    securityRules: [
      {
        name: 'AllowHTTPS'
        properties: {
          priority: 100
          direction: 'Inbound'
          access: 'Allow'
          protocol: 'Tcp'
          sourceAddressPrefix: '*'
          sourcePortRange: '*'
          destinationAddressPrefix: '*'
          destinationPortRange: '443'
        }
      }
    ]
  }
}

resource appGwNsg 'Microsoft.Network/networkSecurityGroups@2023-09-01' = {
  name: 'nsg-appgw-${namePrefix}-${uniqueSuffix}'
  location: location
  tags: tags
  properties: {
    securityRules: [
      {
        name: 'AllowGatewayManager'
        properties: {
          priority: 100
          direction: 'Inbound'
          access: 'Allow'
          protocol: 'Tcp'
          sourceAddressPrefix: 'GatewayManager'
          sourcePortRange: '*'
          destinationAddressPrefix: '*'
          destinationPortRange: '65200-65535'
        }
      }
      {
        name: 'AllowHTTPS'
        properties: {
          priority: 110
          direction: 'Inbound'
          access: 'Allow'
          protocol: 'Tcp'
          sourceAddressPrefix: '*'
          sourcePortRange: '*'
          destinationAddressPrefix: '*'
          destinationPortRange: '443'
        }
      }
    ]
  }
}

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
          networkSecurityGroup: {
            id: aksNsg.id
          }
        }
      }
      {
        name: 'snet-appgw'
        properties: {
          addressPrefix: '10.0.16.0/24'
          networkSecurityGroup: {
            id: appGwNsg.id
          }
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
