using namespace System.Collections
using namespace System.Collections.Generic

class DependsOn {
    hidden [List[ItemId]] $_items
    DependsOn() {
        $this._items = [List[ItemId]]@()
    }
    DependsOn([string] $DependsOnString) {
        $this._items = [List[ItemId]]@()
        if ([string]::IsNullOrEmpty($DependsOnString)) {
            return
        }
        $Parts = $DependsOnString.Split(';')
        foreach ($Part in $Parts) {
            $this.Add([ItemId]::new($Part.Trim()))
        }
    }
    DependsOn([DependsOn] $DependsOn) {
        $this._items = [List[ItemId]]@()
        if ($DependsOn.Count() -eq 0) {
            return
        }
        $this.AddRange($DependsOn._items)
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
    [void] AddRange([IEnumerable[ItemId]] $Ids) {
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
    [IEnumerator] GetEnumerator() {
        return $this._items.GetEnumerator()
    }
    [IEnumerator] GetEnumerator([int] $Index, [int] $Count) {
        return $this._items.GetEnumerator($Index, $Count)
    }
    [string] ToString() {
        return ($this._items -join ';')
    }
}
