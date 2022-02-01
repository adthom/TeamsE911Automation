function Get-CsE911RowString {
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [object]
        $Row
    )
    if ($null -eq $Row) { return [string]::Empty }
    $Row | Select-Object -Property * -ExcludeProperty EntryHash | ConvertTo-Json -Compress
}
