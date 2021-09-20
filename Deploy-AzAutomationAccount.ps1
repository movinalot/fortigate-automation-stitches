
<#
    .DESCRIPTION
        Commands to:
        * Setup an Azure Automation Account
        * Import Azure PowerShell Modules into the Automation Account
        * Create, Import and Publish an Azure Automation Account Runbook
        * Create Azure Automation Account Webhook to invoke the Runbook
    .NOTES
        AUTHOR: jmcdonough@fortinet.com
        LAST EDIT: September 20, 2021
#>

New-AzResourceGroup -Name "automation-account" -Location eastus2
New-AzAutomationAccount -ResourceGroupName "automation-account" -Location eastus2 -Name "user-automation-01" -AssignSystemIdentity -Plan Basic
New-AzRoleAssignment -ObjectId (Get-AzAutomationAccount -ResourceGroupName "automation-account" -Name "user-automation-01").Identity.PrincipalId -RoleDefinitionName "Contributor" -Scope (Get-AzResourceGroup -Name "Production-EastUS2" -Location eastus2).ResourceId
@("Accounts", "Automation","Compute","Network","Resources") | ForEach-Object {Import-AzAutomationModule -ResourceGroupName "automation-account" -AutomationAccountName "user-automation-01" -Name Az.$_  -ContentLinkUri https://www.powershellgallery.com/api/v2/package/Az.$_}
New-AzAutomationRunbook -ResourceGroupName "automation-account" -AutomationAccountName "user-automation-01" -Name "ManageRouteTableUpdates" -Type PowerShell
Import-AzAutomationRunbook -Name "ManageRouteTableUpdates" -ResourceGroupName "automation-account" -AutomationAccountName "user-automation-01" -Path "./Azure/ManageRouteTableUpdates.ps1" -Type PowerShell –Force
Publish-AzAutomationRunbook -ResourceGroupName "automation-account" -AutomationAccountName "user-automation-01" -Name "ManageRouteTableUpdates"
New-AzAutomationWebhook -ResourceGroupName "automation-account" -AutomationAccountName "user-automation-01" -RunbookName "ManageRouteTableUpdates" -Name "routetableupdate" -IsEnabled $True -ExpiryTime "09/12/2022" -Force
