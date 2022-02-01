# PSScriptAnalyzerSettings.psd1
@{
    Rules               = @{
        PSAlignAssignmentStatement                     = @{
            Enable         = $true
            CheckHashtable = $true
        }
        PSUseConsistentWhitespace                      = @{
            Enable                                  = $true
            CheckInnerBrace                         = $true
            CheckOpenBrace                          = $true
            CheckOpenParen                          = $true
            CheckOperator                           = $true
            CheckPipe                               = $true
            CheckPipeForRedundantWhitespace         = $true
            CheckSeparator                          = $true
            CheckParameter                          = $true
            IgnoreAssignmentOperatorInsideHashTable = $true
        }
        PSUseConsistentIndentation                     = @{
            Enable              = $true
            IndentationSize     = 4
            PipelineIndentation = 'IncreaseIndentationForFirstPipeline'
            Kind                = 'space'
        }
        PSPlaceOpenBrace                               = @{
            Enable             = $true
            OnSameLine         = $true
            NewLineAfter       = $true
            IgnoreOneLineBlock = $true
        }
        PSPlaceCloseBrace                              = @{
            Enable             = $true
            NoEmptyLineBefore  = $true
            IgnoreOneLineBlock = $true
            NewLineAfter       = $true
        }
        PSUseCompatibleSyntax                          = @{
            Enable         = $true
            TargetVersions = @(
                "5.1",
                "7.0"
            )
        }
        PSUseCompatibleTypes                           = @{
            Enable         = $true
            TargetProfiles = @(
                'win-8_x64_10.0.14393.0_5.1.14393.2791_x64_4.0.30319.42000_framework'   # Server 2016 - Windows
                'win-8_x64_10.0.14393.0_7.0.0_x64_3.1.2_core'                           # Server 2016 - Core
                'win-8_x64_10.0.17763.0_5.1.17763.316_x64_4.0.30319.42000_framework'    # Server 2019 - Windows
                'win-8_x64_10.0.17763.0_7.0.0_x64_3.1.2_core'                           # Server 2019 - Core
                'win-48_x64_10.0.17763.0_5.1.17763.316_x64_4.0.30319.42000_framework'   # Windows 10 1809 - Windows
                'win-4_x64_10.0.18362.0_7.0.0_x64_3.1.2_core'                           # Windows 10 1809 - Core
                'ubuntu_x64_18.04_7.0.0_x64_3.1.2_core'                                 # Ubuntu 18.04 - Core
            )
        }
        PSUseCompatibleCommmands                       = @{
            Enable         = $true
            TargetProfiles = @(
                'win-8_x64_10.0.14393.0_5.1.14393.2791_x64_4.0.30319.42000_framework'   # Server 2016 - Windows
                'win-8_x64_10.0.14393.0_7.0.0_x64_3.1.2_core'                           # Server 2016 - Core
                'win-8_x64_10.0.17763.0_5.1.17763.316_x64_4.0.30319.42000_framework'    # Server 2019 - Windows
                'win-8_x64_10.0.17763.0_7.0.0_x64_3.1.2_core'                           # Server 2019 - Core
                'win-48_x64_10.0.17763.0_5.1.17763.316_x64_4.0.30319.42000_framework'   # Windows 10 1809 - Windows
                'win-4_x64_10.0.18362.0_7.0.0_x64_3.1.2_core'                           # Windows 10 1809 - Core
                'ubuntu_x64_18.04_7.0.0_x64_3.1.2_core'                                 # Ubuntu 18.04 - Core
            )
        }
        PSUseCompatibleCmdlets                         = @{
            Enable        = $true
            Compatibility = @(
                "desktop-5.1.14393.206-windows"
                "core-6.1.0-windows"
                "core-6.1.0-macos"
                "core-6.1.0-linux"
            )
        }
        PSUseToExportFieldsInManifest                  = @{
            Enable = $true
        }
        PSUseSupportsShouldProcess                     = @{
            Enable = $true
        }
        PSUseSingularNouns                             = @{
            Enable = $true
        }
        PSUseShouldProcessForStateChangingFunctions    = @{
            Enable = $true
        }
        PSUsePSCredentialType                          = @{
            Enable = $true
        }
        PSUseProcessBlockForPipelineCommand            = @{
            Enable = $true
        }
        PSUseOutputTypeCorrectly                       = @{
            Enable = $true
        }
        PSUseLiteralInitializerForHashtable            = @{
            Enable = $true
        }
        PSUseDeclaredVarsMoreThanAssignments           = @{
            Enable = $true
        }
        PSUseCorrectCasing                             = @{
            Enable = $true
        }
        PSUseCmdletCorrectly                           = @{
            Enable = $true
        }
        PSUseBOMForUnicodeEncodedFile                  = @{
            Enable = $true
        }
        PSUseApprovedVerbs                             = @{
            Enable = $true
        }
        PSShouldProcess                                = @{
            Enable = $true
        }
        PSReviewUnusedParameter                        = @{
            Enable = $true
        }
        PSAvoidAssignmentToAutomaticVariable           = @{ 
            Enabled = $true
        }	
        PSAvoidDefaultValueForMandatoryParameter       = @{ 
            Enabled = $true
        }	
        PSAvoidDefaultValueSwitchParameter             = @{ 
            Enabled = $true
        }	
        PSAvoidGlobalAliases                           = @{ 
            Enabled = $true
        }
        PSAvoidGlobalFunctions                         = @{ 
            Enabled = $true
        }	
        PSAvoidGlobalVars                              = @{ 
            Enabled = $true
        }	
        PSAvoidInvokingEmptyMembers                    = @{ 
            Enabled = $true
        }	
        PSAvoidLongLines                               = @{ 
            Enabled = $true
        }	
        PSAvoidOverwritingBuiltInCmdlets               = @{ 
            Enabled = $true
        }	
        PSAvoidNullOrEmptyHelpMessageAttribute         = @{ 
            Enabled = $true
        }	
        PSAvoidShouldContinueWithoutForce              = @{ 
            Enabled = $true
        }	
        PSUseUsingScopeModifierInNewRunspaces          = @{ 
            Enabled = $true
        }
        # configure below
        # PSAvoidUsingDoubleQuotesForConstantString = @{ 
        #     Enabled = $true
        # }
        PSAvoidUsingCmdletAliases                      = @{ 
            Enabled = $true
        }
        PSAvoidUsingComputerNameHardcoded              = @{ 
            Enabled = $true
        }	
        PSAvoidUsingConvertToSecureStringWithPlainText = @{ 
            Enabled = $true
        }	
        PSAvoidUsingDeprecatedManifestFields           = @{ 
            Enabled = $true
        }	
        PSAvoidUsingEmptyCatchBlock                    = @{ 
            Enabled = $true
        }	
        PSAvoidUsingInvokeExpression                   = @{ 
            Enabled = $true
        }	
        PSAvoidUsingPlainTextForPassword               = @{ 
            Enabled = $true
        }	
        PSAvoidUsingPositionalParameters               = @{ 
            Enabled = $true
        }	
        PSAvoidTrailingWhitespace                      = @{ 
            Enabled = $true
        }	
        PSAvoidUsingUsernameAndPasswordParams          = @{ 
            Enabled = $true
        }	
        PSAvoidUsingWMICmdlet                          = @{ 
            Enabled = $true
        }	
        PSAvoidUsingWriteHost                          = @{ 
            Enabled = $true
        }	
        PSMisleadingBacktick                           = @{ 
            Enabled = $true
        }	
        PSMissingModuleManifestField                   = @{ 
            Enabled = $true
        }	
        PSPossibleIncorrectComparisonWithNull          = @{ 
            Enabled = $true
        }	
        PSPossibleIncorrectUsageOfAssignmentOperator   = @{ 
            Enabled = $true
        }	
        PSPossibleIncorrectUsageOfRedirectionOperator  = @{ 
            Enabled = $true
        }	
        PSProvideCommentHelp                           = @{
            Enabled                 = $true
            ExportedOnly            = $true
            BlockComment            = $true
            VSCodeSnippetCorrection = $true
            Placement               = "begin"
        }
        PSReservedCmdletChar                           = @{ 
            Enabled = $true
        }	
        PSReservedParams                               = @{ 
            Enabled = $true
        }
    }
    IncludeDefaultRules = $true
}