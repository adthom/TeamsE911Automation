function ConvertTo-PhysicalAddressString {
    [CmdletBinding()]
    [OutputType([string])]
    param (
        [Parameter(Mandatory = $true, Position = 0, ValueFromPipeline = $true)]
        [AllowEmptyString()]
        [AllowNull()]
        [string]
        $address
    )
    process {
        try {
            <#
                clean up address to attempt to parse all typical formats, even if in Windows PowerShell
                001122334455
                00-11-22-33-44-55
                0011.2233.4455 (only if using pwsh)
                00:11:22:33:44:55 (only if using pwsh)
                F0-E1-D2-C3-B4-A5
                f0-e1-d2-c3-b4-a5 (only if using pwsh)
            #>
            $address = $address -replace '[:\.]', ''
            $address = $address.ToUpper()
            $pa = [Net.NetworkInformation.PhysicalAddress]::Parse($address)
            if ($pa) {
                [BitConverter]::ToString($pa.GetAddressBytes())
            }
            else {
                return $null
            }
        }
        catch {
            return $null
        }
    }
}
