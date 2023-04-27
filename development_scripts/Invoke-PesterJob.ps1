#Requires -Modules @{ModuleName='Pester';ModuleVersion='5.0.0'}

function Invoke-PesterJob {
    [CmdletBinding(DefaultParameterSetName='Simple')]
    param(
        [Parameter(ParameterSetName='Legacy', Position=0)]
        [Parameter(ParameterSetName='Simple', Position=0)]
        [Alias('Script')]
        [string[]]
        ${Path},
    
        [Parameter(ParameterSetName='Simple')]
        [string[]]
        ${ExcludePath},
    
        [Parameter(ParameterSetName='Legacy', Position=4)]
        [Parameter(ParameterSetName='Simple')]
        [Alias('Tags','Tag')]
        [string[]]
        ${TagFilter},
    
        [Parameter(ParameterSetName='Legacy')]
        [Parameter(ParameterSetName='Simple')]
        [string[]]
        ${ExcludeTagFilter},
    
        [Parameter(ParameterSetName='Simple')]
        [Parameter(ParameterSetName='Legacy', Position=1)]
        [Alias('Name')]
        [string[]]
        ${FullNameFilter},
    
        [Parameter(ParameterSetName='Simple')]
        [switch]
        ${CI},
    
        [Parameter(ParameterSetName='Simple')]
        [ValidateSet('Diagnostic','Detailed','Normal','Minimal','None')]
        [string]
        ${Output},
    
        [Parameter(ParameterSetName='Legacy')]
        [Parameter(ParameterSetName='Simple')]
        [switch]
        ${PassThru},
    
        [Parameter(ParameterSetName='Simple')]
        [Pester.ContainerInfo[]]
        ${Container},
    
        [Parameter(ParameterSetName='Advanced')]
        [PesterConfiguration]
        ${Configuration},
    
        [Parameter(ParameterSetName='Legacy', Position=2)]
        [switch]
        ${EnableExit},
    
        [Parameter(ParameterSetName='Legacy')]
        [System.Object[]]
        ${CodeCoverage},
    
        [Parameter(ParameterSetName='Legacy')]
        [string]
        ${CodeCoverageOutputFile},
    
        [Parameter(ParameterSetName='Legacy')]
        [string]
        ${CodeCoverageOutputFileEncoding},
    
        [Parameter(ParameterSetName='Legacy')]
        [ValidateSet('JaCoCo')]
        [string]
        ${CodeCoverageOutputFileFormat},
    
        [Parameter(ParameterSetName='Legacy')]
        [switch]
        ${Strict},
    
        [Parameter(ParameterSetName='Legacy')]
        [string]
        ${OutputFile},
    
        [Parameter(ParameterSetName='Legacy')]
        [ValidateSet('NUnitXml','NUnit2.5','JUnitXml')]
        [string]
        ${OutputFormat},
    
        [Parameter(ParameterSetName='Legacy')]
        [switch]
        ${Quiet},
    
        [Parameter(ParameterSetName='Legacy')]
        [System.Object]
        ${PesterOption},
    
        [Parameter(ParameterSetName='Legacy')]
        [Pester.OutputTypes]
        ${Show}
    )
    $params = $PSBoundParameters
    Start-Job -ScriptBlock { Set-Location $using:pwd; Invoke-Pester @using:params } | Receive-Job -Wait -AutoRemoveJob -InformationAction SilentlyContinue
}
Set-Alias ipj Invoke-PesterJob