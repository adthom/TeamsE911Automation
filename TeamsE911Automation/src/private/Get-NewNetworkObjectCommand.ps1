function Get-NewNetworkObjectCommand {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true, ValueFromPipeline = $true)]
        [object]
        $NetworkObject,

        [Parameter(Mandatory = $true)]
        [string]
        $LocationId
    )
    process {
        $NetworkObjectParams = @{
            LocationId = $LocationId
        }
        if ($NetworkObject.NetworkDescription) {
            $NetworkObjectParams['Description'] = $NetworkObject.NetworkDescription
        }

        switch ($NetworkObject.NetworkObjectType) {
            "WirelessAccessPoint" {
                $NetworkObjectParams['BSSID'] = ConvertTo-PhysicalAddressString -address $NetworkObject.NetworkObjectIdentifier.Trim()
                break
            }
            "Port" {
                $ChassisID, $PortID = $NetworkObject.NetworkObjectIdentifier.Trim() -split ';', 2
                $ChassisIDParsed = ConvertTo-PhysicalAddressString -address $ChassisID
                if (![string]::IsNullOrEmpty($ChassisIDParsed)) {
                    $ChassisID = $ChassisIDParsed
                }
                $NetworkObjectParams['ChassisID'] = $ChassisID
                $NetworkObjectParams['PortID'] = $PortID
                break
            }
            "Switch" {
                $ChassisID = $NetworkObject.NetworkObjectIdentifier.Trim()
                $ChassisIDParsed = ConvertTo-PhysicalAddressString -address $ChassisID
                if (![string]::IsNullOrEmpty($ChassisIDParsed)) {
                    $ChassisID = $ChassisIDParsed
                }
                $NetworkObjectParams['ChassisID'] = $ChassisID
                break
            }
            "Subnet" {
                $NetworkObjectParams['Subnet'] = $NetworkObject.NetworkObjectIdentifier.Trim()
                break
            }
        }

        $LocationCommand = "Set-CsOnlineLis{0} -ErrorAction Stop" -f $NetworkObject.NetworkObjectType.Trim()
        foreach ($Parameter in $NetworkObjectParams.Keys) {
            $LocationCommand += ' -{0} "{1}"' -f $Parameter, ($NetworkObjectParams[$Parameter] -replace , '"', '`"')
        }
        $LocationCommand | Write-Output
    }
}
