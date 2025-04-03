// ---------------------- Orchestration Bicep file ----------------------
// targetScope = 'subscription'

metadata description = 'Deployment of monitoring resources.'
metadata author = 'Gayatri Ramachandran'
metadata project = 'Azure Cloud Transformation Program'
metadata workstream = 'Workstream A Platform enablement (E02, E05, E06, E10 platform)'

// ---------------------- Parameters ----------------------
@description('Required. Name Object to create resource name')
param nameObject object

@description('Required. The location where the resources to be deployed.')
param location string

@description('Required.Security details of the storage account')
param storagesecuritydetails object

// ---------------------- Resources ----------------------
// resource existingresourceGroup 'Microsoft.Resources/resourceGroups@2024-07-01' existing = {
//   name: 'pxs-icdm-di-s-we-rg01'
  
// }


//var storagedetails = loadYamlContent('container.yaml')

// var storagedetailsdelete = loadYamlContent('containerdelete.yaml')
module storageAccount 'br/public:avm/res/storage/storage-account:0.18.0' = {
    scope: resourceGroup('pxs-icdm-di-s-we-rg01')    
    name: 'storageAccountDeployment01'    
    params: {
      // Required parameters
      name: concat('${nameObject.client}${nameObject.workloadIdentifier}${nameObject.purpose}${nameObject.environment}${nameObject.region}st03')
      // Non-required parameters
      allowBlobPublicAccess: storagesecuritydetails.publicstorageaccess
      skuName: 'Standard_ZRS'
      location: location
      networkAcls: {
        bypass: 'AzureServices'
        defaultAction: 'Deny'
      }
      blobServices: {
        isVersioningEnabled: true
        restorePolicyDays: storagesecuritydetails.restorepolicydays
        deleteRetentionPolicyDays: storagesecuritydetails.softdeleteforblobs
        containerDeleteRetentionPolicyDays: storagesecuritydetails.softdeleteforcontainers
        restorePolicyEnabled: storagesecuritydetails.restorePolicyEnabledbool
        containerDeleteRetentionPolicyEnabled: true
        changeFeedEnabled: true
        changeFeedRetentionInDays: storagesecuritydetails.changeFeedRetentionInDays
        
      }
      managementPolicyRules: [
        {
          enabled: true
          name: 'FirstRule'
          type: 'Lifecycle'
          definition: {
            actions: {
              version: {
                delete: {
                  daysAfterCreationGreaterThan: 15
                }
              }
              baseBlob: {
                delete: {
                  daysAfterModificationGreaterThan: 15
                }
              }
            }

            filters: {
              blobTypes: [
                'blockBlob'
              ]
            }
          }
        }
      ]
    }
  }

 
// @description('Required. The details of the storage account resource.')
// param storagedetails object
  // @description('Required. The details of the storage account resource.')
// param storagedetailscontainer array

// @description('Required. The details of the storage account resource.')
// param publicstorageaccess bool

// @description('Required. The details of the storage account resource.')
// param privatestorageaccess bool

// @description('Required. The details of the event grid system topic event subscription')
// param eventgridsystopicsub object

// @description('Required. The details of the event grid system topic')
// param eventgridsystemtopic object
//param containerjson object
//param containerFilesJson array

// @description('List of container files')
// param containerFiles array

// @description('Required. Soft delete for containers')
// param softdeleteforcontainers int

// @description('Required. Soft delete for blobs')
// param softdeleteforblobs int

// @description('Required.Change Feed retention in days')
// param changeFeedRetentionInDays int

// @description('Required. restore policy days')
// param restorepolicydays int

// @description('Required. restore policy enabled')
// param restorePolicyEnabledbool bool

// @description('Required. Number of Storage Account')
// param storageaccountcount int

// @description('Required. Number of Storage Account')
// param containersparameter object

// @description('Optional. The SKU name of the Log Analytics workspace.')
// param logAnalyticsWorkspaceSkuName string = 'PerGB2018'

// @description('Optional. Use resource permissions')
// param useResourcePermissions bool = true

// ---------------------- Variables ----------------------
  // module resourceGroupPrimary 'br/public:avm/res/resources/resource-group:0.4.1' = {
//   name: 'demorg123'
//   params: {
//     name: resourceGroupName
//     location: location
//   }
// }
//var containerFilePaths = ['containerdetailsjson/container01.json','containerdetailsjson/container02.json']
// Load the content of each YAML file
//param storagedetails object
//var storagedetails = loadJsonContent ('./containerjson')
//var yamlFilePaths = split(environment('containerFiles'), ' ')

// output containerFilesOutput array = containerFiles
// module storageAccountprivate 'br/public:avm/res/storage/storage-account:0.17.0' = {
//   name: 'PrivatestorageAccountDeployment'
//   scope: resourceGroup
//   params: {
//     // Required parameters
//     name: concat('${nameObject.client}${nameObject.workloadIdentifier}${nameObject.purpose}${nameObject.environment}${nameObject.region}st02')
//     // Non-required parameters
//     allowBlobPublicAccess: privatestorageaccess
//     skuName: 'Standard_ZRS'

//     location: location
//     networkAcls: {
//       bypass: 'AzureServices'
//       defaultAction: 'Deny'
//     }
//     blobServices: {
//       isVersioningEnabled: true
//       //restorePolicyDays: restorepolicydays
//       deleteRetentionPolicyDays: softdeleteforblobs
//       containerDeleteRetentionPolicyDays: softdeleteforcontainers
//       restorePolicyEnabled: restorePolicyEnabledbool
//       containerDeleteRetentionPolicyEnabled: true
//       changeFeedEnabled: true
//       changeFeedRetentionInDays: changeFeedRetentionInDays
//       containers: [
//         {
//           name: '${storagedetails.container1}'
//           publicAccess: 'None'
//         }
//         {
//           name: '${storagedetails.container2}'
//           publicAccess: 'None'
//         }
//       ]
//     }
//   }
// }
// module systemTopic 'br/public:avm/res/event-grid/system-topic:0.4.0' = {
//   name: 'systemTopicDeployment'
//   scope: resourceGroup
//   params: {
//     // Required parameters

//     name: (concat('${nameObject.client}-${nameObject.workloadIdentifier}-${nameObject.purpose}-${nameObject.environment}-${nameObject.region}-egst1'))
//     source: storageAccount.outputs.resourceId
//     topicType: '${eventgridsystemtopic.topictype}'
//     // Non-required parameters
//     location: location

//     eventSubscriptions: [
//       {
//         name: 'eventgrid-webhook'
//         expirationTimeUtc: '2099-01-01T11:00:21.715Z'

//         destination: {
//           endpointType: 'WebHook'
//           properties: {
//             resourceId: storageAccount.outputs.resourceId
//             endpointUrl: '${eventgridsystopicsub.endpointurl}'
//           }
//         }
//         filter: {
//           includedEventTypes: ['Microsoft.Storage.BlobCreated', 'Microsoft.Storage.BlobDeleted']
//           isSubjectCaseSensitive: true
//           subjectBeginsWith: '/blobServices/default/containers/webhook-provider'
//           subjectEndsWith: '.json'
//         }
//       }
//     ]
//   }
// }
// ---------------------- Modules ----------------------
// module workspace 'br/public:avm/res/operational-insights/workspace:0.9.1' = {
//   name: take('${timestamp}-logworkspace-${workloadName}', 64)
//   scope: resourceGroup
//   params: {
//     name: toUpper(concat('${nameObject.client}-${nameObject.workloadIdentifier}-${workloadName}-${nameObject.environment}-${nameObject.region}-log1'))
//     location: location
//     diagnosticSettings: diagnosticSettings
//     skuName: logAnalyticsWorkspaceSkuName
//     useResourcePermissions: useResourcePermissions
//   }
// }

// module automationAccount 'br/public:avm/res/automation/automation-account:0.11.1' = {
//   name: take('${timestamp}-automationaccount-${workloadName}', 64)
//   scope: resourceGroup
//   params: {
//     name: toUpper(concat('${nameObject.client}-${nameObject.workloadIdentifier}-${workloadName}-${nameObject.environment}-${nameObject.region}-aa1'))
//     location: location
//   }
// }
