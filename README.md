# Azure Technical Academy - Hybrid IT Day 2: automation

## Prerequisities
- All day1 labs completed and knowledge of all topics covered
- Homework from day1 completed and shared with instructors via private message on Teams
- Access to own Azure subscription as Owner (access to single Resource Group is not enough for this lab)
- Rights to create Service Principal in AAD or precreated Service Principal with credentials
- Sufficient quota in subscription
  - 10 or more total vCPUs in region West Europe
  - 10 or more B-series VM vCPUs in region West Europe
- Precreated Azure DevOps organization with full rights for purpose of this Lab, instructions in [documentation](https://docs.microsoft.com/en-us/azure/devops/organizations/accounts/create-organization?view=azure-devops)

## Learn ARM template basics - parameters, variables, resources, copy loop, uniquestring, resourceId, reference, outputs
First let's learn some ARM template basics. Jump to arm-tutorial folder.

Deploy simple template to create Public IP.

```powershell
az group create -n arm-testing -l westeurope
az group deployment create -g arm-testing --template-file 01.json
```

Deploy template that has different name for IP.
```powershell
az group deployment create -g arm-testing --template-file 02.json
```

Notice new object has been added, but previous one is still there. Default ARM mode is Incremental (not pure desired state) to prevent beginners accidentaly destroy things, just adding or changing (if property can be changed without recreation). With Complete mode ARM will make actual state to reflect desired state in template, so if there are resources in reality that are not described in template, those will be deleted.

```powershell
az group deployment create -g arm-testing --template-file 02.json --mode Complete
```

Avoid repeating values by using variables. Eg. do not hardcode location with every resource. Rather make it variable and reference it. It is than easier to change your template.

```powershell
az group deployment create -g arm-testing --template-file 03.json --mode Complete
```

ARM provides couple of functions. Most of the time you will want location of your resources to be the same as location for your Resource Group (even it is not mandatory). We can get location of Resource Group during runtime via function call.

```powershell
az group deployment create -g arm-testing --template-file 04.json --mode Complete
```

ARM template should be universal so you do not change it when deploying to different environments. Let's make IP name prefix to be parameter and also take environment name as parameter with fixed allowed values. We will use concat string function to build actual IP name.

```powershell
az group deployment create -g arm-testing --template-file 05.json --mode Complete
```

Notice CLI has asked for required parameters (if you do not require parameter use defaultValue). You can also specify this via CLI and it does not have to be complete set (CLI will ask for missing pieces).

```powershell
az group deployment create -g arm-testing `
    --template-file 05.json `
    --mode Complete `
    --parameters ipNamePrefix=myip
```

You can also provide values in JSON file (but still can override some with --parameters).

```powershell
az group deployment create -g arm-testing `
    --template-file 05.json `
    --mode Complete `
    --parameters "@05.parameters.json"
```

Sometimes you need to deploy resources to more resource groups or even subscriptions with single template. This can be achieved using nested or linked templates. One (master) template can execute different template either writen inline (nested) or via URL (linked) and do that within context of specific resource group and subscription.
```powershell
az group create -n arm-testing-secondary -l westeurope
az group deployment create -g arm-testing `
    --template-file 06.json `
    --mode Complete `
    --parameters "@06.parameters.json" `
    --parameters secondaryResourceGroupName=arm-testing-secondary
```

Some resources such as storage account require globaly unique names. ARM template should not generate random values as it is not idempotent (you should be able to run template any number of times and always get the same results). To generate some string in a way that it is very likely to be unique yet stable for deployment use uniqueString function (hash) with some input on which you generate that hash (eg. full resource group ID, which includes subscription ID and resource group name).

```powershell
az group deployment create -g arm-testing `
    --template-file 07.json `
    --mode Complete `
    --parameters "@07.parameters.json" `
    --parameters secondaryResourceGroupName=arm-testing-secondary
```

ARM creates all resources in parallel by default. If there are dependencies between resources, we need to declare those. Eg. we can create Blob storage container, but for that storage account needs to exist first. Container is subresource and can be specified under resource:[] in main resource or separately where name consist of parentresource/childresources. To declare dependecy we will use dependsOn. You can use simple resource name (if there is no conflict), but best practice is always to use full resource ID. To get that during runtime let's use resourceId function (note resourceId by default search current resource group, but can be extended to look into specified resource group or even different subscription).

```powershell
az group deployment create -g arm-testing `
    --template-file 08.json `
    --mode Complete `
    --parameters "@08.parameters.json" `
    --parameters secondaryResourceGroupName=arm-testing-secondary
```

Most of the time you will be deploying resource using Resource Group scope, but there are objects, that are on Subscription level. Example is Resource Group object (belongs to subscription, not resource group), subscription-level RBAC, subscription-level policies such as Security Center etc. Subscription-scoped ARM templates can create Resource Groups and use different API (and CLI command). Let's create two new resource groups via template.

```powershell
az deployment create -l westeurope `
    --template-file subscriptionLevel.json
```

Finally let's use nested templates to orchestrate complete deployment process. Note in practical life with more complex templates you will use rather linked templates (store individual templates in storage account or Git repository) to make master JSON smaller, more readable and included templates more reusable.
```powershell
az deployment create -l westeurope `
    --template-file solution.json `
    --parameters "@solution.parameters.json"
```

We have learned basic ARM template structures. Delete environment and let's start deploying some real scenarios.
```powershell
az group delete -y --no-wait -n arm-testing
az group delete -y --no-wait -n arm-testing-secondary
az group delete -y --no-wait -n arm-newtesting
az group delete -y --no-wait -n arm-newtesting-secondary
```



## Provision Azure SQL via GUI

## Create ARM template for Azure SQL

## Leverage Azure Key Vault to manage and store deployment secrets

## Create ARM template for networking

## Create ARM template for shared monitoring environment and Azure Backup

## Learn how to use and upgrade Virtual Machine Scale Set on Linux with VM extensions

## Create ARM template for Linux-based VMSS with custom script extension

## Create ARM template for Windows-based VMSS with PowerShell DSC automation

## Create Master ARM template to include complete solution

## Use Azure DevOps Repos to store and maintain ARM templates

## Use Azure DevOps Pipelines to orchestrate desired state infrastructure lifecycle (part of CI/CD strategy)

## Automation and governance with Azure Bluprints
Consider following scenario. We have created hub subcription with centralized components such as Azure Firewall, Azure VPN and Domain Controller. Application projects are deployed in spoke subscriptions that allow connectivity via hub network. Suppose for certain types of projects we have following governance needs:
- Deploy VNET for project and automatically configure VNET peering with hub subscription.
- Allow networking team access to VNET configurations, but do not let application operators touch it.
- Limit application operators so they cannot bypass routing rules, create their own VNETs or Public IP, but allow them to manage internal networking resources such as internal Load Balancer or NSGs for microsegmentation. They should also be able to manage all other resource on level similar to Contributor such as deploying VMs, PaaS services and creatng Resource Groups.
- Due policy regulations make sure resources can be created only in regions West Europe and North Europe, but not others (especialy those not within EU).

We will use ARM templates to deploy basic resources, Azure Policy and RBAC with custom role to fullfil this need and automate as much as we can so new subscriptions follow our rules. We will use Azure Bluprints to combine those and and enroll subscription.

For demo purposes we will use single subscription (the same we use for whole lab). For preparation create following AAD objects:
- User netguy and Security Group netOps with netguy as member
- User project1guy and Security Group project1 with project1guy as member

To simulate hub subscription create resource group hub with VNET.
```bash
az group create -n hub -l westeurope
az network vnet create -n hub-net \
    -g hub  \
    --address-prefix 10.0.0.0/24 \
    --subnet-name sub \
    --subnet-prefix 10.0.0.0/24
```

For deployment of base resources we will use ARM template to deploy VNET with subnet, route table forcing all traffic leaving VNET to go via firewall in hub network and configure peering on both sides. Note that for deployment to different subscription/resourcegroup we will use nested template. See template in [blueprints folder](blueprints/deployspoke.json). **Make sure you modify hubVnetId and hubSubscriptionId based on your environment!**

Go to Azure Bluprints and create blueprint definition. Add Resource Group named network (name fixed) and copy contents of ARM template as Azure Resource Manager artefact. Make sure Parameters are to be filled during Blueprint assignment.

Store and publish bluprint as **version 1**. Assign bluprint to your subscription (configure parameters as project1 for VNET name and 10.0.1.0/24 for ip range) and make sure networking resources are created and VNET peering is connected.

Now we will add rights for networking team to resource group network. Edit Bluprint and add artefact under resource group of type Role Assignment. Select netOps as Contributor and make it fixed parameter. Save and publish this blueprint as **version 2**. Go to Blueprint assignments and Update to version 2. After deployment is done go to network Resource Group -> Access Control (IAM) and check netOps group is assigned. Open anonymous window and connect as netguy to make sure you see only one resource group with networking.

Next we want application users to be able to do pretty much everything except for bypassing our routing, modify VNETs, create new ones or create VPN or Public IP. For this we will create custom RBAC role. Blueprint Role Assignment currently does not support custom role so we will have to solve assignments also via ARM template. Careful - **input parameter will be AAD Security Group Object ID**, not name (you will find in AAD)!

Study template [here](blueprints/limitedContributorRole.json). Modify blueprint and add this template as Artefact on Subscription level. Publish as **version 3** and update your assignment. In anonymous window connect to Azure as project1guy and make sure it meets our expectations:
- user **cannot** modify routing table in network resource group
- user **cannot** create VNET or Public IP
- user **can** create Network Interface Card (to deploy VM)
- user **can** create additional resources such as new Resource Group

For compliance reasons we want to limit resources to be deployed only in West Europe and North Europe. Modify blueprint and add Azure Policy artefact on subscription level. Find Allowed Locations built-in policy and set fixed parameter to West Europe and North Europe only. Save blueprint and publish as **version 4**. After deployment connect as project1guy and create storage account in West Europe and East US. Deployment in East US should fail.

## Automate and publish corporate golden images with Shared Image Gallery and Image Builder

## Package you ARM template and publish in Azure Service Catalog as Managed Application (internal SaaS-style)

## Contacts

### Tomas Kubica - Azure TSP at Microsoft
- https://www.linkedin.com/in/tkubica
- https://github.com/tkubica12
- https://twitter.com/tkubica

### Jaroslav Jindrich - Cloud Solutions Architect
- https://www.linkedin.com/in/jjindrich
- https://github.com/jjindrich
- https://twitter.com/jjindrich_cz
