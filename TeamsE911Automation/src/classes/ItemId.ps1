class ItemId {
    hidden [string] $_variableName

    # override init to allow for pseudo constructor chaining
    hidden Init([Object]$inputId = $null) {
        if ($inputId -is [ItemId]) {
            $this.Id = $inputId.Id
            return
        }
        if ([string]::IsNullOrEmpty($inputId) -or !($inputId -is [string] -or $inputId -is [Guid])) {
            $inputId = [Guid]::NewGuid()
        }
        $this.Id = [Guid]$inputId
    }
    ItemId() {
        $this.Init($null)
    }
    ItemId([Object]$inputId = $null) {
        $this.Init($inputId)
    }

    [Guid] $Id

    [string] VariableName() {
        if ([string]::IsNullOrEmpty($this._variableName)) { $this._variableName = '${0}' -f $this.ToString().Replace('-', '') }
        return $this._variableName
    }
    [string] Trim() {
        return $this.ToString().Trim()
    }
    [string] ToString() {
        if ($null -eq $this.Id) { $this.Id = [Guid]::NewGuid() }
        return $this.Id.Guid
    }
    [bool] Equals($Other) {
        if ($null -eq $Other) {
            return $false
        }
        return $this.Id -eq $Other.Id
    }
}
