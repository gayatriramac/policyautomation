# This script automates the management of Azure Storage containers and their role assignments.
# It performs the following tasks:
# 1. Fetches existing containers and their role assignments from the Azure portal.
# 2. Reads container details and role assignments from YAML configuration files.
# 3. Compares the portal data with the YAML configuration:
#    - Removes outdated role assignments and containers not present in the YAML configuration.
#    - Adds new containers and role assignments specified in the YAML configuration.
# 4. Ensures that the portal state matches the desired state defined in the YAML files.
# 5. Outputs the results of the operations for verification and debugging purposes.

# The script uses Azure CLI commands to interact with Azure resources and PowerShell to process data.
# Ensure that the required environment variables ($resourceGroupName, $storageAccountName, $subscriptionId) are set before running the script.
# Additionally, the YAML configuration files should be placed in the './containerdetails' folder.

# PART 1
# Fetch details from PORTAL
Write-Host "Starting the script" -ForegroundColor Green

$resourceGroupName = $env:resourceGroupName
$storageAccountName = $env:storageAccountName
$subscriptionId = $env:subscriptionId

# Get all accounts in one subscription
$keys = az storage account keys list -g $resourceGroupName -n $storageAccountName --query [0].value
$resultsfromportal = @()

# Get all containers in one account
$containers = az storage container list --account-name $storageAccountName --account-key $keys | ConvertFrom-Json

foreach ($container in $containers) {
    Write-Host "Checking role assignments for container: $($container.Name)"

    # Define the scope for the container role assignments
    $scope = "/subscriptions/$subscriptionId/resourceGroups/$resourceGroupName/providers/Microsoft.Storage/storageAccounts/$storageAccountName/blobServices/default/containers/$($container.Name)"

    # Get all role assignments for the container filtered by the 'Storage Blob Data Reader' role
    $roleAssignments = az role assignment list --scope $scope --query "[?roleDefinitionName=='Storage Blob Data Reader' || roleDefinitionName=='Storage Blob Data Contributor']" | ConvertFrom-Json

    # Check if there are any role assignments for this container and role
    if ($roleAssignments) {
        foreach ($roleAssignment in $roleAssignments) {
            if ($roleAssignment.Scope -eq "$scope") {
                $resultsfromportal += [PSCustomObject]@{
                    ContainerName = $container.Name
                    PrincipalId = $roleAssignment.principalId
                    RoleDefinitionIdOrName = $roleAssignment.RoleDefinitionName
                    DisplayName = $roleAssignment.DisplayName
                    Scope = $roleAssignment.Scope
                }
            }
        }
    } else {
        Write-Host "No 'Storage Blob Data Reader/Contributor' role assignments found for container $($container.Name)."
    }
}
Write-Host "From Portal: $($resultsfromportal | ConvertTo-Json -Depth 5)" -ForegroundColor Green

# PART 2
# Fetch details from YAML
Write-Host "Fetching details from YAML" -ForegroundColor Yellow
$yamlFolderPath = "./containerdetails"
$yamlFiles = Get-ChildItem -Path $yamlFolderPath -Filter *.yaml

# Initialize an array to hold container names from the YAML files
$resultsfromyaml = @()

# Loop through each YAML file and extract the container name
foreach ($file in $yamlFiles) {
    # Read and parse the YAML file
    $yamlContent = Get-Content -Path $file.FullName | Out-String | ConvertFrom-Yaml

    # Check if 'containerdetails' exists in the parsed YAML content
    if ($yamlContent.containerdetails) {
        foreach ($entry in $yamlContent.containerdetails) {
            # Ensure 'roleAssignments' exists for the current entry
            if ($entry.roleAssignments) {
                foreach ($yamlroleAssignment in $entry.roleAssignments) {
                    # Extract data
                    $containerName = $entry.Name
                    $yamlprincipalId = $yamlroleAssignment.principalId
                    $roleDefinitionIdOrName = $yamlroleAssignment.roleDefinitionIdOrName
                    $displayname = $yamlroleAssignment.displayName
                    $scopefromyaml = "/subscriptions/$subscriptionId/resourceGroups/$resourceGroupName/providers/Microsoft.Storage/storageAccounts/$storageAccountName/blobServices/default/containers/$containerName"

                    # Add to array
                    if ($yamlprincipalId -ne $null) {
                        $resultsfromyaml += [PSCustomObject]@{
                            ContainerName = $containerName
                            PrincipalId = $yamlprincipalId
                            RoleDefinitionIdOrName = $roleDefinitionIdOrName
                            DisplayName = $displayname
                            Scope = $scopefromyaml
                        }
                    }
                }
            }
        }
    }
}
# Print the final array after processing all files
Write-Host "From YAML: $($resultsfromyaml | ConvertTo-Json -Depth 5)" -ForegroundColor Yellow

# PART 3
# Perform deletion process

# Step 1: Initialize lists to track removals
$toRemoveAssignments = @()  # A list to store role assignments to remove
$toRemoveContainers = @()   # A list to store containers to remove
$toRemoveAssignmentsonly = @() # A list to store only the role assignments to remove
$uniquecontainers = @()

# Step 2: Loop through the resultsfromportal array and compare it with the YAML array
Write-Host "Starting the updating process if any" -ForegroundColor DarkRed
foreach ($portalAssignment in $resultsfromportal) {
    # Find if the container exists in the YAML array
    $yamlContainer = $resultsfromyaml | Where-Object { $_.ContainerName -eq $portalAssignment.ContainerName }

    if ($yamlContainer) {
        # If the container exists in YAML, compare role assignments
        $yamlRoleAssignments = $yamlContainer | Where-Object {
            $_.PrincipalId -eq $portalAssignment.PrincipalId -and
            $_.RoleDefinitionIdOrName -eq $portalAssignment.RoleDefinitionIdOrName
        }

        if (-not $yamlRoleAssignments) {
            # If the role assignment in portal does not exist in YAML, mark for removal
            Write-Host "Removing outdated role assignment for Container: $($portalAssignment.ContainerName), PrincipalId: $($portalAssignment.PrincipalId)"
            $toRemoveAssignmentsonly += $portalAssignment
        }
    } else {
        # If the container does not exist in YAML, mark the entire container and its role assignments for removal
        Write-Host "Removing role assignments and container: $($portalAssignment.ContainerName) for $($portalAssignment.PrincipalId)"
        $toRemoveAssignments += $portalAssignment
        $uniquecontainers += $portalAssignment.ContainerName
        $toRemoveContainers = $uniquecontainers | Sort-Object -Unique
    }
}

# Step 3: Perform the removal based on identified role assignments and containers

# Remove the outdated role assignments from resultsfromportal
foreach ($removeAssignment in $toRemoveAssignmentsonly) {
    Write-Host "Removing outdated role assignment for Container: $($removeAssignment.ContainerName), PrincipalId: $($removeAssignment.PrincipalId)" -ForegroundColor Red
    az role assignment delete --scope $removeAssignment.Scope --assignee $removeAssignment.PrincipalId --role $removeAssignment.RoleDefinitionIdOrName
    Write-Host "Completed the removal process of Role Assignment."
}

# Remove containers that were identified for removal
if ($toRemoveContainers -ne $null) {
    foreach ($containerNameentry in $toRemoveContainers) {
        az storage container delete --account-name $storageAccountName --account-key $keys --name $containerNameentry
        Write-Host "Completed the removal process of Container and Role Assignment."
    }
} else {
    Write-Host "Nothing to remove" -ForegroundColor DarkRed
}

# PART 4
# Perform addition process
$resultfromportalv2 = @()
$v2Results = @()

# Addition of new entries
Write-Host "Starting the adding process if any" -ForegroundColor DarkCyan
foreach ($arrayentry in $resultsfromyaml) {
    $matchingRoleAssignments = $resultsfromportal | Where-Object { $_.ContainerName -eq $arrayentry.ContainerName }

    if (-not $matchingRoleAssignments) {
        # Container not found in role assignments, create the container
        if ($containers | Where-Object { $_.name -eq $arrayentry.ContainerName }) {
            Write-Host "Container '$($arrayentry.ContainerName)' already exists." -ForegroundColor Cyan
        } else {
            az storage container create --name $arrayentry.ContainerName --account-name $storageAccountName --account-key $keys
            if ($LASTEXITCODE -eq 0) {
                Write-Host "Container '$($arrayentry.ContainerName)' created." -ForegroundColor DarkGreen
                $scope2 = "/subscriptions/$subscriptionId/resourceGroups/$resourceGroupName/providers/Microsoft.Storage/storageAccounts/$storageAccountName/blobServices/default/containers/$($arrayentry.ContainerName)"
                $portalroleassignmentsarray = az role assignment list --scope $scope2 --query "[?roleDefinitionName=='Storage Blob Data Reader' || roleDefinitionName=='Storage Blob Data Contributor']" | ConvertFrom-Json
                if ($portalroleassignmentsarray) {
                    foreach ($array2entry in $portalroleassignmentsarray) {
                        $resultfromportalv2 += [PSCustomObject]@{
                            ContainerName = $arrayentry.ContainerName
                            PrincipalId = $array2entry.principalId
                            RoleDefinitionIdOrName = $array2entry.RoleDefinitionName
                            Scope = $array2entry.Scope
                        }
                        $v2Results = $resultfromportalv2 | Select-Object -Property ContainerName, PrincipalId, RoleDefinitionIdOrName, Scope -Unique
                    }
                }
                Write-Host "From Portal for newly created container: $($v2Results | ConvertTo-Json -Depth 5)" -ForegroundColor Green
            } else {
                Write-Host "Failed to create container '$($arrayentry.ContainerName)'. Please check the error message." -ForegroundColor Red
            }
        }
    } else {
        Write-Host "Container '$($arrayentry.ContainerName)' already present" -ForegroundColor Cyan
    }

    # Check if the specific role assignment exists for the container
    $matchingRoleAssignment = $matchingRoleAssignments | Where-Object {
        $_.PrincipalId -eq $arrayentry.PrincipalId -and
        $_.RoleDefinitionIdOrName -eq $arrayentry.RoleDefinitionIdOrName
    }
    if (-not $matchingRoleAssignment) {
        az role assignment create --assignee-object-id $arrayentry.PrincipalId --role $arrayentry.RoleDefinitionIdOrName --scope "/subscriptions/$subscriptionId/resourceGroups/$resourceGroupName/providers/Microsoft.Storage/storageAccounts/$storageAccountName/blobServices/default/containers/$($arrayentry.ContainerName)" --assignee-principal-type ServicePrincipal
        Write-Host "Role assignment added for PrincipalId '$($arrayentry.PrincipalId)' in container '$($arrayentry.ContainerName)'." -ForegroundColor Cyan
    } else {
        Write-Host "Role assignment '$($arrayentry.PrincipalId)' with '$($arrayentry.RoleDefinitionIdOrName)' already present" -ForegroundColor Cyan
    }
}

# PART 5
# Clean up any role assignments that are in the portal but not in the YAML file
Write-Host "Checking for role assignments to remove..." -ForegroundColor Yellow
$uniqueresults = $v2Results | Sort-Object -Unique
foreach ($portal in $v2Results) {
    # Check if the PrincipalId exists in the $resultsfromyaml
    $matchingEntry = $resultsfromyaml | Where-Object {
        $_.PrincipalId -eq $portal.PrincipalId -and
        $_.ContainerName -eq $portal.ContainerName
    }
    if (-not $matchingEntry) {
        Write-Host "Removing role assignment for PrincipalId '$($portal.PrincipalId)' in container '$($portal.ContainerName)'" -ForegroundColor Red
        az role assignment delete --scope $portal.Scope --assignee $portal.PrincipalId --role $portal.RoleDefinitionIdOrName --only-show-errors

        if ($LASTEXITCODE -eq 0) {
            Write-Host "Successfully removed role assignment for PrincipalId '$($portal.PrincipalId)' in scope '$($portal.Scope)'." -ForegroundColor Green
        } else {
            Write-Host "Failed to remove role assignment for PrincipalId '$($portal.PrincipalId)' in scope '$($portal.Scope)'. Please check the error." -ForegroundColor Yellow
        }
    }
}