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
    $HashGenerator = [System.Security.Cryptography.HashAlgorithm]::Create('sha256')
    return [Convert]::ToBase64String($HashGenerator.ComputeHash([Text.Encoding]::UTF8.GetBytes($String)))
}
