function StringToString {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory,Position = 0)]
        [string]
        $string,

        [Parameter(Mandatory)]
        [StringBuilder]
        $sb,

        [Parameter()]
        [int]
        $indent = 0,

        [Parameter()]
        [switch]
        $Compress,

        [Parameter()]
        [int]
        $indentSize = 4,

        [Parameter()]
        [char]
        $indentChar = ' '
    )
    process {
        $str = $string -replace "'","''"
        $str = $str -replace "`r?`n", '''+"`r`n"+'''
        $null = $sb.Append("'")
        $null = $sb.Append($str)
        $null = $sb.Append("'")
    }
}