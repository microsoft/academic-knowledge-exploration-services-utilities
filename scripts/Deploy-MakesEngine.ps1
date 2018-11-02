<#
*---------------------------------------------------------------------------------------------
*  Copyright (c) Microsoft Corporation. All rights reserved.
*  Licensed under the MIT License. See License.txt in the project root for license information.
*---------------------------------------------------------------------------------------------
.SYNOPSIS
Deploys a Microsoft Academic Knowledge Exploration Service (MAKES) engine to a target Azure Cloud Service

.DESCRIPTION
Enables deployment of a Microsoft Academic Knowledge Exploration Service (MAKES) engine to Azure. 

If the target cloud service does not exist it will be created and the MAKES engine deployed to the production slot.

If the target cloud service already exists and has a production deployment, the MAKES engine will be deployed
to the staging slot and then swapped with the production slot to ensure no service downtime.

.PARAMETER StorageAccountName
Blob storage account containing MAKES engine(s), e.g. makesascontoso

.PARAMETER DataVersion
Data version to deploy in YYYY-MM-DD format, e.g. '2018-10-12'

.PARAMETER EngineType
Engine type ('semantic' for semantic-interpretation-engine, 'entity' for entity-engine)

.PARAMETER InstanceType
Instance type ('small' for D3_v2/D4_v2, 'large' for E32_v3)

.PARAMETER ServiceName
Cloud service name to deploy the MAKES engine to, e.g. contoso-makes-entity

#>

[CmdletBinding()]
Param(
    [Parameter(
        Mandatory = $false,
        Position = 0)]
    [string]
    $StorageAccountName,
    
    [Parameter(
        Mandatory = $false,
        Position = 1)]
    [string]
    $ServiceName,
    
    [Parameter(
        Mandatory = $false,
        Position = 2)]
    [string]
    $DataVersion,
    
    [Parameter(
        Mandatory = $false,
        Position = 3)]
    [string]
    $EngineType,
    
    [Parameter(
        Mandatory = $false,
        Position = 4)]
    [string]
    $InstanceType
)

Function WaitForDeployment {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true, Position=0)]
        [string]$serviceNameToWaitFor, 
        [Parameter(Mandatory=$true, Position=1)]
        [string]$deploymentSlot)
    
    # Check if deployment succeeded
    Write-Host "Waiting for deployment to come online (this could take 1+ hours depending on configuration)" -NoNewline
    do {
        $checkDeployment = Get-AzureDeployment -ServiceName $serviceNameToWaitFor -Slot $deploymentSlot -ErrorAction silentlycontinue
        $allOnline = $true
        for ($i = 0; $i -lt $checkDeployment.RoleInstanceList.Count; $i++) {
            if($checkDeployment.RoleInstanceList[$i].InstanceStatus -ne "ReadyRole") {
                $allOnline = $false
            }
        }
        Write-Host "." -NoNewline
        Start-Sleep -Seconds 30
    } while ($allOnline -eq $false)
    
    Write-Host
}

Function OutputSectionHeader {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true, Position=0)]
        [string]$message)

    Write-Host
    Write-Host "########################################"
    Write-Host $message
    Write-Host
}

# Ask user for storage account
if (!$StorageAccountName) { 
    Write-Host
    Write-Host "Blob storage account containing MAKES engine(s), e.g. makesascontoso" 
    $StorageAccountName = Read-Host
} 

if (!$DataVersion) { 
    Write-Host
    Write-Host "Data version to deploy in YYYY-MM-DD format, e.g. '2018-10-12'"
    $DataVersion = Read-Host 
} 

if (!$EngineType) { 
    Write-Host
    Write-Host "Engine type ('semantic' for semantic-interpretation-engine, 'entity' for entity-engine)"
    $EngineType = Read-Host 
}

switch ($EngineType) {
    'semantic' {
        $EngineType = "semantic-interpretation-engine"
    }
    'entity' {
        $EngineType = "entity-engine"
    }
    Default {
        Write-Error "Engine type must be either 'semantic' or 'entity'"
        Exit 1
    }
}

if (!$InstanceType) { 
    Write-Host
    Write-Host "Instance type ('small' for D3_v2/D4_v2, 'large' for E32_v3)"
    $InstanceType = Read-Host 
}

switch ($InstanceType) {
    'small' {
        if ($EngineType -eq 'semantic-interpretation-engine') {
            $InstanceType = "D4_v2"
        }
        else {
            $InstanceType = "D3_v2"
        }
    }
    'large' {
        $InstanceType = "E32_v3"
    }
    Default {
        Write-Error "Instance type must be either 'small' or 'large'"
        Exit 1
    }
}

if (!$ServiceName) { 
    Write-Host
    Write-Host "Cloud service name to deploy the MAKES engine to, e.g. contoso-makes-entity" 
    $ServiceName = Read-Host
} 

try {
    OutputSectionHeader "Verifying Azure account..."
    $azureAccount = Get-AzureAccount -ErrorAction Stop    
}
catch {
    Add-AzureAccount
    $azureAccount = Get-AzureAccount    
}

try {
    OutputSectionHeader "Verifying storage account..."
    # Verify storage account exists
    $storageAccount = Get-AzureStorageAccount -StorageAccountName $StorageAccountName -ErrorAction Stop
    $storageCredentials = Get-AzureStorageKey $StorageAccountName -ErrorAction Stop
}
catch {
    Write-Error "Storage account not found"
    Exit 1
}

$storageContext = New-AzureStorageContext -StorageAccountName $storageCredentials.StorageAccountName -StorageAccountKey $storageCredentials.Primary

try {
    # Verify desired data version / engine exists
    $targetEngineConfig = Get-AzureStorageBlob -Blob "$DataVersion/$EngineType/configuration.cscfg" -Container "makes" -Context $storageContext -ErrorAction Stop
    $targetEnginePackage = Get-AzureStorageBlob -Blob "$DataVersion/$EngineType/package-$InstanceType.cspkg" -Container "makes" -Context $storageContext -ErrorAction Stop

    # Download configuration file
    OutputSectionHeader "Configuring MAKES..."
    $random = Get-Random
    $localConfigFile = "$EngineType-configuration-$random.cscfg"
    Get-AzureStorageBlobContent -Blob $targetEngineConfig.ICloudBlob.Name -Container $targetEngineConfig.ICloudBlob.Container.Name -Context $storageContext -Destination $localConfigFile -Force | Out-Null

    (Get-Content ".\$localConfigFile").Replace("_STORAGE_ACCOUNT_NAME_", $StorageAccountName).Replace("_STORAGE_ACCOUNT_ACCESS_KEY_", $storageCredentials.Primary) | Set-Content ".\$localConfigFile"
}
catch [Microsoft.WindowsAzure.Commands.Storage.Common.ResourceNotFoundException] {
    # Add logic here to remember that the blob doesn't exist...
    Write-Error "Engine files not found for data version $DataVersion"
    Exit 1
}

try {

    # Check if cloud service exists
    $service = Get-AzureService -ServiceName $ServiceName -ErrorAction Stop
}
catch [Microsoft.WindowsAzure.Commands.Common.ComputeCloudException] {
    
    try {

        # Need to create the cloud service
        OutputSectionHeader "Service does not exist, attempting to create..."
        $service = New-AzureService -ServiceName $ServiceName -Location $storageAccount.Location -ErrorAction Stop
        
    }
    catch {
        Write-Error "Unable to create new service"
        Exit 1
    }
}

# Check if service name already exists
$deployment = Get-AzureDeployment -ServiceName $ServiceName -Slot "Production" -ErrorAction silentlycontinue

if ($deployment.Name -eq $null) {
    # Do a new deployment
    OutputSectionHeader "Creating new deployment..."

    $deployment = New-AzureDeployment -ServiceName $ServiceName -Slot "Production" -Package $targetEnginePackage.ICloudBlob.Uri.AbsoluteUri -Configuration "$PSScriptRoot\$localConfigFile"

    # Wait for deployment to come online
    WaitForDeployment $ServiceName "Production"
}
else {
    # Do an update deployment
    OutputSectionHeader "Updating current deployment..."    

    # Deploy to staging slot
    Write-Host "Deploying to staging slot..."
    $deployment = New-AzureDeployment -ServiceName $ServiceName -Slot "Staging" -Package $targetEnginePackage.ICloudBlob.Uri.AbsoluteUri -Configuration "$PSScriptRoot\$localConfigFile"

    # Wait for deployment to come online
    WaitForDeployment $ServiceName "Staging"

    # Swap staging/production slot
    Write-Host "Swapping staging with production slot..."
    $swapStatus = Move-AzureDeployment -ServiceName $ServiceName

    # Delete staging slot
    Write-Host "Deleting staging slot..."
    Remove-AzureDeployment -ServiceName $ServiceName -Slot "Staging" -Force -DeleteVHD | Out-Null
}

# Clean up temporary files
Remove-Item "$PSScriptRoot\$localConfigFile" | Out-Null

Write-Host
Write-Host "Engine is now online and can be accessed at http://$ServiceName.cloudapp.net/test.html"
Exit 0