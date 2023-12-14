# need to ensure Pester is versioned appropriately
#Requires -Modules @{ModuleName='Pester';ModuleVersion='5.0.0'}
Describe 'Get-CsE911NeededChange' {
    BeforeAll {
        $ModuleRoot = Split-Path -Path (Split-Path -Path $PSCommandPath -Parent) -Parent
        $ModuleName = 'TeamsE911Automation'

        $WVerboseFunc = [Func[bool]] { $______pester_invoke_block_parameters.Block.ShouldRun -and !$______pester_invoke_block_parameters.Block.Skip -and $____Pester.Configuration.Output.Verbosity.Value -in @('Diagnostic') }
        $WVParam = @{
            Verbose = $WVerboseFunc.Invoke()
        }

        # import secrets and connect
        $env:AZUREMAPS_API_KEY = 'DUMMY_SECRET_VALUE'

        Get-Module $ModuleName | Remove-Module
        Get-Module MicrosoftTeams | Remove-Module
        Import-Module "${ModuleRoot}\bin\debug\${ModuleName}" -Force

        $KnownGoodRow = @{ CompanyName = 'TestCompany'; CompanyTaxId = ''; Description = ''; Address = '1 Microsoft Way'; Location = ''; City = 'Redmond'; StateOrProvince = 'WA'; PostalCode = '98052'; CountryOrRegion = 'US'; Latitude = '47.63963'; Longitude = '-122.12852'; ELIN = ''; NetworkDescription = ''; NetworkObjectType = 'Subnet'; NetworkObjectIdentifier = '10.0.0.0'; SkipMapsLookup = 'false'; EntryHash = ''; Warning = '' }
        function Get-TestRow {
            param (
                [string[]]
                $PropertiesToExclude,
                [hashtable]
                $OverrideValues
            )
            $Properties = [Collections.Generic.List[object]]::new()
            $Properties.Add('*')
            $TestObject = [PSCustomObject]$KnownGoodRow
            foreach ($Key in $OverrideValues.Keys) {
                $TestObject.$Key = $OverrideValues[$Key]
            }
            foreach ($Property in $PropertiesToExclude) {
                if ($OverrideValues.ContainsKey($Property)) { $PropertiesToExclude = $PropertiesToExclude.Where({ $_ -ne $Property }) }
                $Properties.Add(@{
                        Name       = $Property
                        Expression = { '' }
                    })
            }
            $TestObject | Select-Object -Property $Properties -ExcludeProperty $PropertiesToExclude
        }
        function Get-CommandParameters {
            param (
                [ScriptBlock]
                $Command,
                [string[]]
                $ParametersToCheck
            )
            if ($null -eq $Command) { return $null }
            $CommandElements = $Command.Ast.FindAll([System.Func[System.Management.Automation.Language.Ast, bool]] { $args[0] -is [System.Management.Automation.Language.CommandAst] }, $false).CommandElements
            $Updated = @{}
            for ($i = 0; $i -lt $CommandElements.Count; $i++) {
                if ($CommandElements[$i] -isnot [System.Management.Automation.Language.CommandParameterAst]) { continue }
                if ($CommandElements[$i].ParameterName -notin $ParametersToCheck) { continue }
                $Param = $CommandElements[$i]
                $Value = $Param.Argument
                if ($null -eq $Value) {
                    $i++
                    $Value = $CommandElements[$i].Value
                    if ($null -eq $Value) {
                        $Value = $CommandElements[$i].Extent.Text
                    }
                }
                $Updated[$Param.ParameterName] = $Value
            }
            return [PSCustomObject]$Updated
        }

        Mock -ModuleName $ModuleName -CommandName Assert-TeamsIsConnected -MockWith {
            return
        }
        Mock -ModuleName $ModuleName -CommandName New-CsOnlineLisCivicAddress -MockWith {
            [CmdletBinding(PositionalBinding = $false, SupportsShouldProcess, ConfirmImpact = 'Medium')]
            param(
                [Parameter(Mandatory, ValueFromPipelineByPropertyName)]
                [System.String]
                ${CompanyName},
                [Parameter(Mandatory, ValueFromPipelineByPropertyName)]
                [System.String]
                ${CountryOrRegion},
                [Parameter(ValueFromPipelineByPropertyName)]
                [System.String]
                ${City},
                [Parameter(ValueFromPipelineByPropertyName)]
                [System.String]
                ${CityAlias},
                [Parameter(ValueFromPipelineByPropertyName)]
                [System.String]
                ${CompanyTaxId},
                [Parameter(ValueFromPipelineByPropertyName)]
                [System.String]
                ${Confidence},
                [Parameter(ValueFromPipelineByPropertyName)]
                [System.String]
                ${Description},
                [Parameter(ValueFromPipelineByPropertyName)]
                [System.String]
                ${Elin},
                [Parameter()]
                [System.Management.Automation.SwitchParameter]
                ${Force},
                [Parameter(ValueFromPipelineByPropertyName)]
                [System.String]
                ${HouseNumber},
                [Parameter(ValueFromPipelineByPropertyName)]
                [System.String]
                ${HouseNumberSuffix},
                [Parameter(ValueFromPipelineByPropertyName)]
                [System.Boolean]
                ${IsAzureMapValidationRequired},
                [Parameter(ValueFromPipelineByPropertyName)]
                [System.String]
                ${Latitude},
                [Parameter(ValueFromPipelineByPropertyName)]
                [System.String]
                ${Longitude},
                [Parameter(ValueFromPipelineByPropertyName)]
                [System.String]
                ${PostalCode},
                [Parameter(ValueFromPipelineByPropertyName)]
                [System.String]
                ${PostDirectional},
                [Parameter(ValueFromPipelineByPropertyName)]
                [System.String]
                ${PreDirectional},
                [Parameter(ValueFromPipelineByPropertyName)]
                [System.String]
                ${StateOrProvince},
                [Parameter(ValueFromPipelineByPropertyName)]
                [System.String]
                ${StreetName},
                [Parameter(ValueFromPipelineByPropertyName)]
                [System.String]
                ${StreetSuffix},
                [Parameter()]
                [System.String]
                ${ValidationStatus},
                [Parameter(DontShow)]
                [System.String]
                ${MsftInternalProcessingMode}
            )
            return [PSCustomObject]@{
                CompanyName                  = $CompanyName
                CountryOrRegion              = $CountryOrRegion
                City                         = $City
                CityAlias                    = $CityAlias
                CompanyTaxId                 = $CompanyTaxId
                Confidence                   = $Confidence
                Description                  = $Description
                Elin                         = $Elin
                HouseNumber                  = $HouseNumber
                HouseNumberSuffix            = $HouseNumberSuffix
                IsAzureMapValidationRequired = $IsAzureMapValidationRequired
                Latitude                     = $Latitude
                Longitude                    = $Longitude
                PostalCode                   = $PostalCode
                PostDirectional              = $PostDirectional
                PreDirectional               = $PreDirectional
                StateOrProvince              = $StateOrProvince
                StreetName                   = $StreetName
                StreetSuffix                 = $StreetSuffix
                ValidationStatus             = $ValidationStatus
            }
        }
        Mock -ModuleName $ModuleName -CommandName New-CsOnlineLisLocation -MockWith {
            [CmdletBinding(DefaultParameterSetName = 'ExistingCivicAddress', PositionalBinding = $false, SupportsShouldProcess, ConfirmImpact = 'Medium')]
            param(
                [Parameter(Mandatory, ValueFromPipelineByPropertyName)]
                [System.String]
                ${Location},
                [Parameter(ParameterSetName = 'ExistingCivicAddress', Mandatory, ValueFromPipelineByPropertyName)]
                [System.Guid]
                ${CivicAddressId},
                [Parameter(ValueFromPipelineByPropertyName)]
                [System.String]
                ${CityAlias},
                [Parameter(ValueFromPipelineByPropertyName)]
                [Alias('Name')]
                [System.String]
                ${CompanyName},
                [Parameter(ValueFromPipelineByPropertyName)]
                [System.String]
                ${CompanyTaxId},
                [Parameter(ValueFromPipelineByPropertyName)]
                [System.String]
                ${Confidence},
                [Parameter(ValueFromPipelineByPropertyName)]
                [System.String]
                ${Elin},
                [Parameter()]
                [System.Management.Automation.SwitchParameter]
                ${Force},
                [Parameter(ValueFromPipelineByPropertyName)]
                [System.String]
                ${HouseNumberSuffix},
                [Parameter(ValueFromPipelineByPropertyName)]
                [System.String]
                ${Latitude},
                [Parameter(ValueFromPipelineByPropertyName)]
                [System.String]
                ${Longitude},
                [Parameter(DontShow)]
                [System.String]
                ${MsftInternalProcessingMode},
                [Parameter(ParameterSetName = 'CreateCivicAddress', Mandatory, ValueFromPipelineByPropertyName)]
                [Alias('Country')]
                [System.String]
                ${CountryOrRegion},
                [Parameter(ParameterSetName = 'CreateCivicAddress', ValueFromPipelineByPropertyName)]
                [System.String]
                ${City},
                [Parameter(ParameterSetName = 'CreateCivicAddress', ValueFromPipelineByPropertyName)]
                [System.String]
                ${Description},
                [Parameter(ParameterSetName = 'CreateCivicAddress', ValueFromPipelineByPropertyName)]
                [System.String]
                ${HouseNumber},
                [Parameter(ParameterSetName = 'CreateCivicAddress', ValueFromPipelineByPropertyName)]
                [System.String]
                ${PostalCode},
                [Parameter(ParameterSetName = 'CreateCivicAddress', ValueFromPipelineByPropertyName)]
                [System.String]
                ${PostDirectional},
                [Parameter(ParameterSetName = 'CreateCivicAddress', ValueFromPipelineByPropertyName)]
                [System.String]
                ${PreDirectional},
                [Parameter(ParameterSetName = 'CreateCivicAddress', ValueFromPipelineByPropertyName)]
                [Alias('State')]
                [System.String]
                ${StateOrProvince},
                [Parameter(ParameterSetName = 'CreateCivicAddress', ValueFromPipelineByPropertyName)]
                [System.String]
                ${StreetName},
                [Parameter(ParameterSetName = 'CreateCivicAddress', ValueFromPipelineByPropertyName)]
                [System.String]
                ${StreetSuffix}
            )
            return [PSCustomObject]@{
                Location          = $Location
                CivicAddressId    = $CivicAddressId
                CityAlias         = $CityAlias
                CompanyName       = $CompanyName
                CompanyTaxId      = $CompanyTaxId
                Confidence        = $Confidence
                Elin              = $Elin
                HouseNumberSuffix = $HouseNumberSuffix
                Latitude          = $Latitude
                Longitude         = $Longitude
                CountryOrRegion   = $CountryOrRegion
                City              = $City
                Description       = $Description
                HouseNumber       = $HouseNumber
                PostalCode        = $PostalCode
                PostDirectional   = $PostDirectional
                PreDirectional    = $PreDirectional
                StateOrProvince   = $StateOrProvince
                StreetName        = $StreetName
                StreetSuffix      = $StreetSuffix
            }
        }
        Mock -ModuleName $ModuleName -CommandName Set-CsOnlineLisWirelessAccessPoint -MockWith {
            [CmdletBinding(PositionalBinding = $false, SupportsShouldProcess, ConfirmImpact = 'Medium')]
            param(
                [Parameter(Position = 1, Mandatory, ValueFromPipelineByPropertyName)]
                [System.String]
                ${BSSID},
                [Parameter(Mandatory)]
                [System.Guid]
                ${LocationId},
                [Parameter()]
                [System.String]
                ${Description},
                [Parameter()]
                [System.Management.Automation.SwitchParameter]
                ${Force},
                [Parameter()]
                [System.Boolean]
                ${IsDebug},
                [Parameter()]
                [System.String]
                ${NCSApiUrl},
                [Parameter()]
                [System.String]
                ${TargetStore},
                [Parameter(DontShow)]
                [System.String]
                ${MsftInternalProcessingMode}
            )
            return [PSCustomObject]@{
                BSSID       = $BSSID
                LocationId  = $LocationId
                Description = $Description
            }
        }
        Mock -ModuleName $ModuleName -CommandName Set-CsOnlineLisSwitch -MockWith {
            [CmdletBinding(PositionalBinding = $false, SupportsShouldProcess, ConfirmImpact = 'Medium')]
            param(
                [Parameter(Position = 1, Mandatory, ValueFromPipelineByPropertyName)]
                [System.String]
                ${ChassisID},
                [Parameter(Mandatory)]
                [System.Guid]
                ${LocationId},
                [Parameter()]
                [System.String]
                ${Description},
                [Parameter()]
                [System.Management.Automation.SwitchParameter]
                ${Force},
                [Parameter()]
                [System.Boolean]
                ${IsDebug},
                [Parameter()]
                [System.String]
                ${NCSApiUrl},
                [Parameter()]
                [System.String]
                ${TargetStore},
                [Parameter(DontShow)]
                [System.String]
                ${MsftInternalProcessingMode}
            )
            return [PSCustomObject]@{
                ChassisID   = $ChassisID
                LocationId  = $LocationId
                Description = $Description
            }
        }
        Mock -ModuleName $ModuleName -CommandName Set-CsOnlineLisPort -MockWith {
            [CmdletBinding(PositionalBinding = $false, SupportsShouldProcess, ConfirmImpact = 'Medium')]
            param(
                [Parameter(Position = 1, Mandatory, ValueFromPipelineByPropertyName)]
                [System.String]
                ${ChassisID},
                [Parameter(Mandatory)]
                [System.Guid]
                ${LocationId},
                [Parameter(Mandatory)]
                [System.String]
                ${PortID},
                [Parameter()]
                [System.String]
                ${Description},
                [Parameter()]
                [System.Management.Automation.SwitchParameter]
                ${Force},
                [Parameter()]
                [System.Boolean]
                ${IsDebug},
                [Parameter()]
                [System.String]
                ${NCSApiUrl},
                [Parameter()]
                [System.String]
                ${TargetStore},
                [Parameter(DontShow)]
                [System.String]
                ${MsftInternalProcessingMode}
            )
            return [PSCustomObject]@{
                ChassisID   = $ChassisID
                LocationId  = $LocationId
                PortID      = $PortID
                Description = $Description
            }
        }
        Mock -ModuleName $ModuleName -CommandName Set-CsOnlineLisSubnet -MockWith {
            [CmdletBinding(PositionalBinding = $false, SupportsShouldProcess, ConfirmImpact = 'Medium')]
            param(
                [Parameter(Mandatory, ValueFromPipelineByPropertyName)]
                [System.Guid]
                ${LocationId},
                [Parameter(Position = 1, Mandatory, ValueFromPipelineByPropertyName)]
                [System.String]
                ${Subnet},
                [Parameter()]
                [System.String]
                ${Description},
                [Parameter()]
                [System.Management.Automation.SwitchParameter]
                ${Force},
                [Parameter()]
                [System.Boolean]
                ${IsDebug},
                [Parameter()]
                [System.String]
                ${NCSApiUrl},
                [Parameter()]
                [System.String]
                ${TargetStore},
                [Parameter(DontShow)]
                [System.String]
                ${MsftInternalProcessingMode}
            )
            return [PSCustomObject]@{
                LocationId  = $LocationId
                Subnet      = $Subnet
                Description = $Description
            }
        }

        # Mock internal scoped functions
        InModuleScope -ModuleName $ModuleName -ScriptBlock {
            ${function:Get-CsOnlineLisCivicAddress} = {
                param (
                    [string]
                    $CivicAddressId,
                    [switch]
                    $PopulateNumberOfTelephoneNumbers,
                    [switch]
                    $PopulateNumberOfVoiceUsers
                )
                $AddressJson = '[{"AdditionalLocationInfo":null,"City":"Redmond","CityAlias":null,"CivicAddressId":"bf04d062-eef6-4b86-bf19-c9bc428c5d61","CompanyName":"TestCompany","CompanyTaxId":null,"Confidence":null,"CountryOrRegion":"US","CountyOrDistrict":null,"DefaultLocationId":"ffc35422-eb5d-4741-8c46-51fc070bce78","Description":null,"Elin":null,"HouseNumber":"101","HouseNumberSuffix":null,"Latitude":"47.63963","Longitude":"-122.12852","NumberOfTelephoneNumbers":1,"NumberOfVoiceUsers":0,"PartnerId":"00000000-0000-0000-0000-000000000000","PostDirectional":null,"PostalCode":"98052","PreDirectional":null,"StateOrProvince":"WA","StreetName":"Microsoft Way","StreetSuffix":null,"TenantId":"b4299772-a707-4b10-80f2-8a599e1d7500","ValidationStatus":"Validated"},{"AdditionalLocationInfo":null,"City":"Redmond","CityAlias":null,"CivicAddressId":"a279d3d7-f2ad-4369-bd9e-389efaef8a11","CompanyName":"TestCompany","CompanyTaxId":null,"Confidence":null,"CountryOrRegion":"US","CountyOrDistrict":null,"DefaultLocationId":"c9f19766-91d8-4945-82a8-97508395affa","Description":null,"Elin":null,"HouseNumber":"102","HouseNumberSuffix":null,"Latitude":"47.63963","Longitude":"-122.12852","NumberOfTelephoneNumbers":1,"NumberOfVoiceUsers":1,"PartnerId":"00000000-0000-0000-0000-000000000000","PostDirectional":null,"PostalCode":"98052","PreDirectional":null,"StateOrProvince":"WA","StreetName":"Microsoft Way","StreetSuffix":null,"TenantId":"b4299772-a707-4b10-80f2-8a599e1d7500","ValidationStatus":"Validated"}]'
                $Addresses = $AddressJson | ConvertFrom-Json
                if (!$PopulateNumberOfTelephoneNumbers) {
                    foreach ($a in $Addresses) {
                        $a.NumberOfTelephoneNumbers = -1
                    }
                }
                if (!$PopulateNumberOfVoiceUsers) {
                    foreach ($a in $Addresses) {
                        $a.NumberOfVoiceUsers = -1
                    }
                }
                if ($CivicAddressId) {
                    $Addresses = $Addresses.Where({ $_.CivicAddressId -eq $CivicAddressId })
                }
                return $Addresses
            }
            ${function:Get-CsOnlineLisLocation} = {
                param (
                    [string]
                    $LocationId,
                    [string]
                    $CivicAddressId,
                    [switch]
                    $PopulateNumberOfTelephoneNumbers,
                    [switch]
                    $PopulateNumberOfVoiceUsers
                )
                $LocationJson = '[{"AdditionalLocationInfo":null,"City":"Redmond","CityAlias":null,"CivicAddressId":"bf04d062-eef6-4b86-bf19-c9bc428c5d61","CompanyName":"TestCompany","CompanyTaxId":null,"Confidence":null,"CountryOrRegion":"US","CountyOrDistrict":null,"LocationId":"ffc35422-eb5d-4741-8c46-51fc070bce78","Description":null,"Elin":null,"HouseNumber":"101","HouseNumberSuffix":null,"IsDefault": true,"Latitude":"47.63963","Longitude":"-122.12852","NumberOfTelephoneNumbers":1,"NumberOfVoiceUsers":0,"PartnerId":"00000000-0000-0000-0000-000000000000","PostDirectional":null,"PostalCode":"98052","PreDirectional":null,"StateOrProvince":"WA","StreetName":"Microsoft Way","StreetSuffix":null,"TenantId":"b4299772-a707-4b10-80f2-8a599e1d7500","ValidationStatus":"Validated"},{"AdditionalLocationInfo":null,"City":"Redmond","CityAlias":null,"CivicAddressId":"a279d3d7-f2ad-4369-bd9e-389efaef8a11","CompanyName":"TestCompany","CompanyTaxId":null,"Confidence":null,"CountryOrRegion":"US","CountyOrDistrict":null,"LocationId":"c9f19766-91d8-4945-82a8-97508395affa","Description":null,"Elin":null,"HouseNumber":"102","HouseNumberSuffix":null,"IsDefault": true,"Latitude":"47.63963","Longitude":"-122.12852","NumberOfTelephoneNumbers":1,"NumberOfVoiceUsers":1,"PartnerId":"00000000-0000-0000-0000-000000000000","PostDirectional":null,"PostalCode":"98052","PreDirectional":null,"StateOrProvince":"WA","StreetName":"Microsoft Way","StreetSuffix":null,"TenantId":"b4299772-a707-4b10-80f2-8a599e1d7500","ValidationStatus":"Validated"}]'
                $Locations = $LocationJson | ConvertFrom-Json
                if (!$PopulateNumberOfTelephoneNumbers) {
                    foreach ($l in $Locations) {
                        $l.NumberOfTelephoneNumbers = -1
                    }
                }
                if (!$PopulateNumberOfVoiceUsers) {
                    foreach ($l in $Locations) {
                        $l.NumberOfVoiceUsers = -1
                    }
                }
                if ($LocationId) {
                    $Locations = $Locations.Where({ $_.LocationId -eq $LocationId })
                }
                if ($CivicAddressId) {
                    $Locations = $Locations.Where({ $_.CivicAddressId -eq $CivicAddressId })
                }
                return $Locations
            }
            ${function:Get-CsOnlineLisSwitch} = {
                param (
                    [string]
                    $ChassisID
                )
                return
            }
            ${function:Get-CsOnlineLisPort} = {
                param (
                    [string]
                    $ChassisID,
                    [string]
                    $PortID
                )
                return
            }
            ${function:Get-CsOnlineLisSubnet} = {
                param (
                    [string]
                    $Subnet
                )
                return
            }
            ${function:Get-CsOnlineLisWirelessAccessPoint} = {
                param (
                    [string]
                    $BSSID
                )
                return
            }
            ${function:Get-CsOnlineLisCivicAddressAll} = {
                param (
                    [switch]
                    $PopulateNumberOfTelephoneNumbers,
                    [switch]
                    $PopulateNumberOfVoiceUsers
                )
                $AddressJson = '[{"AdditionalLocationInfo":null,"City":"Redmond","CityAlias":null,"CivicAddressId":"bf04d062-eef6-4b86-bf19-c9bc428c5d61","CompanyName":"TestCompany","CompanyTaxId":null,"Confidence":null,"CountryOrRegion":"US","CountyOrDistrict":null,"DefaultLocationId":"ffc35422-eb5d-4741-8c46-51fc070bce78","Description":null,"Elin":null,"HouseNumber":"101","HouseNumberSuffix":null,"Latitude":"47.63963","Longitude":"-122.12852","NumberOfTelephoneNumbers":1,"NumberOfVoiceUsers":0,"PartnerId":"00000000-0000-0000-0000-000000000000","PostDirectional":null,"PostalCode":"98052","PreDirectional":null,"StateOrProvince":"WA","StreetName":"Microsoft Way","StreetSuffix":null,"TenantId":"b4299772-a707-4b10-80f2-8a599e1d7500","ValidationStatus":"Validated"},{"AdditionalLocationInfo":null,"City":"Redmond","CityAlias":null,"CivicAddressId":"a279d3d7-f2ad-4369-bd9e-389efaef8a11","CompanyName":"TestCompany","CompanyTaxId":null,"Confidence":null,"CountryOrRegion":"US","CountyOrDistrict":null,"DefaultLocationId":"c9f19766-91d8-4945-82a8-97508395affa","Description":null,"Elin":null,"HouseNumber":"102","HouseNumberSuffix":null,"Latitude":"47.63963","Longitude":"-122.12852","NumberOfTelephoneNumbers":1,"NumberOfVoiceUsers":1,"PartnerId":"00000000-0000-0000-0000-000000000000","PostDirectional":null,"PostalCode":"98052","PreDirectional":null,"StateOrProvince":"WA","StreetName":"Microsoft Way","StreetSuffix":null,"TenantId":"b4299772-a707-4b10-80f2-8a599e1d7500","ValidationStatus":"Validated"}]'
                $Addresses = $AddressJson | ConvertFrom-Json
                if (!$PopulateNumberOfTelephoneNumbers) {
                    foreach ($a in $Addresses) {
                        $a.NumberOfTelephoneNumbers = -1
                    }
                }
                if (!$PopulateNumberOfVoiceUsers) {
                    foreach ($a in $Addresses) {
                        $a.NumberOfVoiceUsers = -1
                    }
                }
                if ($CivicAddressId) {
                    $Addresses = $Addresses.Where({ $_.CivicAddressId -eq $CivicAddressId })
                }
                return $Addresses
            }
            ${function:Get-CsOnlineLisLocationAll} = {
                param (
                    [string]
                    $CivicAddressId,
                    [switch]
                    $PopulateNumberOfTelephoneNumbers,
                    [switch]
                    $PopulateNumberOfVoiceUsers
                )
                $LocationJson = '[{"AdditionalLocationInfo":null,"City":"Redmond","CityAlias":null,"CivicAddressId":"bf04d062-eef6-4b86-bf19-c9bc428c5d61","CompanyName":"TestCompany","CompanyTaxId":null,"Confidence":null,"CountryOrRegion":"US","CountyOrDistrict":null,"LocationId":"ffc35422-eb5d-4741-8c46-51fc070bce78","Description":null,"Elin":null,"HouseNumber":"101","HouseNumberSuffix":null,"IsDefault": true,"Latitude":"47.63963","Longitude":"-122.12852","NumberOfTelephoneNumbers":1,"NumberOfVoiceUsers":0,"PartnerId":"00000000-0000-0000-0000-000000000000","PostDirectional":null,"PostalCode":"98052","PreDirectional":null,"StateOrProvince":"WA","StreetName":"Microsoft Way","StreetSuffix":null,"TenantId":"b4299772-a707-4b10-80f2-8a599e1d7500","ValidationStatus":"Validated"},{"AdditionalLocationInfo":null,"City":"Redmond","CityAlias":null,"CivicAddressId":"a279d3d7-f2ad-4369-bd9e-389efaef8a11","CompanyName":"TestCompany","CompanyTaxId":null,"Confidence":null,"CountryOrRegion":"US","CountyOrDistrict":null,"LocationId":"c9f19766-91d8-4945-82a8-97508395affa","Description":null,"Elin":null,"HouseNumber":"102","HouseNumberSuffix":null,"IsDefault": true,"Latitude":"47.63963","Longitude":"-122.12852","NumberOfTelephoneNumbers":1,"NumberOfVoiceUsers":1,"PartnerId":"00000000-0000-0000-0000-000000000000","PostDirectional":null,"PostalCode":"98052","PreDirectional":null,"StateOrProvince":"WA","StreetName":"Microsoft Way","StreetSuffix":null,"TenantId":"b4299772-a707-4b10-80f2-8a599e1d7500","ValidationStatus":"Validated"}]'
                $Locations = $LocationJson | ConvertFrom-Json
                if (!$PopulateNumberOfTelephoneNumbers) {
                    foreach ($l in $Locations) {
                        $l.NumberOfTelephoneNumbers = -1
                    }
                }
                if (!$PopulateNumberOfVoiceUsers) {
                    foreach ($l in $Locations) {
                        $l.NumberOfVoiceUsers = -1
                    }
                }
                if ($CivicAddressId) {
                    $Locations = $Locations.Where({ $_.CivicAddressId -eq $CivicAddressId })
                }
                return $Locations
            }
            ${function:Get-CsOnlineLisSwitchByLocation} = {
                param (
                    [string]
                    $LocationId
                )
                return
            }
            ${function:Get-CsOnlineLisPortByLocation} = {
                param (
                    [string]
                    $LocationId
                )
                return
            }
            ${function:Get-CsOnlineLisSubnetByLocation} = {
                param (
                    [string]
                    $LocationId
                )
                return
            }
            ${function:Get-CsOnlineLisWirelessAccessPointByLocation} = {
                param (
                    [string]
                    $LocationId
                )
                return
            }
        }
        # Mock Azure Maps
        InModuleScope -ModuleName $ModuleName -ScriptBlock {
            class MockMapsClient {
                [string] $BaseAddress = 'https://atlas.microsoft.com/search/address/json'

                hidden static [PSCustomObject] $GoodResult = @{
                    type = 'Point Address'
                    id = 'xyU-b3vVzKnm34zjakDnYQ'
                    score = 11.8789978027
                    matchConfidence = @{
                        score = 0.995402642144865
                    }
                    address = @{
                        streetNumber = '1'
                        streetName = 'Microsoft Way'
                        municipality = 'Redmond'
                        countrySecondarySubdivision = 'King'
                        countrySubdivision = 'WA'
                        countrySubdivisionName = 'Washington'
                        countrySubdivisionCode = 'WA'
                        postalCode = '98052'
                        extendedPostalCode = '98052-6399'
                        countryCode = 'US'
                        country = 'United States'
                        countryCodeISO3 = 'USA'
                        freeformAddress = '1 Microsoft Way, Redmond, WA 98052'
                        localName = 'Redmond'
                    }
                    position = @{
                        lat = 47.63963
                        lon = -122.12852
                    }
                    viewport = @{
                        topLeftPoint = @{
                            lat = 47.64257
                            lon = -122.12698
                        }
                        btmRightPoint = @{
                            lat = 47.64077
                            lon = -122.12432
                        }
                    }
                    entryPoints = @(
                        @{
                            type = 'main'
                            position = @{
                                lat = 47.64186
                                lon = -122.12566
                            }
                        }
                    )
                }
                [PSCustomObject] GetStringAsync([string] $Uri) {
                    $n = [DateTime]::Now
                    $vparam = Get-Variable WVParam -ValueOnly -ErrorAction SilentlyContinue
                    if ($null -eq $vparam) {
                        $vparam = @{ Verbose = $false }
                    }
                    $Query = @{}
                    Write-Verbose "MockMapsClient Uri: '$Uri'" @vparam
                    $Uri.Split('?',2)[1].Split('&').ForEach({$k,$v = $_.Split('=',2); $Query[$k.Trim()] = [Web.HttpUtility]::UrlDecode("$v").Trim()})
                    if ([string]::IsNullOrEmpty($Query['query']) -or [string]::IsNullOrEmpty($Query['subscription-key']) -or [string]::IsNullOrEmpty($Query['api-version'])) {
                        return [PSCustomObject]@{
                            Result = $null
                        }
                    }
                    $results = @( & {
                        Write-Verbose "MockMapsClient Query: '$($Query['query'])'" @vparam
                        if ($Query['query'] -notlike '*Microsoft Way*') {
                            return
                        }
                        [MockMapsClient]::GoodResult
                    } )
                    $result = @{
                        summary = @{
                            query = "$($Query['query'])".ToLower()
                            queryType = 'NON_NEAR'
                            queryTime = ([DateTime]::Now - $n).TotalMilliseconds
                            numResults = $results.Count
                            offset = 0
                            totalResults = $results.Count
                            fuzzyLevel = 1
                        }
                        results = $results
                    } | ConvertTo-Json -Depth 99 -Compress
                    Write-Verbose "MockMapsClient Result: '$result'" @vparam
                    return [PSCustomObject]@{
                        Result = $result
                    }
                }
            }
            $null = [AddressValidator]::new()
            [AddressValidator] | Update-TypeData -Force -MemberType NoteProperty -MemberName MapsClient -Value ([MockMapsClient]::new())
        }

        $OnlineAddresses = @(InModuleScope -ModuleName $ModuleName { Get-CsOnlineLisCivicAddress }).Where({ $null -ne $_ }).Count * 2
        $OnlineLocations = @(InModuleScope -ModuleName $ModuleName { Get-CsOnlineLisLocation }).Where({ $null -ne $_ }).Count * 2
        $OnlineNetworkObjects = @(InModuleScope -ModuleName $ModuleName { Get-CsOnlineLisSwitch }).Where({ $null -ne $_ }).Count
        $OnlineNetworkObjects += @(InModuleScope -ModuleName $ModuleName { Get-CsOnlineLisPort }).Where({ $null -ne $_ }).Count
        $OnlineNetworkObjects += @(InModuleScope -ModuleName $ModuleName { Get-CsOnlineLisSubnet }).Where({ $null -ne $_ }).Count
        $OnlineNetworkObjects += @(InModuleScope -ModuleName $ModuleName { Get-CsOnlineLisWirelessAccessPoint }).Where({ $null -ne $_ }).Count
    }
    Describe 'Online Configuration Is Generated' {
        BeforeAll {
            $WVParam = @{ Verbose = $WVerboseFunc.Invoke() }
            InModuleScope -ModuleName $ModuleName { Reset-CsE911Cache -Verbose:$Verbose } -Parameters $WVParam
            $null = Get-TestRow | Get-CsE911NeededChange @WVParam
        }
        BeforeEach {
            $WVParam = @{ Verbose = $WVerboseFunc.Invoke() }
        }
        It 'Generates exactly <OnlineAddresses> online addresses' {
            $d = InModuleScope -ModuleName $ModuleName { [E911ModuleState]::OnlineAddresses }
            Write-Verbose "OnlineAddresses: $($d.Count)" @WVParam
            foreach ($k in $d.Keys) { Write-Verbose "  OnlineAddress: ${k}: $($d[$k] | Select-Object * | ConvertTo-Json -Compress -Depth 1 -WarningAction SilentlyContinue)" @WVParam }
            $d.Count | Should -Be $OnlineAddresses
        }
        It 'Generates exactly <OnlineLocations> online locations' {
            $d = InModuleScope -ModuleName $ModuleName { [E911ModuleState]::OnlineLocations }
            Write-Verbose "OnlineLocations: $($d.Count)" @WVParam
            foreach ($k in $d.Keys) { Write-Verbose "  OnlineLocation: ${k}: $($d[$k] | Select-Object * | ConvertTo-Json -Compress -Depth 1 -WarningAction SilentlyContinue)" @WVParam }
            $d.Count | Should -Be $OnlineLocations
        }
        It 'Generates exactly <OnlineNetworkObjects> online network objects' {
            $d = InModuleScope -ModuleName $ModuleName { [E911ModuleState]::OnlineNetworkObjects }
            Write-Verbose "OnlineNetworkObjects: $($d.Count)" @WVParam
            foreach ($k in $d.Keys) { Write-Verbose "  OnlineNetworkObject: ${k}: $($d[$k] | Select-Object * | ConvertTo-Json -Compress -Depth 1 -WarningAction SilentlyContinue)" @WVParam }
            $d.Count | Should -Be $OnlineNetworkObjects
        }
    }

    Describe 'Input with <Name>' -ForEach @(
        @{
            Name              = 'Subnet'
            Exclude           = @()
            Override          = @{}
            Warnings          = @()
            WarningTypes      = @()
            WarningCount      = 0
            CommandCount      = 2
            ExpectedLocations = 1
            ExpectedAddresses = 1
            ExpectedCount     = 1
        }
        @{
            Name              = 'Subnet in TestLocation'
            Exclude           = @()
            Override          = @{ Location = 'TestLocation' }
            Warnings          = @()
            WarningTypes      = @()
            WarningCount      = 0
            CommandCount      = 3
            ExpectedLocations = 1
            ExpectedAddresses = 1
            ExpectedCount     = 1
        }
        @{
            Name              = 'Subnet with mask'
            Exclude           = @()
            Override          = @{ NetworkObjectIdentifier = '10.10.10.10/24' }
            Warnings          = @()
            WarningTypes      = @()
            WarningCount      = 0
            CommandCount      = 2
            ExpectedLocations = 1
            ExpectedAddresses = 1
            ExpectedCount     = 1
        }
        @{
            Name              = 'Switch'
            Exclude           = @()
            Override          = @{ NetworkObjectType = 'Switch'; NetworkObjectIdentifier = 'DE-AD-BE-EF-00-01' }
            Warnings          = @()
            WarningTypes      = @()
            WarningCount      = 0
            CommandCount      = 2
            ExpectedLocations = 1
            ExpectedAddresses = 1
            ExpectedCount     = 1
        }
        @{
            Name              = 'Switch with lower case address'
            Exclude           = @()
            Override          = @{ NetworkObjectType = 'Switch'; NetworkObjectIdentifier = 'de-ad-be-ef-00-01' }
            Warnings          = @()
            WarningTypes      = @()
            WarningCount      = 0
            CommandCount      = 2
            ExpectedLocations = 1
            ExpectedAddresses = 1
            ExpectedCount     = 1
        }
        @{
            Name              = 'Switch with mixed case address'
            Exclude           = @()
            Override          = @{ NetworkObjectType = 'Switch'; NetworkObjectIdentifier = 'De-aD-Be-ef-00-01' }
            Warnings          = @()
            WarningTypes      = @()
            WarningCount      = 0
            CommandCount      = 2
            ExpectedLocations = 1
            ExpectedAddresses = 1
            ExpectedCount     = 1
        }
        @{
            Name              = 'Switch with mixed case and : in the address'
            Exclude           = @()
            Override          = @{ NetworkObjectType = 'Switch'; NetworkObjectIdentifier = 'De:aD:Be:ef:00:01' }
            Warnings          = @()
            WarningTypes      = @()
            WarningCount      = 0
            CommandCount      = 2
            ExpectedLocations = 1
            ExpectedAddresses = 1
            ExpectedCount     = 1
        }
        @{
            Name              = 'Switch with mixed case and mixed/no/misplaced separators in the address'
            Exclude           = @()
            Override          = @{ NetworkObjectType = 'Switch'; NetworkObjectIdentifier = 'De-a::DB-eef00-01' }
            Warnings          = @()
            WarningTypes      = @()
            WarningCount      = 0
            CommandCount      = 2
            ExpectedLocations = 1
            ExpectedAddresses = 1
            ExpectedCount     = 1
        }
        @{
            Name              = 'Port'
            Exclude           = @()
            Override          = @{ NetworkObjectType = 'Port'; NetworkObjectIdentifier = 'DE-AD-BE-EF-00-01;g0/1' }
            Warnings          = @()
            WarningTypes      = @()
            WarningCount      = 0
            CommandCount      = 2
            ExpectedLocations = 1
            ExpectedAddresses = 1
            ExpectedCount     = 1
        }
        @{
            Name              = 'Wireless Access Point'
            Exclude           = @()
            Override          = @{ NetworkObjectType = 'WirelessAccessPoint'; NetworkObjectIdentifier = 'DE-AD-BE-EF-00-01' }
            Warnings          = @()
            WarningTypes      = @()
            WarningCount      = 0
            CommandCount      = 2
            ExpectedLocations = 1
            ExpectedAddresses = 1
            ExpectedCount     = 1
        }
        @{
            Name              = 'Wireless Access Point with Wildcard'
            Exclude           = @()
            Override          = @{ NetworkObjectType = 'WirelessAccessPoint'; NetworkObjectIdentifier = 'DE-AD-BE-EF-00-0*' }
            Warnings          = @()
            WarningTypes      = @()
            WarningCount      = 0
            CommandCount      = 2
            ExpectedLocations = 1
            ExpectedAddresses = 1
            ExpectedCount     = 1
        }
        @{
            Name              = 'Subnet with an address that is too long'
            Exclude           = @()
            Override          = @{ NetworkObjectIdentifier = '10.10.10.10.10' }
            Warnings          = @( 'InvalidInput:SubnetId ''''' )
            WarningTypes      = @( 'InvalidInput' )
            WarningCount      = 2
            CommandCount      = 0
            ExpectedLocations = 1
            ExpectedAddresses = 1
            ExpectedCount     = 1
        }
        @{
            Name              = 'Switch with an address that is too long'
            Exclude           = @()
            Override          = @{ NetworkObjectType = 'Switch'; NetworkObjectIdentifier = 'DE-AD-BE-EF-00-01-1' }
            Warnings          = @( 'InvalidInput:ChassisId ''''' )
            WarningTypes      = @( 'InvalidInput' )
            WarningCount      = 2
            CommandCount      = 0
            ExpectedLocations = 1
            ExpectedAddresses = 1
            ExpectedCount     = 1
        }
        @{
            Name              = 'Switch with an address containing invalid characters'
            Exclude           = @()
            Override          = @{ NetworkObjectType = 'Switch'; NetworkObjectIdentifier = 'DE-AD-BE-EF-00-ZZ' }
            Warnings          = @( 'InvalidInput:ChassisId ''''' )
            WarningTypes      = @( 'InvalidInput' )
            WarningCount      = 2
            CommandCount      = 0
            ExpectedLocations = 1
            ExpectedAddresses = 1
            ExpectedCount     = 1
        }
        @{
            Name              = 'All Empty'
            Exclude           = @('CompanyName', 'CompanyTaxId', 'Description', 'Address', 'Location', 'City', 'StateOrProvince', 'PostalCode', 'CountryOrRegion', 'Latitude', 'Longitude', 'ELIN', 'NetworkDescription', 'NetworkObjectType', 'NetworkObjectIdentifier', 'SkipMapsLookup', 'EntryHash', 'Warning')
            Override          = @{}
            Warnings          = @( "InvalidInput:NetworkObjectType 'Unknown'", 'InvalidInput:CompanyName missing', 'InvalidInput:Address missing', 'InvalidInput:City missing', 'InvalidInput:StateOrProvince missing', 'InvalidInput:CountryOrRegion missing', 'InvalidInput:CountryOrRegion not ISO 3166-1 alpha-2 code', 'MapsValidation:Maps API failure: https://atlas.microsoft.com/search/address/json?subscription-key=<APIKEY REDACTED>&api-version=1.0&query=&limit=10&countrySet= Produced no results!' )
            WarningTypes      = @( 'InvalidInput', 'MapsValidation' )
            WarningCount      = 8
            CommandCount      = 0
            ExpectedLocations = 1
            ExpectedAddresses = 1
            ExpectedCount     = 1
        }
        @{
            Name              = 'Missing NetworkObjectIdentifier'
            Exclude           = @('NetworkObjectIdentifier')
            Override          = @{}
            Warnings          = @( 'InvalidInput:NetworkObjectIdentifier missing', 'InvalidInput:SubnetId ''''' )
            WarningTypes      = @( 'InvalidInput' )
            WarningCount      = 2
            CommandCount      = 0
            ExpectedLocations = 1
            ExpectedAddresses = 1
            ExpectedCount     = 1
        }
        @{
            Name              = 'Missing NetworkObjectType'
            Exclude           = @('NetworkObjectType')
            Override          = @{}
            Warnings          = @( "InvalidInput:NetworkObjectType 'Unknown'" )
            WarningTypes      = @( 'InvalidInput' )
            WarningCount      = 1
            CommandCount      = 0
            ExpectedLocations = 1
            ExpectedAddresses = 1
            ExpectedCount     = 1
        }
        @{
            Name              = 'Missing Only Longitude'
            Exclude           = @('Longitude')
            Override          = @{}
            Warnings          = @( 'InvalidInput:Longitude missing' )
            WarningTypes      = @( 'InvalidInput' )
            WarningCount      = 1
            CommandCount      = 0
            ExpectedLocations = 1
            ExpectedAddresses = 1
            ExpectedCount     = 1
        }
        @{
            Name              = 'Missing Only Latitude'
            Exclude           = @('Latitude')
            Override          = @{}
            Warnings          = @( 'InvalidInput:Latitude missing' )
            WarningTypes      = @( 'InvalidInput' )
            WarningCount      = 1
            CommandCount      = 0
            ExpectedLocations = 1
            ExpectedAddresses = 1
            ExpectedCount     = 1
        }
        @{
            Name              = 'Missing Latitude & Longitude with SkipMaps true'
            Exclude           = @('Latitude', 'Longitude')
            Override          = @{ SkipMapsLookup = $true }
            Warnings          = @( 'InvalidInput:Latitude missing', 'InvalidInput:Longitude missing' )
            WarningTypes      = @( 'InvalidInput' )
            WarningCount      = 2
            CommandCount      = 0
            ExpectedLocations = 1
            ExpectedAddresses = 1
            ExpectedCount     = 1
        }
        @{
            Name              = 'Missing CountryOrRegion'
            Exclude           = @('CountryOrRegion')
            Override          = @{}
            Warnings          = @( 'InvalidInput:CountryOrRegion missing', 'InvalidInput:CountryOrRegion not ISO 3166-1 alpha-2 code' )
            WarningTypes      = @( 'InvalidInput', 'MapsValidation', 'MapsValidationDetail' )
            WarningCount      = 4
            CommandCount      = 0
            ExpectedLocations = 1
            ExpectedAddresses = 1
            ExpectedCount     = 1
        }
        @{
            Name              = 'Missing PostalCode with SkipMaps true'
            Exclude           = @('PostalCode')
            Override          = @{ SkipMapsLookup = $true }
            Warnings          = @( 'InvalidInput:PostalCode missing' )
            WarningTypes      = @( 'InvalidInput' )
            WarningCount      = 1
            CommandCount      = 0
            ExpectedLocations = 1
            ExpectedAddresses = 1
            ExpectedCount     = 1
        }
        @{
            Name              = 'Missing StateOrProvince'
            Exclude           = @('StateOrProvince')
            Override          = @{}
            Warnings          = @( 'InvalidInput:StateOrProvince missing' )
            WarningTypes      = @( 'InvalidInput', 'MapsValidation', 'MapsValidationDetail' )
            WarningCount      = 3
            CommandCount      = 0
            ExpectedLocations = 1
            ExpectedAddresses = 1
            ExpectedCount     = 1
        }
        @{
            Name              = 'Missing City'
            Exclude           = @('City')
            Override          = @{}
            Warnings          = @( 'InvalidInput:City missing' )
            WarningTypes      = @( 'InvalidInput', 'MapsValidation', 'MapsValidationDetail' )
            WarningCount      = 3
            CommandCount      = 0
            ExpectedLocations = 1
            ExpectedAddresses = 1
            ExpectedCount     = 1
        }
        @{
            Name              = 'Missing Address'
            Exclude           = @('Address')
            Override          = @{}
            Warnings          = @( 'InvalidInput:Address missing' )
            WarningTypes      = @( 'InvalidInput', 'MapsValidation' )
            WarningCount      = 2
            CommandCount      = 0
            ExpectedLocations = 1
            ExpectedAddresses = 1
            ExpectedCount     = 1
        }
        @{
            Name              = 'Missing Company Name'
            Exclude           = @('CompanyName')
            Override          = @{}
            Warnings          = @( 'InvalidInput:CompanyName missing' )
            WarningTypes      = @( 'InvalidInput' )
            WarningCount      = 1
            CommandCount      = 0
            ExpectedLocations = 1
            ExpectedAddresses = 1
            ExpectedCount     = 1
        }
    ) {
        BeforeAll {
            $WVParam = @{ Verbose = $WVerboseFunc.Invoke() }
            $Row = Get-TestRow -PropertiesToExclude $Exclude -OverrideValues $Override
            InModuleScope -ModuleName $ModuleName { Reset-CsE911Cache -Verbose:$Verbose } -Parameters $WVParam
            $Changes = @(Get-CsE911NeededChange -LocationConfiguration $Row @WVParam)
            $ActualWarnings = (@($Changes.Where({ $_.UpdateType -eq 'Source' }).ProcessInfo.Warning) -split ';').Where({ ![string]::IsNullOrEmpty($_) })
            $ActualTypes = ($ActualWarnings.ForEach({ ($_ -split ':')[0] }) | Sort-Object -Unique).Where({ ![string]::IsNullOrEmpty($_) })
            $ActualCommands = $Changes.Where({ $_.UpdateType -eq 'Online' })
            Write-Verbose "Testing Row: $($Row | Select-Object * | ConvertTo-Json -Compress -Depth 1 -WarningAction SilentlyContinue)" @WVParam
        }
        It 'Generates exactly <CommandCount> commands' {
            Write-Verbose "Commands Generated: $($ActualCommands.Count)" @WVParam
            foreach ($Command in $ActualCommands) { Write-Verbose "  Command: $($Command.ProcessInfo.ToString())" @WVParam }
            $ActualCommands.Count | Should -Be $CommandCount
        }
        It 'Issues exactly <WarningCount> warnings' {
            Write-Verbose "Warnings Generated: $($ActualWarnings.Count)" @WVParam
            foreach ($Warning in $ActualWarnings) { Write-Verbose "  Warning: $Warning" @WVParam }
            $ActualWarnings.Count | Should -Be $WarningCount
        }
        $Warnings | ForEach-Object {
            It 'Issues the specific warning: <Warning>' -TestCases @{ 'Warning' = $_ } {
                Write-Verbose "Warning: $Warning is expected: $($Warning -in $ActualWarnings)" @WVParam
                $Warning -in $ActualWarnings | Should -Be $true
            }
        }
        It 'Issues only expected warning types' {
            $ActualTypes.Where({ $_ -notin $WarningTypes }).Count | Should -Be 0
        }
        $WarningTypes | ForEach-Object {
            It 'Issues a warning of type: <Type>' -TestCases @{ 'Type' = $_ } {
                Write-Verbose "Warning Type: $Type is expected: $($Type -in $ActualTypes)" @WVParam
                $Type -in $ActualTypes | Should -Be $true
            }
        }
        It 'OnlineAddresses should contain <OnlineAddresses> items' {
            $d = InModuleScope -ModuleName $ModuleName { [E911ModuleState]::OnlineAddresses }
            Write-Verbose "OnlineAddresses: $($d.Count)" @WVParam
            foreach ($k in $d.Keys) { Write-Verbose "  OnlineAddress: ${k}: $($d[$k] | Select-Object * | ConvertTo-Json -Compress -Depth 1 -WarningAction SilentlyContinue)" @WVParam }
            $d.Count | Should -Be $OnlineAddresses
        }
        It 'OnlineLocations should contain <OnlineLocations> items' {
            $d = InModuleScope -ModuleName $ModuleName { [E911ModuleState]::OnlineLocations }
            Write-Verbose "OnlineLocations: $($d.Count)" @WVParam
            foreach ($k in $d.Keys) { Write-Verbose "  OnlineLocation: ${k}: $($d[$k] | Select-Object * | ConvertTo-Json -Compress -Depth 1 -WarningAction SilentlyContinue)" @WVParam }
            $d.Count | Should -Be $OnlineLocations
        }
        It 'OnlineNetworkObjects should contain <OnlineNetworkObjects> items' {
            $d = InModuleScope -ModuleName $ModuleName { [E911ModuleState]::OnlineNetworkObjects }
            Write-Verbose "OnlineNetworkObjects: $($d.Count)" @WVParam
            foreach ($k in $d.Keys) { Write-Verbose "  OnlineNetworkObject: ${k}: $($d[$k] | Select-Object * | ConvertTo-Json -Compress -Depth 1 -WarningAction SilentlyContinue)" @WVParam }
            $d.Count | Should -Be $OnlineNetworkObjects
        }
        It 'Addresses should contain <ExpectedAddresses> items' {
            $d = InModuleScope -ModuleName $ModuleName { [E911ModuleState]::Addresses }
            Write-Verbose "Addresses: $($d.Count)" @WVParam
            foreach ($k in $d.Keys) { Write-Verbose "  Address: ${k}: $($d[$k] | Select-Object * | ConvertTo-Json -Compress -Depth 1 -WarningAction SilentlyContinue)" @WVParam }
            $d.Count | Should -Be $ExpectedAddresses
        }
        It 'Locations should contain <ExpectedLocations> items' {
            $d = InModuleScope -ModuleName $ModuleName { [E911ModuleState]::Locations }
            Write-Verbose "Locations: $($d.Count)" @WVParam
            foreach ($k in $d.Keys) { Write-Verbose "  Location: ${k}: $($d[$k] | Select-Object * | ConvertTo-Json -Compress -Depth 1 -WarningAction SilentlyContinue)" @WVParam }
            $d.Count | Should -Be $ExpectedLocations
        }
        It 'NetworkObjects should contain <ExpectedCount> items' {
            $d = InModuleScope -ModuleName $ModuleName { [E911ModuleState]::NetworkObjects }
            Write-Verbose "NetworkObjects: $($d.Count)" @WVParam
            foreach ($k in $d.Keys) { Write-Verbose "  NetworkObject: ${k}: $($d[$k] | Select-Object * | ConvertTo-Json -Compress -Depth 1 -WarningAction SilentlyContinue)" @WVParam }
            $d.Count | Should -Be $ExpectedCount
        }
    }
    Describe 'Location Change For Existing NetworkObject' {
        BeforeAll {
            $AddressHash = @{
                AdditionalLocationInfo   = $null
                City                     = 'Redmond'
                CityAlias                = $null
                CivicAddressId           = 'bf04d062-eef6-4b86-bf19-c9bc428c5d61'
                CompanyName              = 'TestCompany'
                CompanyTaxId             = $null
                Confidence               = $null
                CountryOrRegion          = 'US'
                CountyOrDistrict         = $null
                DefaultLocationId        = 'ffc35422-eb5d-4741-8c46-51fc070bce78'
                Description              = $null
                Elin                     = $null
                HouseNumber              = '1'
                HouseNumberSuffix        = $null
                Latitude                 = '47.63963'
                Longitude                = '-122.12852'
                NumberOfTelephoneNumbers = 1
                NumberOfVoiceUsers       = 0
                PartnerId                = '00000000-0000-0000-0000-000000000000'
                PostDirectional          = $null
                PostalCode               = '98052'
                PreDirectional           = $null
                StateOrProvince          = 'WA'
                StreetName               = 'Microsoft Way'
                StreetSuffix             = $null
                TenantId                 = 'b4299772-a707-4b10-80f2-8a599e1d7500'
                ValidationStatus         = 'Validated'
            }
            $Address = [PSCustomObject]$AddressHash
            $AddressHash.Add('LocationId', $AddressHash['DefaultLocationId'])
            $DefaultLocation = [PSCustomObject]$AddressHash
            $AddressHash['LocationId'] = [Guid]::NewGuid().Guid
            $AddressHash['Location'] = 'TestLocation'
            $OriginalLocation = $AddressHash['Location']
            $OriginalLocationId = $AddressHash['LocationId']
            $CivicAddressId = $AddressHash['CivicAddressId']
            $ChassisID = 'DE-AD-BE-EF-BE-EF'
            $PortID = 'ge-0/0/1'
            $Description = 'Test Switch Port'
            $NonDefaultLocation = [PSCustomObject]$AddressHash

            Mock -ModuleName $ModuleName -CommandName Get-CsOnlineLisCivicAddressInternal -MockWith {
                param (
                    [switch]
                    $PopulateNumberOfTelephoneNumbers,
                    [switch]
                    $PopulateNumberOfVoiceUsers
                )
                $Addresses = @($Address)
                if (!$PopulateNumberOfTelephoneNumbers) {
                    foreach ($a in $Addresses) {
                        $a.NumberOfTelephoneNumbers = -1
                    }
                }
                if (!$PopulateNumberOfVoiceUsers) {
                    foreach ($a in $Addresses) {
                        $a.NumberOfVoiceUsers = -1
                    }
                }
                return $Addresses
            }
            Mock -ModuleName $ModuleName -CommandName Get-CsOnlineLisLocationInternal -MockWith {
                param (
                    [switch]
                    $PopulateNumberOfTelephoneNumbers,
                    [switch]
                    $PopulateNumberOfVoiceUsers
                )
                $Locations = @($DefaultLocation, $NonDefaultLocation)
                if (!$PopulateNumberOfTelephoneNumbers) {
                    foreach ($l in $Locations) {
                        $l.NumberOfTelephoneNumbers = -1
                    }
                }
                if (!$PopulateNumberOfVoiceUsers) {
                    foreach ($l in $Locations) {
                        $l.NumberOfVoiceUsers = -1
                    }
                }
                return $Locations
            }
            Mock -ModuleName $ModuleName -CommandName Get-CsOnlineLisPortInternal -MockWith {
                return [PSCustomObject]@{
                    ChassisID   = $ChassisID
                    LocationId  = $OriginalLocationId
                    PortID      = $PortID
                    Description = $Description
                }
            }
            $Row = [PSCustomObject]@{
                CompanyName             = $AddressHash['CompanyName']
                CompanyTaxId            = $AddressHash['CompanyTaxId']
                Description             = $AddressHash['Description']
                Address                 = "$($AddressHash['HouseNumber']) $($AddressHash['StreetName'])"
                Location                = $OriginalLocation
                City                    = $AddressHash['City']
                StateOrProvince         = $AddressHash['StateOrProvince']
                PostalCode              = $AddressHash['PostalCode']
                CountryOrRegion         = $AddressHash['CountryOrRegion']
                Latitude                = $AddressHash['Latitude']
                Longitude               = $AddressHash['Longitude']
                ELIN                    = $AddressHash['ELIN']
                NetworkDescription      = $Description
                NetworkObjectType       = 'Port'
                NetworkObjectIdentifier = "$ChassisID;$PortID"
                SkipMapsLookup          = $false
                EntryHash               = ''
                Warning                 = ''
            }
            $Hash = InModuleScope -ModuleName $ModuleName { [E911DataRow]::GetHash($Row) }
            InModuleScope -ModuleName $ModuleName { Reset-CsE911Cache }
            $Row.EntryHash = $Hash
            $Row.Location += ' changed'
            $Changes = @(Get-CsE911NeededChange -LocationConfiguration $Row )
            $SourceCommands = $Changes.Where({ $_.UpdateType -eq 'Source' })
            $ActualCommands = $Changes.Where({ $_.UpdateType -eq 'Online' })
        }
        It 'Creates 2 Changes' {
            $ActualCommands.Count | Should -Be 2
        }
        It 'Creates 0 Address Changes' {
            $ActualCommands.Where({ $_.CommandType -eq 'Address' }).Count | Should -Be 0
        }
        It 'Creates 1 Location Change' {
            $ActualCommands.Where({ $_.CommandType -eq 'Location' }).Count | Should -Be 1
        }
        It 'Creates 1 NetworkObject Change' {
            $ActualCommands.Where({ $_.CommandType -eq 'NetworkObject' }).Count | Should -Be 1
        }
        It 'Should Only Change LocationId of NetworkObject' {
            $Command = $ActualCommands.Where({ $_.CommandType -eq 'NetworkObject' })[0].ProcessInfo
            $Updated = Get-CommandParameters -Command $Command -ParametersToCheck @('LocationId', 'Description', 'ChassisID', 'PortID')
            $Updated.ChassisID | Should -Be $ChassisID
            $Updated.PortID | Should -Be $PortID
            $Updated.Description | Should -Be $Description
            $Updated.LocationId | Should -Not -Be $OriginalLocationId
        }
        It 'Should Only Change Location of Location' {
            $Command = $ActualCommands.Where({ $_.CommandType -eq 'Location' })[0].ProcessInfo
            $Updated = Get-CommandParameters -Command $Command -ParametersToCheck @('Location', 'CivicAddressId')
            $Updated.CivicAddressId | Should -Be $CivicAddressId
            $Updated.Location | Should -Not -Be $OriginalLocation
        }
        It 'Original Hash should not be null or empty' {
            $Hash | Should -Not -BeNullOrEmpty
        }
        It 'Should Update the Hash with a valid new Hash' {
            $NewHash = $SourceCommands[0].ProcessInfo.GetHash()
            $NewHash | Should -Not -BeNullOrEmpty
            $NewHash | Should -Not -Be $Hash
        }
    }
}