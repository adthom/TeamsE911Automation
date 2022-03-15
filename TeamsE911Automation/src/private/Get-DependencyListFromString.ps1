function Get-DependencyListFromString {
    param (
        $Change
    )
    ($Change.DependsOn -split ';').Where({ ![string]::IsNullOrEmpty($_) }).ForEach('Trim')
}
