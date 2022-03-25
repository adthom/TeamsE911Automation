function Get-StringHash {
    [CmdletBinding()]
    [OutputType([string])]
    param (
        [string]
        $String
    )
    if ([string]::IsNullOrEmpty($String)) {
        return [string]::Empty
    }
    if ($null -eq $Script:HashGenerator) {
        $Script:HashGenerator = [System.Security.Cryptography.HashAlgorithm]::Create('sha256')
    }
    return [Convert]::ToBase64String($Script:HashGenerator.ComputeHash([Text.Encoding]::UTF8.GetBytes($String)))
}
