using module '..\..\modules\TeamsE911Internal\bin\release\TeamsE911Internal\TeamsE911Internal.psd1'
using module '..\..\modules\PSClassExtensions\bin\release\PSClassExtensions\PSClassExtensions.psd1'
using namespace System.Collections.Generic

class E911ModuleState {
    static [int] $MapsQueryCount = 0

    static [string[]] $NumberWords = @('zero', 'one', 'two', 'three', 'four', 'five', 'six', 'seven', 'eight', 'nine', 'ten', 'eleven', 'twelve', 'thirteen', 'fourteen', 'fifteen', 'sixteen', 'seventeen', 'eighteen', 'nineteen', 'twenty')

    hidden static [HashSet[string]] $Abbreviations = @('alley', 'allee', 'ally', 'anex', 'annex', 'annx', 'arcade', 'avenue', 'av', 'aven', 'avenu', 'avn', 'avnue', 'bayou', 'bayoo', 'beach', 'bend', 'bluff', 'bluf', 'bluffs', 'bot', 'bottm', 'bottom', 'boulevard', 'boul', 'boulv', 'branch', 'brnch', 'bridge', 'brdge', 'brook', 'brooks', 'burg', 'burgs', 'bypass', 'bypa', 'bypas', 'byps', 'camp', 'cmp', 'canyn', 'canyon', 'cnyn', 'cape', 'causeway', 'causwa', 'center', 'cen', 'cent', 'centr', 'centre', 'cnter', 'cntr', 'centers', 'circle', 'circ', 'circl', 'crcl', 'crcle', 'circles', 'cliff', 'cliffs', 'club', 'common', 'commons', 'corner', 'corners', 'course', 'court', 'courts', 'cove', 'coves', 'creek', 'crescent', 'crsent', 'crsnt', 'crest', 'crossing', 'crssng', 'crossroad', 'crossroads', 'curve', 'dale', 'dam', 'divide', 'div', 'dvd', 'drive', 'driv', 'drv', 'drives', 'estate', 'estates', 'expressway', 'exp', 'expr', 'express', 'expw', 'extension', 'extn', 'extnsn', 'extensions', 'falls', 'ferry', 'frry', 'field', 'fields', 'flat', 'flats', 'ford', 'fords', 'forest', 'forests', 'forge', 'forg', 'forges', 'fork', 'forks', 'fort', 'frt', 'freeway', 'freewy', 'frway', 'frwy', 'garden', 'gardn', 'grden', 'grdn', 'gardens', 'grdns', 'gateway', 'gatewy', 'gatway', 'gtway', 'glen', 'glens', 'green', 'greens', 'grove', 'grov', 'groves', 'harbor', 'harb', 'harbr', 'hrbor', 'harbors', 'haven', 'heights', 'ht', 'highway', 'highwy', 'hiway', 'hiwy', 'hway', 'hill', 'hills', 'hollow', 'hllw', 'hollows', 'holws', 'inlet', 'island', 'islnd', 'islands', 'islnds', 'isles', 'junction', 'jction', 'jctn', 'junctn', 'juncton', 'junctions', 'jctns', 'key', 'keys', 'knoll', 'knol', 'knolls', 'lake', 'lakes', 'landing', 'lndng', 'lane', 'light', 'lights', 'loaf', 'lock', 'locks', 'lodge', 'ldge', 'lodg', 'loops', 'manor', 'manors', 'meadow', 'meadows', 'mdw', 'medows', 'mill', 'mills', 'mission', 'missn', 'mssn', 'motorway', 'mount', 'mnt', 'mountain', 'mntain', 'mntn', 'mountin', 'mtin', 'mountains', 'mntns', 'neck', 'orchard', 'orchrd', 'ovl', 'overpass', 'prk', 'parks', 'parkway', 'parkwy', 'pkway', 'pky', 'parkways', 'pkwys', 'passage', 'paths', 'pikes', 'pine', 'pines', 'place', 'plain', 'plains', 'plaza', 'plza', 'point', 'points', 'port', 'ports', 'prairie', 'prr', 'radial', 'rad', 'radiel', 'ranch', 'ranches', 'rnchs', 'rapid', 'rapids', 'rest', 'ridge', 'rdge', 'ridges', 'river', 'rvr', 'rivr', 'road', 'roads', 'route', 'shoal', 'shoals', 'shore', 'shoar', 'shores', 'shoars', 'skyway', 'spring', 'spng', 'sprng', 'springs', 'spngs', 'sprngs', 'spurs', 'square', 'sqr', 'sqre', 'squ', 'squares', 'sqrs', 'station', 'statn', 'stn', 'stravenue', 'strav', 'straven', 'stravn', 'strvn', 'strvnue', 'stream', 'streme', 'street', 'strt', 'str', 'streets', 'summit', 'sumit', 'sumitt', 'terrace', 'terr', 'throughway', 'trace', 'traces', 'track', 'tracks', 'trk', 'trks', 'trafficway', 'trail', 'trails', 'trls', 'trailer', 'trlrs', 'tunnel', 'tunel', 'tunls', 'tunnels', 'tunnl', 'turnpike', 'trnpk', 'turnpk', 'underpass', 'union', 'unions', 'valley', 'vally', 'vlly', 'valleys', 'viaduct', 'vdct', 'viadct', 'view', 'views', 'village', 'vill', 'villag', 'villg', 'villiage', 'villages', 'ville', 'vista', 'vist', 'vst', 'vsta', 'walks', 'wy', 'well', 'wells', 'northwest', 'northeast', 'southwest', 'southeast', 'n', 'e', 'ne', 'w', 'nw', 's', 'se', 'sw', 'south', 'north', 'eighth', 'second', 'west', 'sixth', 'ninth', 'east', 'tenth', 'fourth', 'third', 'seventh', 'first', 'fifth')
    hidden static [hashtable] $s_replacementHash = @{aly = @('alley', 'allee', 'ally'); anx = @('anex', 'annex', 'annx'); arc = @('arcade'); ave = @('avenue', 'av', 'aven', 'avenu', 'avn', 'avnue'); byu = @('bayou', 'bayoo'); bch = @('beach'); bnd = @('bend'); blf = @('bluff', 'bluf'); blfs = @('bluffs'); btm = @('bot', 'bottm', 'bottom'); blvd = @('boulevard', 'boul', 'boulv'); br = @('branch', 'brnch'); brg = @('bridge', 'brdge'); brk = @('brook'); brks = @('brooks'); bg = @('burg'); bgs = @('burgs'); byp = @('bypass', 'bypa', 'bypas', 'byps'); cp = @('camp', 'cmp'); cyn = @('canyn', 'canyon', 'cnyn'); cpe = @('cape'); cswy = @('causeway', 'causwa'); ctr = @('center', 'cen', 'cent', 'centr', 'centre', 'cnter', 'cntr'); ctrs = @('centers'); cir = @('circle', 'circ', 'circl', 'crcl', 'crcle'); cirs = @('circles'); clf = @('cliff'); clfs = @('cliffs'); clb = @('club'); cmn = @('common'); cmns = @('commons'); cor = @('corner'); cors = @('corners'); crse = @('course'); ct = @('court'); cts = @('courts'); cv = @('cove'); cvs = @('coves'); crk = @('creek'); cres = @('crescent', 'crsent', 'crsnt'); crst = @('crest'); xing = @('crossing', 'crssng'); xrd = @('crossroad'); xrds = @('crossroads'); curv = @('curve'); dl = @('dale'); dm = @('dam'); dv = @('divide', 'div', 'dvd'); dr = @('drive', 'driv', 'drv'); drs = @('drives'); est = @('estate'); ests = @('estates'); expy = @('expressway', 'exp', 'expr', 'express', 'expw'); ext = @('extension', 'extn', 'extnsn'); exts = @('extensions'); fls = @('falls'); fry = @('ferry', 'frry'); fld = @('field'); flds = @('fields'); flt = @('flat'); flts = @('flats'); frd = @('ford'); frds = @('fords'); frst = @('forest', 'forests'); frg = @('forge', 'forg'); frgs = @('forges'); frk = @('fork'); frks = @('forks'); ft = @('fort', 'frt'); fwy = @('freeway', 'freewy', 'frway', 'frwy'); gdn = @('garden', 'gardn', 'grden', 'grdn'); gdns = @('gardens', 'grdns'); gtwy = @('gateway', 'gatewy', 'gatway', 'gtway'); gln = @('glen'); glns = @('glens'); grn = @('green'); grns = @('greens'); grv = @('grove', 'grov'); grvs = @('groves'); hbr = @('harbor', 'harb', 'harbr', 'hrbor'); hbrs = @('harbors'); hvn = @('haven'); hts = @('heights', 'ht'); hwy = @('highway', 'highwy', 'hiway', 'hiwy', 'hway'); hl = @('hill'); hls = @('hills'); holw = @('hollow', 'hllw', 'hollows', 'holws'); inlt = @('inlet'); is = @('island', 'islnd'); iss = @('islands', 'islnds'); isle = @('isles'); jct = @('junction', 'jction', 'jctn', 'junctn', 'juncton'); jcts = @('junctions', 'jctns'); ky = @('key'); kys = @('keys'); knl = @('knoll', 'knol'); knls = @('knolls'); lk = @('lake'); lks = @('lakes'); lndg = @('landing', 'lndng'); ln = @('lane'); lgt = @('light'); lgts = @('lights'); lf = @('loaf'); lck = @('lock'); lcks = @('locks'); ldg = @('lodge', 'ldge', 'lodg'); loop = @('loops'); mnr = @('manor'); mnrs = @('manors'); mdw = @('meadow'); mdws = @('meadows', 'mdw', 'medows'); ml = @('mill'); mls = @('mills'); msn = @('mission', 'missn', 'mssn'); mtwy = @('motorway'); mt = @('mount', 'mnt'); mtn = @('mountain', 'mntain', 'mntn', 'mountin', 'mtin'); mtns = @('mountains', 'mntns'); nck = @('neck'); orch = @('orchard', 'orchrd'); oval = @('ovl'); opas = @('overpass'); park = @('prk', 'parks'); pkwy = @('parkway', 'parkwy', 'pkway', 'pky', 'parkways', 'pkwys'); psge = @('passage'); path = @('paths'); pike = @('pikes'); pne = @('pine'); pnes = @('pines'); pl = @('place'); pln = @('plain'); plns = @('plains'); plz = @('plaza', 'plza'); pt = @('point'); pts = @('points'); prt = @('port'); prts = @('ports'); pr = @('prairie', 'prr'); radl = @('radial', 'rad', 'radiel'); rnch = @('ranch', 'ranches', 'rnchs'); rpd = @('rapid'); rpds = @('rapids'); rst = @('rest'); rdg = @('ridge', 'rdge'); rdgs = @('ridges'); riv = @('river', 'rvr', 'rivr'); rd = @('road'); rds = @('roads'); rte = @('route'); shl = @('shoal'); shls = @('shoals'); shr = @('shore', 'shoar'); shrs = @('shores', 'shoars'); skwy = @('skyway'); spg = @('spring', 'spng', 'sprng'); spgs = @('springs', 'spngs', 'sprngs'); spur = @('spurs'); sq = @('square', 'sqr', 'sqre', 'squ'); sqs = @('squares', 'sqrs'); sta = @('station', 'statn', 'stn'); stra = @('stravenue', 'strav', 'straven', 'stravn', 'strvn', 'strvnue'); strm = @('stream', 'streme'); st = @('street', 'strt', 'str'); sts = @('streets'); smt = @('summit', 'sumit', 'sumitt'); ter = @('terrace', 'terr'); trwy = @('throughway'); trce = @('trace', 'traces'); trak = @('track', 'tracks', 'trk', 'trks'); trfy = @('trafficway'); trl = @('trail', 'trails', 'trls'); trlr = @('trailer', 'trlrs'); tunl = @('tunnel', 'tunel', 'tunls', 'tunnels', 'tunnl'); tpke = @('turnpike', 'trnpk', 'turnpk'); upas = @('underpass'); un = @('union'); uns = @('unions'); vly = @('valley', 'vally', 'vlly'); vlys = @('valleys'); via = @('viaduct', 'vdct', 'viadct'); vw = @('view'); vws = @('views'); vlg = @('village', 'vill', 'villag', 'villg', 'villiage'); vlgs = @('villages'); vl = @('ville'); vis = @('vista', 'vist', 'vst', 'vsta'); walk = @('walks'); way = @('wy'); wl = @('well'); wls = @('wells') }

    hidden static [Lazy[Dictionary[HashSet[string], string]]] $s_replacementdictionary = [Lazy[Dictionary[HashSet[string], string]]]::new(
        [Func[Dictionary[HashSet[string], string]]] { 
            $dict = [Dictionary[HashSet[string], string]]@{}
            foreach ($key in [E911ModuleState]::s_replacementHash.Keys) {
                $dict[[HashSet[string]]([string[]][E911ModuleState]::s_replacementHash[$key])] = $key
            }
            return $dict
        })

    hidden static [Dictionary[HashSet[string], string]] $AbbreviationLookup = [E911ModuleState]::s_replacementdictionary.Value
    
    static [string] GetReplacement([string] $item) {
        if ([E911ModuleState]::Abbreviations.Contains($item)) {
            $key = [E911ModuleState]::AbbreviationLookup.Keys.Where({ $_.Contains($item) }, 'First', 1)[0]
            if ($null -eq $key) {
                return $item
            }
            return [E911ModuleState]::AbbreviationLookup[$key]
        }
        return $item
    }

    static [List[string]] GetCleanAddressParts([string] $Address) {
        $Address = $Address.ToLowerInvariant()
        $AddressTokens = [List[string]][string[]]($Address -split '\b').Where({ $_ -match '\w' }).ForEach({ $_.Trim() })
        for ($i = 0; $i -lt $AddressTokens.Count; $i++) {
            $CurrentToken = $AddressTokens[$i]
            if ([E911ModuleState]::Abbreviations.Contains($CurrentToken)) {
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
                $Replacement = [E911ModuleState]::GetReplacement($CurrentToken)
                if ($null -ne $Replacement) {
                    $AddressTokens[$i] = $Replacement
                }
            }
            if (($Index = [E911ModuleState]::NumberWords.IndexOf($CurrentToken)) -gt 0) {
                $AddressTokens[$i] = $Index
            }
        }
        return $AddressTokens
    }

    static [bool] TestIsAddressMatch([string] $ReferenceAddress, [string] $DifferenceAddress) {
        if ($ReferenceAddress -eq $DifferenceAddress) { return $true }

        $ReferenceAddressTokens = [E911ModuleState]::GetCleanAddressParts($ReferenceAddress)
        $ReferenceMatched = [bool[]]::new($ReferenceAddressTokens.Count)

        $DifferenceAddressTokens = [E911ModuleState]::GetCleanAddressParts($DifferenceAddress)
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

    static [void] ValidateAddress([E911Address] $Address) {
        if ($null -eq [E911ModuleState]::MapsKey()) {
            $Address.Warning.Add([WarningType]::MapsValidation, 'No Maps API Key Found')
            return
        }
        $QueryArgs = [ordered]@{
            'subscription-key' = [E911ModuleState]::MapsKey()
            'api-version'      = '1.0'
            query              = [E911ModuleState]::_getAddressInMapsQueryForm($Address)
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
            [void]$Query.AppendFormat('{0}{1}={2}', $JoinChar, $Parameter, [System.Web.HttpUtility]::UrlEncode($Value))
        }
        try {
            [E911ModuleState]::MapsQueryCount++
            $CleanUri = ('{0}{1}' -f [E911ModuleState]::MapsClient().BaseAddress, $Query.ToString())
            $CleanUri = $CleanUri -replace [Regex]::Escape([E911ModuleState]::MapsKey()), '<APIKEY REDACTED>'
            Write-Debug $CleanUri
            $responseString = [E911ModuleState]::MapsClient().GetStringAsync($Query.ToString()).Result
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
                        # what am I doing here? there is no address.extendedPostalCode field on my E911Address object??
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
        if ($ResultFound -and !([E911ModuleState]::TestIsAddressMatch($AzureAddress, $Address.Address))) {
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
            if (![E911ModuleState]::CompareDoubleFuzzy($Address.Latitude, $AzureMapsAddress.Latitude)) {
                $Address.Warning.Add([WarningType]::MapsValidation, "Provided Latitude: '$($Address.Latitude)' does not match Azure Maps Latitude: '$($AzureMapsAddress.Latitude)'!")
                $Warned = $true
            }
            if (![E911ModuleState]::CompareDoubleFuzzy($Address.Longitude, $AzureMapsAddress.Longitude)) {
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

    static [bool] $WriteWarnings = $false

    hidden static [Dictionary[string, E911Address]] $OnlineAddresses = @{}
    hidden static [Dictionary[string, E911Address]] $Addresses = @{}
    hidden static [Dictionary[string, E911Location]] $OnlineLocations = @{}
    hidden static [Dictionary[string, E911Location]] $Locations = @{}
    hidden static [Dictionary[string, E911NetworkObject]] $OnlineNetworkObjects = @{}
    hidden static [Dictionary[string, E911NetworkObject]] $NetworkObjects = @{}

    static [E911Address] GetOrCreateAddress([PSCustomObject] $obj, [bool] $ShouldValidate) {
        $dbgStr = $obj | Select-Object -Property * | ConvertTo-Json -Compress
        $Hash = [E911Address]::GetHash($obj)
        $Test = $null
        if ([E911ModuleState]::Addresses.TryGetValue($Hash, [ref] $Test)) {
            $Equal = [E911Address]::Equals($Test, $obj)
            if ($Equal -and ($Test.Warning.MapsValidationFailed() -or $null -eq $obj.SkipMapsLookup -or !$Test.SkipMapsLookup -or $obj.SkipMapsLookup -eq $Test.SkipMapsLookup)) {
                return $Test
            }
            if (!$Equal) {
                # not a true match, we will force this one to be created
                $Test = $null
            }
        }
        $OnlineChanged = $false
        $Online = $null
        if (![string]::IsNullOrEmpty($obj.CivicAddressId) -and [E911ModuleState]::OnlineAddresses.TryGetValue($obj.CivicAddressId.ToLower(), [ref] $Online)) {
            if ([E911Address]::Equals($Online, $obj)) {
                return $Online
            }
            $OnlineChanged = $true
        }
        if ($null -eq $Online -and [E911ModuleState]::OnlineAddresses.TryGetValue($Hash, [ref] $Online)) {
            if ([E911Address]::Equals($Online, $obj)) {
                if (![string]::IsNullOrEmpty($obj.CivicAddressId)) {
                    # found a duplicate online address, lets add this address id here so we can link this up later
                    [E911ModuleState]::OnlineAddresses.Add($obj.CivicAddressId.ToLower(), $Online)
                    # $DuplicatedOnline = [E911Address]::new($obj, $ShouldValidate)
                    # [E911ModuleState]::OnlineAddresses.Add($obj.CivicAddressId.ToLower(), $DuplicatedOnline)
                    # return $DuplicatedOnline
                }
                return $Online
            }
            $OnlineChanged = $true
        }
        $New = [E911Address]::new($obj, $ShouldValidate)
        if ($New.GetHash() -ne $Hash) { throw 'Address Hash Functions do not match!' }
        if ($null -ne $Test) {
            if ($New.HasWarnings()) {
                $Test.Warning.AddRange($New.Warning)
            }
            $Test.Latitude = if ($Test.Latitude -eq 0) { $New.Latitude } else { $Test.Latitude }
            $Test.Longitude = if ($Test.Longitude -eq 0) { $New.Longitude } else { $Test.Longitude }
            $Test.SkipMapsLookup = $false
            $Test._hasChanged = $true
            [E911ModuleState]::Addresses[$Test.GetHash()] = $Test
            if ($Test._isOnline -and $OnlineChanged) {
                [E911ModuleState]::OnlineAddresses[$Test.GetHash()] = $Test
                [E911ModuleState]::OnlineAddresses[$Test.Id.ToString().ToLower()] = $Test
            }
            return $Test
        }
        if ((!$New._isOnline -and $ShouldValidate) -or $OnlineChanged) {
            $New._hasChanged = $true
            [E911ModuleState]::Addresses.Add($New.GetHash(), $New)
        }
        if ($OnlineChanged) {
            [E911ModuleState]::OnlineAddresses[$New.GetHash()] = $New
            [E911ModuleState]::OnlineAddresses[$New.Id.ToString().ToLower()] = $New
        }
        if ($New._isOnline -and !$OnlineChanged) {
            [E911ModuleState]::OnlineAddresses.Add($New.GetHash(), $New)
            [E911ModuleState]::OnlineAddresses.Add($New.Id.ToString().ToLower(), $New)
        }
        return $New
    }

    static [E911Location] GetOrCreateLocation([PSCustomObject] $obj, [bool]$ShouldValidate) {
        $OnlineChanged = $false
        $Online = $null
        if (![string]::IsNullOrEmpty($obj.LocationId) -and [E911ModuleState]::OnlineLocations.TryGetValue($obj.LocationId.ToLower(), [ref] $Online)) {
            if (([string]::IsNullOrEmpty($obj.Location) -and [string]::IsNullOrEmpty($obj.CountryOrRegion)) -or [E911Location]::Equals($Online, $obj)) {
                return $Online
            }
            # not sure we should ever get here...
            $OnlineChanged = $true
        }
        $Hash = [E911Location]::GetHash($obj)
        $Temp = $null
        if ([E911ModuleState]::Locations.TryGetValue($Hash, [ref] $Temp) -and [E911Location]::Equals($Temp, $obj)) {
            return $Temp
        }
        if ($null -eq $Online -and [E911ModuleState]::OnlineLocations.TryGetValue($Hash, [ref] $Online)) {
            if ([E911Location]::Equals($Online, $obj)) {
                if (![string]::IsNullOrEmpty($obj.LocationId)) {
                    # found a duplicate online location, lets add this location id here so we can link this up later
                    [E911ModuleState]::OnlineLocations.Add($obj.LocationId.ToLower(), $Online)
                }
                return $Online
            }
            $OnlineChanged = $true
        }
        $New = [E911Location]::new($obj, $ShouldValidate)
        if ($New.GetHash() -ne $Hash) { throw 'Location Hash Functions do not match!' }
        if ((!$New._isOnline -and $ShouldValidate) -or $OnlineChanged) {
            $New._hasChanged = $true
            [E911ModuleState]::Locations.Add($New.GetHash(), $New)
        }
        if ($OnlineChanged) {
            $New._hasChanged = $true
            [E911ModuleState]::OnlineLocations[$New.GetHash()] = $New
            [E911ModuleState]::OnlineLocations[$New.Id.ToString().ToLower()] = $New
        }
        return $New
    }

    static [E911NetworkObject] GetOrCreateNetworkObject([PSCustomObject] $obj, [bool]$ShouldValidate) {
        $Hash = [E911NetworkObject]::GetHash($obj)
        $dup = $false
        $Test = $null
        if ([E911ModuleState]::NetworkObjects.TryGetValue($Hash, [ref] $Test)) {
            if ([E911Location]::Equals($obj, $Test._location)) {
                return $Test
            }
            if ($Test.Type -ne [NetworkObjectType]::Unknown) {
                $dup = $true
                $Test._isDuplicate = $true
                $Test.Warning.Add([WarningType]::DuplicateNetworkObject, "$($Test.Type):$($Test.Identifier) exists in other rows")
            }
        }
        $OnlineChanged = $false
        $Online = $null
        if ([E911ModuleState]::OnlineNetworkObjects.TryGetValue($Hash, [ref] $Online)) {
            if ([E911NetworkObject]::Equals($Online, $obj)) {
                if ($dup) {
                    $Online.Warning.Add([WarningType]::DuplicateNetworkObject, "$($Online.Type):$($Online.Identifier) exists in other rows")
                }
                return $Online
            }
            $OnlineChanged = $true
        }
        $New = [E911NetworkObject]::new($obj, $ShouldValidate)
        if ($dup) {
            $New.Warning.Add([WarningType]::DuplicateNetworkObject, "$($New.Type):$($New.Identifier) exists in other rows")
        }
        if (!$dup <#-and $New.Type -ne [NetworkObjectType]::Unknown#> -and ((!$New._isOnline -and $ShouldValidate) -or $OnlineChanged)) {
            if ($New.Type -ne [NetworkObjectType]::Unknown) {
                $New._hasChanged = $true
            }
            if (![E911ModuleState]::NetworkObjects.ContainsKey($New.GetHash())) {
                [E911ModuleState]::NetworkObjects.Add($New.GetHash(), $New)
            }
            if ($Hash -ne $New.GetHash()) {
                [E911ModuleState]::NetworkObjects.Add($Hash, $New)
            }
        }
        if ($OnlineChanged) {
            $New._hasChanged = $true
            [E911ModuleState]::OnlineNetworkObjects[$New.GetHash()] = $New
            if ($Hash -ne $New.GetHash()) {
                [E911ModuleState]::OnlineNetworkObjects[$Hash] = $New
            }
        }
        if ($New._isOnline -and !$OnlineChanged) {
            [E911ModuleState]::OnlineNetworkObjects.Add($New.GetHash(), $New)
            if ($Hash -ne $New.GetHash()) {
                [E911ModuleState]::OnlineNetworkObjects.Add($Hash, $New)
            }
        }
        return $New
    }

    static [bool] $ForceOnlineCheck = $false
    # this is set to false after first caching run, then set to true after processing first online change in Set-CsE911OnlineChange
    static hidden [bool] $ShouldClear = $true

    static [void] FlushCaches([PSFunctionHost] $ParentProcessHelper) {
        $flushProcess = [PSFunctionHost]::StartNew($ParentProcessHelper, 'Clearing Caches')
        try {
            [E911ModuleState]::MapsQueryCount = 0
            $flushProcess.WriteVerbose('Flushing Caches...')
            $OnlineAddrCount = [E911ModuleState]::OnlineAddresses.Count
            $AddrCount = [E911ModuleState]::Addresses.Count
            $OnlineLocCount = [E911ModuleState]::OnlineLocations.Count
            $LocCount = [E911ModuleState]::Locations.Count
            $OnlineNobjCount = [E911ModuleState]::OnlineNetworkObjects.Count
            $NobjCount = [E911ModuleState]::NetworkObjects.Count
            [E911ModuleState]::OnlineAddresses.Clear()
            $flushProcess.WriteVerbose(('{0} Online Addresses Removed' -f ($OnlineAddrCount - [E911ModuleState]::OnlineAddresses.Count)))
            [E911ModuleState]::Addresses.Clear()
            $flushProcess.WriteVerbose(('{0} Addresses Removed' -f ($AddrCount - [E911ModuleState]::Addresses.Count)))
            [E911ModuleState]::OnlineLocations.Clear()
            $flushProcess.WriteVerbose(('{0} Online Locations Removed' -f ($OnlineLocCount - [E911ModuleState]::OnlineLocations.Count)))
            [E911ModuleState]::Locations.Clear()
            $flushProcess.WriteVerbose(('{0} Locations Removed' -f ($LocCount - [E911ModuleState]::Locations.Count)))
            [E911ModuleState]::OnlineNetworkObjects.Clear()
            $flushProcess.WriteVerbose(('{0} Online Network Objects Removed' -f ($OnlineNobjCount - [E911ModuleState]::OnlineNetworkObjects.Count)))
            [E911ModuleState]::NetworkObjects.Clear()
            $flushProcess.WriteVerbose(('{0} Network Objects Removed' -f ($NobjCount - [E911ModuleState]::NetworkObjects.Count)))
            [E911ModuleState]::ShouldClear = $false
        }
        finally {
            if ($null -ne $flushProcess) {
                $flushProcess.Dispose()
            }
        }
    }

    hidden static [string] GetCommandName() {
        $CallStack = Get-PSCallStack
        $CommandName = $CallStack.Command
        $IgnoreNames = @([E911ModuleState].DeclaredMethods.Name | Sort-Object -Unique)
        $IgnoreNames += '<ScriptBlock>'
        if ($CommandName.Count -gt 1) {
            $CommandName = $CommandName | Where-Object { ![string]::IsNullOrEmpty($_) -and $_ -notin $IgnoreNames -and $_ -match '(?=^[^-]*-[^-]*$)' } | Select-Object -First 1
        }
        if ([string]::IsNullOrEmpty($CommandName)) {
            $CommandName = $CallStack.FunctionName | Where-Object { ![string]::IsNullOrEmpty($_) -and $_ -notin $IgnoreNames -and $_ -match '^E911' } | Select-Object -First 1
        }
        if ([string]::IsNullOrEmpty($CommandName)) {
            $CommandName = $CallStack.Command | Where-Object { ![string]::IsNullOrEmpty($_) -and $_ -notin $IgnoreNames } | Select-Object -First 1
        }
        return $CommandName
    }

    hidden static [long] $Interval = 200

    static [void] InitializeCaches([PSFunctionHost] $parent) {
        $currentProcess = [PSFunctionHost]::StartNew($parent, 'Initializing Caches')
        
        try {
            if ([E911ModuleState]::ShouldClear) {
                [E911ModuleState]::FlushCaches($currentProcess)
            }
            if (([E911ModuleState]::Addresses.Count + [E911ModuleState]::Locations.Count + [E911ModuleState]::NetworkObjects.Count + [E911ModuleState]::OnlineAddresses.Count + [E911ModuleState]::OnlineLocations.Count + [E911ModuleState]::OnlineNetworkObjects.Count) -gt 0) {
                $currentProcess.Complete()
                return
            }
            $currentProcess.WriteVerbose('Populating Caches...')
            $currentProcess.ForceUpdate('Getting Objects from LIS')
                
            [LisObjectHelper]::LoadCache($currentProcess, [E911ModuleState]::ShouldClear)
            $lisLocations = [LisLocation]::GetAll()
            $locationSet = [LisLocationPrioritySet]$lisLocations
            $onlineLisNetworkObjects = [LisNetworkObject]::GetAll($true, $false)
            
            if ($lisLocations.Count -gt $locationSet.Count) {
                $currentProcess.WriteWarning(('Found {0} Duplicate Locations' -f ($lisLocations.Count - $locationSet.Count)))
                foreach ($duplicate in $lisLocations.Where({ !$locationSet.Contains($_) }) ) {
                    $newLocation = $locationSet.Where({ $_.GetHash() -eq $duplicate.GetHash() }, 'First', 1)[0]
                    $currentProcess.WriteWarning(('Duplicate Location {0}: Updating to {1}' -f $duplicate.LocationId, $newLocation.LocationId))
                }
            }

            $CachedAddresses = 0
            $CachedLocations = 0
            $CachedNetworkObjects = 0
            $locationProcess = [PSFunctionHost]::StartNew($currentProcess, 'Caching Locations')
            $locationProcess.Total = $locationSet.Count
            foreach ($onlineLocation in $locationSet) {
                $currentProcess.Update(('Addresses: {0} Locations: {1} NetworkObjects: {2}' -f $CachedAddresses, $CachedLocations, $CachedNetworkObjects))
                $locationProcess.Update($true, ('Processing Location: {0}' -f $onlineLocation.LocationId))
                $address = $null
                if (![E911ModuleState]::OnlineAddresses.TryGetValue($onlineLocation.CivicAddressId, [ref] $address)) {
                    $onlineAddress = $onlineLocation.GetCivicAddress()
                    if ($null -ne $onlineAddress) {
                        $locationProcess.WriteVerbose(('Caching Address: {0}' -f $onlineAddress.CivicAddressId))
                        $address = $onlineAddress._getE911Address()
                        [E911ModuleState]::OnlineAddresses[$onlineAddress.CivicAddressId] = $address
                        [E911ModuleState]::OnlineAddresses[$address.GetHash()] = $address
                        $CachedAddresses++
                    }
                }
                if ($null -eq $address) {
                    $locationProcess.WriteWarning(('Location: {0} is orphaned!' -f $onlineLocation.LocationId))
                }
                $locationProcess.WriteVerbose(('Caching Location: {0}' -f $onlineLocation.LocationId))
                $newOLoc = $onlineLocation._getE911Location($address)
                [E911ModuleState]::OnlineLocations[$onlineLocation.LocationId] = $newOLoc
                [E911ModuleState]::OnlineLocations[$newOLoc.GetHash()] = $newOLoc
                $CachedLocations++
            }
            $locationProcess.Complete()
            $currentProcess.WriteVerbose(('Cached {0} Civic Addresses' -f $CachedAddresses))
            $currentProcess.WriteVerbose(('Cached {0} Locations' -f $CachedLocations))

            $networkObjectProcess = [PSFunctionHost]::StartNew($currentProcess, 'Caching Network Objects')
            $networkObjectProcess.Total = $onlineLisNetworkObjects.Count
            foreach ($networkObject in $onlineLisNetworkObjects) {
                $networkObjectProcess.WriteVerbose(('Processing {0}: {1}' -f $networkObject.Type, $networkObject.Identifier()))
                $currentProcess.Update(('Addresses: {0} Locations: {1} NetworkObjects: {2}' -f $CachedAddresses, $CachedLocations, $CachedNetworkObjects))
                $networkObjectProcess.Update($true, ('Processing {0}: {1}' -f $networkObject.Type, $networkObject.Identifier()))
                $location = $networkObject.GetLocation()
                $newLocation = $null
                if ($null -ne $location) {
                    $locationSet.TryGetValue($location, [ref] $newLocation)
                }
                else {
                    $networkObjectProcess.WriteWarning(('{0}: {1} is orphaned!' -f $networkObject.Type, $networkObject.Identifier()))
                }
                if ($null -eq $newLocation -and $null -ne $location) {
                    $networkObjectProcess.WriteWarning(('LOCATION RETRIEVAL FAILURE: {0} {1}' -f $location.GetHash(), $location.LocationId))
                }
                $newNetworkObject = [E911NetworkObject]::new($true, @{
                        Type        = $networkObject.Type
                        Identifier  = $networkObject.Identifier()
                        Description = if ($null -eq $networkObject.Description) { '' } else { $networkObject.Description }
                    })
                $newNetworkObject._hasChanged = $null -ne $newLocation -and $networkObject.LocationId -ne $newLocation.LocationId
                $newNetworkObject._location = if ($null -ne $newLocation) { [E911ModuleState]::OnlineLocations[$newLocation.LocationId] } else { $null }
                [E911ModuleState]::OnlineNetworkObjects[$newNetworkObject.GetHash()] = $newNetworkObject
                $CachedNetworkObjects++
            }
            $currentProcess.WriteVerbose(('Cached {0} Network Objects' -f $CachedNetworkObjects))
        }
        finally {
            if ($null -ne $currentProcess) {
                $currentProcess.Dispose()
            }
        }
    }

    hidden static [string] $_azureMapsApiKey
    hidden static [System.Net.Http.HttpClient] $_mapsClient
    hidden static [string] MapsKey() {
        if ([string]::IsNullOrEmpty([E911ModuleState]::_azureMapsApiKey) -and ![string]::IsNullOrEmpty($env:AZUREMAPS_API_KEY) -and $env:AZUREMAPS_API_KEY -ne [E911ModuleState]::_azureMapsApiKey) {
            [E911ModuleState]::_azureMapsApiKey = $env:AZUREMAPS_API_KEY
        }
        return [E911ModuleState]::_azureMapsApiKey
    }
    hidden static [System.Net.Http.HttpClient] MapsClient() {
        if ($null -eq [E911ModuleState]::_mapsClient) {
            
            [E911ModuleState]::_mapsClient = [System.Net.Http.HttpClient]::new()
            [E911ModuleState]::_mapsClient.BaseAddress = 'https://atlas.microsoft.com/search/address/json'
        }
        return [E911ModuleState]::_mapsClient
    }
    hidden static [int] $_geocodeDecimalPlaces = 3
    hidden static [bool] CompareDoubleFuzzy([double] $ReferenceNum, [double] $DifferenceNum) {
        $Same = [Math]::Round($ReferenceNum, [E911ModuleState]::_geocodeDecimalPlaces) -eq [Math]::Round($DifferenceNum, [E911ModuleState]::_geocodeDecimalPlaces)
        if ($Same) {
            return $true
        }
        $Delta = [Math]::Abs($ReferenceNum - $DifferenceNum)
        $FmtString = [string]::new('0', [E911ModuleState]::_geocodeDecimalPlaces)
        $IsFuzzyMatch = [Math]::Round($Delta, [E911ModuleState]::_geocodeDecimalPlaces) -eq 0
        if (!$IsFuzzyMatch -and $ReferenceNum -ne 0.0) {
            Write-Debug (("ReferenceNum: {0:0.$FmtString}`tDifferenceNum: {1:0.$FmtString}`tDiff: {2:0.$FmtString}" -f $ReferenceNum, $DifferenceNum, $Delta))
        }
        return $IsFuzzyMatch
    }
    hidden static [string] _getAddressInMapsQueryForm([E911Address] $Address) {
        $sb = [Text.StringBuilder]::new()
        [void]$sb.Append($Address.Address)
        [void]$sb.Append(' ')
        [void]$sb.Append($Address.City)
        [void]$sb.Append(' ')
        [void]$sb.Append($Address.StateOrProvince)
        if (![string]::IsNullOrEmpty($Address.PostalCode)) {
            [void]$sb.Append(' ')
            [void]$sb.Append($Address.PostalCode)
        }
        return $sb.ToString()
    }
}