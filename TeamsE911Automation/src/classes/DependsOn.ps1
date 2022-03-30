class DependsOn {
    hidden [System.Collections.Generic.List[ItemId]] $_items
    DependsOn() {
        $this._items = [System.Collections.Generic.List[ItemId]]::new()
    }
    DependsOn([string] $DependsOnString) {
        $this._items = [System.Collections.Generic.List[ItemId]]::new()
        if ([string]::IsNullOrEmpty($DependsOnString)) {
            return
        }
        $Parts = $DependsOnString.Split(';')
        foreach ($Part in $Parts) {
            $this.Add([ItemId]::new($Part.Trim()))
        }
    }
    [void] Clear() {
        $this._items.Clear()
    }
    [bool] Contains([ItemId] $Id) {
        return $this._items.Contains($Id)
    }
    [int] Count() {
        return $this._items.Count
    }
    [void] Add([ItemId] $Id) {
        if ($this._items.Contains($Id)) { return }
        $this._items.Add($Id)
    }
    [void] AddRange([System.Collections.Generic.IEnumerable[ItemId]] $Ids) {
        foreach ($Id in $Ids) {
            $this.Add($Id)
        }
    }
    [void] AddRange([DependsOn] $DependsOn) {
        foreach ($Id in $DependsOn.GetEnumerator()) {
            $this.Add($Id)
        }
    }
    [void] AddAsString([string] $Id) {
        $this.Add([ItemId]::new($Id))
    }
    [void] Remove([ItemId] $Id) {
        $this._items.Remove($Id)
    }
    [void] Insert([int]$Position, [ItemId] $Id) {
        $this._items.Insert($Position, $Id)
    }
    [System.Collections.IEnumerator] GetEnumerator() {
        return $this._items.GetEnumerator()
    }
    [System.Collections.IEnumerator] GetEnumerator([int] $Index, [int] $Count) {
        return $this._items.GetEnumerator($Index, $Count)
    }
    [string] ToString() {
        return ($this._items -join ';')
    }
}
