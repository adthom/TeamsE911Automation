# using module ..\..\..\modules\PSClassExtensions\PSClassExtensions.psd1
# # using module @{ModuleName='Microsoft.PowerShell.Utility';ModuleVersion='5.0.0.0'}
# using namespace System.Management.Automation
# using namespace System.Collections.Generic
# using namespace Microsoft.PowerShell.Commands

# [Cmdlet([VerbsCommon]::Get, 'CsE911OnlineConfiguration')]
# class GetCsE911OnlineConfiguration : PSClassCmdlet {
#     [Parameter(Mandatory = $false, HelpMessage = 'Include orphaned configuration')]
#     [switch] $IncludeOrphanedConfiguration

#     hidden [HashSet[string]] $FoundLocationHashes
#     hidden [HashSet[string]] $FoundAddressHashes

#     GetCsE911OnlineConfiguration() : base('Getting Existing Configuration') {}

#     [void] BeginProcessing() {
#         ([PSClassCmdlet]$this).BeginProcessing()
#         $this.AssertTeamsIsConnected()
#         # initialize caches
#         # [E911ModuleState]::ShouldClear = $true
#         [E911ModuleState]::InitializeCaches($this.FunctionHost)
#         $this.FoundLocationHashes = @()
#         $this.FoundAddressHashes = @()
#     }

#     [void] EndProcessing() {
#         $generatorHelper = [PSFunctionHost]::StartNew($this.FunctionHost, 'Generating Configuration')
#         $generatorHelper.Total = [E911ModuleState]::OnlineNetworkObjects.Count
#         foreach ($nObj in [E911ModuleState]::OnlineNetworkObjects.Values) {
#             $generatorHelper.Update($true, 'From Network Objects')
#             if ($null -ne $nObj._location) {
#                 [void]$this.FoundLocationHashes.Add($nObj._location.GetHash())
#                 if ($null -ne $nObj._location._address) {
#                     [void]$this.FoundAddressHashes.Add($nObj._location._address.GetHash())
#                 }
#             }
#             $generatorHelper.WriteVerbose(('Processing {0}:{1}' -f $nObj.Type, $nObj.Identifier))
#             if ($null -eq $nObj._location -or $null -eq $nObj._location._address -or ($nObj._isOnline -and !($nObj._location._isOnline -and $nObj._location._address._isOnline))) {
#                 if (!$this.IncludeOrphanedConfiguration) {
#                     continue
#                 }
#                 $nObj.Warning.Add([WarningType]::GeneralFailure, 'Orphaned Network Object')
#             }

#             # $Row = [E911DataRow]::new($nObj)
#             # $Formatted = $Row.ToString() | ConvertFrom-Json
#             # $this.WriteObject($Formatted)
#             $this.WriteRowToOutput([E911DataRow]::new($nObj))
#         }

#         $generatorHelper.Restart()
#         $generatorHelper.Total = [E911ModuleState]::OnlineLocations.Count
#         foreach ($location in [E911ModuleState]::OnlineLocations.Values) {
#             $generatorHelper.Update($true, 'From Locations')
#             if ($this.FoundLocationHashes.Contains($location.GetHash())) {
#                 continue
#             }
#             [void]$this.FoundLocationHashes.Add($location.GetHash())
#             if ($null -eq $location._address -or ($location._isOnline -and !$location._address._isOnline) -and !$this.IncludeOrphanedConfiguration) {
#                 # $generatorHelper.WriteWarning(('{0} is orphaned!' -f $location.Location))
#                 continue
#             }
#             if (!$this.FoundAddressHashes.Contains($location._address.GetHash())) {
#                 [void]$this.FoundAddressHashes.Add($location._address.GetHash())
#             }
#             if ([string]::IsNullOrEmpty($location.Location)) {
#                 # don't output the default location if there is nothing associated
#                 continue
#             }
#             # $Row = [E911DataRow]::new($location)
#             # $Formatted = $Row.ToString() | ConvertFrom-Json
#             # $this.WriteObject($Formatted)
#             $this.WriteRowToOutput([E911DataRow]::new($location))
#         }

#         $generatorHelper.Restart()
#         $generatorHelper.Total = [E911ModuleState]::OnlineAddresses.Count
#         foreach ($address in [E911ModuleState]::OnlineAddresses.Values) {

#             $generatorHelper.Update($true, 'From Addresses')
#             if ($this.FoundAddressHashes.Contains($address.GetHash())) {
#                 continue
#             }
#             [void]$this.FoundAddressHashes.Add($address.GetHash())
#             # $Row = [E911DataRow]::new($address)
#             # $Formatted = $Row.ToString() | ConvertFrom-Json
#             # $this.WriteObject($Formatted)
#             $this.WriteRowToOutput([E911DataRow]::new($address))
#         }
#         # $generatorHelper.Complete()
#         $generatorHelper.WriteVerbose('Finished')
#         ([PSClassCmdlet]$this).EndProcessing()
#     }

#     hidden [void] AssertTeamsIsConnected() {
#         try {
#             [Microsoft.TeamsCmdlets.Powershell.Connect.TeamsPowerShellSession]::ClientAuthenticated()
#             # maybe check for token expiration here?
#         }
#         catch {
#             throw "Run Connect-MicrosoftTeams prior to executing this script!"
#         }
#     }

#     hidden [void] WriteRowToOutput([E911DataRow] $Row) {
#         $jsonCmd = [ConvertFromJsonCommand]::new()
#         $Formatted = $Row.ToString() #| ConvertFrom-Json
#         $jsonCmd.InputObject = $Formatted
#         ([Cmdlet]$this).WriteObject($jsonCmd.Invoke())
#     }
# }