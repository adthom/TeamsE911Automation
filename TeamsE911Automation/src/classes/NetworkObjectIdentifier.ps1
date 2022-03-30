class NetworkObjectIdentifier {
    [string] $PhysicalAddress
    [string] $PortId
    [System.Net.IPAddress] $SubnetId

    NetworkObjectIdentifier ([string] $NetworkObjectString) {
        if ([string]::IsNullOrEmpty($NetworkObjectString)) {
            return
        }
        $tryParts = $NetworkObjectString.Split(';')
        if ($tryParts.Count -eq 2) {
            $this.PhysicalAddress = [NetworkObjectIdentifier]::TryConvertToPhysicalAddressString($tryParts[0].Trim())
            $this.PortId = $tryParts[1].Trim()
            return
        }
        $addr = [NetworkObjectIdentifier]::TryConvertToPhysicalAddressString($NetworkObjectString.Trim())
        if (![string]::IsNullOrEmpty($addr)) {
            $this.PhysicalAddress = $addr
            return
        }
        $addr = [System.Net.IPAddress]::Any
        if ([System.Net.IPAddress]::TryParse($NetworkObjectString.Trim(), [ref] $addr)) {
            $this.SubnetId = $addr
            return
        }
        throw
    }

    [string] ToString() {
        $sb = [System.Text.StringBuilder]::new()
        if (![string]::IsNullOrEmpty($this.PhysicalAddress)) {
            [void]$sb.Append($this.PhysicalAddress)
            if (![string]::IsNullOrEmpty($this.PortId)) {
                [void]$sb.Append(';')
                [void]$sb.Append($this.PortId)
            }
            return $sb.ToString()
        }
        if ($null -ne $this.SubnetId) {
            [void]$sb.Append($this.SubnetId.ToString())
        }
        return $sb.ToString()
    }

    hidden static [string] TryConvertToPhysicalAddressString([string]$addressString) {
        try {
            $address = $addressString.ToUpper() -replace '[^A-F0-9\*]', ''
            $addressParts = $address -split '(\w{2})' | Where-Object { ![string]::IsNullOrEmpty($_) }
            if ($addressParts.Count -ne 6) { return '' }
            $address = $addressParts -join '-'
            if ($addressParts[-1].EndsWith('*') -and $addressParts[-1].Length -in @(1, 2)) {
                for ($i = 0; $i -lt ($addressParts.Count - 1); $i++) {
                    if ($addressParts[$i] -notmatch '^[A-F0-9]{2}$') { return '' }
                }
                return $address
            }
            $pa = [Net.NetworkInformation.PhysicalAddress]::Parse($address)
            if ($pa) {
                return [BitConverter]::ToString($pa.GetAddressBytes())
            }
            return ''
        }
        catch {
            return [string]::Empty
        }
    }
}
