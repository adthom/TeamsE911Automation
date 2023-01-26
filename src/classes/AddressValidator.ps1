# using module ..\..\modules\PSClassExtensions\bin\debug\PSClassExtensions
# WarningType
# E911Address
using namespace System.Web
using namespace System.Text
using namespace System.Net.Http
using namespace System.Collections.Generic

class AddressValidator {
    [string[]] $NumberWords = @('zero', 'one', 'two', 'three', 'four', 'five', 'six', 'seven', 'eight', 'nine', 'ten', 'eleven', 'twelve', 'thirteen', 'fourteen', 'fifteen', 'sixteen', 'seventeen', 'eighteen', 'nineteen', 'twenty')
    [HashSet[string]] $Abbreviations = @('alley','allee','ally','anex','annex','annx','arcade','avenue','av','aven','avenu','avn','avnue','bayou','bayoo','beach','bend','bluff','bluf','bluffs','bot','bottm','bottom','boulevard','boul','boulv','branch','brnch','bridge','brdge','brook','brooks','burg','burgs','bypass','bypa','bypas','byps','camp','cmp','canyn','canyon','cnyn','cape','causeway','causwa','center','cen','cent','centr','centre','cnter','cntr','centers','circle','circ','circl','crcl','crcle','circles','cliff','cliffs','club','common','commons','corner','corners','course','court','courts','cove','coves','creek','crescent','crsent','crsnt','crest','crossing','crssng','crossroad','crossroads','curve','dale','dam','divide','div','dvd','drive','driv','drv','drives','estate','estates','expressway','exp','expr','express','expw','extension','extn','extnsn','extensions','falls','ferry','frry','field','fields','flat','flats','ford','fords','forest','forests','forge','forg','forges','fork','forks','fort','frt','freeway','freewy','frway','frwy','garden','gardn','grden','grdn','gardens','grdns','gateway','gatewy','gatway','gtway','glen','glens','green','greens','grove','grov','groves','harbor','harb','harbr','hrbor','harbors','haven','heights','ht','highway','highwy','hiway','hiwy','hway','hill','hills','hollow','hllw','hollows','holws','inlet','island','islnd','islands','islnds','isles','junction','jction','jctn','junctn','juncton','junctions','jctns','key','keys','knoll','knol','knolls','lake','lakes','landing','lndng','lane','light','lights','loaf','lock','locks','lodge','ldge','lodg','loops','manor','manors','meadow','meadows','mdw','medows','mill','mills','mission','missn','mssn','motorway','mount','mnt','mountain','mntain','mntn','mountin','mtin','mountains','mntns','neck','orchard','orchrd','ovl','overpass','prk','parks','parkway','parkwy','pkway','pky','parkways','pkwys','passage','paths','pikes','pine','pines','place','plain','plains','plaza','plza','point','points','port','ports','prairie','prr','radial','rad','radiel','ranch','ranches','rnchs','rapid','rapids','rest','ridge','rdge','ridges','river','rvr','rivr','road','roads','route','shoal','shoals','shore','shoar','shores','shoars','skyway','spring','spng','sprng','springs','spngs','sprngs','spurs','square','sqr','sqre','squ','squares','sqrs','station','statn','stn','stravenue','strav','straven','stravn','strvn','strvnue','stream','streme','street','strt','str','streets','summit','sumit','sumitt','terrace','terr','throughway','trace','traces','track','tracks','trk','trks','trafficway','trail','trails','trls','trailer','trlrs','tunnel','tunel','tunls','tunnels','tunnl','turnpike','trnpk','turnpk','underpass','union','unions','valley','vally','vlly','valleys','viaduct','vdct','viadct','view','views','village','vill','villag','villg','villiage','villages','ville','vista','vist','vst','vsta','walks','wy','well','wells','northwest','northeast','southwest','southeast','n','e','ne','w','nw','s','se','sw','south','north','eighth','second','west','sixth','ninth','east','tenth','fourth','third','seventh','first','fifth')
    [hashtable] $s_replacementHash = @{aly=@('alley','allee','ally');anx=@('anex','annex','annx');arc=@('arcade');ave=@('avenue','av','aven','avenu','avn','avnue');byu=@('bayou','bayoo');bch=@('beach');bnd=@('bend');blf=@('bluff','bluf');blfs=@('bluffs');btm=@('bot','bottm','bottom');blvd=@('boulevard','boul','boulv');br=@('branch','brnch');brg=@('bridge','brdge');brk=@('brook');brks=@('brooks');bg=@('burg');bgs=@('burgs');byp=@('bypass','bypa','bypas','byps');cp=@('camp','cmp');cyn=@('canyn','canyon','cnyn');cpe=@('cape');cswy=@('causeway','causwa');ctr=@('center','cen','cent','centr','centre','cnter','cntr');ctrs=@('centers');cir=@('circle','circ','circl','crcl','crcle');cirs=@('circles');clf=@('cliff');clfs=@('cliffs');clb=@('club');cmn=@('common');cmns=@('commons');cor=@('corner');cors=@('corners');crse=@('course');ct=@('court');cts=@('courts');cv=@('cove');cvs=@('coves');crk=@('creek');cres=@('crescent','crsent','crsnt');crst=@('crest');xing=@('crossing','crssng');xrd=@('crossroad');xrds=@('crossroads');curv=@('curve');dl=@('dale');dm=@('dam');dv=@('divide','div','dvd');dr=@('drive','driv','drv');drs=@('drives');est=@('estate');ests=@('estates');expy=@('expressway','exp','expr','express','expw');ext=@('extension','extn','extnsn');exts=@('extensions');fls=@('falls');fry=@('ferry','frry');fld=@('field');flds=@('fields');flt=@('flat');flts=@('flats');frd=@('ford');frds=@('fords');frst=@('forest','forests');frg=@('forge','forg');frgs=@('forges');frk=@('fork');frks=@('forks');ft=@('fort','frt');fwy=@('freeway','freewy','frway','frwy');gdn=@('garden','gardn','grden','grdn');gdns=@('gardens','grdns');gtwy=@('gateway','gatewy','gatway','gtway');gln=@('glen');glns=@('glens');grn=@('green');grns=@('greens');grv=@('grove','grov');grvs=@('groves');hbr=@('harbor','harb','harbr','hrbor');hbrs=@('harbors');hvn=@('haven');hts=@('heights','ht');hwy=@('highway','highwy','hiway','hiwy','hway');hl=@('hill');hls=@('hills');holw=@('hollow','hllw','hollows','holws');inlt=@('inlet');is=@('island','islnd');iss=@('islands','islnds');isle=@('isles');jct=@('junction','jction','jctn','junctn','juncton');jcts=@('junctions','jctns');ky=@('key');kys=@('keys');knl=@('knoll','knol');knls=@('knolls');lk=@('lake');lks=@('lakes');lndg=@('landing','lndng');ln=@('lane');lgt=@('light');lgts=@('lights');lf=@('loaf');lck=@('lock');lcks=@('locks');ldg=@('lodge','ldge','lodg');loop=@('loops');mnr=@('manor');mnrs=@('manors');mdw=@('meadow');mdws=@('meadows','mdw','medows');ml=@('mill');mls=@('mills');msn=@('mission','missn','mssn');mtwy=@('motorway');mt=@('mount','mnt');mtn=@('mountain','mntain','mntn','mountin','mtin');mtns=@('mountains','mntns');nck=@('neck');orch=@('orchard','orchrd');oval=@('ovl');opas=@('overpass');park=@('prk','parks');pkwy=@('parkway','parkwy','pkway','pky','parkways','pkwys');psge=@('passage');path=@('paths');pike=@('pikes');pne=@('pine');pnes=@('pines');pl=@('place');pln=@('plain');plns=@('plains');plz=@('plaza','plza');pt=@('point');pts=@('points');prt=@('port');prts=@('ports');pr=@('prairie','prr');radl=@('radial','rad','radiel');rnch=@('ranch','ranches','rnchs');rpd=@('rapid');rpds=@('rapids');rst=@('rest');rdg=@('ridge','rdge');rdgs=@('ridges');riv=@('river','rvr','rivr');rd=@('road');rds=@('roads');rte=@('route');shl=@('shoal');shls=@('shoals');shr=@('shore','shoar');shrs=@('shores','shoars');skwy=@('skyway');spg=@('spring','spng','sprng');spgs=@('springs','spngs','sprngs');spur=@('spurs');sq=@('square','sqr','sqre','squ');sqs=@('squares','sqrs');sta=@('station','statn','stn');stra=@('stravenue','strav','straven','stravn','strvn','strvnue');strm=@('stream','streme');st=@('street','strt','str');sts=@('streets');smt=@('summit','sumit','sumitt');ter=@('terrace','terr');trwy=@('throughway');trce=@('trace','traces');trak=@('track','tracks','trk','trks');trfy=@('trafficway');trl=@('trail','trails','trls');trlr=@('trailer','trlrs');tunl=@('tunnel','tunel','tunls','tunnels','tunnl');tpke=@('turnpike','trnpk','turnpk');upas=@('underpass');un=@('union');uns=@('unions');vly=@('valley','vally','vlly');vlys=@('valleys');via=@('viaduct','vdct','viadct');vw=@('view');vws=@('views');vlg=@('village','vill','villag','villg','villiage');vlgs=@('villages');vl=@('ville');vis=@('vista','vist','vst','vsta');walk=@('walks');way=@('wy');wl=@('well');wls=@('wells')}
    [Lazy[Dictionary[HashSet[string],string]]] $s_replacementdictionary = [Lazy[Dictionary[HashSet[string],string]]]::new(
        [Func[Dictionary[HashSet[string],string]]] { 
            $dict = [Dictionary[HashSet[string],string]]@{}
            foreach ($key in $this.s_replacementHash.Keys) {
                $dict[[HashSet[string]]([string[]]$this.s_replacementHash[$key])] = $key
            }
            return $dict
        })

    [string] GetReplacement([string] $item) {
        if ($this.Abbreviations.Contains($item)) {
            $key = $this.AbbreviationLookup.Keys.Where({$_.Contains($item)},'First',1)[0]
            if ($null -eq $key) {
                return $item
            }
            return $this.AbbreviationLookup[$key]
        }
        return $item
    }
    [List[string]] GetCleanAddressParts([string] $Address) {
        $Address = $Address.ToLowerInvariant()
        $AddressTokens = [List[string]][string[]]($Address -split '\b').Where({$_ -match '\w'}).ForEach({$_.Trim()})
        for ($i = 0; $i -lt $AddressTokens.Count; $i++) {
            $CurrentToken = $AddressTokens[$i]
            if ($this.Abbreviations.Contains($CurrentToken)) {
                # replace potential abbreviation with common string
                if ($CurrentToken -match '^(?:n(?:orth)?|s(?:outh)?|e(?:ast)?|w(?:est)?|(?:(?:n(?:orth)?|s(?:outh)?)(?:e(?:ast)?|w(?:est)?)))$') {
                    # handle directional indicators, since they could split into multiple strings
                    $CurrentToken = $CurrentToken -replace '^n(orth)?', 'north'
                    $CurrentToken = $CurrentToken -replace '^s(outh)?', 'south'
                    $CurrentToken = $CurrentToken -replace 'e(ast)?$', 'east'
                    $CurrentToken = $CurrentToken -replace 'w(est)$', 'west'
                    if ($CurrentToken.Length -gt 5 -and ($CurrentToken.StartsWith('north') -or $CurrentToken.StartsWith('south'))) {
                        # split northeast/southeast/northwest/southwest into 2 fields
                        $Parts = $CurrentToken -split '(?<=h)'
                        $CurrentToken = $Parts[0]
                        $AddressTokens.Insert(($i + 1), $Parts[1])
                    }
                    $AddressTokens[$i] = $CurrentToken
                }
                $Replacement = $this.GetReplacement($CurrentToken)
                if ($null -ne $Replacement) {
                    $AddressTokens[$i] = $Replacement
                }
            }
            if (($Index = $this.NumberWords.IndexOf($CurrentToken)) -gt 0) {
                $AddressTokens[$i] = $Index
            }
        }
        return $AddressTokens
    }
    [bool] TestIsAddressMatch([string] $ReferenceAddress, [string] $DifferenceAddress) {
        if ($ReferenceAddress -eq $DifferenceAddress) { return $true }

        $ReferenceAddressTokens = $this.GetCleanAddressParts($ReferenceAddress)
        $ReferenceMatched = [bool[]]::new($ReferenceAddressTokens.Count)

        $DifferenceAddressTokens = $this.GetCleanAddressParts($DifferenceAddress)
        $DifferenceMatched = [bool[]]::new($DifferenceAddressTokens.Count)
        # simple match first
        for ($i = 0; $i -lt $ReferenceAddressTokens.Count; $i++) {
            if ($ReferenceMatched[$i]) { continue } # already matched, skip
            if (($Index = $DifferenceAddressTokens.IndexOf($ReferenceAddressTokens[$i])) -gt -1 -and !$DifferenceMatched[$Index]) {
                $ReferenceMatched[$i] = $true
                $DifferenceMatched[$Index] = $true
                continue
            }
        }
        $RefUnmatched = $ReferenceMatched.Where({ !$_ }).Count
        $DiffUnmatched = $DifferenceMatched.Where({ !$_ }).Count
        if ($RefUnmatched -eq 0 -and $DiffUnmatched -eq 0) {
            return $true
        }
        return $false
    }
    [void] ValidateAddress([E911Address] $Address) {
        if ($null -eq $this.MapsKey) {
            $Address.Warning.Add([WarningType]::MapsValidation, 'No Maps API Key Found')
            return
        }
        $QueryArgs = [ordered]@{
            'subscription-key' = $this.MapsKey
            'api-version'      = '1.0'
            query              = $this._getAddressInMapsQueryForm($Address)
            limit              = 10
            countrySet         = $Address.CountryOrRegion
        }
        $Query = [Text.StringBuilder]::new()
        $JoinChar = '?'
        foreach ($Parameter in $QueryArgs.Keys) {
            if ($Query.Length -gt 1) {
                $JoinChar = '&'
            }
            $Value = $QueryArgs[$Parameter] -join ','
            [void]$Query.AppendFormat('{0}{1}={2}', $JoinChar, $Parameter, [HttpUtility]::UrlEncode($Value))
        }
        try {
            $this.MapsQueryCount++
            $CleanUri = ('{0}{1}' -f $this.MapsClient.BaseAddress, $Query.ToString())
            $CleanUri = $CleanUri -replace [Regex]::Escape($this.MapsKey), '<APIKEY REDACTED>'
            Write-Debug $CleanUri
            $responseString = $this.MapsClient.GetStringAsync($Query.ToString()).Result
            $Response = ''
            if (![string]::IsNullOrEmpty($responseString)) {
                $Response = $responseString | ConvertFrom-Json
            }
            if ([string]::IsNullOrEmpty($Response)) {
                throw "$CleanUri Produced no results!"
                return
            }
        }
        catch {
            $Address.Warning.Add([WarningType]::MapsValidation, "Maps API failure: $($_.Exception.Message)")
            return
        }

        $AzureMapsAddress = if ( $Response.summary.totalResults -gt 0 ) {
            $MapsAddress = @($Response.results | Sort-Object -Property score -Descending).Where({ $_.type -in @('Point Address', 'Address Range') }, 'First', 1)[0]
            if ($null -eq $MapsAddress) {
                $Address.Warning.Add([WarningType]::MapsValidation, 'No Addresses Found')
                return
            }
            $PostalOrZipCode = switch ($MapsAddress.address.countryCode) {
                { $_ -in @('CA', 'IE', 'GB', 'PT') } {
                    if ([string]::IsNullOrEmpty($Address.address.extendedPostalCode)) {
                        $MapsAddress.address.postalCode
                    }
                    else {
                        $MapsAddress.address.extendedPostalCode
                    }
                }
                default {
                    $MapsAddress.address.postalCode
                }
            }
            [PSCustomObject]@{
                HouseNumber        = $MapsAddress.address.streetNumber
                StreetName         = ($MapsAddress.address.streetName -split ',')[0]
                City               = ($MapsAddress.address.municipality -split ',')[0]
                AlternateCityNames = @(($MapsAddress.address.localName -split ',')[0] , ($MapsAddress.address.municipalitySubdivision -split ',')[0]).Where({ ![string]::IsNullOrEmpty($_) })
                StateOrProvince    = $MapsAddress.address.countrySubdivision
                PostalCode         = $PostalOrZipCode
                Country            = $MapsAddress.address.countryCode
                Latitude           = $MapsAddress.position.lat
                Longitude          = $MapsAddress.position.lon
            }
        }
        if (!$AzureMapsAddress) {
            Write-Debug ($Response | ConvertTo-Json -Compress)
        }
        $MapResultString = $($AzureMapsAddress | ConvertTo-Json -Compress)
        $ResultFound = ![string]::IsNullOrEmpty($MapResultString)
        if (!$ResultFound) {
            $Address.Warning.Add([WarningType]::MapsValidation, 'Address Not Found')
        }
        $Warned = $false
        # write warnings for changes from input
        $AzureAddress = '{0} {1}' -f $AzureMapsAddress.HouseNumber, $AzureMapsAddress.StreetName
        if ($ResultFound -and !($this.TestIsAddressMatch($AzureAddress, $Address.Address))) {
            # need to be better with fuzzy match here
            $Address.Warning.Add([WarningType]::MapsValidation, "Provided Address: '$($Address.Address)' does not match Azure Maps Address: '$($AzureAddress)'!")
            $Warned = $true
        }
        if ($ResultFound -and $Address.City -ne $AzureMapsAddress.City -and $Address.City -notin $AzureMapsAddress.AlternateCityNames) {
            # need to be better with fuzzy match here
            $Address.Warning.Add([WarningType]::MapsValidation, "Provided City: '$($Address.City)' does not match Azure Maps City: '$($AzureMapsAddress.City)'!")
            $Warned = $true
        }
        if ($ResultFound -and $Address.StateOrProvince -ne $AzureMapsAddress.StateOrProvince) {
            $Address.Warning.Add([WarningType]::MapsValidation, "Provided StateOrProvince: '$($Address.StateOrProvince)' does not match Azure Maps StateOrProvince: '$($AzureMapsAddress.StateOrProvince)'!")
            $Warned = $true
        }
        if ($ResultFound -and $Address.PostalCode -ne $AzureMapsAddress.PostalCode) {
            $Address.Warning.Add([WarningType]::MapsValidation, "Provided PostalCode: '$($Address.PostalCode)' does not match Azure Maps PostalCode: '$($AzureMapsAddress.PostalCode)'!")
            $Warned = $true
        }
        if ($ResultFound -and $Address.CountryOrRegion -ne $AzureMapsAddress.Country) {
            $Address.Warning.Add([WarningType]::MapsValidation, "Provided Country: '$($Address.CountryOrRegion)' does not match Azure Maps Country: '$($AzureMapsAddress.Country)'!")
            $Warned = $true
        }
        if ($ResultFound -and ![string]::IsNullOrEmpty($Address.Latitude) -and ![string]::IsNullOrEmpty($Address.Longitude) -and $Address.Latitude -ne 0 -and $Address.Longitude -ne 0) {
            if (!$this.CompareDoubleFuzzy($Address.Latitude, $AzureMapsAddress.Latitude)) {
                $Address.Warning.Add([WarningType]::MapsValidation, "Provided Latitude: '$($Address.Latitude)' does not match Azure Maps Latitude: '$($AzureMapsAddress.Latitude)'!")
                $Warned = $true
            }
            if (!$this.CompareDoubleFuzzy($Address.Longitude, $AzureMapsAddress.Longitude)) {
                $Address.Warning.Add([WarningType]::MapsValidation, "Provided Longitude: '$($Address.Longitude)' does not match Azure Maps Longitude: '$($AzureMapsAddress.Longitude)'!")
                $Warned = $true
            }
        }
        if ($ResultFound -and [string]::IsNullOrEmpty($Address.Latitude) -or [string]::IsNullOrEmpty($Address.Longitude) -or ($Address.Latitude -eq 0 -and $Address.Longitude -eq 0)) {
            $Address.Latitude = $AzureMapsAddress.Latitude
            $Address.Longitude = $AzureMapsAddress.Longitude
        }
        if ($ResultFound -and $Warned) {
            $Address.Warning.Add([WarningType]::MapsValidationDetail, "AzureMapsAddress: $($AzureMapsAddress | ConvertTo-Json -Compress)")
        }
    }

    [bool] CompareDoubleFuzzy([double] $ReferenceNum, [double] $DifferenceNum) {
        $Same = [Math]::Round($ReferenceNum, $this._geocodeDecimalPlaces) -eq [Math]::Round($DifferenceNum, $this._geocodeDecimalPlaces)
        if ($Same) {
            return $true
        }
        $Delta = [Math]::Abs($ReferenceNum - $DifferenceNum)
        $FmtString = [string]::new('0', $this._geocodeDecimalPlaces)
        $IsFuzzyMatch = [Math]::Round($Delta, $this._geocodeDecimalPlaces) -eq 0
        if (!$IsFuzzyMatch -and $ReferenceNum -ne 0.0) {
            Write-Debug (("ReferenceNum: {0:0.$FmtString}`tDifferenceNum: {1:0.$FmtString}`tDiff: {2:0.$FmtString}" -f $ReferenceNum, $DifferenceNum, $Delta))
        }
        return $IsFuzzyMatch
    }
    [string] _getAddressInMapsQueryForm([E911Address] $Address) {
        $sb = [StringBuilder]::new()
        $sb.AppendJoin(' ', $Address.Address, $Address.City, $Address.StateOrProvince, $Address.PostalCode)
        # $sb.Append($Address.Address)
        # $sb.Append(' ')
        # $sb.Append($Address.City)
        # $sb.Append(' ')
        # $sb.Append($Address.StateOrProvince)
        # if (![string]::IsNullOrEmpty($Address.PostalCode)) {
        #     $sb.Append(' ')
        #     $sb.Append($Address.PostalCode)
        # }
        do {
            # remove all double spaces until there are no more
            $len = $sb.Length
            $null = $sb.Replace('  ', ' ')
        } while ($sb.Length -lt $len)
        return $sb.ToString().Trim()
    }
    [void] ResetQueryCounter() {
        $this._mapsQueryCount = 0
    }

    hidden [string] $_azureMapsApiKey
    hidden [HttpClient] $_mapsClient
    hidden [int] $_geocodeDecimalPlaces = 3
    hidden [int] $_mapsQueryCount = 0
    static AddressValidator() {
        [PSClassProperty]::UpdateType(([AddressValidator]), @(
            @{
                Name = 'MapsClient'
                Getter = {
                    if ($null -eq $this._mapsClient) {
                        $this._mapsClient = [HttpClient]::new()
                        $this._mapsClient.BaseAddress = 'https://atlas.microsoft.com/search/address/json'
                    }
                    return $this._mapsClient
                } 
            },
            @{
                Name = 'MapsKey'
                Getter = {
                    if ([string]::IsNullOrEmpty($this._azureMapsApiKey) -and ![string]::IsNullOrEmpty($env:AZUREMAPS_API_KEY) -and $env:AZUREMAPS_API_KEY -ne $this._azureMapsApiKey) {
                        $this._azureMapsApiKey = $env:AZUREMAPS_API_KEY
                    }
                    return $this._azureMapsApiKey
                } 
            },
            @{
                Name = 'AbbreviationLookup'
                Getter = { 
                    return $this.s_replacementdictionary.Value
                }
            },
            @{
                Name = 'MapsQueryCount'
                Setter = {
                    if (($value-$this._mapsQueryCount) -eq 1) {
                        $this._mapsQueryCount = $value
                    }
                }
                Getter = { 
                    return $this._mapsQueryCount
                }
            }
        ))
    }
}