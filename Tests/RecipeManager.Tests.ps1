BeforeAll {
    $ModuleRoot = Split-Path $PSScriptRoot -Parent
    Import-Module (Join-Path $ModuleRoot 'RecipeManager.psd1') -Force
}

Describe 'RecipeManager behavior checks' {
    It 'loads enums from dedicated config file' {
        $module = Get-Module RecipeManager
        $enums = $module.SessionState.PSVariable.GetValue('RecipeEnums')
        $enums | Should -Not -BeNullOrEmpty
        @($enums.Categories) | Should -Contain '主食'
        @($enums.Categories) | Should -Contain '蒸菜'
        @($enums.TagTaxonomy.PrimaryTags) | Should -Contain '厨具'
        @($enums.TagTaxonomy.SecondaryTagsByPrimary.厨具) | Should -Contain '砂锅'
        @($enums.TagTaxonomy.SecondaryTagsByPrimary.厨具) | Should -Contain '炖盅'
    }

    It 'loads noodles from dedicated config file' {
        $module = Get-Module RecipeManager
        $noodles = $module.SessionState.PSVariable.GetValue('Noodles')
        $noodles | Should -Not -BeNullOrEmpty
        @($noodles.NoodleDishes.'港粤风味') | Should -Contain '餐蛋面'
    }

    It 'loads beverages and chinese tea from dedicated config files' {
        $module = Get-Module RecipeManager
        $beverages = $module.SessionState.PSVariable.GetValue('Beverages')
        $chineseTea = $module.SessionState.PSVariable.GetValue('ChineseTea')
        $beverages | Should -Not -BeNullOrEmpty
        $chineseTea | Should -Not -BeNullOrEmpty
        $beverages.Beverages.NonAlcoholicBeverages.Tea.ChineseTeaTaxonomyPath | Should -Be 'Config/ChineseTea.json'
        @($chineseTea.ChineseTeaSystem.'绿茶') | Should -Contain '西湖龙井'
    }

    It 'loads regional cuisines from dedicated config file' {
        $module = Get-Module RecipeManager
        $regionalCuisines = $module.SessionState.PSVariable.GetValue('RegionalCuisines')
        $regionalCuisines | Should -Not -BeNullOrEmpty
        @($regionalCuisines.'八大菜系') | Should -Contain '粤菜'
    }

    It 'loads cooking techniques from dedicated config file' {
        $module = Get-Module RecipeManager
        $cookingTechniques = $module.SessionState.PSVariable.GetValue('CookingTechniques')
        $cookingTechniques | Should -Not -BeNullOrEmpty
        @($cookingTechniques.MediumBased.'油介质') | Should -Contain '干炒'
        @($cookingTechniques.HeatControl.'温度维度') | Should -Contain '猛火'
        @($cookingTechniques.Preparation.'切割技法') | Should -Contain '切丁'
        $cookingTechniques.Aliases.AliasToCanonical.白灼 | Should -Be '灼'
        @($cookingTechniques.Aliases.CanonicalToAliases.锅气) | Should -Contain '镬气'
    }

    It 'loads cooking workflow config for structured SOP output' {
        $module = Get-Module RecipeManager
        $workflow = $module.SessionState.PSVariable.GetValue('CookingWorkflow')
        $workflow | Should -Not -BeNullOrEmpty
        $workflow.Workflows.GenericWokWorkflow.Name | Should -Be '通用炒锅工作流'
        @($workflow.Workflows.GenericWokWorkflow.WokOrder) | Should -Contain '分段调味（A上色挂味，B校正提香）'
    }

    It 'loads herbal schema and herbal materials data' {
        $module = Get-Module RecipeManager
        $herbalSchema = $module.SessionState.PSVariable.GetValue('HerbalMedicineSchema')
        $herbalMaterials = @($module.SessionState.PSVariable.GetValue('HerbalMaterials'))
        $herbalSchema | Should -Not -BeNullOrEmpty
        $herbalMaterials.Count | Should -BeGreaterThan 0
        @($herbalSchema.HerbalMedicineSchema.中医药性.归经) | Should -Contain '肺'
        @($herbalMaterials.药材名) | Should -Contain '黄芪'
    }

    It 'prioritizes herbal shard index and keeps it aligned with loaded data' {
        $module = Get-Module RecipeManager
        $settings = $module.SessionState.PSVariable.GetValue('RecipeConfig')
        $loaded = @($module.SessionState.PSVariable.GetValue('HerbalMaterials'))
        $indexPath = Join-Path $ModuleRoot $settings.HerbalMaterialsIndexPath
        $indexRows = @(Get-Content -Path $indexPath -Raw | ConvertFrom-Json)

        @($indexRows).Count | Should -BeGreaterThan 0
        @($loaded).Count | Should -Be @($indexRows).Count
        @($indexRows.name) | Should -Contain '黄芪'
        @($indexRows.file) | Should -Contain 'Data/HerbalMaterials/黄芪.json'
    }

    It 'returns workflow via public command' {
        $wf = Get-CookingWorkflow -Name 'StirFriedRiceNoodles'
        $wf.Name | Should -Be '炒粉/炒面场景'
        @($wf.RecommendedOrder) | Should -Contain '米粉入锅'
    }

    It 'returns herbal materials via public command' {
        $all = @(Get-HerbalMaterial)
        $all.Count | Should -BeGreaterThan 0
        @($all.药材名) | Should -Contain '山药'

        $byName = @(Get-HerbalMaterial -Name '黄')
        @($byName.药材名) | Should -Contain '黄芪'

        $byRegex = @(Get-HerbalMaterial -Name '^枸杞子$' -Regex)
        $byRegex.Count | Should -Be 1
        $byRegex[0].药材名 | Should -Be '枸杞子'

        $byConstitution = @(Get-HerbalMaterial -Constitution '气虚质')
        @($byConstitution.药材名) | Should -Contain '黄芪'
    }

    It 'validates herbal materials and returns summary' {
        $summary = Test-HerbalMaterial
        $summary.Total | Should -BeGreaterThan 0
        $summary.Invalid | Should -Be 0
    }

    It 'returns detailed validation rows for herbal materials' {
        $details = @(Test-HerbalMaterial -Detailed)
        @($details).Count | Should -BeGreaterThan 0
        @($details[0].PSObject.Properties.Name) | Should -Contain 'IsValid'
        @($details | Where-Object { -not $_.IsValid }).Count | Should -Be 0
    }

    It 'exports herbal validation details to csv' {
        $csvPath = Join-Path $TestDrive 'herbal-validation.csv'
        $rows = @(Test-HerbalMaterial -Detailed -ExportCsv $csvPath)
        Test-Path $csvPath | Should -BeTrue
        @($rows).Count | Should -BeGreaterThan 0
        $csvRows = Import-Csv -Path $csvPath
        @($csvRows).Count | Should -BeGreaterThan 0
        @($csvRows.药材名) | Should -Contain '黄芪'
    }

    It 'throws when using herbal -OpenCsv without -ExportCsv' {
        {
            Test-HerbalMaterial -Detailed -OpenCsv
        } | Should -Throw
    }

    It 'exports and attempts to open herbal validation csv' {
        $csvPath = Join-Path $TestDrive 'herbal-validation-open.csv'
        Mock -CommandName Start-Process -ModuleName RecipeManager

        $rows = @(Test-HerbalMaterial -Detailed -ExportCsv $csvPath -OpenCsv)
        Test-Path $csvPath | Should -BeTrue
        @($rows).Count | Should -BeGreaterThan 0
        Should -Invoke -CommandName Start-Process -ModuleName RecipeManager -Times 1 -Exactly -ParameterFilter { $FilePath -eq $csvPath }
    }

    It 'returns workflow section directly via public command' {
        $kpi = @(Get-CookingWorkflow -Name 'GenericWokWorkflow' -Section KPI)
        @($kpi).Count | Should -BeGreaterThan 0
        @($kpi.Metric) | Should -Contain '食材利用率'
    }

    It 'uses GenericWokWorkflow as default when querying section only' {
        $temperature = Get-CookingWorkflow -Section TemperatureGuidelines
        $temperature.爆香起始锅温 | Should -Be '>=180C'
    }

    It 'returns KPI as table-friendly rows when -AsTable is set' {
        $rows = @(Get-CookingWorkflow -Section KPI -AsTable)
        @($rows).Count | Should -BeGreaterThan 0
        @($rows.指标) | Should -Contain '食材利用率'
        @($rows[0].PSObject.Properties.Name) | Should -Contain '家庭目标'
    }

    It 'returns CCP as table-friendly rows when -AsTable is set' {
        $rows = @(Get-CookingWorkflow -Section CriticalControlPoints -AsTable)
        @($rows).Count | Should -BeGreaterThan 0
        @($rows.风险点) | Should -Contain '交叉污染'
        @($rows[0].PSObject.Properties.Name) | Should -Contain '控制措施'
    }

    It 'exports section to csv when -ExportCsv is provided' {
        $csvPath = Join-Path $TestDrive 'workflow-kpi.csv'
        $rows = @(Get-CookingWorkflow -Section KPI -AsTable -ExportCsv $csvPath)
        Test-Path $csvPath | Should -BeTrue
        @($rows).Count | Should -BeGreaterThan 0
        $csvRows = Import-Csv -Path $csvPath
        @($csvRows).Count | Should -BeGreaterThan 0
        @($csvRows.指标) | Should -Contain '食材利用率'
    }

    It 'throws when using -ExportCsv without -Section' {
        $csvPath = Join-Path $TestDrive 'invalid.csv'
        {
            Get-CookingWorkflow -ExportCsv $csvPath
        } | Should -Throw
    }

    It 'throws when using -OpenCsv without -ExportCsv' {
        {
            Get-CookingWorkflow -Section KPI -OpenCsv
        } | Should -Throw
    }

    It 'exports and attempts to open csv when -OpenCsv is set' {
        $csvPath = Join-Path $TestDrive 'workflow-kpi-open.csv'
        Mock -CommandName Start-Process -ModuleName RecipeManager

        $rows = @(Get-CookingWorkflow -Section KPI -AsTable -ExportCsv $csvPath -OpenCsv)
        Test-Path $csvPath | Should -BeTrue
        @($rows).Count | Should -BeGreaterThan 0
        Should -Invoke -CommandName Start-Process -ModuleName RecipeManager -Times 1 -Exactly -ParameterFilter { $FilePath -eq $csvPath }
    }

    It 'accepts technique aliases by normalization mapping' {
        $module = Get-Module RecipeManager
        $recipe = [PSCustomObject]@{
            ID = '00000000-0000-0000-0000-000000000001'
            Name = '别名校验样例'
            Category = '炒菜'
            Ingredients = @([PSCustomObject]@{ Item = '测试食材'; Amount = '1份' })
            Steps = @('测试步骤')
            Tags = @('经典菜')
            Techniques = @('白灼', '手撕')
        }

        {
            & $module { param($r) Invoke-RecipeValidation -Recipe $r -ErrorAction Stop } $recipe
        } | Should -Not -Throw
    }

    It 'accepts valid noodle style from noodles config' {
        $module = Get-Module RecipeManager
        $recipe = [PSCustomObject]@{
            ID = '00000000-0000-0000-0000-000000000002'
            Name = '面食品类校验样例'
            Category = '主食'
            Ingredients = @([PSCustomObject]@{ Item = '面条'; Amount = '1份' })
            Steps = @('测试步骤')
            Tags = @('经典菜')
            NoodleStyle = '餐蛋面'
        }

        {
            & $module { param($r) Invoke-RecipeValidation -Recipe $r -ErrorAction Stop } $recipe
        } | Should -Not -Throw
    }

    It 'rejects invalid noodle style not in noodles config' {
        $module = Get-Module RecipeManager
        $recipe = [PSCustomObject]@{
            ID = '00000000-0000-0000-0000-000000000003'
            Name = '非法面食品类样例'
            Category = '主食'
            Ingredients = @([PSCustomObject]@{ Item = '面条'; Amount = '1份' })
            Steps = @('测试步骤')
            Tags = @('经典菜')
            NoodleStyle = '不存在的面'
        }

        {
            & $module { param($r) Invoke-RecipeValidation -Recipe $r -ErrorAction Stop } $recipe
        } | Should -Throw
    }

    It 'accepts valid beverage style from beverages config' {
        $module = Get-Module RecipeManager
        $recipe = [PSCustomObject]@{
            ID = '00000000-0000-0000-0000-000000000004'
            Name = '饮料品类校验样例'
            Category = '主食'
            Ingredients = @([PSCustomObject]@{ Item = '面条'; Amount = '1份' })
            Steps = @('测试步骤')
            Tags = @('经典菜')
            BeverageStyle = '王老吉'
        }

        {
            & $module { param($r) Invoke-RecipeValidation -Recipe $r -ErrorAction Stop } $recipe
        } | Should -Not -Throw
    }

    It 'rejects invalid beverage style not in beverages config' {
        $module = Get-Module RecipeManager
        $recipe = [PSCustomObject]@{
            ID = '00000000-0000-0000-0000-000000000005'
            Name = '非法饮料品类样例'
            Category = '主食'
            Ingredients = @([PSCustomObject]@{ Item = '面条'; Amount = '1份' })
            Steps = @('测试步骤')
            Tags = @('经典菜')
            BeverageStyle = '不存在的饮料'
        }

        {
            & $module { param($r) Invoke-RecipeValidation -Recipe $r -ErrorAction Stop } $recipe
        } | Should -Throw
    }

    It 'accepts valid ServingNote and rejects oversized or whitespace-only' {
        $module = Get-Module RecipeManager
        $ok = [PSCustomObject]@{
            ID = '00000000-0000-0000-0000-000000000010'
            Name = 'ServingNote样例'
            Category = '炒菜'
            Ingredients = @([PSCustomObject]@{ Item = '测'; Amount = '1' })
            Steps = @('步骤')
            Tags = @('经典菜')
            ServingNote = '上桌说明：宜配米饭。'
        }
        {
            & $module { param($r) Invoke-RecipeValidation -Recipe $r -ErrorAction Stop } $ok
        } | Should -Not -Throw

        $long = 'x' * 4001
        $tooLong = [PSCustomObject]@{
            ID = '00000000-0000-0000-0000-000000000011'
            Name = 'ServingNote过长'
            Category = '炒菜'
            Ingredients = @([PSCustomObject]@{ Item = '测'; Amount = '1' })
            Steps = @('步骤')
            Tags = @('经典菜')
            ServingNote = $long
        }
        {
            & $module { param($r) Invoke-RecipeValidation -Recipe $r -ErrorAction Stop } $tooLong
        } | Should -Throw

        $blank = [PSCustomObject]@{
            ID = '00000000-0000-0000-0000-000000000012'
            Name = 'ServingNote空白'
            Category = '炒菜'
            Ingredients = @([PSCustomObject]@{ Item = '测'; Amount = '1' })
            Steps = @('步骤')
            Tags = @('经典菜')
            ServingNote = '   '
        }
        {
            & $module { param($r) Invoke-RecipeValidation -Recipe $r -ErrorAction Stop } $blank
        } | Should -Throw
    }

    It 'loads recipe data through public API' {
        $data = Get-Recipe
        $data | Should -Not -BeNullOrEmpty
        @($data).Count | Should -BeGreaterThan 0
    }

    It 'stores recipes as one json file per dish under Data/Recipes by category' {
        $shardRoot = Join-Path $ModuleRoot 'Data/Recipes'
        Test-Path $shardRoot | Should -BeTrue
        $shardFiles = @(Get-ChildItem -Path $shardRoot -Recurse -Filter '*.json' -File)
        $shardFiles.Count | Should -BeGreaterThan 1
        @($shardFiles.Name) | Should -Contain '番茄炒蛋.json'
        @($shardFiles.Name) | Should -Contain '包菜洋葱火腿玉米粒炒粉.json'
    }

    It 'returns beverage taxonomy from public command' {
        $all = Get-BeverageTaxonomy
        $all | Should -Not -BeNullOrEmpty
        $all.Beverages.Beverages.NonAlcoholicBeverages.PSObject.Properties.Name | Should -Contain 'Tea'
        $teaOnly = Get-BeverageTaxonomy -Type ChineseTea
        @($teaOnly.ChineseTeaSystem.'红茶') | Should -Contain '祁门红茶'
    }

    It 'keeps recipe docs mapping consistent with docs index' {
        $allRecipes = @(Get-Recipe)
        $target = $allRecipes | Where-Object { $_.Name -eq '包菜洋葱火腿玉米粒炒粉' } | Select-Object -First 1
        $target | Should -Not -BeNullOrEmpty
        $target.DocPath | Should -Be 'Docs/菜谱/主食/米粉/包菜洋葱火腿玉米粒炒粉.md'
        @($target.DocCategories) | Should -Contain '主食/米粉'
    }

    It 'sync command creates missing recipe json for newly added docs file' {
        $docPath = Join-Path $ModuleRoot 'Docs/菜谱/炒菜/自动同步测试.md'
        $jsonPath = Join-Path $ModuleRoot 'Data/Recipes/炒菜/自动同步测试.json'
        try {
            "测试文档" | Set-Content -Path $docPath -Encoding UTF8
            if (Test-Path -LiteralPath $jsonPath) {
                Remove-Item -LiteralPath $jsonPath -Force
            }

            $result = Sync-RecipeDocs -DocPaths @('Docs/菜谱/炒菜/自动同步测试.md')
            @($result.CreatedFiles) | Should -Contain 'Data/Recipes/炒菜/自动同步测试.json'
            Test-Path -LiteralPath $jsonPath | Should -BeTrue

            $created = Get-Content -Path $jsonPath -Raw | ConvertFrom-Json
            $created.Category | Should -Be '炒菜'
            $created.DocPath | Should -Be 'Docs/菜谱/炒菜/自动同步测试.md'
            @($created.DocCategories) | Should -Contain '炒菜'
        }
        finally {
            if (Test-Path -LiteralPath $docPath) {
                Remove-Item -LiteralPath $docPath -Force
            }
            if (Test-Path -LiteralPath $jsonPath) {
                Remove-Item -LiteralPath $jsonPath -Force
            }
            Sync-RecipeDocs | Out-Null
        }
    }

    It 'sync command appends regional cuisine tags based on doc content' {
        $docPath = Join-Path $ModuleRoot 'Docs/菜谱/炒菜/地域打标测试.md'
        $jsonPath = Join-Path $ModuleRoot 'Data/Recipes/炒菜/地域打标测试.json'
        try {
            "这是一道典型川菜，适合下饭。" | Set-Content -Path $docPath -Encoding UTF8
            if (Test-Path -LiteralPath $jsonPath) {
                Remove-Item -LiteralPath $jsonPath -Force
            }

            Sync-RecipeDocs -DocPaths @('Docs/菜谱/炒菜/地域打标测试.md') | Out-Null
            $created = Get-Content -Path $jsonPath -Raw | ConvertFrom-Json
            @($created.Tags) | Should -Contain '川菜'
        }
        finally {
            if (Test-Path -LiteralPath $docPath) {
                Remove-Item -LiteralPath $docPath -Force
            }
            if (Test-Path -LiteralPath $jsonPath) {
                Remove-Item -LiteralPath $jsonPath -Force
            }
            Sync-RecipeDocs | Out-Null
        }
    }

    It 'sync command maps regional alias to canonical cuisine tag' {
        $docPath = Join-Path $ModuleRoot 'Docs/菜谱/炒菜/地域别名测试.md'
        $jsonPath = Join-Path $ModuleRoot 'Data/Recipes/炒菜/地域别名测试.json'
        try {
            "这道菜是典型四川家常风味。" | Set-Content -Path $docPath -Encoding UTF8
            if (Test-Path -LiteralPath $jsonPath) {
                Remove-Item -LiteralPath $jsonPath -Force
            }

            Sync-RecipeDocs -DocPaths @('Docs/菜谱/炒菜/地域别名测试.md') | Out-Null
            $created = Get-Content -Path $jsonPath -Raw | ConvertFrom-Json
            @($created.Tags) | Should -Contain '川菜'
        }
        finally {
            if (Test-Path -LiteralPath $docPath) {
                Remove-Item -LiteralPath $docPath -Force
            }
            if (Test-Path -LiteralPath $jsonPath) {
                Remove-Item -LiteralPath $jsonPath -Force
            }
            Sync-RecipeDocs | Out-Null
        }
    }

    It 'filters 蒸菜 by Category and matches DocPath from index' {
        $steam = @(Get-Recipe -Category '蒸菜')
        $steam.Count | Should -Be 3
        $paths = @($steam | ForEach-Object { $_.DocPath }) | Sort-Object -Unique
        $paths | Should -Contain 'Docs/菜谱/蒸菜/五花肉蛋羹.md'
        $paths | Should -Contain 'Docs/菜谱/蒸菜/粉蒸肉.md'
        $paths | Should -Contain 'Docs/菜谱/蒸菜/蒜泥手撕茄子.md'
        foreach ($r in $steam) {
            @($r.DocCategories) | Should -Contain '蒸菜'
        }
        $rou = @(Get-Recipe -Name '五花肉蛋羹' -Regex | Select-Object -First 1)
        $rou.ServingNote | Should -Not -BeNullOrEmpty
        $rou.ServingNote | Should -Match '口感与佐餐'
    }

    It 'supports fuzzy name matching by default' {
        $result = Get-Recipe -Name '番茄'
        @($result).Count | Should -BeGreaterThan 0
        ($result | Select-Object -First 1).Name | Should -Match '番茄'
    }

    It 'supports regex name matching when -Regex is set' {
        $result = Get-Recipe -Name '^番茄炒蛋$' -Regex
        @($result).Count | Should -Be 1
        ($result | Select-Object -First 1).Name | Should -Be '番茄炒蛋'
    }

    It 'supports hierarchical food navigation via DocCategories' {
        $result = Get-Recipe -Name '炒粉'
        @($result).Count | Should -BeGreaterThan 0
        @(($result | Select-Object -First 1).DocCategories) | Should -Contain '主食/米粉'
    }

    It 'accepts secondary tags under cross-category dimensions' {
        $module = Get-Module RecipeManager
        $recipe = [PSCustomObject]@{
            ID = '00000000-0000-0000-0000-000000000020'
            Name = '二级标签校验样例'
            Category = '炒菜'
            Ingredients = @([PSCustomObject]@{ Item = '测'; Amount = '1' })
            Steps = @('步骤')
            Tags = @('经典菜', '食材/植物/蔬菜/茄果/番茄', '口味/酸辣', '场景/便当')
        }

        {
            & $module { param($r) Invoke-RecipeValidation -Recipe $r -ErrorAction Stop } $recipe
        } | Should -Not -Throw
    }

    It 'rejects category outside Settings enum in Set-Recipe' {
        {
            Set-Recipe -Name '番茄炒蛋' -Category '西式' -WhatIf -ErrorAction Stop
        } | Should -Throw
    }

    It 'accepts remove by ID parameter set without Name' {
        {
            Remove-Recipe -ID '00000000-0000-0000-0000-000000000000' -WhatIf -ErrorAction Stop
        } | Should -Not -Throw
    }

    It 'throws on import when herbal shard index exists but loads zero records' {
        $cloneRoot = Join-Path $TestDrive 'RecipeManagerClone'
        New-Item -Path $cloneRoot -ItemType Directory -Force | Out-Null
        Copy-Item -Path (Join-Path $ModuleRoot '*') -Destination $cloneRoot -Recurse -Force

        $cloneSettingsPath = Join-Path $cloneRoot 'Config/Settings.json'
        $settings = Get-Content -Path $cloneSettingsPath -Raw | ConvertFrom-Json
        $settings.HerbalMaterialsPath = 'Data/HerbalMaterials-fallback.json'
        $settings.HerbalMaterialsRoot = 'Data/HerbalMaterials'
        $settings.HerbalMaterialsIndexPath = 'Data/HerbalMaterials/index.json'
        $settings | ConvertTo-Json -Depth 20 | Set-Content -Path $cloneSettingsPath -Encoding UTF8

        $cloneShardRoot = Join-Path $cloneRoot 'Data/HerbalMaterials'
        New-Item -Path $cloneShardRoot -ItemType Directory -Force | Out-Null
        '[]' | Set-Content -Path (Join-Path $cloneShardRoot 'index.json') -Encoding UTF8
        '[{"药材名":"回退样例"}]' | Set-Content -Path (Join-Path $cloneRoot 'Data/HerbalMaterials-fallback.json') -Encoding UTF8

        Remove-Module RecipeManager -ErrorAction SilentlyContinue
        {
            Import-Module (Join-Path $cloneRoot 'RecipeManager.psd1') -Force -ErrorAction Stop
        } | Should -Throw

        Import-Module (Join-Path $ModuleRoot 'RecipeManager.psd1') -Force
    }
}

