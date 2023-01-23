function ValueTypeToString {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory,Position = 0)]
        [ValueType]
        $value,

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
        $type = $value.GetType().Name -replace '^System\.',''
        $fmtString = switch ($type) {
            'TimeSpan' { "[$_]'{0}'"; break }
            {$_.StartsWith('Date') -or $_.StartsWith('Time')} { "[$_]'{0:o}'"; break }
            {$_.EndsWith('byte')} { "[$_]0X{0:X2}"; break }
            'Int32' { '{0}'; break }
            'Int64' { '{0}l'; break }
            'Double' { '{0:#.0}'; break }
            'Single' { '[float]{0}'; break }
            'Decimal' { '{0}d'; break }
            'BigInteger' { '[bigint]{0}'; break }
            # # only in 6.2+
            # 'sbyte' { '0X{0:X2}y'; break }
            # 'byte' { '0X{0:X2}uy'; break }
            # 'Int16' { '{0}s'; break }
            # 'Int16' { '[short]{0}'; break }
            # 'UInt16' { '{0}us'; break }
            # 'UInt16' { '[ushort]{0}'; break }
            # 'UInt32' { '{0}u'; break }
            # 'UInt32' { '[uint]{0}'; break }
            # 'UInt64' { '{0}ul'; break }
            # 'UInt64' { '[ulong]{0}'; break }
            # 'BigInteger' { '{0}n'; break }
            default { "[$_]{0}" }
        }
        $null = $sb.AppendFormat($fmtString, $value)
    }
}