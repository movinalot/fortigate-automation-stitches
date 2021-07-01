
<#
    .DESCRIPTION
        A runbook which receives a webhook from FortiGate Automaiton
        Stitch to add/removed microsegmentation route in routetable.
    .NOTES
        AUTHOR: jmcdonough@fortinet.com
        LASTEDIT: May 28, 2021
#>

param (
    [Parameter (Mandatory = $false)]
    [object] $WebhookData
)

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

    write-output $rtAction,$rtAddr,$rtResourceGroupName,$rtRouteTableName,$rtNamePrefix

    if ($rtAction.Equals('object-add')) {

        Connect-AzAccount -Identity
        
        $rtNextHopIp = $(Get-AzResource -ResourceGroupName $rtResourceGroupName `
                                        -ResourceType Microsoft.Network/routeTables | `
                        Get-AzRouteTable -Name $rtRouteTableName | `
                        Get-AzRouteConfig -Name toDefault).NextHopIpAddress

        Get-AzResource -ResourceGroupName $rtResourceGroupName `
                        -ResourceType Microsoft.Network/routeTables | `
            Get-AzRouteTable -Name $rtRouteTableName | `
            Add-AzRouteConfig -Name "$rtNamePrefix-$rtAddr" `
                            -AddressPrefix "$rtAddr/32" `
                            -NextHopType VirtualAppliance `
                            -NextHopIpAddress $rtNextHopIp | `
            Set-AzRouteTable
    } elseif ($rtAction.Equals('object-remove')) {

        Connect-AzAccount -Identity

        Get-AzResource -ResourceGroupName $rtResourceGroupName `
                        -ResourceType Microsoft.Network/routeTables | `
            Get-AzRouteTable -Name $rtRouteTableName | `
            Remove-AzRouteConfig -Name "$rtNamePrefix-$rtAddr" | `
            Set-AzRouteTable
    } else {
        write-Error "Runbook action did not match object-add or object-remove."
    }

}
else {
    # Error
    write-Error "This runbook is meant to be started from an Azure webhook only."
}