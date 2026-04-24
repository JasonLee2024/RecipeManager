function Invoke-RecipeValidation {
    <#
    .SYNOPSIS
        策略审计算子 (Policy Validator)。负责核验业务数据是否符合系统规则。
    .DESCRIPTION
        基于 GuardianTree v3.0 标准。
        本算子执行“双轨制”校验：
        1. 结构轨：基于 Policy.RequiredFields 检查物理字段是否存在。
        2. 逻辑轨：基于 Enums 节点检查业务数据（分类、标签）的合规性。
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true, ValueFromPipeline = $true)]
        [PSCustomObject]$Recipe
    )

    process {
        # [SRE 防御] 确保全局配置已注入，否则拒绝执行任何校验
        if ($null -eq $script:RecipeConfig) {
            throw "[致命故障] 系统配置未加载。请执行 Import-Module -Force 重新初始化模块。"
        }

        if ($null -eq $script:RecipeEnums) {
            throw "[致命故障] 枚举配置未加载。请执行 Import-Module -Force 重新初始化模块。"
        }
        if ($null -eq $script:RegionalCuisines) {
            throw "[致命故障] 地域菜系配置未加载。请执行 Import-Module -Force 重新初始化模块。"
        }
        if ($null -eq $script:CookingTechniques) {
            throw "[致命故障] 烹饪技法配置未加载。请执行 Import-Module -Force 重新初始化模块。"
        }
        if ($null -eq $script:Noodles) {
            throw "[致命故障] 面食配置未加载。请执行 Import-Module -Force 重新初始化模块。"
        }
        if ($null -eq $script:Beverages) {
            throw "[致命故障] 饮料配置未加载。请执行 Import-Module -Force 重新初始化模块。"
        }
        if ($null -eq $script:ChineseTea) {
            throw "[致命故障] 中国茶配置未加载。请执行 Import-Module -Force 重新初始化模块。"
        }

        # 1. 载入系统策略与独立枚举配置
        $Policy = $script:RecipeConfig.Policy
        $Enums = $script:RecipeEnums

        # [降级防线] 如果全局关闭了严格校验，则直接放行
        if (-not $Policy.StrictValidation) {
            Write-Verbose "[审计跳过] 系统处于兼容模式，绕过校验。"
            return $true
        }

        Write-Verbose "[策略审计] 正在对目标 [$($Recipe.Name)] 执行合规性扫描..."

        # 2. 必填字段校验 (Required Fields)
        foreach ($Field in $Policy.RequiredFields) {
            # 检查对象是否包含该属性
            if (-not $Recipe.psobject.Properties.Match($Field).Count) {
                throw "[策略违规] 数据结构异常: 缺失必填字段 [$Field]。"
            }
            
            # 检查字段的值是否为空
            $Value = $Recipe.$Field
            if ($null -eq $Value -or ($Value -is [string] -and [string]::IsNullOrWhiteSpace($Value))) {
                throw "[策略违规] 数据实体异常: 必填字段 [$Field] 的值不能为空。"
            }
        }

        # 3. [关键修复] 分类枚举校验
        # 从平级的 $Enums 变量中提取 Categories
        $AllowedCategories = $Enums.Categories
        if ($AllowedCategories -notcontains $Recipe.Category) {
            $AllowedStr = $AllowedCategories -join ', '
            throw "[策略违规] 越权数据: 分类 [$($Recipe.Category)] 非法。合法集合: ($AllowedStr)。"
        }

        # 4. [关键修复] 标签体系校验
        if ($null -ne $Recipe.Tags -and $Recipe.Tags.Count -gt 0) {
            $AllowedTags = @()

            # 新结构：主标签 + 二级标签（父/子）+ 独立地域菜系
            if ($null -ne $Enums.TagTaxonomy) {
                $PrimaryTags = @($Enums.TagTaxonomy.PrimaryTags)
                $AllowedTags += $PrimaryTags

                $SecondaryMap = $Enums.TagTaxonomy.SecondaryTagsByPrimary
                if ($null -ne $SecondaryMap) {
                    foreach ($Parent in $SecondaryMap.PSObject.Properties.Name) {
                        foreach ($Child in @($SecondaryMap.$Parent)) {
                            # 二级标签按“主标签/二级标签”编码，避免扁平标签耦合
                            $AllowedTags += "$Parent/$Child"
                        }
                    }
                }
            }

            if ($null -ne $script:RegionalCuisines) {
                foreach ($CuisineGroup in $script:RegionalCuisines.PSObject.Properties.Name) {
                    $AllowedTags += @($script:RegionalCuisines.$CuisineGroup)
                }
            }

            # 兼容旧结构：如仍存在 AllowedTags，则并入允许集合
            if ($null -ne $Enums.AllowedTags) {
                $AllowedTags += @($Enums.AllowedTags)
            }

            $AllowedTags = $AllowedTags | Select-Object -Unique
            foreach ($Tag in $Recipe.Tags) {
                if ($AllowedTags -notcontains $Tag) {
                    $AllowedStr = $AllowedTags -join ', '
                    throw "[策略违规] 越权数据: 标签 [$Tag] 非法。合法池: ($AllowedStr)。"
                }
            }
        }

        # 5. 可选字段校验：烹饪技法（独立维度，不与标签耦合）
        if ($Recipe.psobject.Properties.Match('Techniques').Count -gt 0 -and $null -ne $Recipe.Techniques -and $Recipe.Techniques.Count -gt 0) {
            $AllowedTechniques = @()
            if ($null -ne $script:CookingTechniques.MediumBased) {
                foreach ($Medium in $script:CookingTechniques.MediumBased.PSObject.Properties.Name) {
                    $AllowedTechniques += @($script:CookingTechniques.MediumBased.$Medium)
                }
            }
            if ($null -ne $script:CookingTechniques.HeatControl) {
                foreach ($HeatDimension in $script:CookingTechniques.HeatControl.PSObject.Properties.Name) {
                    $AllowedTechniques += @($script:CookingTechniques.HeatControl.$HeatDimension)
                }
            }
            if ($null -ne $script:CookingTechniques.Preparation) {
                foreach ($PrepDimension in $script:CookingTechniques.Preparation.PSObject.Properties.Name) {
                    $AllowedTechniques += @($script:CookingTechniques.Preparation.$PrepDimension)
                }
            }
            $AllowedTechniques = $AllowedTechniques | Select-Object -Unique

            $TechniqueAliases = @{}
            if ($null -ne $script:CookingTechniques.Aliases) {
                if ($null -ne $script:CookingTechniques.Aliases.AliasToCanonical) {
                    foreach ($AliasKey in $script:CookingTechniques.Aliases.AliasToCanonical.PSObject.Properties.Name) {
                        $TechniqueAliases[$AliasKey] = [string]$script:CookingTechniques.Aliases.AliasToCanonical.$AliasKey
                    }
                }
                elseif ($null -ne $script:CookingTechniques.Aliases.CanonicalToAliases) {
                    foreach ($CanonicalKey in $script:CookingTechniques.Aliases.CanonicalToAliases.PSObject.Properties.Name) {
                        foreach ($AliasValue in @($script:CookingTechniques.Aliases.CanonicalToAliases.$CanonicalKey)) {
                            $TechniqueAliases[[string]$AliasValue] = [string]$CanonicalKey
                        }
                    }
                }
                else {
                    # 向后兼容：历史结构为扁平 Alias->Canonical 映射
                    foreach ($AliasKey in $script:CookingTechniques.Aliases.PSObject.Properties.Name) {
                        $TechniqueAliases[$AliasKey] = [string]$script:CookingTechniques.Aliases.$AliasKey
                    }
                }
            }

            foreach ($Technique in $Recipe.Techniques) {
                $NormalizedTechnique = if ($TechniqueAliases.ContainsKey([string]$Technique)) {
                    $TechniqueAliases[[string]$Technique]
                }
                else {
                    [string]$Technique
                }

                if ($AllowedTechniques -notcontains $NormalizedTechnique) {
                    $AllowedStr = $AllowedTechniques -join ', '
                    throw "[策略违规] 越权数据: 烹饪技法 [$Technique] 非法。合法池: ($AllowedStr)。"
                }
            }
        }

        # 6. 可选字段校验：文档归档双向对应（DocPath / DocCategories）
        if ($null -ne $script:CategoryDocIndex) {
            if ($Recipe.psobject.Properties.Match('DocPath').Count -gt 0 -and -not [string]::IsNullOrWhiteSpace([string]$Recipe.DocPath)) {
                $DocPath = [string]$Recipe.DocPath

                if ($null -eq $script:CategoryDocIndex.DocToCategory.$DocPath) {
                    throw "[策略违规] 文档路径 [$DocPath] 未在 Docs 索引中登记。"
                }

                $DocAbsPath = Join-Path $script:ModuleRoot $DocPath
                if (-not (Test-Path -LiteralPath $DocAbsPath)) {
                    throw "[策略违规] 文档路径 [$DocPath] 在文件系统中不存在。"
                }

                if ($Recipe.psobject.Properties.Match('DocCategories').Count -gt 0 -and $null -ne $Recipe.DocCategories -and $Recipe.DocCategories.Count -gt 0) {
                    $IndexedCategories = @($script:CategoryDocIndex.DocToCategory.$DocPath)
                    foreach ($DocCategory in @($Recipe.DocCategories)) {
                        if ($IndexedCategories -notcontains [string]$DocCategory) {
                            throw "[策略违规] 文档分类 [$DocCategory] 与索引不一致。文档路径: [$DocPath]。"
                        }
                    }
                }
            }
        }

        # 7. 可选字段校验：面食品类（NoodleStyle）
        if ($Recipe.psobject.Properties.Match('NoodleStyle').Count -gt 0 -and -not [string]::IsNullOrWhiteSpace([string]$Recipe.NoodleStyle)) {
            $AllowedNoodles = @()
            if ($null -ne $script:Noodles.NoodleDishes) {
                foreach ($StyleGroup in $script:Noodles.NoodleDishes.PSObject.Properties.Name) {
                    $AllowedNoodles += @($script:Noodles.NoodleDishes.$StyleGroup)
                }
            }
            $AllowedNoodles = $AllowedNoodles | Select-Object -Unique

            if ($AllowedNoodles -notcontains [string]$Recipe.NoodleStyle) {
                $AllowedStr = $AllowedNoodles -join ', '
                throw "[策略违规] 越权数据: 面食品类 [$($Recipe.NoodleStyle)] 非法。合法池: ($AllowedStr)。"
            }
        }

        # 8. 可选字段校验：饮料品类（BeverageStyle）
        if ($Recipe.psobject.Properties.Match('BeverageStyle').Count -gt 0 -and -not [string]::IsNullOrWhiteSpace([string]$Recipe.BeverageStyle)) {
            $AllowedBeverages = @()
            $NonAlcoholic = $script:Beverages.Beverages.NonAlcoholicBeverages
            if ($null -ne $NonAlcoholic) {
                foreach ($BeverageGroup in $NonAlcoholic.PSObject.Properties.Name) {
                    $GroupValue = $NonAlcoholic.$BeverageGroup
                    if ($GroupValue -is [array]) {
                        $AllowedBeverages += @($GroupValue)
                    }
                }
                if ($null -ne $NonAlcoholic.Tea -and $null -ne $NonAlcoholic.Tea.GlobalTea) {
                    $AllowedBeverages += @($NonAlcoholic.Tea.GlobalTea)
                }
            }

            if ($null -ne $script:ChineseTea.ChineseTeaSystem) {
                foreach ($TeaGroup in $script:ChineseTea.ChineseTeaSystem.PSObject.Properties.Name) {
                    $AllowedBeverages += @($script:ChineseTea.ChineseTeaSystem.$TeaGroup)
                }
            }

            $AllowedBeverages = $AllowedBeverages | Select-Object -Unique
            if ($AllowedBeverages -notcontains [string]$Recipe.BeverageStyle) {
                $AllowedStr = $AllowedBeverages -join ', '
                throw "[策略违规] 越权数据: 饮料品类 [$($Recipe.BeverageStyle)] 非法。合法池: ($AllowedStr)。"
            }
        }

        # 9. 可选字段校验：佐餐/搭配说明（ServingNote，自由文本，不参与标签枚举）
        if ($Recipe.psobject.Properties.Match('ServingNote').Count -gt 0 -and $null -ne $Recipe.ServingNote) {
            $sn = [string]$Recipe.ServingNote
            if ([string]::IsNullOrWhiteSpace($sn)) {
                throw "[策略违规] ServingNote 不能只含空白字符；若需清空请省略该字段或使用 Set-Recipe 清空语义。"
            }
            if ($sn.Length -gt 4000) {
                throw "[策略违规] ServingNote 超出长度上限（4000 字符）。"
            }
        }

        Write-Verbose "[策略审计] 目标 [$($Recipe.Name)] 完美合规，准许注入持久层。"
        return $true
    }
}