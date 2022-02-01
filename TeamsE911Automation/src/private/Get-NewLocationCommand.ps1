function Get-NewLocationCommand {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true, ValueFromPipeline = $true)]
        [object]
        $NetworkObject,

        [Parameter(Mandatory = $true)]
        [string]
        $LocationIdVariableName,

        [Parameter(Mandatory = $true)]
        [string]
        $CivicAddressId
    )
    process {
        $LocationParams = @{
            CivicAddressId = $CivicAddressId
            Location       = $NetworkObject.Location
        }

        if ($NetworkObject.Elin) {
            $LocationParams['Elin'] = $NetworkObject.Elin
        }

        $LocationCommand = "{0} = New-CsOnlineLisLocation -ErrorAction Stop" -f $LocationIdVariableName
        foreach ($Parameter in $LocationParams.Keys) {
            $LocationCommand += ' -{0} "{1}"' -f $Parameter, ($LocationParams[$Parameter] -replace , '"', '`"')
        }
        $LocationCommand | Write-Output
    }
}
