using './main.bicep'

param nameObject = {
  client: 'pxs'
  workloadIdentifier: 'icdm'
  environment: 'd'
  region: 'gwc'
  purpose: 'istio'
}

param kvDetails = {
  enableRbacAuthorization: true
  sku: 'premium'
  privateEndpoints: [
    {
      customDnsConfigs: [
        {
          fqdn: 'akskv-pe.privatelink.vaultcore.azure.net'
          ipAddresses: [
            '10.5.1.13'
          ]
        }
      ]
      ipConfigurations: [
        {
          name: 'KvIPconfig'
          properties: {
            groupId: 'vault'
            memberName: 'default'
            privateIPAddress: '10.5.1.13'
          }
        }
      ]
    }
  ]
}

param networkDetails = {
  existingPrivateDNSZoneRG: 'pxs-azure-middleware-dns-d-gwc-rg'
  existingPrivateDNSZone: 'privatelink.vaultcore.azure.net'
  existingnetworkRG: 'pxs-azure-middleware-d-gwc-rg'
  existingvnet: 'pxs-azure-middleware-d-gwc-vnet'
  existingsubnet: 'aks-privendpoint-subnet'
  existingaksRG: 'pxs-azure-middleware-d-gwc-rg_aks_pxs-azure-middleware-d-gwc-aks_nodes'
  existingmanagedidentity: 'azurekeyvaultsecretsprovider-pxs-azure-middleware-d-gwc-aks'
}
