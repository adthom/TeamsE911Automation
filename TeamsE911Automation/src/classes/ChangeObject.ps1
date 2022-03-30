class ChangeObject {
    hidden [string] $_hash
    hidden [CommandType] $CommandType
    hidden [object] $CommandObject
    hidden [void] Init([PSCustomObject] $obj) {
        if ($obj.CommandObject) {
            $this.CommandObject = $obj.CommandObject
            $this.Id = [ItemId]::new($obj.CommandObject.Id)
        }
        if ($null -eq $this.Id -and $null -ne $obj.Id) {
            $this.Id = [ItemId]::new($obj.Id)
        }
        if ($null -eq $this.Id) {
            $this.Id = [ItemId]::new()
        }
        $this.UpdateType = [UpdateType]$obj.UpdateType
        if ($this.UpdateType -eq [UpdateType]::Source) {
            $this.ProcessInfo = [E911DataRow]$obj.ProcessInfo
        }
        if ($this.UpdateType -eq [UpdateType]::Online) {
            $this.ProcessInfo = if ($obj.ProcessInfo -is [string]) { [ScriptBlock]::Create($obj.ProcessInfo) } else { $obj.ProcessInfo }
        }
        if ($obj.CommandType) {
            $this.CommandType = $obj.CommandType
        }
        $d = $obj.DependsOn
        if ($null -eq $d) {
            $d = [DependsOn]::new()
        }
        $this.DependsOn = [DependsOn]::new($d)
    }
    ChangeObject([E911DataRow] $row) {
        $this.Init([PSCustomObject]@{
                Id            = $row.Id
                UpdateType    = [UpdateType]::Source
                ProcessInfo   = $row
                CommandObject = $row
                DependsOn     = [DependsOn]::new()
            })
    }
    ChangeObject([E911DataRow] $row, [DependsOn] $deps) {
        $this.Init([PSCustomObject]@{
                Id            = $row.Id
                UpdateType    = [UpdateType]::Source
                ProcessInfo   = $row
                CommandObject = $row
                DependsOn     = [DependsOn]::new($deps)
            })
    }
    ChangeObject([PSCustomObject] $obj) {
        $this.Init($obj)
    }
    ChangeObject([Hashtable] $obj) {
        $this.Init([PSCustomObject]$obj)
    }
    [ItemId] $Id
    [UpdateType] $UpdateType
    [object] $ProcessInfo
    [DependsOn] $DependsOn

    [string] GetHash() {
        if ([string]::IsNullOrEmpty($this._hash) -and $null -ne $this.ProcessInfo) {
            $this._hash = [Hasher]::GetHash($this.ProcessInfo.ToString())
        }
        return $this._hash
    }

    [bool] Equals($Value) {
        if ($null -eq $Value) {
            return $false
        }
        return $this.GetHash() -eq $Value.GetHash()
    }
}
