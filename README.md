# Teams E911 Automation Workflow module
## This repo provides an example of how to create an automated workflow to input
### THIS IS PURELY SAMPLE CODE

See the the required data format [here](./scripts/StringlyTypedDataStructure.txt)

This module contains 4 cmdlets:
1. Get-CsE911NeededChange => This cmdlet processes all the LIS information provided in the source CSV, along with all LIS information already confiigured in Teams, determines what changes/updates are required and creates all the PowerShell one-liners to execute the changes/updates to the online and source environments
2. Set-CsE911OnlineChange => This cmdlet executes all the changes/updates online (in Teams service)
3. Set-CsE911SourceChange => This cmdlet executes all the changes/updates to the source (CSV) - this writes any Warnings or EntryHashes back to the source data that can then be exported to overwrite the source CSV with the latest updates. In the future, if the same CSV is processed, any rows with an EntryHash that matches the current row with no be re-processed.
4. Export-CsE911OnlineConfiguration => This cmdlet allows exporting all infromation from Teams in the source data format required for the TeamsE911Automation module to process and can be used as a potential backup source file


## Below is a sample workflow leveraging CSV files
#### Set environment variable with your own Azure Maps Api Key
the TeamsE911Automation module leverages Azure Maps to perform civic address validation and obtain proper geocodes. This requires the use of your own Azure Maps api key. More information on obtaining an Azure Maps api key can be found here: https://docs.microsoft.com/en-us/azure/azure-maps/how-to-manage-authentication
```powershell
$env:AZUREMAPS_API_KEY = '<UPDATE_WITH_API_KEY>'
```

#### Import TeamsE911Automation module.
```powershell
Import-Module "..\Module\TeamsE911Automation"
```
#### Connect to Microsoft Teams
The TeamsE911Automation module requires using the MicrosoftTeams PowerShell module to execute all required changes/updates against the Teams service
```powershell
Connect-MicrosoftTeams
```

#### Set path to source data csv
```powershell
$CsvPath1 = "$PSScriptRoot\e911LisSourceData.csv"
```

#### Import the source csv data and store in a variable
```powershell
$RawInput1 = Import-Csv -Path $CsvPath1
```

#### Execute lis automation based on source data
You can choose to execute each step of the process (Get-CsE911NeededChange => Set-CsE911OnlineChange => Set-CsE911SourceChange) individually, or pipe them together to execute in a single run. The following example chains the 3 steps in a single execution.
#### Process the imported csv data to analyze the current teams tenant configuration and prepare changes to online and source data
```powershell
$RawOutput1 = $RawInput1 | Get-CsE911NeededChange | # determine any needed changes
    Set-CsE911OnlineChange |                        # process online changes
    Set-CsE911SourceChange -RawInput $RawInput1     # process source changes (adding any warning data if a provided input failed to process for any reason)
```

#### Write $RawOutput1 back to source data
```powershell
$RawOutput1 | Export-Csv -Path $CsvPath1 -NoTypeInformation
```

#### Display count of processed inputs (rows from csv) and outputs (changes to be made to online and source data) 
```powershell
Write-Information "$($RawInput1.Count) inputs provided to pipeline" -InformationAction Continue
Write-Information "$($RawOutput1.Count) outputs generated from pipeline" -InformationAction Continue
```
