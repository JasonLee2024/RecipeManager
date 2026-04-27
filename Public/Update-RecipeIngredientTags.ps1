function Update-RecipeIngredientTags {
    <#
    .SYNOPSIS
        基于 Ingredients.Item 自动补齐食材路径标签（食材/...）。

    .DESCRIPTION
        读取菜谱对象的 Ingredients（Item 字段），结合 Config/IngredientTaxonomy.json 中的多级树形体系，
        自动推断并补齐 Tags 中的食材路径标签（例如：食材/加工与其他/调味品/生抽）。

        设计目标：
        - 只补齐缺失标签，不移除用户已有标签（幂等）。
        - 支持 -WhatIf 安全预演。
        - 兼容 “陈醋或香醋/米粉/粉丝”等复合写法，尽量从字符串中提取可识别的关键字。

    .PARAMETER Name
        仅处理名称匹配的菜谱（默认模糊匹配）。支持从管道输入。

    .PARAMETER Category
        仅处理指定分类的菜谱（如：炒菜、主食）。

    .PARAMETER PassThru
        输出更新后的菜谱对象（或在 -WhatIf 下输出预期变更）。

    .EXAMPLE
        Update-RecipeIngredientTags -Category '炒菜' -WhatIf

    .EXAMPLE
        '番茄' | Update-RecipeIngredientTags -PassThru
    #>
    [CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact = 'Medium')]
    param(
        [Parameter(Position = 0, ValueFromPipeline = $true, ValueFromPipelineByPropertyName = $true)]
        [string]$Name,

        [Parameter()]
        [string]$Category,

        [Parameter()]
        [switch]$PassThru
    )

    begin {
        if ($null -eq $script:IngredientTaxonomy -or $null -eq $script:IngredientTaxonomy.Taxonomy -or $null -eq $script:IngredientTaxonomy.Taxonomy.食材) {
            throw "[致命故障] 食材体系未加载（IngredientTaxonomy）。请重新 Import-Module -Force。"
        }

        function Get-TaxonomyPaths {
            param(
                [Parameter(Mandatory = $true)]
                [object]$Node,

                [Parameter(Mandatory = $true)]
                [string]$Prefix
            )

            $paths = @()
            if ($null -eq $Node) { return $paths }

            if ($Node -is [System.Collections.IDictionary]) {
                foreach ($k in @($Node.Keys)) {
                    $child = $Node[$k]
                    $nextPrefix = if ([string]::IsNullOrWhiteSpace($Prefix)) { [string]$k } else { "$Prefix/$k" }
                    $paths += $nextPrefix
                    $paths += @(Get-TaxonomyPaths -Node $child -Prefix $nextPrefix)
                }
                return $paths
            }

            foreach ($p in @($Node.PSObject.Properties | Where-Object { $_.MemberType -eq 'NoteProperty' })) {
                $nextPrefix = if ([string]::IsNullOrWhiteSpace($Prefix)) { [string]$p.Name } else { "$Prefix/$($p.Name)" }
                $paths += $nextPrefix
                $paths += @(Get-TaxonomyPaths -Node $p.Value -Prefix $nextPrefix)
            }

            return $paths
        }

        function Get-LeafPathIndex {
            param(
                [Parameter(Mandatory = $true)]
                [object]$RootNode
            )

            # 返回：keyword -> path[]
            $index = @{}
            $allPaths = @(Get-TaxonomyPaths -Node $RootNode -Prefix '食材')
            foreach ($path in $allPaths) {
                $parts = @([string]$path -split '/')
                if ($parts.Count -lt 2) { continue }
                $leaf = [string]$parts[-1]
                if ([string]::IsNullOrWhiteSpace($leaf)) { continue }
                if (-not $index.ContainsKey($leaf)) { $index[$leaf] = @() }
                $index[$leaf] += $path
            }
            return $index
        }

        function Get-IngredientKeywords {
            param(
                [Parameter(Mandatory = $true)]
                [string]$ItemText
            )

            $t = [string]$ItemText
            if ([string]::IsNullOrWhiteSpace($t)) { return @() }

            # 去掉括号内容，避免“（可选）/（约40°C）”干扰
            $t = [regex]::Replace($t, "（[^）]*）", "")
            $t = [regex]::Replace($t, "\\([^\\)]*\\)", "")

            # 常见分隔符拆分
            $rawParts = @($t -split "[/、,，;；]|或|和|及|与")
            $rawParts = @($rawParts | ForEach-Object { ([string]$_).Trim() } | Where-Object { -not [string]::IsNullOrWhiteSpace($_) })

            # 额外保留原始字符串本身（用于 contains 匹配）
            return @($t.Trim()) + $rawParts
        }

        $leafIndex = Get-LeafPathIndex -RootNode $script:IngredientTaxonomy.Taxonomy.食材
        $leafKeywords = @($leafIndex.Keys | Sort-Object { $_.Length } -Descending)

        $pipelineNames = [System.Collections.Generic.List[string]]::new()
        $anyPipelineName = $false
    }

    process {
        if ($PSBoundParameters.ContainsKey('Name') -and -not [string]::IsNullOrWhiteSpace($Name)) {
            $anyPipelineName = $true
            $pipelineNames.Add([string]$Name) | Out-Null
        }
    }

    end {
        $all = Invoke-DataProvider -Load -ErrorAction Stop
        if (-not $all) { return }

        $targets = $all
        if ($PSBoundParameters.ContainsKey('Category') -and -not [string]::IsNullOrWhiteSpace($Category)) {
            $targets = @($targets | Where-Object { [string]$_.Category -eq [string]$Category })
        }

        if ($anyPipelineName) {
            # 多个 Name 输入时：按“任一命中”模糊包含
            $targets = @($targets | Where-Object {
                $n = [string]$_.Name
                foreach ($q in $pipelineNames) {
                    if (-not [string]::IsNullOrWhiteSpace($q) -and $n -like "*$q*") { return $true }
                }
                return $false
            })
        }

        $changed = $false
        $outputs = @()

        foreach ($r in $targets) {
            $existing = @()
            if ($null -ne $r.Tags) { $existing = @($r.Tags | ForEach-Object { [string]$_ }) }

            $suggested = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::Ordinal)
            foreach ($tag in $existing) { [void]$suggested.Add([string]$tag) }

            $ingredients = @()
            if ($null -ne $r.Ingredients) { $ingredients = @($r.Ingredients) }

            foreach ($ing in $ingredients) {
                if ($null -eq $ing) { continue }
                $item = ''
                if ($ing.PSObject.Properties.Match('Item').Count -gt 0) { $item = [string]$ing.Item }
                if ([string]::IsNullOrWhiteSpace($item)) { continue }

                $candidates = @(Get-IngredientKeywords -ItemText $item)
                foreach ($kw in $leafKeywords) {
                    foreach ($cand in $candidates) {
                        if ($cand.Contains($kw)) {
                            foreach ($p in @($leafIndex[$kw])) {
                                [void]$suggested.Add([string]$p)
                            }
                            break
                        }
                    }
                }
            }

            $newTags = @($suggested)
            $added = @($newTags | Where-Object { $existing -notcontains $_ })
            if ($added.Count -eq 0) {
                if ($PassThru) { $outputs += $r }
                continue
            }

            $preview = [pscustomobject]@{
                Name  = $r.Name
                Added = $added
            }

            if ($PSCmdlet.ShouldProcess("菜谱: $($r.Name)", "补齐食材路径标签（新增 $($added.Count) 项）")) {
                $r.Tags = $newTags
                Invoke-RecipeValidation -Recipe $r -ErrorAction Stop
                $changed = $true
            }

            if ($PassThru) {
                # -WhatIf 时返回预期变更对象；否则返回更新后的菜谱对象
                if ($WhatIfPreference) { $outputs += $preview } else { $outputs += $r }
            }
        }

        if ($changed) {
            Invoke-DataProvider -SaveData $all -ErrorAction Stop
        }

        if ($PassThru -and $outputs.Count -gt 0) {
            $outputs
        }
    }
}

