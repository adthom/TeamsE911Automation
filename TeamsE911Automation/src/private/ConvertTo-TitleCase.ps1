function ConvertTo-TitleCase {
    [CmdletBinding()]
    [OutputType([string])]
    param (
        [Parameter(Mandatory = $true, Position = 0, ValueFromPipeline = $true)]
        [string]
        $String
    )
    process {
        $parts = $String -split '(\s+)'
        $newStringSb = [Text.StringBuilder]::new()
        for ($i = 0; $i -lt $parts.Length; $i++) {
            $str = $parts[$i]
            if ([string]::IsNullOrWhiteSpace($str)) {
                $newStringSb.Append($str) | Out-Null
                continue
            }
            $str = $parts[$i]
            $newStringSb.Append($str[0].ToString().ToUpper()) | Out-Null
            if ($str.Length -gt 1) {
                $newStringSb.Append($str.Substring(1, $str.Length - 1).ToLower()) | Out-Null
            }
        }
        return $newStringSb.ToString()
    }
}
