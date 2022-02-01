# This PSM1 is for debugging purposes only
# This is replaced in release builds by the build.ps1 process

#Get public and private function definition files.
$Public = @( Get-ChildItem -Path $PSScriptRoot\Public\*.ps1 -ErrorAction SilentlyContinue )
$Private = @( Get-ChildItem -Path $PSScriptRoot\Private\*.ps1 -ErrorAction SilentlyContinue )

#Dot source the files
foreach ($import in @($Public + $Private)) {
    try {
        # Write-Verbose "Importing $($import.FullName)" -Verbose
        . $import.FullName
    }
    catch {
        Write-Error -Message "Failed to import function $($import.FullName): $_"
    }
}

# Here I might...
# Read in or create an initial config file and variable
# Export Public functions ($Public.BaseName) for WIP modules
# Set variables visible to the module and its functions only
Export-ModuleMember -Function @($Public.BaseName + $Private.BaseName)