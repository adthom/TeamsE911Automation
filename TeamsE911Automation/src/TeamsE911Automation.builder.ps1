# This PSM1 is for debugging purposes only
# This is replaced in release builds by the build.ps1 process

$ModuleName = (($MyInvocation.ScriptName -split '\\')[-1] -split '\.',2)[0]
$BuildPath = Join-Path -Path (Split-Path -Path $PSScriptRoot -Parent) -ChildPath 'build'
$OutputFile = "${PSScriptRoot}\${ModuleName}.psm1"
# Clear the module file first
Set-Content -Path $OutputFile -Value '' | Out-Null

if (![string]::IsNullOrWhiteSpace(($DisclaimerText = Get-Content -Path "${BuildPath}\disclaimer.txt" -ErrorAction SilentlyContinue))) {
    $DisclaimerText = ($DisclaimerText -split "`n").ForEach({"# $_"}) -join "`n"
    Set-Content -Path $OutputFile -Value $DisclaimerText
    Add-Content -Path $OutputFile -Value ''
}

# First load any classes if present
$Classes = @( Get-ChildItem -Path $PSScriptRoot\classes\*.ps1 -ErrorAction SilentlyContinue )
# Dot source the files
foreach ($class in $Classes) {
    try {
        Write-Verbose "Importing $($class.FullName)"
        Add-Content -Path $OutputFile -Value "# (imported from $($class.FullName -replace [Regex]::Escape($PSScriptRoot),'.'))" | Out-Null
        $Raw = Get-Content -Path $class.FullName -Raw
        $Raw = ($Raw.Trim() -replace '(\r?\n){3,}',([Environment]::NewLine + [Environment]::NewLine)) + [Environment]::NewLine
        $Raw | Add-Content -Path $OutputFile | Out-Null
    }
    catch {
        Write-Error -Message "Failed to import class $($import.FullName): $_"
    }
}

# Get public and private function definition files.
$Public = @( Get-ChildItem -Path $PSScriptRoot\public\*.ps1 -ErrorAction SilentlyContinue )
$Private = @( Get-ChildItem -Path $PSScriptRoot\private\*.ps1 -ErrorAction SilentlyContinue )

# Dot source the files
foreach ($import in @($Public + $Private)) {
    try {
        Write-Verbose "Importing $($import.FullName)"
        Add-Content -Path $OutputFile -Value "# (imported from $($import.FullName -replace [Regex]::Escape($PSScriptRoot),'.'))" | Out-Null
        $Raw = Get-Content -Path $import.FullName -Raw
        $Raw = ($Raw.Trim() -replace '(\r?\n){3,}',([Environment]::NewLine + [Environment]::NewLine)) + [Environment]::NewLine
        $Raw | Add-Content -Path $OutputFile | Out-Null
    }
    catch {
        Write-Error -Message "Failed to import function $($import.FullName): $_"
    }
}

# Here I might...
# Read in or create an initial config file and variable
# Export Public functions ($Public.BaseName) for WIP modules
# Set variables visible to the module and its functions only
foreach ($import in @($Public + $Private)) {
    Add-Content -Path $OutputFile -Value "Export-ModuleMember -Function $($import.BaseName)" | Out-Null
}

if (![string]::IsNullOrWhiteSpace(($AdditionalModuleChecks = Get-Content -Path "${BuildPath}\modulechecks.ps1" -ErrorAction SilentlyContinue))) {
    Add-Content -Path $OutputFile -Value ''
    Add-Content -Path $OutputFile -Value $AdditionalModuleChecks
}