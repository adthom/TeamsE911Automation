using namespace System.Collections
using namespace System.Collections.Generic
using namespace System.Management.Automation
using namespace System.Management.Automation.Language
using namespace System.Text
using namespace Microsoft.PowerShell.Commands

function ItemToString {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory, ValueFromPipeline, Position = 0)]
        [AllowNull()]
        [AllowEmptyCollection()]
        [AllowEmptyString()]
        [object]
        $item,

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
        
        [Parameter()]
        [switch]
        $AsKey,

        [switch]
        $SortKeys
    )
    process {
        $itemSb = [StringBuilder]::new()
        $nestParams = @{
            sb         = $itemSb
            # indent = $indent + 1
            indent     = $indent
            Compress   = $AsKey -or $Compress
            indentSize = $indentSize
            indentChar = $indentChar
        }
        if ($null -eq $item) {
            if ($AsKey) { throw "`$null is not a valid key! ($item)" }
            $null = $itemSb.Append('$null')
        }
        elseif ($item -is [IDictionary]) {
            DictionaryToString $item @nestParams -SortKeys:$SortKeys
        }
        elseif ($item -is [ICollection] -or (
            ($t = $item.GetType()).DeclaredProperties.Where({ $_.Name -eq 'Count' }, 'First', 1).Count -gt 0 -and 
                $t.DeclaredMembers.Where({ $_.Name -eq 'GetEnumerator' }, 'First', 1).Count -gt 0)) {
            CollectionToString $item @nestParams
        }
        elseif ($item -is [string]) {
            StringToString $item @nestParams
        }
        elseif ($item -is [ValueType]) {
            ValueTypeToString $item @nestParams
        }
        else {
            $itemType = $item.GetType().FullName -replace '^System\.', ''
            $null = $itemSb.Append('[')
            $null = $itemSb.Append($itemType)
            $null = $itemSb.Append(']')
            $hash = [ordered]@{}
            foreach ($prop in $item.PSObject.Properties.Name) {
                $hash[$prop] = $item.$prop
            }
            DictionaryToString $hash @nestParams
        }
        $itemString = $itemSb.ToString()
        if ($AsKey) {
            if ($item -is [string] -and $itemString.Trim("'") -match '^[A-Z_]\w*$') {
                $itemString = $itemString.Trim("'")
            }
            elseif ($itemString.StartsWith('@') -or $itemString.StartsWith('[')) {
                $itemString = '(' + $itemString + ')'
            }
        }
        $null = $sb.Append($itemString)
    }
}