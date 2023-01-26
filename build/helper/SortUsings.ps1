function SortUsings {
    [CmdletBinding()]
    [OutputType([string])]
    param (
        [Parameter(Mandatory, ValueFromPipeline)]
        [string[]]
        $Usings
    )
    begin {
        $NewUsings = [Collections.Generic.Dictionary[string, Collections.Generic.HashSet[string]]]@{}
    }
    process {
        foreach ($using in $Usings) {
            $parts = ($using -split '\s+', 3)
            $type = $parts[1].ToLower()
            if (!$NewUsings.ContainsKey($type)) {
                $NewUsings[$type] = @()
            }
            $null = $NewUsings[$type].Add($parts[2])
        }
    }
    end {
        $usingTypes = [string[]]$NewUsings.Keys
        $usingTypes = [string[]]($usingTypes | Sort-Object -Property { [Management.Automation.Language.UsingStatementKind]$_ })
        foreach ($type in $usingTypes) {
            $targets = [string[]]($NewUsings[$type])
            $sortedTargets = [Collections.Generic.List[string]]@()
            foreach ($target in $targets) {
                $i = 0
                while ($true) {
                    if ($i -ge $sortedTargets.Count) {
                        $sortedTargets.Add($target)
                        break
                    }
                    $current = $sortedTargets[$i]
                    if ($current.StartsWith($target)) {
                        $sortedTargets.Insert($i, $target)
                        break
                    }
                    if ($target.StartsWith($current)) {
                        $sortedTargets.Insert($i + 1, $target)
                        break
                    }
                    if ($target -lt $current) {
                        $sortedTargets.Insert($i, $target)
                        break
                    }
                    $i++
                }
            }
            foreach ($target in $sortedTargets) {
                'using {0} {1}' -f $type, $target | Write-Output
            }
        }
    }
}