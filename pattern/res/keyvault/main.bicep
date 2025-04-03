targetScope = 'subscription'

//---------------------- Metadata ----------------------

metadata name = 'Add playground resources'
metadata description = 'This Module deploys key vault into pxs-cn-is-azplg0024-sub subscription.'
metadata project = 'ACTP'
metadata workstream = 'Workstream A - E05'

// ---------------------- Parameters ----------------------

@description('Required. Name Object to create resource name')
param nameObject object

@description('Optional. Location for all Resources.')
param location string = deployment().location

@description('Required. details of Keyvault')
param kvDetails object

@description('Optional. timestamp')
param timestamp string = utcNow()

@description('Optional. Enable/Disable usage telemetry for module.')
param enableTelemetry bool = false

@description('Required. Details of network configuration')
param networkDetails object

// // ---------------------- Variables ----------------------

var workloadName = 'iac'

var keyVaultName = toLower(concat('${nameObject.client}${nameObject.workloadIdentifier}${nameObject.environment}${nameObject.region}kv1'))

resource resourceGroup 'Microsoft.Resources/resourceGroups@2024-07-01' = {
  name: (concat('${nameObject.client}-${nameObject.workloadIdentifier}-${nameObject.purpose}-${nameObject.environment}-${nameObject.region}-rg-1'))
  location: 'westeurope'
}

@description('Reference the existing Private DNS Zone Resource Group')
resource existingPrivateDNSZoneRG 'Microsoft.Resources/resourceGroups@2024-07-01' existing = {
  name: networkDetails.existingPrivateDNSZoneRG
}

@description('Reference the existing Private DNS Zone')
resource existingPrivateDNSZone 'Microsoft.Network/privateDnsZones@2024-06-01' existing = {
  name: networkDetails.existingPrivateDNSZone
  scope: existingPrivateDNSZoneRG
}

@description('Reference the existing Private DNS Zone')
resource existingnetworkRG 'Microsoft.Resources/resourceGroups@2024-07-01' existing = {
  name: networkDetails.existingnetworkRG
}

@description('Reference the existing Virtual Network')
resource existingvnet 'Microsoft.Network/virtualNetworks@2024-05-01' existing = {  
  name: networkDetails.existingvnet
  scope: existingnetworkRG
}

@description('Reference the existing Private Endpoint Subnet')
resource existingsubnet 'Microsoft.Network/virtualNetworks/subnets@2024-05-01' existing = {  
  parent: existingvnet
  name: networkDetails.existingsubnet
}

@description('Reference the existing AKS Nodes Resource Group')
resource existingaksRG 'Microsoft.Resources/resourceGroups@2024-07-01' existing = {
  name: networkDetails.existingaksRG 
}

@description('Reference the existing Keyvault addon User managed Identity')
resource existingmanagedidentity 'Microsoft.ManagedIdentity/userAssignedIdentities@2023-01-31' existing = {
  name: networkDetails.existingmanagedidentity
  scope: existingaksRG
}
@description('Azure keyvault deployment')
module keyvault 'br:pxsmytinfsweacr1.azurecr.io/elements/res/key-vault/vault:0.10.2' = {
  name: take('${timestamp}-kv-${workloadName}', 64)
  scope: resourceGroup
  params: {
    location: location
    name: keyVaultName
    enableRbacAuthorization: kvDetails.enableRbacAuthorization
    sku: kvDetails.sku
    privateEndpoints: [
      for pe in kvDetails.privateEndpoints: {
        customDnsConfigs: pe.customDnsConfigs
        ipConfigurations: pe.ipConfigurations
        privateDnsZoneGroup: {
          privateDnsZoneGroupConfigs: [
            {
               privateDnsZoneResourceId: existingPrivateDNSZone.id
            }
          ]
        }
         subnetResourceId: existingsubnet.id
      }
    ]
    roleAssignments: [
      {
        principalId: existingmanagedidentity.properties.principalId
        principalType: 'ServicePrincipal'
        roleDefinitionIdOrName: 'Key Vault Secrets User'
      }
    ]
    publicNetworkAccess: 'Enabled'
    enableTelemetry: enableTelemetry
  }
}
