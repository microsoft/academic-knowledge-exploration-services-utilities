---
title: Deploy Microsoft Academic Knolwedge Exploration Services Engine
description: Powershell script for deploying Microsoft Academic Knowledge Exploration Service (MAKES) engines to Azure Cloud Services
date: 11/2/2018
---

# Deploy-MakesEngine

Deploys a Microsoft Academic Knowledge Exploration Service (MAKES) engine to a target Azure Cloud Service.

## Description

The Deploy-Makes-Engine cmdlet deploys a MAKES engine to a target Azure Cloud Service.

If the target cloud service does not exist it will be created and the MAKES engine deployed to the production slot.

If the target cloud service already exists and has a production deployment, the MAKES engine will be deployed to the staging slot and then swapped with the production slot to ensure no service downtime.

## Examples

### Example 1: Deploy semantic interpretation engine to large cloud service instance

This command would deploy the 2018-10-12 version of the MAKES semantic interpretation engine to the cloud service "contoso-makes-semantic" with a E32_v3 instance.

```powershell
Deploy-MakesEngine.ps1 -StorageAccountName makesascontoso -DataVersion 2018-10-12 -EngineType semantic -InstanceType large -Ser
viceName contoso-makes-semantic
```

### Example 2: Deploy entity engine to small cloud service instance

This command would deploy the 2018-10-12 version of the MAKES entity engine to the cloud service "contoso-makes-entity" with a D3_v2 instance.

```powershell
Deploy-MakesEngine.ps1 -StorageAccountName makesascontoso -DataVersion 2018-10-05 -EngineType entity -InstanceType small -Ser
viceName contoso-makes-entity
```

## Required Parameters

### -StorageAccountName
Blob storage account containing MAKES engine(s), e.g. makesascontoso

### -DataVersion
Data version to deploy in YYYY-MM-DD format, e.g. '2018-10-12'

### -EngineType
MAKES engine type ('semantic' for semantic-interpretation-engine, 'entity' for entity-engine)

### -InstanceType
Instance type ('small' for D3_v2/D4_v2, 'large' for E32_v3)

### -ServiceName
Cloud service name to deploy the MAKES engine to, e.g. contoso-makes-entity

## Contributing

This project welcomes contributions and suggestions.  Most contributions require you to agree to a
Contributor License Agreement (CLA) declaring that you have the right to, and actually do, grant us
the rights to use your contribution. For details, visit https://cla.microsoft.com.

When you submit a pull request, a CLA-bot will automatically determine whether you need to provide
a CLA and decorate the PR appropriately (e.g., label, comment). Simply follow the instructions
provided by the bot. You will only need to do this once across all repos using our CLA.

This project has adopted the [Microsoft Open Source Code of Conduct](https://opensource.microsoft.com/codeofconduct/).
For more information see the [Code of Conduct FAQ](https://opensource.microsoft.com/codeofconduct/faq/) or
contact [opencode@microsoft.com](mailto:opencode@microsoft.com) with any additional questions or comments.
