function CollectionToString {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory,Position = 0)]
        [ICollection]
        $collection,

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
        $nestParams = @{
            sb = $sb
            indent = $indent + 1
            Compress = $Compress
            indentSize = $indentSize
            indentChar = $indentChar
        }
        $c = $collection.Count
        $null = $sb.Append('@(')
        for ($i = 0; $i -lt $c; $i++) {
            if ($i -ge 1 -and ($i+1) -le $c -and $Compress) { $null = $sb.Append(',') }
            if (!$Compress) {
                $null = $sb.AppendLine()
                $null = $sb.Append($indentChar, ($indentSize * ($indent + 1)))
            }
            $value = $collection[$i]
            ItemToString $value @nestParams
        }
        if($c -gt 0 -and !$Compress) {
            $null = $sb.AppendLine()
            $null = $sb.Append($indentChar, ($indentSize * $indent))
        }
        $null = $sb.Append(')')
    }
}