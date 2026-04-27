function Sync-RecipeDocs {
    <#
    .SYNOPSIS
        同步 Docs 菜谱文档到 Data/Recipes 分片文件。
    .DESCRIPTION
        扫描 Docs/菜谱 下的 Markdown 文档，重建 Docs/CategoryDocIndex.json，
        并为缺失的菜谱 JSON 自动创建最小骨架数据。
    #>
    [CmdletBinding(SupportsShouldProcess = $true)]
    param(
        [Parameter(Mandatory = $false)]
        [string[]]$DocPaths
    )

    process {
        if ([string]::IsNullOrWhiteSpace($script:ModuleRoot)) {
            throw "[致命故障] 模块根路径未初始化，无法执行文档同步。"
        }

        $docsRecipeRootRel = if (-not [string]::IsNullOrWhiteSpace([string]$script:RecipeConfig.DocsRecipeRoot)) {
            [string]$script:RecipeConfig.DocsRecipeRoot
        }
        else {
            "Docs/菜谱"
        }

        $docsRecipeRootAbs = Join-Path $script:ModuleRoot $docsRecipeRootRel
        if (-not (Test-Path -LiteralPath $docsRecipeRootAbs)) {
            throw "[同步失败] 未找到菜谱文档目录: $docsRecipeRootAbs"
        }

        $docsIndexRel = if (-not [string]::IsNullOrWhiteSpace([string]$script:RecipeConfig.DocsIndexPath)) {
            [string]$script:RecipeConfig.DocsIndexPath
        }
        else {
            "Docs/CategoryDocIndex.json"
        }
        $docsIndexAbs = Join-Path $script:ModuleRoot $docsIndexRel

        $recipeRootAbs = Join-Path $script:ModuleRoot ([string]$script:RecipeConfig.Storage.RecipeRoot)
        if (-not (Test-Path -LiteralPath $recipeRootAbs)) {
            New-Item -Path $recipeRootAbs -ItemType Directory -Force | Out-Null
        }

        $allDocFiles = @(Get-ChildItem -Path $docsRecipeRootAbs -Recurse -File -Filter '*.md' -ErrorAction Stop)
        $regionalCuisineTags = @()
        if ($null -ne $script:RegionalCuisines) {
            foreach ($groupName in $script:RegionalCuisines.PSObject.Properties.Name) {
                $regionalCuisineTags += @($script:RegionalCuisines.$groupName)
            }
            $regionalCuisineTags = @($regionalCuisineTags | Where-Object { -not [string]::IsNullOrWhiteSpace([string]$_) } | Select-Object -Unique)
        }
        $regionalAliasMap = @{}
        if ($null -ne $script:RegionalCuisineAliases) {
            foreach ($aliasKey in $script:RegionalCuisineAliases.PSObject.Properties.Name) {
                $regionalAliasMap[[string]$aliasKey] = [string]$script:RegionalCuisineAliases.$aliasKey
            }
        }
        $targetDocSet = $null
        if ($PSBoundParameters.ContainsKey('DocPaths')) {
            $targetDocSet = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)
            foreach ($docPath in @($DocPaths)) {
                if ([string]::IsNullOrWhiteSpace($docPath)) { continue }
                $normalized = ([string]$docPath).Replace('\', '/')
                [void]$targetDocSet.Add($normalized)
            }
        }

        $docToCategory = [ordered]@{}
        foreach ($doc in $allDocFiles) {
            $docRel = ($doc.FullName.Substring($script:ModuleRoot.Length + 1)).Replace('\', '/')
            $afterRoot = $docRel.Substring(($docsRecipeRootRel.Replace('\', '/') + '/').Length)
            $parts = @($afterRoot -split '/')
            $folderParts = @()
            if ($parts.Count -gt 1) {
                $folderParts = $parts[0..($parts.Count - 2)]
            }

            $categories = @()
            for ($i = 0; $i -lt $folderParts.Count; $i++) {
                $categories += (($folderParts[0..$i]) -join '/')
            }
            $docToCategory[$docRel] = $categories
        }

        $categoryToDocs = [ordered]@{}
        foreach ($docRel in $docToCategory.Keys) {
            foreach ($category in @($docToCategory[$docRel])) {
                if (-not $categoryToDocs.Contains($category)) {
                    $categoryToDocs[$category] = @()
                }
                $categoryToDocs[$category] += $docRel
            }
        }
        foreach ($category in @($categoryToDocs.Keys)) {
            $categoryToDocs[$category] = @($categoryToDocs[$category] | Sort-Object -Unique)
        }

        $indexPayload = [ordered]@{
            CategoryToDocs = $categoryToDocs
            DocToCategory  = $docToCategory
        }

        if ($PSCmdlet.ShouldProcess($docsIndexRel, "重建文档分类索引")) {
            $indexPayload | ConvertTo-Json -Depth 20 | Set-Content -Path $docsIndexAbs -Encoding UTF8
            $script:CategoryDocIndex = $indexPayload
        }

        $created = [System.Collections.Generic.List[string]]::new()
        foreach ($docRel in $docToCategory.Keys) {
            if ($null -ne $targetDocSet -and -not $targetDocSet.Contains($docRel)) {
                continue
            }

            $categories = @($docToCategory[$docRel])
            if ($categories.Count -eq 0) { continue }

            $topCategory = [string]$categories[0]
            $name = [System.IO.Path]::GetFileNameWithoutExtension($docRel)
            if ([string]::IsNullOrWhiteSpace($name)) { continue }

            $categoryDir = Join-Path $recipeRootAbs $topCategory
            if (-not (Test-Path -LiteralPath $categoryDir)) {
                New-Item -Path $categoryDir -ItemType Directory -Force | Out-Null
            }

            $targetFile = Join-Path $categoryDir ("$name.json")
            $docAbs = Join-Path $script:ModuleRoot $docRel
            $docText = if (Test-Path -LiteralPath $docAbs) { Get-Content -Path $docAbs -Raw -ErrorAction SilentlyContinue } else { '' }
            $detectedCuisineTags = @()
            foreach ($tag in $regionalCuisineTags) {
                if (-not [string]::IsNullOrWhiteSpace($docText) -and ([string]$docText).Contains([string]$tag)) {
                    $detectedCuisineTags += [string]$tag
                }
            }
            if (-not [string]::IsNullOrWhiteSpace($docText)) {
                foreach ($keyword in $regionalAliasMap.Keys) {
                    if ($docText.Contains($keyword)) {
                        $detectedCuisineTags += $regionalAliasMap[$keyword]
                    }
                }
            }
            $detectedCuisineTags = @($detectedCuisineTags | Select-Object -Unique)

            if (-not (Test-Path -LiteralPath $targetFile)) {
                $newRecipe = [ordered]@{
                    ID            = [guid]::NewGuid().ToString()
                    Name          = $name
                    Category      = $topCategory
                    PrepTime      = 10
                    Ingredients   = @()
                    Steps         = @("待补充")
                    Tags          = @("经典菜") + $detectedCuisineTags
                    DocPath       = $docRel
                    DocCategories = $categories
                    CreateTime    = (Get-Date -Format "yyyy-MM-ddTHH:mm:ssZ")
                }

                if ($PSCmdlet.ShouldProcess($targetFile, "创建缺失菜谱 JSON")) {
                    $newRecipe | ConvertTo-Json -Depth 20 | Set-Content -Path $targetFile -Encoding UTF8
                    $created.Add(($targetFile.Substring($script:ModuleRoot.Length + 1)).Replace('\', '/')) | Out-Null
                }
            }
            else {
                $existing = Get-Content -Path $targetFile -Raw -ErrorAction Stop | ConvertFrom-Json -ErrorAction Stop
                $changed = $false

                if (-not $existing.PSObject.Properties.Match('DocPath').Count -or [string]$existing.DocPath -ne $docRel) {
                    $existing | Add-Member -NotePropertyName 'DocPath' -NotePropertyValue $docRel -Force
                    $changed = $true
                }
                if (-not $existing.PSObject.Properties.Match('DocCategories').Count) {
                    $existing | Add-Member -NotePropertyName 'DocCategories' -NotePropertyValue $categories -Force
                    $changed = $true
                }
                elseif ((@($existing.DocCategories) -join '|') -ne ($categories -join '|')) {
                    $existing.DocCategories = $categories
                    $changed = $true
                }
                if (-not $existing.PSObject.Properties.Match('Category').Count -or [string]$existing.Category -ne $topCategory) {
                    $existing.Category = $topCategory
                    $changed = $true
                }
                if (-not $existing.PSObject.Properties.Match('Tags').Count) {
                    $existing | Add-Member -NotePropertyName 'Tags' -NotePropertyValue @('经典菜') -Force
                    $changed = $true
                }
                $tags = @($existing.Tags)
                if ($tags.Count -eq 0) {
                    $tags = @('经典菜')
                }
                $newTagSet = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::Ordinal)
                foreach ($tag in $tags) { [void]$newTagSet.Add([string]$tag) }
                foreach ($tag in $detectedCuisineTags) {
                    if ($newTagSet.Add([string]$tag)) {
                        $changed = $true
                    }
                }
                if ($changed) {
                    $existing.Tags = @($newTagSet)
                }

                if ($changed -and $PSCmdlet.ShouldProcess($targetFile, "补齐菜谱文档映射字段")) {
                    $existing | ConvertTo-Json -Depth 20 | Set-Content -Path $targetFile -Encoding UTF8
                }
            }
        }

        [PSCustomObject]@{
            DocsScanned    = @($docToCategory.Keys).Count
            FilesCreated   = @($created).Count
            CreatedFiles   = @($created)
            DocsIndexPath  = $docsIndexRel.Replace('\', '/')
            DocsRecipeRoot = $docsRecipeRootRel.Replace('\', '/')
        }
    }
}
