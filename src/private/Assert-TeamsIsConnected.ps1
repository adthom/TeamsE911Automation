function Assert-TeamsIsConnected {
    [CmdletBinding()]
    param()
    try {
        [Microsoft.TeamsCmdlets.Powershell.Connect.TeamsPowerShellSession]::ClientAuthenticated()
    }
    catch {
        throw 'Run Connect-MicrosoftTeams prior to executing this script!'
    }
}