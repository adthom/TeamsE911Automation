function Get-CsE911NetworkObjectHashCode {
    [CmdletBinding()]
    [OutputType([string])]
    param (
        [Parameter(Mandatory = $true, Position = 0)]
        [PSObject]
        $NetworkObject
    )

    $NetworkObjectSignatureString = switch ($NetworkObject.NetworkObjectType) {
        "WirelessAccessPoint" {
            ConvertTo-PhysicalAddressString -address $NetworkObject.NetworkObjectIdentifier.Trim()
            break
        }
        "Port" {
            $ChassisID, $PortID = $NetworkObject.NetworkObjectIdentifier.Trim() -split ';', 2
            $ChassisIDParsed = ConvertTo-PhysicalAddressString -address $ChassisID
            if (![string]::IsNullOrEmpty($ChassisIDParsed)) {
                $ChassisID = $ChassisIDParsed
            }
            @($ChassisID, $PortID) -join ';'
            break
        }
        "Switch" {
            $ChassisID = $NetworkObject.NetworkObjectIdentifier.Trim()
            $ChassisIDParsed = ConvertTo-PhysicalAddressString -address $ChassisID
            if (![string]::IsNullOrEmpty($ChassisIDParsed)) {
                $ChassisID = $ChassisIDParsed
            }
            $ChassisID
            break
        }
        "Subnet" {
            $NetworkObject.NetworkObjectIdentifier.Trim()
            break
        }
        default {
            # handle object from Lis export
            if ($NetworkObject.PortId) {
                # port
                @($NetworkObject.ChassisID, $NetworkObject.PortID) -join ';'
            }
            elseif ($NetworkObject.ChassisId) {
                # switch
                $NetworkObject.ChassisId
            }
            elseif ($NetworkObject.Subnet) {
                # Subnet
                $NetworkObject.Subnet
            }
            elseif ($NetworkObject.Bssid) {
                # WirelessAccessPoint
                $NetworkObject.Bssid
            }
            else {
                # return empty string if no match
                ""
            }
        }
    }
    return (Get-StringHash -String $NetworkObjectSignatureString.ToLower())
}
