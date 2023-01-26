function Assert-TeamsIsConnected {
    [CmdletBinding()]
    param()
    try {
        [Microsoft.TeamsCmdlets.Powershell.Connect.TeamsPowerShellSession]::ClientAuthenticated()
        # maybe check for token expiration here?
    }
    catch {
        throw "Run Connect-MicrosoftTeams prior to executing this script!"
    }
}
