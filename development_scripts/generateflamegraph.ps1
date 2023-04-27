param (
    $Tracer,

    [string]
    $GraphTitle = 'Flame Graph',

    [string]
    $OutputPath = (Join-Path $PSScriptRoot 'flamegraph.svg')
)
begin {
    class StringArrayComparer : Collections.Generic.IComparer[string[]] {
        [int] Compare([string[]] $x, [string[]] $y) {
            for ($i = 0; $i -lt $x.Length; $i++) {
                if ($i -ge $y.Length) { return 1 }
                if ($x[$i] -ne $y[$i]) { return $x[$i].CompareTo($y[$i]) }
            }
            if ($y.Length -gt $x.Length) { return -1 }
            return 0
        }
    }
    
    class rgbcolor {
        [byte] $R
        [byte] $G
        [byte] $B
        rgbcolor() {}
        rgbcolor([byte] $r, [byte] $g, [byte] $b) {
            $this.R = $r
            $this.G = $g
            $this.B = $b
        }
        rgbcolor([string] $rgbcolor) {
            $rgbcolor = $rgbcolor.Substring(4).TrimEnd(')')
            $parts = $rgbcolor.Split(',')
            $this.R = [byte]($parts[0])
            $this.G = [byte]($parts[1])
            $this.B = [byte]($parts[2])
        }
        [string] ToString() {
            return "rgb($($this.R),$($this.G),$($this.B))"
        }
    }
    
    class FlameGraphBar {
        [string] $Title
        [int] $Samples
        [int] $XIndexStart
        [int] $XIndexEnd
        [int] $YIndex
        FlameGraphBar([object[]] $arguments) {
            $method = $arguments[0][$arguments[1]]
            # $this.Title = '{0}.{1} {2}[{3}]' -f $method.Source, $method.Method, $method.File, $method.Line
            $this.Title = '{0}.{1}[{2}]' -f $method.Source, $method.Method, $method.Line
            $this.Samples = $arguments[2]
            $this.XIndexStart = $arguments[3]
            $this.XIndexEnd = $arguments[4]
            $this.YIndex = $arguments[5]
        }
    
        FlameGraphBar([string] $title, [object[]] $arguments) {
            # $this.Title = '{0}.{1} {2}[{3}]' -f $method.Source, $method.Method, $method.File, $method.Line
            $this.Title = $title
            $this.Samples = $arguments[0]
            $this.XIndexStart = $arguments[1]
            $this.XIndexEnd = $arguments[2]
            $this.YIndex = $arguments[3]
        }
        FlameGraphBar() {}
    }
    
    class HotFlameGraphBuilder {
        [FlameGraphBar[]] $Bars
        [string] $Title
        [int] $ViewWidth = 1280
        [int] $ViewHeight = 720
        [int] $XPadding = 10
        [int] $YPaddingRows = 2
        [int] $MaxDepth = 1
        [int] $MinDepth = 0
        [int] $TotalSamples = 0
        [double] $XScaleFactor = 1
        
        [string] $FontFamily = 'Verdana'
        [int] $FontSize = 12
    
        [rgbcolor] $fontColor = [rgbcolor]::new(0,0,0)
    
        # [Collections.Generic.SortedSet[double]] $RelativeWidthsSorted = @()
        [Collections.Generic.Dictionary[string, int]] $TitlesSorted = @{}
        [Collections.Generic.Dictionary[string, double]] $RelativeWidthsSorted = @{}
        [Collections.Generic.Dictionary[string,rgbcolor]] $ColorMap = @{}
        [double] $MinWeight = [double]::MaxValue
        [double] $MaxWeight = [double]::MinValue
    
        HotFlameGraphBuilder([FlameGraphBar[]] $bars, [int] $totalSamples, [string] $title, [int] $viewwidth, [int] $viewheight) {
            $this.Bars = $bars
            $this.Title = $title
            $this.ViewWidth = $viewwidth
            $this.ViewHeight = $viewheight
            $this.MinDepth = ($bars | Measure-Object -Property YIndex -Minimum).Minimum
            $this.MaxDepth = ($bars | Measure-Object -Property YIndex -Maximum).Maximum - $this.MinDepth
            $this.TotalSamples = $totalSamples
        }
    
        static [string] GetFlameGraph([FlameGraphBar[]] $bars, [int] $totalSamples, [string] $title, [int] $viewwidth, [int] $viewheight) {
            return [HotFlameGraphBuilder]::new($bars, $totalSamples, $title, $viewwidth, $viewheight).Build()
        }
    
        [string] Build() {
            return [Text.StringBuilder]::new().Append($this.GetHeader()).Append($this.GetBody()).Append('</svg>')
        }
    
        hidden [string] GetHeader() {
            $sb = [Text.StringBuilder]::new()
            $header = [HotFlameGraphBuilder]::GetHeaderTemplate() -f $this.ViewWidth, $this.ViewHeight
            $sb.AppendLine($header)
            # x appears have a full 10px of padding on the left and right
            $sb.AppendFormat('    <text text-anchor="middle" x="{0:0.00}" y="{1:0.#}" font-size="{2}" font-family="{3}" fill="{4}">{5}</text>', $this.ViewWidth/2, $this.GetYPosition(-1), [math]::Floor(1.45*$this.FontSize), $this.FontFamily, $this.fontColor, $this.Title).AppendLine()
            $sb.AppendFormat('    <text text-anchor="" x="{0:0.0}" y="{1:0.#}" font-size="{2}" font-family="{3}" fill="{4}" id="details"></text>', $this.GetXPosition(0), $this.GetYPosition($this.MaxDepth + 1), $this.FontSize, $this.FontFamily, $this.fontColor).AppendLine()
            $sb.AppendFormat('    <text text-anchor="" x="{0:0.0}" y="{1:0.#}" font-size="{2}" font-family="{3}" fill="{4}" id="unzoom" onclick="unzoom()" style="opacity:0.0;cursor:pointer">Reset Zoom</text>', $this.GetXPosition(0), $this.GetYPosition(-1), $this.FontSize, $this.FontFamily, $this.fontColor).AppendLine()
            return $sb.ToString()
        }
    
        hidden [void] RankBars() {
            $this.RelativeWidthsSorted.Clear()
            $this.TitlesSorted.Clear()
            [Collections.Generic.HashSet[string]] $seen = @()
            foreach ($bar in $this.Bars) {
                if ($seen.Contains($bar.Title)) {
                    $this.TitlesSorted[$bar.Title] += $bar.Samples
                    continue
                }
                $seen.Add($bar.Title)
                $this.TitlesSorted.Add($bar.Title, $bar.Samples)
            }
            foreach ($key in $this.TitlesSorted.Keys) {
                $this.RelativeWidthsSorted[$key] = $this.GetRelativeBarWith($this.TitlesSorted[$key])
            }
            $arr = [double[]]$this.RelativeWidthsSorted.Values
            $this.MinWeight = $arr[0]
            $this.MaxWeight = $arr[-1]
            $spread = $this.MaxWeight - $this.MinWeight
    
            # build the colormap
            foreach ($key in $this.RelativeWidthsSorted.Keys) {
                $relWeight = $this.RelativeWidthsSorted[$key]
                $index = $arr.IndexOf($relWeight)
                $pct = ([double]$relWeight - $this.MinWeight)/$spread
                $instancePct = ([double]$index)/($arr.Count - 1)
                $weightedPct = ($pct + $instancePct) / 2
                $g = [Math]::Round(255 * ($weightedPct))
                $this.ColorMap[$key] = [rgbcolor]::new(255, $g, 0)
            }
        }
    
        hidden [void] AppendBar([Text.StringBuilder] $sb, [FlameGraphBar] $bar) {
            $bartitle = '{0} ({1} samples, {2:0.00}%)' -f [Web.HttpUtility]::HtmlEncode($bar.Title), $bar.Samples, (100*(([double]$bar.Samples)/$this.TotalSamples))
            $sb.AppendFormat('    <g class="func_g" onmouseover="s(''{0}'')" onmouseout="c()" onclick="zoom(this)">', $bartitle).AppendLine()
            $sb.AppendFormat('        <title>{0}</title>', $bartitle).AppendLine()
            $sb.AppendFormat('        <rect x="{0:0.0}" y="{1:0.#}" width="{2:0.0}" height="{3:0.0}" fill="{4}" rx="2" ry="2" />', $this.GetXPosition($bar.XIndexStart), $this.GetYPosition($bar.YIndex), $this.GetRelativeBarWith($bar.Samples), $this.GetRowHeight()-1, $this.GetColor($bar.Title)).AppendLine()
            # $sb.AppendFormat('        <text text-anchor="" x="{0:0.0}" y="{1:0.#}" font-size="{2}" font-family="{3}" fill="{4}"></text>', $this.GetXPosition($bar.XIndexStart) + 3, $this.GetYPosition($bar.YIndex) + (($this.GetRowHeight()-1)/3), $this.FontSize, $this.FontFamily, $this.fontColor).AppendLine()
            $sb.AppendFormat('        <text text-anchor="" x="{0:0.0}" y="{1:0.#}" font-size="{2}" font-family="{3}" fill="{4}"></text>', $this.GetXPosition($bar.XIndexStart) + 3, $this.GetYPosition($bar.YIndex) + $this.FontSize, $this.FontSize, $this.FontFamily, $this.fontColor).AppendLine()
            $sb.AppendFormat('    </g>').AppendLine()
        }
    
        hidden [string] GetBody() {
            $sb = [System.Text.StringBuilder]::new()
            foreach ($bar in $this.Bars) {
                $this.AppendBar($sb, $bar)
            }
            return $sb.ToString()
        }
    
        hidden [int] GetTotalRows() {
            return ($this.MaxDepth - $this.MinDepth) + (2 * $this.YPaddingRows) + 1
        }
    
        hidden [double] GetRowHeight() {
            # 2 leading rows, 2 trailing rows
            return [Math]::Floor($this.ViewHeight / $this.GetTotalRows()) - 1
        }
    
        hidden [double] GetYMin() {
            return ($this.YPaddingRows + 1) * $this.GetRowHeight()
        }
    
        hidden [double] GetYMax() {
            return $this.ViewHeight - (($this.YPaddingRows) * $this.GetRowHeight())
        }
    
        hidden [double] GetYPosition([int] $index) {
            if ($index -lt 0) { 
                return $this.GetYMin() + (($index - 1) * $this.GetRowHeight())
            }
            return $this.GetYMin() + ((($this.MaxDepth - ($index - $this.MinDepth) - 1)) * $this.GetRowHeight())
        }
    
        hidden [double] GetRelativeBarWith([int] $samples) {
            return $this.GetBarWidth() * $samples
        }
    
        hidden [double] GetXMin() {
            return $this.XPadding
        }
    
        hidden [double] GetXMax() {
            return $this.ViewWidth - $this.XPadding
        }
    
        hidden [double] GetBarWidth() {
            $width = $this.GetXMax() - $this.GetXMin()
            $barWidth = [Math]::Round($width/[double]$this.TotalSamples,2)
            $this.XScaleFactor = $this.TotalSamples / [Math]::Round($width/$barWidth,0)
            if (($this.XScaleFactor * $this.TotalSamples) -gt ($this.XPadding/$width)) {
                $barWidth = [Math]::Round($width/[double]$this.TotalSamples,3)
                $this.XScaleFactor = $this.TotalSamples / [Math]::Round($width/$barWidth,0)
            }
            return $barWidth
        }
    
        hidden [double] GetXPosition([int] $index) {
            return $this.GetXMin() + ($index * $this.GetBarWidth())
        }
    
        hidden [rgbcolor] GetColor([string] $title) {
            if ($this.RelativeWidthsSorted.Count -eq 0) {
                $this.RankBars()
            }
            return $this.ColorMap[$title]
        }
    
        hidden [rgbcolor] GetColor() {
            $R = 205..254 | Get-Random
            $G = 0..229 | Get-Random
            $B = 0..54 | Get-Random
            return [rgbcolor]::new($R, $G, $B)
        }
    
        hidden static [string] $_headerTemplate
        hidden static [string] GetHeaderTemplate() {
            if ([string]::IsNullOrEmpty([HotFlameGraphBuilder]::_headerTemplate)) {
                [HotFlameGraphBuilder]::_headerTemplate = [Text.StringBuilder]::new().
                AppendLine('<?xml version="1.0" standalone="no"?>').
                AppendLine('<!DOCTYPE svg PUBLIC "-//W3C//DTD SVG 1.1//EN" "http://www.w3.org/Graphics/SVG/1.1/DTD/svg11.dtd">').
                AppendLine('<svg version="1.1" width="{0}" height="{1}" onload="init(evt)" viewBox="0 0 {0} {1}" xmlns="http://www.w3.org/2000/svg" xmlns:xlink="http://www.w3.org/1999/xlink">').
                AppendLine('    <defs >').
                AppendLine('        <linearGradient id="background" y1="0" y2="1" x1="0" x2="0">').
                AppendLine('            <stop stop-color="#eeeeee" offset="5%" />').
                AppendLine('            <stop stop-color="#eeeeb0" offset="95%" />').
                AppendLine('        </linearGradient>').
                AppendLine('    </defs>').
                AppendLine('    <style type="text/css">').
                AppendLine('    .func_g:hover {{ stroke:black; stroke-width:0.5; cursor:pointer; }}').
                AppendLine('    </style>').
                AppendLine('    <script type="text/ecmascript">').
                AppendLine('    <![CDATA[').
                AppendLine('        var details, svg;').
                AppendLine('        function init(evt) {{ ').
                AppendLine('            details = document.getElementById("details").firstChild; ').
                AppendLine('            svg = document.getElementsByTagName("svg")[0];').
                AppendLine('            unzoom();').
                AppendLine('        }}').
                AppendLine('        function s(info) {{ details.nodeValue = "Function: " + info; }}').
                AppendLine('        function c() {{ details.nodeValue = '' ''; }}').
                AppendLine('        function find_child(parent, name, attr) {{').
                AppendLine('            var children = parent.childNodes;').
                AppendLine('            for (var i=0; i<children.length;i++) {{').
                AppendLine('                if (children[i].tagName == name)').
                AppendLine('                    return (attr != undefined) ? children[i].attributes[attr].value : children[i];').
                AppendLine('            }}').
                AppendLine('            return;').
                AppendLine('        }}').
                AppendLine('        function orig_save(e, attr, val) {{').
                AppendLine('            if (e.attributes["_orig_"+attr] != undefined) return;').
                AppendLine('            if (e.attributes[attr] == undefined) return;').
                AppendLine('            if (val == undefined) val = e.attributes[attr].value;').
                AppendLine('            e.setAttribute("_orig_"+attr, val);').
                AppendLine('        }}').
                AppendLine('        function orig_load(e, attr) {{').
                AppendLine('            if (e.attributes["_orig_"+attr] == undefined) return;').
                AppendLine('            e.attributes[attr].value = e.attributes["_orig_"+attr].value;').
                AppendLine('            e.removeAttribute("_orig_"+attr);').
                AppendLine('        }}').
                AppendLine('        function update_text(e) {{').
                AppendLine('            var r = find_child(e, "rect");').
                AppendLine('            var t = find_child(e, "text");').
                AppendLine('            var w = parseFloat(r.attributes["width"].value) -3;').
                AppendLine('            var txt = find_child(e, "title").textContent.replace(/\([^(]*\)/,"");').
                AppendLine('            t.attributes["x"].value = parseFloat(r.attributes["x"].value) +3;').
                AppendLine('            ').
                AppendLine('            // Smaller than this size won''t fit anything').
                AppendLine('            if (w < 2*12*0.59) {{').
                AppendLine('                t.textContent = "";').
                AppendLine('                return;').
                AppendLine('            }}').
                AppendLine('            ').
                AppendLine('            t.textContent = txt;').
                AppendLine('            // Fit in full text width').
                AppendLine('            if (/^ *$/.test(txt) || t.getSubStringLength(0, txt.length) < w)').
                AppendLine('                return;').
                AppendLine('            ').
                AppendLine('            for (var x=txt.length-2; x>0; x--) {{').
                AppendLine('                if (t.getSubStringLength(0, x+2) <= w) {{ ').
                AppendLine('                    t.textContent = txt.substring(0,x) + "..";').
                AppendLine('                    return;').
                AppendLine('                }}').
                AppendLine('            }}').
                AppendLine('            t.textContent = "";').
                AppendLine('        }}').
                AppendLine('        function zoom_reset(e) {{').
                AppendLine('            if (e.attributes != undefined) {{').
                AppendLine('                orig_load(e, "x");').
                AppendLine('                orig_load(e, "width");').
                AppendLine('            }}').
                AppendLine('            if (e.childNodes == undefined) return;').
                AppendLine('            for(var i=0, c=e.childNodes; i<c.length; i++) {{').
                AppendLine('                zoom_reset(c[i]);').
                AppendLine('            }}').
                AppendLine('        }}').
                AppendLine('        function zoom_child(e, x, ratio) {{').
                AppendLine('            if (e.attributes != undefined) {{').
                AppendLine('                if (e.attributes["x"] != undefined) {{').
                AppendLine('                    orig_save(e, "x");').
                AppendLine('                    e.attributes["x"].value = (parseFloat(e.attributes["x"].value) - x - 10) * ratio + 10;').
                AppendLine('                    if(e.tagName == "text") e.attributes["x"].value = find_child(e.parentNode, "rect", "x") + 3;').
                AppendLine('                }}').
                AppendLine('                if (e.attributes["width"] != undefined) {{').
                AppendLine('                    orig_save(e, "width");').
                AppendLine('                    e.attributes["width"].value = parseFloat(e.attributes["width"].value) * ratio;').
                AppendLine('                }}').
                AppendLine('            }}').
                AppendLine('            ').
                AppendLine('            if (e.childNodes == undefined) return;').
                AppendLine('            for(var i=0, c=e.childNodes; i<c.length; i++) {{').
                AppendLine('                zoom_child(c[i], x-10, ratio);').
                AppendLine('            }}').
                AppendLine('        }}').
                AppendLine('        function zoom_parent(e) {{').
                AppendLine('            if (e.attributes) {{').
                AppendLine('                if (e.attributes["x"] != undefined) {{').
                AppendLine('                    orig_save(e, "x");').
                AppendLine('                    e.attributes["x"].value = 10;').
                AppendLine('                }}').
                AppendLine('                if (e.attributes["width"] != undefined) {{').
                AppendLine('                    orig_save(e, "width");').
                AppendLine('                    e.attributes["width"].value = parseInt(svg.width.baseVal.value) - (10*2);').
                AppendLine('                }}').
                AppendLine('            }}').
                AppendLine('            if (e.childNodes == undefined) return;').
                AppendLine('            for(var i=0, c=e.childNodes; i<c.length; i++) {{').
                AppendLine('                zoom_parent(c[i]);').
                AppendLine('            }}').
                AppendLine('        }}').
                AppendLine('        function zoom(node) {{ ').
                AppendLine('            var attr = find_child(node, "rect").attributes;').
                AppendLine('            var width = parseFloat(attr["width"].value);').
                AppendLine('            var xmin = parseFloat(attr["x"].value);').
                AppendLine('            var xmax = parseFloat(xmin + width);').
                AppendLine('            var ymin = parseFloat(attr["y"].value);').
                AppendLine('            var ratio = (svg.width.baseVal.value - 2*10) / width;').
                AppendLine('            ').
                AppendLine('            // XXX: Workaround for JavaScript float issues (fix me)').
                AppendLine('            var fudge = 0.0001;').
                AppendLine('            ').
                AppendLine('            var unzoombtn = document.getElementById("unzoom");').
                AppendLine('            unzoombtn.style["opacity"] = "1.0";').
                AppendLine('            ').
                AppendLine('            var el = document.getElementsByTagName("g");').
                AppendLine('            for(var i=0;i<el.length;i++){{').
                AppendLine('                var e = el[i];').
                AppendLine('                var a = find_child(e, "rect").attributes;').
                AppendLine('                var ex = parseFloat(a["x"].value);').
                AppendLine('                var ew = parseFloat(a["width"].value);').
                AppendLine('                // Is it an ancestor').
                AppendLine('                if (0 == 0) {{').
                AppendLine('                    var upstack = parseFloat(a["y"].value) > ymin;').
                AppendLine('                }} else {{').
                AppendLine('                    var upstack = parseFloat(a["y"].value) < ymin;').
                AppendLine('                }}').
                AppendLine('                if (upstack) {{').
                AppendLine('                    // Direct ancestor').
                AppendLine('                    if (ex <= xmin && (ex+ew+fudge) >= xmax) {{').
                AppendLine('                        e.style["opacity"] = "0.5";').
                AppendLine('                        zoom_parent(e);').
                AppendLine('                        e.onclick = function(e){{unzoom(); zoom(this);}};').
                AppendLine('                        update_text(e);').
                AppendLine('                    }}').
                AppendLine('                    // not in current path').
                AppendLine('                    else').
                AppendLine('                        e.style["display"] = "none";').
                AppendLine('                }}').
                AppendLine('                // Children maybe').
                AppendLine('                else {{').
                AppendLine('                    // no common path').
                AppendLine('                    if (ex < xmin || ex + fudge >= xmax) {{').
                AppendLine('                        e.style["display"] = "none";').
                AppendLine('                    }}').
                AppendLine('                    else {{').
                AppendLine('                        zoom_child(e, xmin, ratio);').
                AppendLine('                        e.onclick = function(e){{zoom(this);}};').
                AppendLine('                        update_text(e);').
                AppendLine('                    }}').
                AppendLine('                }}').
                AppendLine('            }}').
                AppendLine('        }}').
                AppendLine('        function unzoom() {{').
                AppendLine('            var unzoombtn = document.getElementById("unzoom");').
                AppendLine('            unzoombtn.style["opacity"] = "0.0";').
                AppendLine('            ').
                AppendLine('            var el = document.getElementsByTagName("g");').
                AppendLine('            for(i=0;i<el.length;i++) {{').
                AppendLine('                el[i].style["display"] = "block";').
                AppendLine('                el[i].style["opacity"] = "1";').
                AppendLine('                zoom_reset(el[i]);').
                AppendLine('                update_text(el[i]);').
                AppendLine('            }}').
                AppendLine('        }}    ').
                AppendLine('    ]]>').
                AppendLine('    </script>').
                AppendLine('    <rect x="0.0" y="0" width="{0:0.0}" height="{1:0.0}" fill="url(#background)" />').
                ToString()
            }
            return [HotFlameGraphBuilder]::_headerTemplate
        }
    }
}
end {
    $FunctionContextProperty = [Management.Automation.CallStackFrame].GetProperty('FunctionContext', [Reflection.BindingFlags]'NonPublic,Instance')
    $scriptBlockField = [Ref].Assembly.GetType('System.Management.Automation.Language.FunctionContext').GetField('_scriptBlock',[System.Reflection.BindingFlags]'NonPublic,Instance')

    $KVP = [System.Collections.Generic.KeyValuePair[DateTime,System.Collections.Generic.List[System.Management.Automation.CallStackFrame]][]]::new($Tracer.Samples.Count)
    ([System.Collections.ICollection]$Tracer.Samples).CopyTo($KVP, 0)
    $Samples = $Tracer.Samples.Count
    $Sorted = $KVP | Sort-Object -Property Key
    
    $sortedoccurences = [Collections.Generic.SortedDictionary[[string[]], int]]::new([StringArrayComparer]::new())
    $prevKey = [string[]]@()
    $prev = [string[]]@()
    $comparer = [StringArrayComparer]::new()
    $Sorted.ForEach({
        $callstack = [System.Management.Automation.CallStackFrame[]]$_.Value
        [Array]::Reverse($callstack)
        $strings = [Collections.Generic.List[string]]@()
        for ($i = 0; $i -lt $callstack.Length; $i++) {
            $csf = $callstack[$i]

            $sb = $scriptBlockField.GetValue($FunctionContextProperty.GetValue($csf))
            $ast = $sb.Ast.Find({$args[0].Extent -eq $csf.Position},$true)[0]
            $parent = $ast.Parent
            while ($null -ne $parent -and $parent -isnot [Management.Automation.Language.FunctionDefinitionAst] -and $parent -isnot [Management.Automation.Language.TypeDefinitionAst]) {
                $parent = $parent.Parent
            }
            if ($null -eq $parent) {
                $funcName = '<ScriptBlock>'
                if ($strings.Where({$_ -eq $funcName},'First',1).Count -eq 0) {
                    $strings.Add($funcName)
                }
            }
            if ($parent -is [Management.Automation.Language.FunctionDefinitionAst]) {
                $funcName = $parent.Name
                while ($null -ne $parent -and $parent -isnot [Management.Automation.Language.TypeDefinitionAst]) {
                    $parent = $parent.Parent
                }
                if ($null -eq $parent) {   
                    $namedBlock = $ast.Parent
                    while ($namedBlock -isnot [Management.Automation.Language.NamedBlockAst]) {
                        $namedBlock = $namedBlock.Parent
                        if ($namedBlock -is [Management.Automation.Language.FunctionDefinitionAst]) {
                            Write-Warning "Could not find named block for $($funcName) @ $($csf.Position)"
                            break
                        }
                    }
                    $funcName = '{0}<{1}>' -f $funcName, $namedBlock.BlockKind

                    if ($strings.Where({$_ -eq $funcName},'First',1).Count -eq 0) {
                        $strings.Add($funcName)
                    }
                }
            }
            if ($parent -is [Management.Automation.Language.TypeDefinitionAst]) {
                $funcName = $parent.Name
                $functionMember = $ast.Parent
                while ($functionMember -isnot [Management.Automation.Language.FunctionMemberAst] -and $functionMember -isnot [Management.Automation.Language.PropertyMemberAst]) {
                    $functionMember = $functionMember.Parent
                    if ($functionMember -is [Management.Automation.Language.TypeDefinitionAst]) {
                        $namestring = $ast.GetType().Name
                        while ($null -ne $ast.Parent) {
                            $ast = $ast.Parent
                            $namestring = '{0}.{1}' -f $ast.GetType().Name, $namestring
                        }
                        Write-Warning "Could not find function member for $($funcName) @ $($csf.Position) - $($namestring)"
                        break
                    }
                }
                $funcName = '{0}<{1}>' -f $funcName, $functionMember.Name
                if ($strings.Where({$_ -eq $funcName},'First',1).Count -eq 0) {
                    $strings.Add($funcName)
                }
            }

            $line = $csf.Position.Text.Split([System.Environment]::NewLine)
            $elipsis = if($line.Length -gt 1) { ' ...' } else { '' }
            $Source = $csf.InvocationInfo.MyCommand.Source
            if ([string]::IsNullOrEmpty($Source)) { $Source = [IO.Path]::GetFileName([IO.Path]::GetDirectoryName($csf.ScriptName)) }
            if ([string]::IsNullOrEmpty($Source) -and [string]::IsNullOrEmpty([IO.Path]::GetFileName($csf.ScriptName))) {
                $str = '{0}{1}' -f $line[0], $elipsis
                $strings.Add($str)
                continue
            }
            $str = '{3}{4} [{0}:{1}:{2}]' -f $Source, [IO.Path]::GetFileName($csf.ScriptName), $csf.ScriptLineNumber, $line[0], $elipsis
            $strings.Add($str)
        }
        if ($comparer.Compare($prev, [string[]]$strings) -eq 0) {
            $sortedoccurences[$prevKey] += 1
            return
        }
        $prev = [string[]]$strings
        $strings.Insert(0,$_.Key.ToString('o'))
        $prevKey = [string[]]$strings
        $sortedoccurences.Add($prevKey, 1)
    })
    $stacks = [string[][]]$sortedoccurences.Keys
    $maxDepth = ($stacks.ForEach('Count') | Measure-Object -Maximum).Maximum
    
    $Bars = [Collections.Generic.List[FlameGraphBar]]@()
    $start = 1
    for ($i = $start; $i -lt $maxDepth; $i++) {
        $x = 0
        $samplestart = 0
        $samplecount = 0
        $cursor = 0
        while ($x -lt $stacks.Count) {
            while ($i -ge $stacks[$x].Length -and $x -lt $stacks.Count) {
                $cursor += $sortedoccurences[$stacks[$x]]
                $x++
            }
            if ($x -ge $stacks.Count) { break }
            $title = $stacks[$x][$i]
            $samplestart = $cursor
            $samplecount = $sortedoccurences[$stacks[$x]]
            $cursor += $sortedoccurences[$stacks[$x]]
            $x++
            while ($x -lt $stacks.Count -and $stacks[$x][$i] -eq $title) {
                if ($i -gt $start -and $stacks[$x][$i-1] -ne $stacks[$x-1][$i-1]) {
                    break
                }
                $samplecount += $sortedoccurences[$stacks[$x]]
                $cursor += $sortedoccurences[$stacks[$x]]
                $x++
            }
            $Bars.Add([FlameGraphBar]::new($title, @($samplecount, $samplestart, 0, $i)))
            $title = $null
        }
    }    
    [HotFlameGraphBuilder]::GetFlameGraph($Bars, $samples, $GraphTitle, 1920, 1080) | Set-Content $OutputPath
}
