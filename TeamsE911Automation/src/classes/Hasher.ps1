class Hasher {
    hidden static $_hashAlgorithm = [System.Security.Cryptography.HashAlgorithm]::Create('sha256')

    static [string] GetHash([string] $string) {
        return [Convert]::ToBase64String([Hasher]::_hashAlgorithm.ComputeHash([Text.Encoding]::UTF8.GetBytes($string)))
    }
}
