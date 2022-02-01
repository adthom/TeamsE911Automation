function Get-DependencyListFromString {
    param (
        $Change
    )
    $Change.DependsOn -split ';' | Where-Object { ![string]::IsNullOrEmpty($_) } | ForEach-Object { $_.Trim() }
}
