[Flags()] enum WarningType {
    InvalidInput = 1
    MapsValidation = 2
    MapsValidationDetail = 4
    OnlineChangeError = 8
    DuplicateNetworkObject = 16
    GeneralFailure = 32
    ValidationErrors = 19 # [WarningType]::InvalidInput -bor [WarningType]::MapsValidation -bor [WarningType]::DuplicateNetworkObject
}
