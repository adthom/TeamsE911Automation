function ConvertTo-QueryString {
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute("PSUseCompatibleTypes", "", MessageId = "System.Web.HttpUtility loaded via module manifest")]
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [hashtable]
        $QueryHash
    )

    $TempList = [System.Collections.Generic.List[string]]::new()
    foreach ( $Parameter in $QueryHash.Keys ) {
        $Value = $QueryHash[$Parameter] -join ','
        $TempList.Add(('{0}={1}' -f $Parameter, [System.Web.HttpUtility]::UrlEncode($Value))) | Out-Null
    }
    $queryString = $TempList -join '&'
    $queryString
}
