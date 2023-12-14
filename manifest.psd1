@{
    # only the first 2 components of this will be used to determine the version number on build
    ModuleVersion        = '0.9'

    # these fields will be merged with the detected usage from requires statements
    CompatiblePSEditions = 'Desktop', 'Core'
    PowerShellVersion    = '5.1'
    RequiredModules      = @('MicrosoftTeams')
    RequiredAssemblies   = 'System.Net.Http', 'System.Web'
    # NestedModules = @()
    FunctionsToExport    = @()

    # these are only set in this file
    GUID                 = 'e3c5735b-f47f-4e07-8a8a-a80015995961'
    Author               = 'Andy Thompson (andthom)'
    CompanyName          = 'Microsoft'
    Copyright            = '(c) 2022 Microsoft Corporation. All rights reserved.'
    Description          = 'TeamsE911Automation project'
    # ScriptsToProcess = @()
    # TypesToProcess = @()
    # FormatsToProcess = @()
    CmdletsToExport      = @()
    VariablesToExport    = '*'
    AliasesToExport      = @()
    PrivateData          = @{
        PSData = @{}
    }
}
