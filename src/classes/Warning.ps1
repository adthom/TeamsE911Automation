class Warning {
    [WarningType] $Type
    [string] $Message
    Warning([string] $WarningString) {
        $Parts = $WarningString.Split(':', 2)
        $this.Type = [WarningType]$Parts[0]
        $this.Message = $Parts[1].Trim()
    }
    Warning([WarningType] $Type, [string] $Message) {
        $this.Type = $Type
        $this.Message = $Message.Trim()
    }
    [string] ToString() {
        return ('{0}:{1}' -f $this.Type, $this.Message)
    }
    [bool] Equals($Other) {
        if ($null -eq $Other) {
            return $false
        }
        return $this.Type -eq $Other.Type -and $this.Message -eq $Other.Message
    }
}
