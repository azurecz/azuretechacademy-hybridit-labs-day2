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

## ARM template basics
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
There are multiple ways to get JSON snipplets to create your templates.

Check [Azure Quickstart Templates](https://github.com/Azure/AzureStack-QuickStart-Templates)

Check [ARM reference guide](https://docs.microsoft.com/en-us/azure/templates/)

Another approach is to create resources using GUI and check results using one of following three approaches. Use GUI to create SQL DB and SQL virtual server in Basic tier and stop on last step of GUI wizard.

* Fill in required details and click Download a template for automation. This is ideal to get well formatted intitial resource template.
* After deployment you can export template - go to Export template section of your Resource Group. Note that this exports a lot of default settings so template can be noisier than needed. Also note export does not expose fields that contain sensitive data (passwords), but those are mandatory to use during provisioning.
* You can also use Resource explorer (find it under All services). This is great for finding details on how Azure operates and get right structures without any parameters. But note, that this is runtime view and includes keys, that are not used when creating ARM templates (etag, id, deploymentState etc.). Also note export does not expose fields that contain sensitive data (passwords), but those are mandatory to use during provisioning.

## Create ARM template for Azure SQL
Go to arm-labs folder. There is template sql.json. Let's deploy it, but expect few issues we will solve as we go.

```powershell
az group create -n cp-sql -l westeurope
az group deployment create -g cp-sql `
    --template-file sql.json `
    --parameters "@sql.parameters.json"
```
There are few issues we need to fix:
* Deployment fails. Use az group deployment validate to get details what is wrong on syntax level and fix the problem.
* Validation is fine, but deployment fails. Investigate what is wrong. Hint: you will use uniqueString function as part of the solution.
* Location is hardcoded. Make it variable and use function to automatically get location of Resource Group template is being deployed to.
* DB login name is hardcoded. Make it parameter.

We will now use more secure way to pass database password. You should not put secrets into template. Storing in parameters file can be OK if this file is kept separately (and more securely). Specifying during deployment time requires person deploying to know password, but that can be fixed by automated deployment and secrets management in CI/CD tool like Azure DevOps. Most secure mechanism is to use Azure KeyVault and referencing stored secret during deployment while account with rights to deploy template does not need rights to manage secrets.

First create KeyVault and add password to it as secret.

```powershell
# Create Key Vault and store secret
az group create -n cp-deployment-artifacts -l westeurope
$keyVaultName = "cpuniquevaultname123"
az keyvault create  `
    -n $keyVaultName `
    -g cp-deployment-artifacts `
     --enabled-for-template-deployment
az keyvault secret set -n cpSqlPassword `
    --vault-name $keyVaultName `
    --value Azure12345678

# Get Key Vault ID
az keyvault show -n $keyVaultName `
    -g cp-deployment-artifacts `
    --query id `
    -o tsv
```

Modify your template parameters file to include reference to KeyVault secret.
```json
"dbPassword": {
    "reference": {
        "keyVault": {
        "id": "/subscriptions/mysubscriptionid/resourceGroups/arm-deployment-artifacts/providers/Microsoft.KeyVault/vaults/cpuniquevaultname123"
        },
        "secretName": "cpSqlPassword"
    }
}
```

Redeploy template using secrets in Key Vault.

## Create ARM templates for networking
First let's create hub network with jump subnet and NSG, GatewaySubnet (this is where VPN can be deployed) and AD DC subnet and NSG.

```powershell
az group create -n cp-hub-networking -l westeurope
az group deployment create -g cp-hub-networking `
    --template-file networkingHub.json
```

For spoke networks we will create universal template that we can reuse whenever we need the same spoke environment with web subnet. Also note that we enable Microsoft.Sql Service Endpoint capability on web subnet, so we can later on allow access from this subnet to Azure SQL without exposing it to Internet.

```powershell
az group create -n cp-spoke1-networking -l westeurope
az group deployment create -g cp-spoke1-networking `
    --template-file networkingSpoke.json `
    --parameters ipRange="10.1.0.0/16" `
    --parameters webSubnetRange="10.1.0.0/24" `
    --parameters vnetName=cp-spoke1-net
```

Run template with different parameters to create spoke2 environment.

```powershell
az group create -n cp-spoke2-networking -l westeurope
az group deployment create -g cp-spoke2-networking `
    --template-file networkingSpoke.json `
    --parameters ipRange="10.2.0.0/16" `
    --parameters webSubnetRange="10.2.0.0/24" `
    --parameters vnetName=cp-spoke2-net
```

We now need to do VNET peerings between sub and spokes. Let's create universal template that configures single peering from source to destination and use it multiple times to get topology we need.

```powershell
az group deployment create -g cp-hub-networking `
    --template-file networkingPeering.json `
    --parameters sourceVnetName=cp-hub-net `
    --parameters destinationVnetName=cp-spoke1-net `
    --parameters destinationVnetResourceGroup=cp-spoke1-networking

az group deployment create -g cp-hub-networking `
    --template-file networkingPeering.json `
    --parameters sourceVnetName=cp-hub-net `
    --parameters destinationVnetName=cp-spoke2-net `
    --parameters destinationVnetResourceGroup=cp-spoke2-networking

az group deployment create -g cp-spoke1-networking `
    --template-file networkingPeering.json `
    --parameters sourceVnetName=cp-spoke1-net `
    --parameters destinationVnetName=cp-hub-net `
    --parameters destinationVnetResourceGroup=cp-hub-networking

az group deployment create -g cp-spoke2-networking `
    --template-file networkingPeering.json `
    --parameters sourceVnetName=cp-spoke2-net `
    --parameters destinationVnetName=cp-hub-net `
    --parameters destinationVnetResourceGroup=cp-hub-networking
```

## Create ARM master template for networking
We have created templates for networking, but need to deploy with right parameters in right order. We will want to orchestrate this. One way of doing that is to use Azure DevOps as we will do later in this lab. For now we will use master ARM template and call linked templates we have to orchestrate complete networking deployment.

First let's delete all networking so we can start over.
```powershell
az group delete -y --no-wait -n cp-hub-networking
az group delete -y --no-wait -n cp-spoke1-networking
az group delete -y --no-wait -n cp-spoke2-networking
```

We will create storage account to host our linked templates and upload.
```powershell
# Make sure you set storage account name to something globaly unique
$storageName = "cpstorageuniquename1234"

# Create storage account
az storage account create -g cp-deployment-artifacts -n $storageName

# Get storage connection string
$storageConnectionString = $(az storage account show-connection-string -g cp-deployment-artifacts -n $storageName -o tsv)

# Create storage container
az storage container create -n deploy --connection-string $storageConnectionString

# Upload files
az storage blob upload -f networkingHub.json `
    -c deploy `
    -n networkingHub.json `
    --connection-string $storageConnectionString

az storage blob upload -f networkingSpoke.json `
    -c deploy `
    -n networkingSpoke.json `
    --connection-string $storageConnectionString

az storage blob upload -f networkingPeering.json `
    -c deploy `
    -n networkingPeering.json `
    --connection-string $storageConnectionString
```

Storage account by default does not allow anonymous access. Let's generate SAS token so ARM master template can access linked files securely.

```powershell
az storage container generate-sas -n deploy `
    --connection-string $storageConnectionString `
    --https-only `
    --permissions r `
    --expiry "2030-1-1T00:00Z" `
    -o tsv
```

Modify networkingMaster.parameters.json file with baseUrl of your storage account and storageToken you received with previous command.

```powershell
az deployment create --template-file networkingMaster.json `
    --parameters "@networkingMaster.parameters.json" `
    -l westeurope
```

There are two things we want to fix and enhance:
- One of peerings is not in connected state. Fix the template and redeploy.
- We now want to have additional subnet in spoke networks with name app and range 10.x.1.0/24. Modify template and master template accordingly and redeploy.

## Add firewall rules / VNET access for Azure SQL
We have deployed Azure SQL, but default there is firewall preventing any access to it. We could allow whole Azure to get access or whitelist specific public IPs, but for more security we want to enable access only from web subnet in cp-spoke1-net and cp-spoke2-net.

There is sqlWithVnet.json and sqlWithVnet.parameters.json with added parameters for Vnet and resource deployment. Make sure you update sqlWithVnet.parameters.json with reference to Key Vault secret you created earlier in the lab.

```powershell
az group deployment create -g cp-sql `
    --template-file sqlWithVnet.json `
    --parameters "@sqlWithVnet.parameters.json"
```

Go to portal and check on SQL server Firewall section that two connections to spoke subnets are configured.

## Learn how to use and upgrade Virtual Machine Scale Set in spoke1 on Linux with VM extensions and ARM
Although in production we should use ARM templates for automation, let's also practice CLI. In this section we will learn how to use Virtual Machine Scale Set to manage web farm (also great for computing clusters etc.) and custom script extensions to install or update application.

Let's create VMSS with Load Balancer. We will intentionaly use older image so we can practice upgrading images in VMSS later on.

```powershell
az group create -n cp-linuxweb-rg -l westeurope
az vmss create -n cp-webscaleset `
    -g cp-linuxweb-rg `
    --image "Canonical:UbuntuServer:18.04-LTS:18.04.201905290" `
    --instance-count 2 `
    --vm-sku Standard_B1ms `
    --admin-username cpadmin `
    --admin-password Azure12345678 `
    --authentication-type password `
    --public-ip-address cp-web-lb-ip `
    --subnet $(az network vnet subnet show -g cp-spoke1-networking --name web --vnet-name cp-spoke1-net --query id -o tsv) `
    --lb cp-web-lb `
    --upgrade-policy-mode Manual
```

Next we will create LB health probe and rules. 

```powershell
az network lb probe create -g cp-linuxweb-rg `
    --lb-name cp-web-lb `
    --name webprobe `
    --protocol Http `
    --path '/' `
    --port 80
az network lb rule create -g cp-linuxweb-rg `
    --lb-name cp-web-lb `
    --name myHTTPRule `
    --protocol tcp `
    --frontend-port 80 `
    --backend-port 80 `
    --frontend-ip-name loadBalancerFrontEnd `
    --backend-pool-name cp-web-lbBEPool `
    --probe-name webprobe
```

We have our webfarm running, but there is no application installed. We will use custom script to do that. In practice we would use our own storage account to store both script and application code similar to how we did linked ARM templates previously. For simplicity we will use publicly available URLs on GitHub for both script (part of this repo) and application package (part of different repo).

We will add VM Extension with custom script. **Make sure you modify protected-settings to point to your SQL URL**. This step will update VMSS model, but not actual VMs as we have set upgrade policy to Manual.

```powershell
az vmss extension set --vmss-name cp-webscaleset `
    --name CustomScript `
    -g cp-linuxweb-rg `
    --version 2.0 `
    --publisher Microsoft.Azure.Extensions `
    --protected-settings '{\"commandToExecute\": \"bash installapp-v1.sh cpdbxff6cpwyypdyu.database.windows.net cpadmin Azure12345678\"}' `
    --settings '{\"fileUris\": [\"https://raw.githubusercontent.com/azurecz/azuretechacademy-hybridit-labs-day2/master/scripts/installapp-v1.sh\"]}'
```

Go to GUI and check VMSS Instances. You should see we are not running latest VMSS model. Let's initiate manual upgrade. We can do it one by one, but for now let's upgrade all VMs in VMSS at once.

```powershell
az vmss update-instances --instance-ids '*' `
    -n cp-webscaleset `
    -g cp-linuxweb-rg
```

When upgrade is finished our application should be running (note it may take some tame after deployment for probes to come up). Check public IP of your VMSS and connect to it via browser. You will see simple todo app connected to our Azure SQL Database - create some todo item. Also check publicip/api/version. You should see version 1 string and responses comming from both servers (balancing works and we have not set any session persistency).

```powershell
$appIp = $(az network public-ip show -g cp-linuxweb-rg -n cp-web-lb-ip --query ipAddress -o tsv)
Invoke-RestMethod $appIp/api/version -DisableKeepAlive
Invoke-RestMethod $appIp/api/version -DisableKeepAlive
Invoke-RestMethod $appIp/api/version -DisableKeepAlive
Invoke-RestMethod $appIp/api/version -DisableKeepAlive
```

Let's now upgrade application by changing custom script extension to new script that downloads newer versions. After this is done initiate manual upgrade on all nodes. Note in practice you may do this one by one to prevent publishing changes that does not work. You can also automate this process by setting upgrade policy to Rolling, but for this lab we will do things manually. **Do not forget to modify protected-settings to fit your DB!**

```powershell
az vmss extension set --vmss-name cp-webscaleset `
    --name CustomScript `
    -g cp-linuxweb-rg `
    --version 2.0 `
    --publisher Microsoft.Azure.Extensions `
    --protected-settings '{\"commandToExecute\": \"bash installapp-v2.sh cpdbxff6cpwyypdyu.database.windows.net cpadmin Azure12345678\"}' `
    --settings '{\"fileUris\": [\"https://raw.githubusercontent.com/azurecz/azuretechacademy-hybridit-labs-day2/master/scripts/installapp-v2.sh\"]}'

az vmss update-instances --instance-ids '*' `
    -n cp-webscaleset `
    -g cp-linuxweb-rg
```

After a while your app should have v2 code.

```powershell
Invoke-RestMethod $appIp/api/version -DisableKeepAlive
```

Azure base images are updated to include latest patches. As our application deployment is automated, we can change VMSS model to include newer OS image version. Note this process also can be automated (auto OS upgrade mode on VMSS), but we will do this manually.

```powershell
az vmss update -n cp-webscaleset `
    -g cp-linuxweb-rg `
    --set virtualMachineProfile.storageProfile.imageReference.version=18.04.201906271

az vmss update-instances --instance-ids '*' `
    -n cp-webscaleset `
    -g cp-linuxweb-rg
```

Our application is suitable for rolling upgrade so in practice you would upgrade instances one by one or use automated upgrading policy to not cause any downtime.

Also note that you can use custom golden images if you do not want to automate only with VM extensions. VMSS is somewhat similar to container orchestration, but with full VMs so can work in scenarios where containers are not an option. VMSS are great for web farms, computing, rendering and HPC clusters, Big Data clusters and are often used to build PaaS on top such as with Azure Kubernetes Service or Azure Databricks.

## Create ARM template for Windows-based web servers in spoke2 including Azure Backup and basic monitoring

Check you have correctly created virtual networks. We will use cp-spoke2-net network.

Create these additional resources (remember Day1 training) in resource group cp-deployment-artifacts

1. Create Monitoring resources (Log Analytics workspace) cpmonitor and configure to capture CPU etc. **Note name has to be globally unique so you will probably need to use different one such as cpmonitor654**.
2. Create Backup vault cpvault

Create **ARM template for Windows VM**

1. Go to folder arm-vmwin and create generic Windows VM ARM template [deploy-vmwin.json](arm-vmwin/deploy-vmwin.json)
2. Click create Windows VM from Azure Portal and Download template for automation (not create VM) and save it to deploy-vmwin.json and deploy-wmwin.params.json
    - Name: cpvmweb
    - Inbound port rules: None
    - Virtual network: cp-spoke2-net
    - Public IP: yes
    - NIC network security group: None
3. Clean up and customize deploy-vmwin.json and deploy-wmwin.params.json to have only this parameters
    - virtualMachineName
    - adminUsername
    - adminPassword
    - virtualMachineSize
    - subnetName
    - virtualNetworkName
    - virtualNetworkResourceGroup
    - other parameters remove and hardcode some logic e.g. new variable for: publicIpAddressName, networkInterfaceName, diagnosticsStorageAccountName
4. Run template for deployment to create VMs - Windows jump server (cpmvmjump), Windows AD server (cpvmad), Windows Web server (cpvmweb)

```powershell
az group create -n cp-vmjump-we-rg -l westeurope
az group deployment create -g cp-vmjump-we-rg `
    --template-file deploy-vmwin.json `
    --parameters deploy-wmwin-jump.params.json `
    --parameters adminPassword=Azure12345678
az group create -n cp-vmad-we-rg -l westeurope
az group deployment create -g cp-vmad-we-rg `
    --template-file deploy-vmwin.json `
    --parameters deploy-wmwin-ad.params.json `
    --parameters adminPassword=Azure12345678
az group create -n cp-vmweb-we-rg -l westeurope
az group deployment create -g cp-vmweb-we-rg `
    --template-file deploy-vmwin.json `
    --parameters deploy-wmwin-web.params.json `
    --parameters adminPassword=Azure12345678
```

Update **ARM template to enable VM monitoring**

1. Go to folder arm-vmwin and update generic Windows VM ARM template [deploy-vmwin.json](arm-vmwin/deploy-vmwin.json)
2. Add new resouce into ARM template for Monitoring Agent
    - copy extension from template https://github.com/Azure/azure-quickstart-templates/blob/master/201-oms-extension-windows-vm/azuredeploy.json
    - add parameter workspaceName, workspaceResourceGroup
3. Add new resource into ARM template for Dependency Agent
4. Run template for deployment to update VMs - Windows jump server (cpmvmjump), Windows AD server (cpvmad), Windows Web server (cpvmweb)

```powershell
az group deployment create -g cp-vmweb-we-rg `
    --template-file deploy-vmfullwin.json `
    --parameters deploy-wmwin-web.params.json `
    --parameters adminPassword=Azure12345678 `
    --parameters workspaceName=cpmonitor `
    --parameters workspaceResourceGroup=cp-deployment-artifacts
az group deployment create -g cp-vmjump-we-rg `
    --template-file deploy-vmfullwin.json `
    --parameters deploy-wmwin-jump.params.json `
    --parameters adminPassword=Azure12345678 `
    --parameters workspaceName=cpmonitor `
    --parameters workspaceResourceGroup=cp-deployment-artifacts
az group deployment create -g cp-vmad-we-rg `
    --template-file deploy-vmfullwin.json `
    --parameters deploy-wmwin-ad.params.json `
    --parameters adminPassword=Azure12345678 `
    --parameters workspaceName=cpmonitor `
    --parameters workspaceResourceGroup=cp-deployment-artifacts
```

Use following links to prepare template

- Azure Monitor https://docs.microsoft.com/en-us/azure/azure-monitor/platform/template-workspace-configuration
- Agent https://azure.microsoft.com/en-us/resources/templates/201-oms-extension-windows-vm/

After deployment check VMs are connected by looking into your Log Analytics workspace.

Create **ARM template for VM backup**

How is Azure Backup configured? It is done directly on Backup Vault resource rather on VM. Nevertheless for consistency we want to make this configuration part of our VM template. Therefore we need to target multiple resource groups in our template (main RG for VM and then backup vault in our cp-infra-rg). This can be done using nested (or linked) template.

Copy your existing deploy-vmfullwin.json template to file deploy-vmfullwin-backup.json and add the following:

1. Create additional parameters backupVaultName and backupVaultResourceGroup
2. Create additional variables:

```json
        "backupFabric": "Azure",
        "backupPolicyName": "DefaultPolicy",
        "protectionContainer": "[concat('iaasvmcontainer;iaasvmcontainerv2;', resourceGroup().name, ';', parameters('virtualMachineName'))]",
        "protectedItem": "[concat('vm;iaasvmcontainerv2;', resourceGroup().name, ';', parameters('virtualMachineName'))]"
```

3. Add resource of type deployments with nested template to configure backup vault

```json
        {
            "type": "Microsoft.Resources/deployments",
            "apiVersion": "2018-05-01",
            "name": "nestedTemplate",
            "resourceGroup": "[parameters('backupVaultResourceGroup')]",
            "properties": {
                "mode": "Incremental",
                "template": {
                    "$schema": "https://schema.management.azure.com/schemas/2015-01-01/deploymentTemplate.json#",
                    "contentVersion": "1.0.0.0",
                    "resources": [
                        {
                            "type": "Microsoft.RecoveryServices/vaults/backupFabrics/protectionContainers/protectedItems",
                            "apiVersion": "2016-12-01",
                            "name": "[concat(parameters('backupVaultName'), '/', variables('backupFabric'), '/',variables('protectionContainer'), '/', variables('protectedItem'))]",
                            "properties": {
                                "protectedItemType": "Microsoft.Compute/virtualMachines",
                                "policyId": "[resourceId('Microsoft.RecoveryServices/vaults/backupPolicies', parameters('backupVaultName'), variables('backupPolicyName'))]",
                                "sourceResourceId": "[resourceId('Microsoft.Compute/virtualMachines', parameters('virtualMachineName'))]"
                            }
                        }
                    ]
                }
            }
        }
```

Deploy VM templates

```powershell
az group deployment create -g cp-vmweb-we-rg `
    --template-file deploy-vmfullwin-backup.json `
    --parameters deploy-wmwin-web.params.json `
    --parameters adminPassword=Azure12345678 `
    --parameters workspaceName=cpmonitor `
    --parameters workspaceResourceGroup=cp-deployment-artifacts `
    --parameters backupVaultName=cpvault `
    --parameters backupVaultResourceGroup=cp-deployment-artifacts
az group deployment create -g cp-vmjump-we-rg `
    --template-file deploy-vmfullwin-backup.json `
    --parameters deploy-wmwin-jump.params.json `
    --parameters adminPassword=Azure12345678 `
    --parameters workspaceName=cpmonitor `
    --parameters workspaceResourceGroup=cp-deployment-artifacts `
    --parameters backupVaultName=cpvault `
    --parameters backupVaultResourceGroup=cp-deployment-artifacts
az group deployment create -g cp-vmad-we-rg `
    --template-file deploy-vmfullwin-backup.json `
    --parameters deploy-wmwin-ad.params.json `
    --parameters adminPassword=Azure12345678 `
    --parameters workspaceName=cpmonitor `
    --parameters workspaceResourceGroup=cp-deployment-artifacts `
    --parameters backupVaultName=cpvault `
    --parameters backupVaultResourceGroup=cp-deployment-artifacts
```

Make sure backup is configured by inspecting you backup vault or Backup tab in your VM.

## Use Azure DevOps to version and orchestrate deployment of infrastructure templates

Check you have Azure DevOps project already created, e.g. try to navigate Repos. 
The aim is to deploy ARM template with Windows Web server cpvmweb into resource group cp-vmweb-we-rg

First we have to clone GitHub repo into our Azure Repos

1. Navigrate to Repos
2. Import Repository and type link to this GitHub (https://github.com/azurecz/azuretechacademy-hybridit-labs-day2.git)

Now we will create first Azure DevOps Pipeline to deploy ARM template with Windows Web server cpvmweb into resource group cp-vmweb-we-rg

1. Create new Release Pipeline with name CPWEB-CD, select Empty job, Stage 1 call DEV
2. Add artifact - link Azure Repos, branch master and change Source alias to _source
3. Configure DEV stage tasks
    - add Azure Resource Group Deployment task
    - select your subscription and click Authorize (if you cannot see it use Manage to configure connection manually)
    - action Create or Update resource group
    - resource group name cp-vmweb-we-rg
    - location westeurope
    - as template locate deploy-vmwin.json in arm-win-solution folder
    - paramaters locate deploy-wmwin-web.params.json in arm-win-solution folder and override -adminPassword Azure12345678
4. Save, Create Release and wait for successfull deployment

Repeat it for all other servers, you can use different pipeline.

![CPWEB-CD release pipeline](/media/devops-cpweb-cd.png)

## Use Azure DevOps deployment agent to deploy application

The aim is to configure VM as Web server and install web application

1. Open Pipelines and configure Deployment groups as target group machines
    - new group CPWEB
2. Prepare Personal Access Token for VM to authenticate against Azure DevOps to receive application builds and configurations
    - Click your profile icon on top right corner and select Security
    - Create new token with following permissions:
      - [Agent Pools: Read & Manage]
      - [Deployment Groups: Read & Manage]
      - [Project and Team: Read]
    - Do not forget to copy your token !
3. Open existing Release pipeline CPWEB-CD and change Azure deployment taks
    - Change Advanced deployment options for virtual machines to deploy Deployment agent as prerequisites
    - Setup new connection to Azure Pipelines using your token and organization URL (https://dev.azure.com/yourorganizationname)
    - Select your project
    - Select deployment group CPWEB
4. Save and Run Release 
5. Ensure cpvmweb is assigned as Target in CPWEB deployment group
6. You may check cpvmweb in Azure Extensions tab - this is how Azure DevOps has deployed agent

![CPWEB-CD release pipeline deployment agent](/media/devops-deploymentagent.png)

![CPWEB-CD deployment group](/media/devops-deploymentgroup.png)

Continue configuration to run installation script on target server

1. Open Repos to prepare script to configure Windows VM
    - under folder scripts create/update file configwin.ps1 to install IIS (remember training Day1))
2. Open existing Release pipeline CPWEB-CD and change Azure deployment taks
    - add Deployment group job in DEV stage and select Deployment group CPWEB
    - add PowerShell script task and select configwin.ps1
3. Run release and verify that application is installed. It does not have connection to Azure SQL so expect 502 error response, but this indicates IIS is running and app loaded, but crashed.

Continue configuration to connect SQL server

1. Open Repos to prepare script to configure application - setup ENV variables
    - create new configwinapp.ps1, add parameters SQL server name (sqlServer), username (sqlUsername), password (sqlPassword)
2. Open existing Release pipeline CPWEB-CD and change Azure deployment taks
    - add PowerShell script task and select configwinapp.ps1 and add arguments for SQL server connection, e.g. -sqlServer "cpsqlserver1.database.windows.net" -sqlUsername "cpadmin" -sqlPassword "Azure12345678"

Connect to cpvmweb IP via browser and you should see application up and running.

![CPWEB-CD deployment group](/media/devops-deploymentgrouptask.png)

We are using secrets directly in our pipeline, perhaps we can enhance that. You may create variables in Azure DevOps, store secrets there securely and use it. You can also for even better security map Azure DevOps variables to Key Vault. We already have one and we have stored our SQL password there previously so let's use it.

1. In Pipelines, Library create new Variable Group
2. Select Link secrets from Azure Key Vault as variables and reference Key Vault we created previously today and secret with SQL password.
3. Edit Release pipeline and in Variables section link our Variable Group. Note you scope it all release phases or to selected stages (eg. set for Dev with one Key Vault and set for Prod).
4. Reference variable in Powershell task parameters, eg. -sqlPassword $(cpSqlPassword)

## DevOps homework

Configure new production deployment

- deploy new resource group with VM cpvmwebprod in another peered network
- deploy web application with Release pipeline CPWEB-CD as new stage PROD
- connect to different PROD SQL server

## Automation and governance with Azure Blueprints
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

## Contacts

### Tomas Kubica - Cloud Solutions Architect
- https://www.linkedin.com/in/tkubica
- https://github.com/tkubica12
- https://twitter.com/tkubica

### Jaroslav Jindrich - Cloud Solutions Architect
- https://www.linkedin.com/in/jjindrich
- https://github.com/jjindrich
- https://twitter.com/jjindrich_cz
