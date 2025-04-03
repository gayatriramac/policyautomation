using './main.bicep'

param location = 'westeurope'

param nameObject = {
  client: 'pxs'
  workloadIdentifier: 'icdm'
  environment: 's'
  region: 'we'
  purpose: 'di'
}
param storagesecuritydetails = {
  publicstorageaccess: false
  softdeleteforcontainers: 10
  softdeleteforblobs: 8
  restorepolicydays: 7
  changeFeedRetentionInDays: 8
  restorePolicyEnabledbool: true
}


// param storagedetails = {
//   storage1: {
//     count: 01
//     containerdetails: [
//       {
//         name: 'avdscripts'
//         roleAssignments: [
//           {
//             principalId: '0de1c562-b495-48e9-9ab3-5a2870d169bc'
//             roleDefinitionIdOrName: 'Storage Blob Data Reader'
//           }
//         ]
//       }
//       {
//         name: 'avdscripts02'
//         roleAssignments: [
//           {
//             principalId: '0de1c562-b495-48e9-9ab3-5a2870d169bc'
//             roleDefinitionIdOrName: 'Storage Blob Data Reader'
//           }
//         ]
//       }
//     ]
//   }
//   storage2: {
//     count: 02
//     containerdetails: [
//       {
//         name: 'avdscripts'
//         roleAssignments: [
//           {
//             principalId: '0de1c562-b495-48e9-9ab3-5a2870d169bc'
//             roleDefinitionIdOrName: 'Storage Blob Data Reader'
//           }
//         ]
//       }
//       {
//         name: 'avdscripts02'
//         roleAssignments: [
//           {
//             principalId: '0de1c562-b495-48e9-9ab3-5a2870d169bc'
//             roleDefinitionIdOrName: 'Storage Blob Data Reader'
//           }
//         ]
//       }
//     ]
//   }
// }

// param storageaccountcount = 2

//param privatestorageaccess = false

// param eventgridsystemtopic = {
//   topictype: 'Microsoft.Storage.StorageAccounts'
// }

// param eventgridsystopicsub = {
//   endpointUrl: 'https://webhook-eventgrid-fdg7febvbqffhxfp.westeurope-01.azurewebsites.net/api/webhook/event'
// }
