using namespace System.Collections
using namespace System.Collections.Generic

class WarningList {
    hidden [List[Warning]] $_items
    hidden [bool] $_mapsValidationFailed
    hidden [int] $_validationFailureCount
    hidden [int] $_itemCountWhenLastUpdatedValidationFailureCount

    WarningList() {
        $this._items = [List[Warning]]::new()
        $this._mapsValidationFailed = $false
    }
    WarningList([string] $WarningListString) {
        $this._items = [List[Warning]]::new()
        $this._mapsValidationFailed = $false
        if ([string]::IsNullOrEmpty($WarningListString)) {
            return
        }
        $Parts = $WarningListString.Split(';')
        foreach ($Part in $Parts) {
            $this.Add([Warning]::new($Part.Trim()))
        }
    }
    [void] Clear() {
        $this._items.Clear()
    }
    [int] Count() {
        return $this._items.Count
    }
    [bool] Contains([Warning] $Warning) {
        return $this._items.Contains($Warning)
    }
    [bool] HasWarnings() {
        return $this.Count() -gt 0
    }
    [bool] ValidationFailed() {
        return $this.ValidationFailureCount() -gt 0
    }
    [int] MapsValidationFailed() {
        return $this._mapsValidationFailed
    }
    [int] ValidationFailureCount() {
        if ($null -eq $this._validationFailureCount -or $this._itemCountWhenLastUpdatedValidationFailureCount -eq $this.Count()) {
            $this._validationFailureCount = $this._items.Where({ ($_.Type -band [WarningType]::ValidationErrors) -eq $_.Type }).Count
        }
        return $this._validationFailureCount
    }
    [void] Add([Warning] $Warning) {
        if ($this.Contains($Warning)) { return }
        if ([E911ModuleState]::WriteWarnings) {
            $CallStack = Get-PSCallStack
            if (($CallStack | Where-Object { $_.FunctionName.StartsWith('AddRange') }).Count -eq 0) {
                $CommandName = [E911ModuleState]::GetCommandName()
                Write-Warning ('[{0}] {1}' -f $CommandName, $Warning.ToString())
            }
        }
        if (!$this._mapsValidationFailed -and $Warning.Type -eq [WarningType]::MapsValidation) {
            $this._mapsValidationFailed = $true
        }
        $this._items.Add($Warning)
    }
    [void] AddAsString([string]$Warning) {
        $this.Add([Warning]::new($Warning))
    }
    [void] Add([WarningType] $Type, [string] $Message) {
        $this.Add([Warning]::new($Type, $Message))
    }
    [void] AddRange([IEnumerable[Warning]] $Ids) {
        foreach ($Id in $Ids) {
            $this.Add($Id)
        }
    }
    [void] AddRangeAsString([IEnumerable[string]] $Ids) {
        foreach ($Id in $Ids) {
            $this.AddAsString($Id)
        }
    }
    [void] AddRange([WarningList] $WarningList) {
        foreach ($Id in $WarningList.GetEnumerator()) {
            $this.Add($Id)
        }
    }
    [void] Insert([int]$Position, [Warning] $Warning) {
        $this._items.Insert($Position, $Warning)
    }
    [IEnumerator] GetEnumerator() {
        return $this._items.GetEnumerator()
    }
    [IEnumerator] GetEnumerator([int] $Index, [int] $Count) {
        return $this._items.GetEnumerator($Index, $Count)
    }
    [void] Remove([Warning] $Warning) {
        $this._items.Remove($Warning)
    }
    [string] ToString() {
        return ($this._items -join ';')
    }
}
