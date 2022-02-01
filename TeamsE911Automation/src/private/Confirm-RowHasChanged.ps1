function Confirm-RowHasChanged {
    [CmdletBinding()]
    [OutputType([bool])]
    param (
        [object]
        $Row
    )
    if ([string]::IsNullOrEmpty($Row.EntryHash)) {
        # if hash is not present, assume row is new/changed
        return $true
    }
    $Hash = Get-CsE911RowHash -Row $Row
    $HashesMatch = $Hash -eq $Row.EntryHash
    return !$HashesMatch
}
