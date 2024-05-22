<#
.SYNOPSIS
This script created Policy Set definition files with the policy definition files and data in the metadata.csv according to the BATCH details.
This metadata.csv contains the Policy Set Definitions name , Policy Definition name and Policy Assignment names, it contains the corresponding mapping.
 
.DESCRIPTION
This script updated the Policy Set definition files in the Policy Set Definition folder.
 
.EXAMPLE
  1. Create the metadata.csv file
  2. Copy this script to root folder REPO that contains the PolicySetDefinitions (policy_set_definitions) , PolicyDefinitions (policy_definitions) folders
  3. Run the script, for corresponding BATCH deployment
  4. Validate updated files in the Policy Set Definition folder
  #>

# Import CSV file
$csvData = Import-Csv -Path 'metadata.csv' -Encoding UTF8

# Write log to display total row count
Write-Host "Total row count in csvData: $($csvData.count)"

# Path for policy definitions and input details for BATCH deployment
$policyDefinitionsFolder = "./policy_definitions/"
$policySetDefinitionsFolder = "./policy_set_definitions/"

# Batch details for the policies
$batchName = Read-Host "Enter the Batch Name to process the policies"
if ([string]::IsNullOrEmpty($batchName)) {
    Write-Error "Batch Name cannot be empty. Exiting script."
    exit
}
Write-Host "Processing Batch Name: $batchName"

# Enter which type of policy to process
$typeOfPolicy = Read-Host "Enter 'Custom', 'Builtin' or 'All' to process the respective policies"
$typeOfPolicy = $typeOfPolicy.ToLower()
if ($typeOfPolicy -notin @('custom', 'builtin', 'all')) {
    Write-Error "Invalid input. Please enter either 'Custom', 'Builtin' or 'All' for the automation to work. Exiting script."
    exit
}
Write-Host "Processing $typeOfPolicy policies"

# First, ensure 'ADOInitiativeFileName' entries are distinct and not null, "OK-DirectAssignment", "Blank"
$distinctInitiatives = @($csvData |
    Where-Object { $_.'ADOInitiativeFileName' -notin @("[OK]-Direct assignment", " ", "#VALUE!") -and $_.'Batch' -eq $batchName } | Select-Object 'ADOInitiativeFileName' -Unique) | Sort-Object -Property 'ADOInitiativeFileName'
Write-Host "Total number of Distinct ADOInitiativeFileName: $($distinctInitiatives.count)"

Write-Host "----------------------------------------"
Write-Host "----------------------------------------"

foreach ($initiative in $distinctInitiatives) {
    try {
        # continue if initiative file is not defined
        if (-not $initiative.ADOInitiativeFileName) {
            Write-Host "Error, ADOInitiativeFileName missing, skipping!"
            continue
        }
        # skipping initiative as it's not supported at this moment
        if ($initiative.ADOInitiativeFileName -match 'policy_set_definition_SCF-AUD-02-01-\d+\.\d+\.\d+.json$') {
            Write-Host "Skipping by default: $($initiative.ADOInitiativeFileName)"
            continue
        }
        $initiativeName = $initiative.ADOInitiativeFileName
        
        # Processing Initiative Data
        Write-Host ("Start Processing Initiative : $initiativeName")
    
        # Log the count of CUSTOM ADOPolicyFileName
        $distinctADOCustomPolicyFileNames = $csvData | Where-Object { $_.'Batch' -eq $batchName -and $_.'ADOPolicyFileName' -ne "N/A" -and $_.'ADOInitiativeFileName' -eq $initiativeName } | Select-Object 'ADOPolicyFileName' -Unique
        if ($null -eq $distinctADOCustomPolicyFileNames.count -or $distinctADOCustomPolicyFileNames.count -eq 0) {
            Write-Host "No distinct custom policy file names found. Exiting script."
        }        
        Write-Host "Total number of Distinct Custom Policies : $($distinctADOCustomPolicyFileNames.count)"

        # Log the count of BUILTIN ADOPolicyFileName
        $distinctBuiltinPolicyFileNames = $csvData | Where-Object { $_.'Batch' -eq $batchName -and $_.'ADOPolicyFileName' -eq "N/A" -and $_.'ADOInitiativeFileName' -eq $initiativeName } | Select-Object 'PolicyID' -Unique
        if ($null -eq $distinctBuiltinPolicyFileNames.count -or $distinctBuiltinPolicyFileNames.count -eq 0) {
            Write-Host "No distinct BUILTIN policy file names found. Exiting script."
        }  
        Write-Host "Total number of Distinct BUILT-IN Policies: $($distinctBuiltinPolicyFileNames.count)"
        Write-Host "----------------------------------------"

        # Loading Initiative File Content
        $initiativeFilePath = Join-Path -Path $policySetDefinitionsFolder -ChildPath $initiativeName
        if (-not (Test-Path $initiativeFilePath -PathType Leaf)) {            
            Write-Host "Initiative file not found in policy set definitions folder."
            $displayName = $csvData | Where-Object { $_.'ADOInitiativeFileName' -eq $initiativeName } | Select-Object 'ADOInitiativeDisplayName' -Unique
            $description = $csvData | Where-Object { $_.'ADOInitiativeFileName' -eq $initiativeName } | Select-Object 'ADOInitiativeDescription' -Unique
            $initiativeInnerName = $csvData | Where-Object { $_.'ADOInitiativeFileName' -eq $initiativeName } | Select-Object 'PolicySet-Name' -Unique
            # Create a new initiative file
            $initiativeContent = @{
                "name"       = "$($initiativeInnerName.ADOInitiativeName)"
                "apiVersion" = "2021-06-01"
                "scope"      = "null"  
                "type"       = "Microsoft.Authorization/policySetDefinitions"        
                properties   = @{
                    "policyType"             = "Custom"  
                    "displayName"            = "$($displayName.'PolicySet-DisplayName')"   
                    "description"            = "$($description.'Assignment-Description')" 
                    "metadata"               = @{
                        "source"               = "https://github.com/Azure/Enterprise-Scale/"
                        "category"             = "SCF"
                        "ASC"                  = "true"
                        "version"              = "1.0.0"   
                        "alzCloudEnvironments" = @(
                            "AzureCloud")                
                    }          
                    policyDefinitions        = @()
                    parameters               = @{}
                    "policyDefinitionGroups" = "null"            
                }
            } 
            $initiativeContent | ConvertTo-Json -Depth 100 | Set-Content -Path $initiativeFilePath -Encoding UTF8 -NoNewline
            $initiativeContent.properties.parameters = $initiativeContent.properties.parameters | ConvertTo-Json -Depth 100 -Compress | ForEach-Object {
                $_ -replace '"value": "{}",'
            } | ConvertFrom-Json
        }
        else {
            $initiativeContent = Get-Content -Path $initiativeFilePath | ConvertFrom-Json
        }
    
        # Process Custom Policies
        switch ($typeOfPolicy) {
            {($_ -eq "custom") -or ($_ -eq "all")} {
                $addedCustomPolicyCount = 0
                foreach ($customPolicy in $distinctADOCustomPolicyFileNames) {  
                    
                    $customPolicyName = $customPolicy.ADOPolicyFileName 
                    Write-Host ("Processing Custom Policy : $customPolicyName" )
        
                    # Forming the Policy SET and Policy Set Parameters
                    $policySetIDName = $customPolicyName -replace "policy_definition_", "" -replace '-\d+.\d+.\d+$', '' -replace "Custom-", "" -replace ".json", ""
        
                    if (-not $customPolicyName.StartsWith('policy_definition_')) {
                        $customPolicyName = "policy_definition_$customPolicyName"
                    }
                    if (-not $customPolicyName.EndsWith('.json')) {
                        $customPolicyName = "$customPolicyName.json"
                    }

                    # Construct the file path using the ADOPolicyFileName field
                    $filePath = Join-Path -Path $policyDefinitionsFolder -ChildPath $customPolicyName
        
                    # Test if the path exists
                    if (Test-Path $filePath -PathType Leaf) {
             
                        # Read the contents of the Custom Policy JSON file
                        $jsonCustomContent = Get-Content -Path $filePath | ConvertFrom-Json
        
                        # Forming the Policy SET structure
                        # Check if the mergedSetPolicyDict already exists in the initiativeContent
                        $existingPolicy = $initiativeContent.properties.policyDefinitions | Where-Object { $_.policyDefinitionReferenceId -eq $policySetIDName }
                        if ($null -eq $existingPolicy) {
                            $mergedSetPolicyDict = @{
                                policyDefinitionReferenceId = $policySetIDName
                                policyDefinitionId          = '${root_scope_resource_id}/providers/Microsoft.Authorization/policyDefinitions/' + $jsonCustomContent.name
                                parameters                  = New-Object PSObject -Property @{}
                                groupNames                  = @() 
                            }
                    
                            # Forming the Policy SET Parameters structure and updating the Parameters in the Policy SET 
                            $jsonCustomContent.properties.parameters.PSObject.Properties | ForEach-Object {
                                $key = $_.Name
                                $keyLocal = $_.Name
                                if ($_.Name.ToString().ToLower() -eq 'effect') {
                                    $keyPart = "Effect"
                                    $keyLocal = "$policySetIDName$keyPart"
                                }
                                $value = $_.Value
                                $mergedSetPolicyDict.parameters | Add-Member -Type NoteProperty -Name $key -Value @{ value = "[parameters('$($keyLocal)')]" }
                                if ($null -eq $initiativeContent.properties.parameters.PSObject.Properties[$key]) {
                                    $initiativeContent.properties.parameters | Add-Member -Type NoteProperty -Name $keyLocal -Value $value
                                }
                                else {
                                    $initiativeContent.properties.parameters.$key = $value
                                }
                            }
                    
                            $initiativeContent.properties.policyDefinitions += $mergedSetPolicyDict
                            $addedCustomPolicyCount++
                        }
                        else {
                            Write-Host ("Policy Definition Reference ID $policySetIDName already exists in the Initiative")
                        }            
                    }
                    else {
                        Write-Error ("The file path $filePath doesn't exist")
                    }
            
                }   
                Write-Host "Total number of newly added Custom Policies added to the Initiative " -NoNewline
                Write-Host $initiativeName -NoNewline -ForegroundColor Green
                Write-Host " : $addedCustomPolicyCount"
                Write-Host "----------------------------------------"
            }

            # Process Built-IN  Policies
            {($_ -eq "builtin") -or ($_ -eq "all")} {
                $addedBuiltinPolicyCount = 0                
                foreach ($builtinPolicy in $distinctBuiltinPolicyFileNames) {  
                    $builtinPolicyName = $builtinPolicy.PolicyID
                    if ($builtinPolicyName -eq "N/A") {
                        Write-Host ("Error: missing BUILT-IN PolicyID, skipping : $builtinPolicyName" )
                        continue
                    }
                    Write-Host ("Processing BUILT-IN Policy : $builtinPolicyName" )
        
                    $policyDefinitionReferenceIdBuiltin = ((Get-AzPolicyDefinition -ID $builtinPolicyName -WarningAction SilentlyContinue).Properties.DisplayName -replace " ", "")
                    Write-Host ($policyDefinitionReferenceIdBuiltin)
                
                    $existingPolicyBuiltin = $initiativeContent.properties.policyDefinitions | Where-Object { $_.policyDefinitionReferenceId -eq $policyDefinitionReferenceIdBuiltin }
                    if ($null -eq $existingPolicyBuiltin) {
                        $mergedSetPolicyDictbuiltin = @{
                            policyDefinitionReferenceId = $policyDefinitionReferenceIdBuiltin
                            policyDefinitionId          = $builtinPolicyName
                            parameters                  = New-Object PSObject -Property @{}
                            groupNames                  = @()
                        }
                
                        $contentFromAzure = (Get-AzPolicyDefinition -ID $builtinPolicyName -WarningAction SilentlyContinue).Properties.Parameters 
                        $contentFromAzure.PSObject.Properties | ForEach-Object {
                            $key = $_.Name
                            $parameterKey = $policyDefinitionReferenceIdBuiltin + $_.Name
                            $value = $_.Value
                            $mergedSetPolicyDictbuiltin.parameters | Add-Member -Type NoteProperty -Name $key -Value @{ value = "[parameters('$($parameterKey)')]" }
                            if ($null -eq $initiativeContent.properties.parameters.PSObject.Properties[$key]) {
                                $initiativeContent.properties.parameters | Add-Member -Type NoteProperty -Name $parameterKey -Value $value
                            }
                            else {
                                $initiativeContent.properties.parameters.$key = $value
                            }
                        }            
                        $initiativeContent.properties.policyDefinitions += $mergedSetPolicyDictbuiltin
                        $addedBuiltinPolicyCount++
                    }
                    else {
                        Write-Host ("Policy Definition Reference ID $policyDefinitionReferenceIdBuiltin already exists in the Initiative")
                    }       
                }
                Write-Host "Total number of newly added BUILTIN Policies added to the Initiative " -NoNewline
                Write-Host $initiativeName -NoNewline -ForegroundColor Green
                Write-Host " : $addedBuiltinPolicyCount"
                Write-Host "----------------------------------------"
            }
            default {
                Write-Host "Invalid input. Please enter 'Custom' or 'Builtin'."
            }
        }

        # Write the updated Initiative JSON content back to the file
        $initiativeContent | ConvertTo-Json -Depth 100 | Set-Content -Path $initiativeFilePath -Encoding UTF8 -NoNewline
    }
    catch {
        Write-Host "Error reading or processing JSON file: $_"
    }               
}
