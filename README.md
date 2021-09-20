# Azure Micro-Segmentation Using Azure Automation and FortiGate Automation Stitches

## Create an Azure RunBook and configure a FortiGate Automation Stitch

A FortiGate Automation Stitch brings together a Trigger and an Action. In this code the trigger is a log event and the action is the execution of a webhook.

* The Trigger - a log event is generated when an IP address is added or removed from a FortiGate dynamic address object
* The Action - a webhook sends an HTTPS POST request to an endpoint in Azure. The endpoint runs a PowerShell script to update an Azure Route Table. The HTTP headers and JSON formatted body contain the information required to update the route table to manage micro-segmentation through the use of host routes. A host route is a route that indicates a specific host by using the IP-ADDRESS/32 in IPV4

This code covers the

* Setup of an Azure Automation Account
* Importing Azure PowerShell Modules into the Automation Account
* Creation, Import, and Publishing of an Azure Automation Account Runbook
* Creation of an Azure Automation Account Webhook to invoke the Runbook
* Creation of a FortiGate Dynamic Address
* Creation of a FortiGate Automation Stitch
* Creation of a FortiGate Automation Stitch Trigger
* Creation of a FortiGate Automation Stitch Action

### Part 1. Azure

Automation in Azure can be accomplished in a number of ways, Logic Apps, Function Apps, Runbooks, etc. Each of the automation methods can be triggered in a number of ways, for example Events, Webhooks, and Schedules.

The Azure Cloudshell PowerShell commands shown below create an Azure Automation account that enables the running of an Azure Runbook via a Webhook. An Azure Runbook is just a script, in this case PowerShell, that the Automation Account can run. The __Actions__ the Runbook can perform are controlled by the rights and scope (where those actions can be performed) that have been granted to the Automation Account.

The __Actions__ are provided by PowerShell Modules that have been imported into the Automation Account. The PowerShell Modules are libraries of commands called Cmdlets that are grouped into several domains. For example, Accounts, Automation, Compute, Network, and Resources.

All of the steps below can be performed by clicking and typing in the Azure Portal. However, the commands shown in each section can be run directly in Azure Cloudshell. Cloudshell has all the required utilities to execute the commands. Nothing additional needs to be loaded on a personal device.

> To run the commands below from Azure Cloudshell, clone this repository to a Cloudshell directory and then switch to that directory.

git clone and directory change
![git clone and directory change](images/azure-automation-account-git-clone.jpg)

1. __Azure Automation Account__
    * Create an Azure [Automation Account](https://docs.microsoft.com/en-us/azure/automation/automation-create-standalone-account)

        * Create a new Resource Group

            ```PowerShell
            # New-AzResourceGroup -Name "resource-group-name-of-the-automation-account" -Location azure-location

            New-AzResourceGroup -Name "automation-account" -Location eastus2
            ```

        * Create an Automation Account in the new Resource Group
            * Choose a Location
            * Provide a Name - for example, user-automation-01
            * Indicate the assignment of a System Assigned Identity
            * Choose the Basic Plan

            ```PowerShell
            # New-AzAutomationAccount -ResourceGroupName "resource-group-name-of-the-automation-account" -Location azure-location -Name "user-automation-01" -AssignSystemIdentity -Plan Basic

            New-AzAutomationAccount -ResourceGroupName "automation-account" -Location eastus2 -Name "user-automation-01" -AssignSystemIdentity -Plan Basic
            ```

        Azure Create Resource Group and Automation Account
        ![Azure Create Resource Group and Automation Account](images/azure-create-rg-and-automation-account.jpg)

        Azure Portal Automation Account
        ![Azure Portal Automation Account](images/azure-automation-account-portal.jpg)

    * Setup Automation Account [Managed Identity](<https://docs.microsoft.com/en-us/azure/active-directory/managed-identities-azure-resources/overview>)

        * The Managed Identity allows the Automation Account to execute the PowerShell Runbook with the prescribed rights and scope. The prescribed rights and scope in this case will be __contributor__ and the Resource Group where the target Route Table is located.

        * In this example the target Route Table is in Resource Group `Production-EastUS2`, which has already been created

        ```PowerShell
        # New-AzRoleAssignment -ObjectId (Get-AzAutomationAccount -ResourceGroupName "resource-group-name-of-the-automation-account" -Name "user-automation-01").Identity.PrincipalId -RoleDefinitionName "Contributor" -Scope (Get-AzResourceGroup -Name "resource-group-name-of-the-target-route-table" -Location azure-location).ResourceId

        New-AzRoleAssignment -ObjectId (Get-AzAutomationAccount -ResourceGroupName "automation-account" -Name "user-automation-01").Identity.PrincipalId -RoleDefinitionName "Contributor" -Scope (Get-AzResourceGroup -Name "Production-EastUS2" -Location eastus2).ResourceId
        ```

        Azure Assign Identity to Automation Account
        ![Azure Assign Identity to Automation Account](images/azure-assign-identity-automation-account.jpg)

    * Import Az PowerShell Modules
    Modules can be imported one at a time or utilizing a PowerShell Array, can be piped to a ForEach-Object installing all modules with a single command line
        * Az.Accounts
        * Az.Automation
        * Az.Compute
        * Az.Network
        * Az.Resources

        ```PowerShell
        # Import-AzAutomationModule -ResourceGroupName "resource-group-name-of-the-automation-account" -AutomationAccountName "user-automation-01" -Name Az.Accounts  -ContentLinkUri https://www.powershellgallery.com/api/v2/package/Az.Accounts
        # @("Accounts", "Automation","Compute","Network","Resources") | ForEach-Object {Import-AzAutomationModule -ResourceGroupName "resource-group-name-of-the-automation-account" -AutomationAccountName "user-automation-01" -Name Az.$_  -ContentLinkUri https://www.powershellgallery.com/api/v2/package/Az.$_}

        @("Accounts", "Automation","Compute","Network","Resources") | ForEach-Object {Import-AzAutomationModule -ResourceGroupName "automation-account" -AutomationAccountName "user-automation-01" -Name Az.$_  -ContentLinkUri https://www.powershellgallery.com/api/v2/package/Az.$_}
        ```

        Azure Automation Account PowerShell Modules
        ![Azure Automation Account PowerShell Modules](images/azure-import-powershell-modules-automation-account.jpg)

        Azure Automation Account PowerShell Modules Portal
        ![Azure Automation Account PowerShell Modules](images/azure-import-powershell-modules-automation-account-portal.jpg)

</br>

1. __Azure Automation Runbook__
    * Create, Import, and Publish Runbook
      * The Runbook in the example is named `ManageRouteTableUpdates`. When importing the Runbook provide a Path that is relative to where the `Import-AzAutomationRunbook` Cmdlet is being run.

      The name of the Runbook and the name of the PowerShell script that is being imported __do not have to match__. In this example they do match but that is not a requirement to importing code for a Runbook.

        ```PowerShell
        # New-AzAutomationRunbook -ResourceGroupName "resource-group-name-of-the-automation-account" -AutomationAccountName "user-automation-01" -Name "name-of-runbook" -Type PowerShell

        New-AzAutomationRunbook -ResourceGroupName "automation-account" -AutomationAccountName "user-automation-01" -Name "ManageRouteTableUpdates" -Type PowerShell
        
        # Import-AzAutomationRunbook -Name "name-of-runbook" -ResourceGroupName "resource-group-name-of-the-automation-account" -AutomationAccountName "user-automation-01" -Path "path-to-powershell-script.ps1" -Type PowerShell –Force

        Import-AzAutomationRunbook -Name "ManageRouteTableUpdates" -ResourceGroupName "automation-account" -AutomationAccountName "user-automation-01" -Path "./Azure/ManageRouteTableUpdates.ps1" -Type PowerShell –Force
        
        # Publish-AzAutomationRunbook -ResourceGroupName "resource-group-name-of-the-automation-account" -AutomationAccountName "user-automation-01" -Name "name-of-runbook"

        Publish-AzAutomationRunbook -ResourceGroupName "automation-account" -AutomationAccountName "user-automation-01" -Name "ManageRouteTableUpdates"
        ```

        Azure Automation Account New Runbook
        ![Azure Automation Account New Runbook](images/azure-new-runbook-automation-account.jpg)

        Azure Automation Account Import Runbook
        ![Azure Automation Account Import Runbook](images/azure-import-runbook-automation-account.jpg)

        Azure Automation Account Publish Runbook
        ![Azure Automation Account Publish Runbook](images/azure-publish-runbook-automation-account.jpg)

        Azure Automation Account Runbook Portal
        ![Azure Automation Account Publish Runbook](images/azure-runbook-automation-account-portal.jpg)

    * Create Webhook
      * The example command below uses `routetableupdate` as the Webhook name

        ```PowerShell
        # New-AzAutomationWebhook -ResourceGroupName "resource-group-name-of-the-automation-account" -AutomationAccountName "user-automation-01" -RunbookName "name-of-runbook" -Name "webhook-name" -IsEnabled $True -ExpiryTime "09/12/2022" -Force

        New-AzAutomationWebhook -ResourceGroupName "automation-account" -AutomationAccountName "user-automation-01" -RunbookName "ManageRouteTableUpdates" -Name "routetableupdate" -IsEnabled $True -ExpiryTime "09/12/2022" -Force
        ```

        The output will include the URI of the enabled webhook. The webhook URI is only viewable at creation and cannot be retrieved afterwards. The output will look similar to below.

        ```text
        ResourceGroupName     : automation-account
        AutomationAccountName : user-automation-01
        Name                  : routetableupdate
        CreationTime          : 9/20/2021 4:06:04 PM +00:00
        Description           :
        ExpiryTime            : 9/12/2022 12:00:00 AM +00:00
        IsEnabled             : True
        LastInvokedTime       : 1/1/0001 12:00:00 AM +00:00
        LastModifiedTime      : 9/20/2021 4:06:04 PM +00:00
        Parameters            : {}
        RunbookName           : ManageRouteTableUpdates
        WebhookURI            : https://020446da-76a7-4092-8330-8c36bd437174.webhook.eus2.azure-automation.net/webhooks?token=1T1%2bZJ
                                9cbJti948rF0%2b4E0C5RSNxht2q1DdaNmCU3zQ%3d
        HybridWorker          :
        ```

        Azure Automation Account Runbook Webhook
        ![Azure Automation Account Runbook Webhook](images/azure-webhook-runbook-automation-account.jpg)

        Azure Automation Account Runbook Webhook Portal
        ![Azure Automation Account Runbook Webhook Portal](images/azure-webhook-runbook-automation-account-portal.jpg)

### Part 2. FortiGate

A FortiGate Automation Stitch brings together a Trigger and one of more Actions.

In this example

* The Trigger is the existence (appearance/disappearance) of a VM with a specific Tag and Value in the monitored Azure Environment.
* The Action is the addition or removal of a host route for that VM in a target route table.

    Automation Stitch
    ![Automation Stitch](images/automation-stitch-stitch.jpg)

    Automation Stitch Trigger
    ![Automation Stitch Trigger](images/automation-stitch-trigger.jpg)

    Automation Stitch Action
    ![Automation Stitch Action](images/automation-stitch-action.jpg)

Utilizing the [FortiGate Azure SDN Connector](https://docs.fortinet.com/document/fortigate-public-cloud/7.0.0/azure-administration-guide/502895/configuring-an-sdn-connector-in-azure), [Azure information](https://docs.fortinet.com/document/fortigate-public-cloud/7.0.0/azure-administration-guide/489236/configuring-an-azure-sdn-connector-for-azure-resources) is periodically retrieved based on the SDN Connector's scope.

When a VM is seen with the Tag `ComputeType` and the Value `WebServer` or `DbServer`, the Trigger portion of the FortiGate Automation Switch is activated. The Action portion of the FortiGate Automation Stitch is a call to the Webhook associated to the Runbook created in Azure.

This example utilizes an Azure Tag and its value to determine if the target route table needs to be updated. The code referenced here can be used to create the FortiGate configurations using the FortiGate CLI. The FortiGate GUI can be utilized can be utilized as well. However, when using the GUI the FortiGate presents `Filter` criteria based on items that __exist__ in the SDN target scope.

1. __FortiGate Dynamic Addresses__
When using the GUI the FortiGate presents `Filter` criteria based on items that __exist__ in the SDN target scope. USe the CLI to create a FortiGate Dynamic Address for a Tag that does not exist yet in Azure.
    * Create Dynamic Address to match a [DbServer](FortiGate/address-DbServers.cfg)
        * Tag: __ComputeType__
        * Value: __DbServer__
    * Create Dynamic Address to match a [WebServer](FortiGate/address-WebServers.cfg)
        * Tag: __ComputeType__
        * Value: __WebServer__

    Example Dynamic Address CLI Configuration
    ![WebServers Dynamic Address](images/dynamic-address-webservers-cli.jpg)

    Example Dynamic Address GUI Configuration
    ![WebServers Dynamic Address](images/dynamic-address-webservers-gui.jpg)

    Example SDN log events showing the removal of IP address 10.1.20.5 and the the addition of IP address 10.1.21.4 to the __WebServers Dynamic Address__ object.
    ![WebServers Dynamic Address Logs](images/dynamic-address-log.jpg)

1. __FortiGate Automation Stitch__
The following actions are focused on the __WebServers__ Dynamic Address object, Trigger and Action that comprise an Automation Stitch.  The same actions would need to be taken to support the __DbServers__ Dynamic Address object.

    * Create [Trigger](FortiGate/routetableupdate-trigger-WebServers.cfg)
        * Log is created when an IP Address is Added to a Dynamic Address object
        * Log is created when an IP Address is Removed from a Dynamic Address object

    Example Automation Stitch Trigger CLI Configuration
    ![Automation Stitch Trigger CLI Configuration](images/routetable-update-trigger-cfg-cli.jpg)

    Example Automation Stitch Trigger List GUI
    ![Automation Stitch Trigger List GUI](images/routetable-update-trigger-lst-gui.jpg)

    Example Automation Stitch Trigger GUI Configuration
    ![Automation Stitch Trigger GUI Configuration](images/routetable-update-trigger-cfg-gui.jpg)

    * Create [Action](FortiGate/routetableupdate-action.cfg)
        * Webhook - the URI of the Azure Automation Account Runbook
        * Body - the IP address of the VM that was added or removed from the Azure environment
        * Headers - the headers that specify the Azure
            * Resource Group - the Azure Resource Group where the target route table is located
            * Route Table Name - the target route table
            * Next Hop IP - the IP of the Next Hop, this is the active FortiGate

    Example Automation Stitch Action CLI Configuration
    ![Automation Stitch ACtion CLI Configuration](images/routetable-update-action-cfg-cli.jpg)

    Example Automation Stitch Action List GUI
    ![Automation Stitch Action List GUI](images/routetable-update-action-lst-gui.jpg)

    Example Automation Stitch Action GUI Configuration
    ![Automation Stitch Action GUI Configuration](images/routetable-update-action-cfg-gui.jpg)

    * Create [Stitch](FortiGate/routetableupdate-stitch-WebServers.cfg)
    The Automation Stitch brings together the Trigger and the Action.
        * Trigger - Logs create for Dynamic Address Object
        * Action - POST to an Azure WebHook data that can be used to update a target Route Table

    Example Automation Stitch CLI Configuration
    ![Automation Stitch CLI Configuration](images/routetable-update-stitch-cfg-cli.jpg)

    Example Automation Stitch List GUI
    ![Automation Stitch List GUI](images/routetable-update-stitch-lst-gui.jpg)

    Example Automation Stitch GUI Configuration
    ![Automation Stitch GUI Configuration](images/routetable-update-stitch-cfg-gui.jpg)
