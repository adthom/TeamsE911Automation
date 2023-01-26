using namespace System.Collections
using namespace System.Collections.Generic
using namespace System.Management.Automation
using namespace System.Management.Automation.Language
using namespace System.Text
using namespace Microsoft.PowerShell.Commands

function DictionaryToString {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory, Position = 0)]
        [IDictionary]
        $dictionary,

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
        $indentChar = ' ',

        [switch]
        $SortKeys
    )
    process {
        $nestParams = @{
            sb         = $sb
            indent     = $indent + 1
            Compress   = $Compress
            indentSize = $indentSize
            indentChar = $indentChar
            SortKeys   = $SortKeys
        }
        $keySb = [StringBuilder]::new()
        $keyParams = @{
            sb    = $keySb
            AsKey = $true
        }
        $keys = [string[]]($dictionary.Keys)
        if ($SortKeys) {
            [Array]::Sort($keys)
        }
        $c = $keys.Count
        $null = $sb.Append('@{')
        if ($c -gt 0) {
            $keyStrings = @{}
            $keys | ForEach-Object {
                $null = $keySb.Clear()
                ItemToString $_ @keyParams
                $keyStrings[$_] = $keySb.ToString()
            }
            # $longestKey = $keyStrings.Values | Sort-Object -Property { $_.Length } -Descending | Select-Object -First 1
            # $maxLen = $longestKey.Length + 1
            for ($i = 0; $i -lt $c; $i++) {
                if ($i -ge 1 -and ($i + 1) -le $c -and $Compress) { $null = $sb.Append(';') }
                if (!$Compress) {
                    $null = $sb.AppendLine()
                    $null = $sb.Append($indentChar, ($indentSize * ($indent + 1)))
                }
                $key = $keys[$i]
                $keyStr = $keyStrings[$key]
                $null = $sb.Append($keyStr)
                # if (!$Compress) { $null = $sb.Append(' ', ([Math]::Max(1, $maxLen - $keyStr.Length))) }
                $null = $sb.Append(' = ')
                if (!$Compress) { $null = $sb.Append(' ') }
                ItemToString ($dictionary[$key]) @nestParams
            }
            if ($c -gt 0 -and !$Compress) { 
                $null = $sb.AppendLine()
                $null = $sb.Append($indentChar, ($indentSize * $indent))
            }
        }
        $null = $sb.Append('}')
    }
}