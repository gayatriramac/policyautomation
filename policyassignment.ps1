<#
.SYNOPSIS
This script creates Policy Assignment files with the policy definition files , policy Intiatives and data in the metadata.csv according to the BATCH details.
 
.DESCRIPTION
This script updated the Policy Assignment files in the Policy Assignment folder.
 
.EXAMPLE
  1. From Consolidated Excel, export "Metadata" sheet to CSV named metadata.csv and copy it to root folder of cloned Clearlisting repo
  2. Copy this script to root folder of cloned Clearlisting folder
  3. Run the script
  4. Validate updated files in the Policy Assignment folder
  #>

# Import CSV file
$csvData = Import-Csv -Path 'metadata.csv'

# Write log to display total row count
Write-Host "Total row count in csvData: $($csvData.count)"

#Path for policy definitions and input details for BATCH deployment
$policyAssignmentsFolder = "./policy_assignments/"
$policySetDefinitionsFolder = "./policy_set_definitions/"
$policyBatchdetail = Read-Host "Enter the BATCH details for Policy Assignment update"
$policyDefinitionsFolder = "./policy_definitions/"

# First, ensure 'AssignmentName' entries are distinct and not "N/A"
$distinctAssignments = @($csvData |
    Where-Object { $_.'AssignmentName' -ne "N/A" -and $_.'Batch' -eq $policyBatchdetail } | Select-Object 'Temp-AssignmentName', 'ADOInitiativeFileName', 'PolicyType', 'PolicyID' -Unique)

#Log the count back into the script , count of the distinct Assignment file
Write-Host "Total number of Distinct ADOAssignmentsFileName: $($distinctAssignments.Count)"

foreach ($Assignment in $distinctAssignments) {
    try {
        $AssignmentName = $Assignment.'Temp-AssignmentName'
        if (-not $AssignmentName -or $AssignmentName.ToLower() -eq 'tbd') {
            Write-Host "Error, AssignmentName missing or equal to 'TBD', skipping : $($Assignment.PolicyID)"
            continue
        }
        if ($AssignmentName -match 'pset-SCF-AUD-02-01-ResourceAuditLogs-\d+\.\d+\.\d+$') {
            Write-Host "Skipping SCF-AUD-02-01 by default: $($AssignmentName)"
            continue
        }
        #Processing Assignment  Data
        $ADOInitiativeName = $Assignment.ADOInitiativeFileName
        Write-Host ("`nStart Processing Assignment : $AssignmentName") -ForegroundColor DarkGreen    
        $distinctADOAssignmentNames = @($csvData | Where-Object { $_.'ADOAssignmentFileName' -ne '[OK]-No PA' -and $_.'Temp-AssignmentName' -eq $AssignmentName -and $_.'Batch' -eq $policyBatchdetail } | Select-Object 'ADOAssignmentFileName' -Unique)
        #Log the count of ADOPolicyFileName
        Write-Host "Total number of Assignments : $($distinctADOAssignmentNames)"      
        $ADOAssignmentName = $distinctADOAssignmentNames.ADOAssignmentFileName
        ### Loading Assignment File Content
        $assignmentFilePath = Join-Path -Path $policyAssignmentsFolder -ChildPath $ADOAssignmentName
        if (-not (Test-Path $assignmentFilePath -PathType Leaf)) {            
            Write-Host "Assignment file not found in policy assignment folder."
            $displayName = $csvData | Where-Object { $_.'ADOAssignmentFileName' -eq $ADOAssignmentName } | Select-Object 'Assignment-DisplayName' -Unique
            $description = $csvData | Where-Object { $_.'ADOAssignmentFileName' -eq $ADOAssignmentName } | Select-Object 'Assignment-Description' -Unique

            ## Create a new Assignment file
            $AssignmentContent = @{
                "name"       = "$AssignmentName"               
                "apiVersion" = "2021-06-01"               
                "type"       = "Microsoft.Authorization/policyAssignments"   
                "location"   = '${defaultLocation}'
                "identity"   = @{
                    "type" = "SystemAssigned"
                }
                properties   = @{
                    "displayName"           = "$($displayName.'Assignment-DisplayName')" 
                    "description"           = "$($description.'Assignment-Description')" 
                    "notScopes"             = @()                    
                    "metadata"              = @{                      
                    }          
                    policyDefinitionId      = ""
                    parameters              = @{}
                    "nonComplianceMessages" = @{
                        "message" = "Resources are not compliant to the policy definition."
                    }        
                    "scope"                 = '${current_scope_resource_id}'   
                    "enforcementMode"       = "Default"
                }
            }              
            $AssignmentContent | ConvertTo-Json -Depth 100 | Set-Content -Path $assignmentFilePath -Encoding UTF8 -NoNewline        
        }
        
        ## Load Assignment file present in the Assignment folder
        $AssignmentContent = Get-Content -Path $assignmentFilePath | ConvertFrom-Json
        if ($ADOInitiativeName -ne "OK-DirectAssignment") {
            $ADOInitiativeCount = 0
            Write-Host ("This $AssignmentName has Initiative file associated with it. Processing Initiative file.")
            $filePath = Join-Path -Path $policySetDefinitionsFolder -ChildPath $ADOInitiativeName
            $jsonInitiativeContent = Get-Content -Path $filePath  | ConvertFrom-Json      
               
            $jsonInitiativeContent.Properties.Parameters.PSObject.Properties | ForEach-Object {               
                $key = $_.Name
                $value = $_.Value 
                if (-not ($AssignmentContent.properties.parameters.PSObject.Properties.Name -contains $key)) {                
                    $AssignmentContent.properties.parameters | Add-Member -Type NoteProperty -Name $key -Value @{ value = $value.defaultValue }  
                }              
                $policyDefinitionId = '${root_scope_resource_id}/providers/Microsoft.Authorization/policySetDefinitions/' + $jsonInitiativeContent.name     
                $AssignmentContent.properties | Add-Member -Type NoteProperty -Name "policyDefinitionId" -Value $policyDefinitionId -Force
                $ADOInitiativeCount++                   
            }
            Write-Host "Total number of Initiatives added to the Assignment " -NoNewline
            Write-Host $ADOAssignmentName -NoNewline -ForegroundColor Green
            Write-Host " : $ADOInitiativeCount"
        }

        else {
            
            ##### Processing Custom Policies
            if ($Assignment.PolicyType -eq "Custom") {
                $customPolicyCount = 0
                Write-Host("Processing CUSTOM Policies") -ForegroundColor DarkMagenta
                $customName = "policy_definition_" + $Assignment.PolicyID + ".json"
                $customFilePath = Join-Path -Path $policyDefinitionsFolder -ChildPath $customName
                if (Test-Path $customFilePath -PathType Leaf) {
                    $jsonCustomContent = Get-Content -Path $customFilePath  | ConvertFrom-Json
                    $jsonCustomContent.Properties.Parameters.PSObject.Properties | ForEach-Object {               
                        $key = $_.Name
                        $value = $_.Value 
                        if (-not ($AssignmentContent.properties.parameters.PSObject.Properties.Name -contains $key)) {                
                            $AssignmentContent.properties.parameters | Add-Member -Type NoteProperty -Name $key -Value @{ value = $value.defaultValue }  
                        }              
                        $policyDefinitionId = '${root_scope_resource_id}/providers/Microsoft.Authorization/policyDefinitions/' + $jsonCustomContent.name     
                        $AssignmentContent.properties | Add-Member -Type NoteProperty -Name "policyDefinitionId" -Value $policyDefinitionId -Force                            
                    }
                    $customPolicyCount++
                    Write-Host("Completed adding CUSTOM Policies") -ForegroundColor DarkMagenta   
                    Write-Host "Total number of Custom Policy Definitions added to the Assignment " -NoNewline
                    Write-Host $ADOAssignmentName -NoNewline -ForegroundColor Green
                    Write-Host " : $customPolicyCount"                   
                }                 
                else {
                    Write-error "Custom policy file not found in policy definitions folder."
                }                             
            }           

            ##### Processing BUILTIN Policies
            else {
                $builtinPolicyCount = 0
                Write-Host("Processing BUILTIN Policies") -ForegroundColor DarkCyan
                $contentFromAzure = (Get-AzPolicyDefinition -ID $Assignment.PolicyID ).Properties.Parameters 
                $policyDefinitionReferenceIdBuiltin = ((Get-AzPolicyDefinition -ID $Assignment.PolicyID ).Properties.DisplayName -replace " ", "")                
                $contentFromAzure.PSObject.Properties | ForEach-Object {               
                    $parameterKey = $policyDefinitionReferenceIdBuiltin + $_.Name 
                    $value = $_.Value 
                    if (-not ($AssignmentContent.properties.parameters.PSObject.Properties.Name -contains $parameterKey)) {                
                        $AssignmentContent.properties.parameters | Add-Member -Type NoteProperty -Name $parameterKey -Value @{ value = $value.defaultValue }  
                    }              
                    $policyDefinitionId = $Assignment.PolicyID  
                    $AssignmentContent.properties | Add-Member -Type NoteProperty -Name "policyDefinitionId" -Value $policyDefinitionId -Force                            
                }
                $builtinPolicyCount++
                Write-Host("Completed adding BUILTIN Policies") -ForegroundColor DarkCyan  
                Write-Host "Total number of Builtin Policy Definitions added to the Assignment " -NoNewline
                Write-Host $ADOAssignmentName -NoNewline -ForegroundColor DarkCyan
                Write-Host " : $builtinPolicyCount"                 
            }            
        }        
        $AssignmentContent | ConvertTo-Json -Depth 100 | Set-Content -Path $assignmentFilePath -Encoding UTF8 -NoNewline    
    }
    catch {
        Write-Host "Error reading or processing JSON file: $_"
    }               
}
