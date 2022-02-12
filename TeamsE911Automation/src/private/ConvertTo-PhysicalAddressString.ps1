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
            $address = $address.ToUpper() -replace '[^A-F0-9\*]',''
            $addressParts = $address -split '(\w{2})' | Where-Object { ![string]::IsNullOrEmpty($_) }
            if ($addressParts.Count -ne 6) {
                return $null
            }
            $address = $addressParts -join '-'
            if ($addressParts[-1].EndsWith('*')) {
                for ($i = 0; $i -lt ($addressParts.Count - 1); $i++) {
                    if ($addressParts[$i] -notmatch '^[A-F0-9]{2}$') { return $null }
                }
                return $address
            }
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
