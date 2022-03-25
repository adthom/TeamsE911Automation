function Compare-DoubleFuzzy {
    [CmdletBinding()]
    [OutputType([bool])]
    param(
        [Parameter(Mandatory = $true, Position = 0)]
        [double]
        $ReferenceNum,

        [Parameter(Mandatory = $true, Position = 1)]
        [double]
        $DifferenceNum,

        [int]
        $DecimalPlaces = 3  # 3 should be within < 860ft, 4 digits gets to < 86ft, 5 digits gets to < 8.6ft
    )

    $Delta = [Math]::Abs($ReferenceNum - $DifferenceNum)
    $FmtString = [string]::new("0", $DecimalPlaces)
    $IsFuzzyMatch = [Math]::Round($Delta, $DecimalPlaces) -eq 0
    if (!$IsFuzzyMatch -and $ReferenceNum -ne 0.0) {
        Write-Verbose ("ReferenceNum: {0:0.$FmtString}`tDifferenceNum: {1:0.$FmtString}`tDiff: {2:0.$FmtString}" -f $ReferenceNum, $DifferenceNum, $Delta)
    }
    return $IsFuzzyMatch
}
