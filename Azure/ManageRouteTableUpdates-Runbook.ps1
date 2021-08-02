
<#
    .DESCRIPTION
        A runbook which receives a webhook from FortiGate Automation
        Stitch to add/removed microsegmentation route in routetable.
    .NOTES
        AUTHOR: jmcdonough@fortinet.com
        LASTEDIT: July 9, 2021
#>

param (
    [Parameter (Mandatory = $false)]
    [object] $WebhookData
)

Clear-AzContext -Force

if ($WebhookData) {

    write-output "Header"
    $WebhookData.RequestHeader
    write-output "Body"
    $WebhookData.RequestBody

    $jsonBody = ConvertFrom-Json -InputObject $WebhookData.RequestBody

    $rtAction = $jsonBody.action
    $rtAddr = $jsonBody.addr
    $rtResourceGroupName = $WebhookData.RequestHeader.ResourceGroupName
    $rtRouteTableName = $WebhookData.RequestHeader.RouteTableName
    $rtNamePrefix = $WebhookData.RequestHeader.RouteNamePrefix
    $rtNextHopIp = $WebhookData.RequestHeader.NextHopIp

    $retryLimit = 5

    write-output $rtAction,$rtAddr,$rtResourceGroupName,$rtRouteTableName,$rtNamePrefix,$rtNextHopIp

    if ($rtAction.Equals('object-add')) {

        Connect-AzAccount -Identity -Force

        $retry = 1
        write-output "Add route: $rtNamePrefix-$rtAddr rg: $rtResourceGroupName rt: $rtRouteTableName nh: $rtNextHopIp"

        # Add route if it does not exist. Try up to retryLimit times, occasionally the add will fail. 
        while (-not (Get-AzRouteTable -ResourceGroupName $rtResourceGroupName -Name $rtRouteTableName | Get-AzRouteConfig -Name "$rtNamePrefix-$rtAddr" -ErrorAction SilentlyContinue)) {

            write-output "  try - $retry"
            Get-AzRouteTable -ResourceGroupName $rtResourceGroupName -Name $rtRouteTableName | `
                Add-AzRouteConfig -Name "$rtNamePrefix-$rtAddr" `
                    -AddressPrefix "$rtAddr/32" `
                    -NextHopType VirtualAppliance `
                    -NextHopIpAddress $rtNextHopIp | `
                Set-AzRouteTable

            if ($retry++ -ge $retryLimit) { break }
        }
    
    } elseif ($rtAction.Equals('object-remove')) {

        Connect-AzAccount -Identity -Force

        $retry = 1
        write-output "Remove route: $rtNamePrefix-$rtAddr rg: $rtResourceGroupName rt: $rtRouteTableName nh: $rtNextHopIp"


        # Remove route if it does exist. Try up to retryLimit times, occasionally the remove will fail.
        while ((Get-AzRouteTable -ResourceGroupName $rtResourceGroupName -Name $rtRouteTableName | Get-AzRouteConfig -Name "$rtNamePrefix-$rtAddr" -ErrorAction SilentlyContinue)) {
        
            write-output "  try - $retry"
            Get-AzRouteTable -ResourceGroupName $rtResourceGroupName -Name $rtRouteTableName | `
                Remove-AzRouteConfig -Name "$rtNamePrefix-$rtAddr" | `
                Set-AzRouteTable
            
            if ($retry++ -ge $retryLimit) { break }
        }
    } else {
        write-Error "Runbook action did not match object-add or object-remove."
    }

}
else {
    # Error
    write-Error "This runbook is meant to be started from an Azure webhook only."
}