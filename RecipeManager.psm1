<#
    .SYNOPSIS
        RecipeManager 架构引擎
    .NOTES
        遵循 GuardianTree v3.0 动态加载规范。
        必须以 UTF-8 with BOM 格式存储。
#>
$ScriptPath = $PSScriptRoot
$script:ModuleRoot = $ScriptPath

# 读取策略配置
$ConfigPath = Join-Path $ScriptPath "Config\Settings.json"
if (-not (Test-Path $ConfigPath)) {
    throw "[模块初始化失败] 未找到配置文件: $ConfigPath"
}

try {
    $script:RecipeConfig = Get-Content -Path $ConfigPath -Raw -ErrorAction Stop | ConvertFrom-Json -ErrorAction Stop
}
catch {
    throw "[模块初始化失败] 配置文件加载或解析失败: $ConfigPath。详情: $($_.Exception.Message)"
}

$EnumsPath = if (-not [string]::IsNullOrWhiteSpace($script:RecipeConfig.EnumsPath)) {
    Join-Path $ScriptPath $script:RecipeConfig.EnumsPath
}
else {
    Join-Path $ScriptPath "Config\RecipeTaxonomy.json"
}

if (-not (Test-Path $EnumsPath)) {
    throw "[模块初始化失败] 未找到枚举配置文件: $EnumsPath"
}

try {
    $script:RecipeEnums = Get-Content -Path $EnumsPath -Raw -ErrorAction Stop | ConvertFrom-Json -ErrorAction Stop
}
catch {
    throw "[模块初始化失败] 枚举配置加载或解析失败: $EnumsPath。详情: $($_.Exception.Message)"
}

$NoodlesPath = if (-not [string]::IsNullOrWhiteSpace($script:RecipeConfig.NoodlesPath)) {
    Join-Path $ScriptPath $script:RecipeConfig.NoodlesPath
}
else {
    Join-Path $ScriptPath "Config\Noodles.json"
}

if (-not (Test-Path $NoodlesPath)) {
    throw "[模块初始化失败] 未找到面食配置文件: $NoodlesPath"
}

try {
    $script:Noodles = Get-Content -Path $NoodlesPath -Raw -ErrorAction Stop | ConvertFrom-Json -ErrorAction Stop
}
catch {
    throw "[模块初始化失败] 面食配置加载或解析失败: $NoodlesPath。详情: $($_.Exception.Message)"
}

$BeveragesPath = if (-not [string]::IsNullOrWhiteSpace($script:RecipeConfig.BeveragesPath)) {
    Join-Path $ScriptPath $script:RecipeConfig.BeveragesPath
}
else {
    Join-Path $ScriptPath "Config\Beverages.json"
}

if (-not (Test-Path $BeveragesPath)) {
    throw "[模块初始化失败] 未找到饮料配置文件: $BeveragesPath"
}

try {
    $script:Beverages = Get-Content -Path $BeveragesPath -Raw -ErrorAction Stop | ConvertFrom-Json -ErrorAction Stop
}
catch {
    throw "[模块初始化失败] 饮料配置加载或解析失败: $BeveragesPath。详情: $($_.Exception.Message)"
}

$ChineseTeaPath = $null
if ($null -ne $script:Beverages.Beverages -and
    $null -ne $script:Beverages.Beverages.NonAlcoholicBeverages -and
    $null -ne $script:Beverages.Beverages.NonAlcoholicBeverages.Tea -and
    -not [string]::IsNullOrWhiteSpace($script:Beverages.Beverages.NonAlcoholicBeverages.Tea.ChineseTeaTaxonomyPath)) {
    $ChineseTeaPath = Join-Path $ScriptPath $script:Beverages.Beverages.NonAlcoholicBeverages.Tea.ChineseTeaTaxonomyPath
}
else {
    $ChineseTeaPath = Join-Path $ScriptPath "Config\ChineseTea.json"
}

if (-not (Test-Path $ChineseTeaPath)) {
    throw "[模块初始化失败] 未找到中国茶配置文件: $ChineseTeaPath"
}

try {
    $script:ChineseTea = Get-Content -Path $ChineseTeaPath -Raw -ErrorAction Stop | ConvertFrom-Json -ErrorAction Stop
}
catch {
    throw "[模块初始化失败] 中国茶配置加载或解析失败: $ChineseTeaPath。详情: $($_.Exception.Message)"
}

$RegionalCuisinesPath = if (-not [string]::IsNullOrWhiteSpace($script:RecipeConfig.RegionalCuisinesPath)) {
    Join-Path $ScriptPath $script:RecipeConfig.RegionalCuisinesPath
}
else {
    Join-Path $ScriptPath "Config\RegionalCuisines.json"
}

if (-not (Test-Path $RegionalCuisinesPath)) {
    throw "[模块初始化失败] 未找到地域菜系配置文件: $RegionalCuisinesPath"
}

try {
    $script:RegionalCuisines = Get-Content -Path $RegionalCuisinesPath -Raw -ErrorAction Stop | ConvertFrom-Json -ErrorAction Stop
}
catch {
    throw "[模块初始化失败] 地域菜系配置加载或解析失败: $RegionalCuisinesPath。详情: $($_.Exception.Message)"
}

$RegionalCuisineAliasesPath = if (-not [string]::IsNullOrWhiteSpace($script:RecipeConfig.RegionalCuisineAliasesPath)) {
    Join-Path $ScriptPath $script:RecipeConfig.RegionalCuisineAliasesPath
}
else {
    Join-Path $ScriptPath "Config\RegionalCuisineAliases.json"
}

if (Test-Path $RegionalCuisineAliasesPath) {
    try {
        $script:RegionalCuisineAliases = Get-Content -Path $RegionalCuisineAliasesPath -Raw -ErrorAction Stop | ConvertFrom-Json -ErrorAction Stop
    }
    catch {
        throw "[模块初始化失败] 地域菜系别名配置加载或解析失败: $RegionalCuisineAliasesPath。详情: $($_.Exception.Message)"
    }
}
else {
    # 别名配置允许缺省，回退到仅匹配标准地域标签
    $script:RegionalCuisineAliases = $null
}

$CookingTechniquesPath = if (-not [string]::IsNullOrWhiteSpace($script:RecipeConfig.CookingTechniquesPath)) {
    Join-Path $ScriptPath $script:RecipeConfig.CookingTechniquesPath
}
else {
    Join-Path $ScriptPath "Config\CookingTechniques.json"
}

if (-not (Test-Path $CookingTechniquesPath)) {
    throw "[模块初始化失败] 未找到烹饪技法配置文件: $CookingTechniquesPath"
}

try {
    $script:CookingTechniques = Get-Content -Path $CookingTechniquesPath -Raw -ErrorAction Stop | ConvertFrom-Json -ErrorAction Stop
}
catch {
    throw "[模块初始化失败] 烹饪技法配置加载或解析失败: $CookingTechniquesPath。详情: $($_.Exception.Message)"
}

$CookingWorkflowPath = if (-not [string]::IsNullOrWhiteSpace($script:RecipeConfig.CookingWorkflowPath)) {
    Join-Path $ScriptPath $script:RecipeConfig.CookingWorkflowPath
}
else {
    Join-Path $ScriptPath "Config\CookingWorkflow.json"
}

if (-not (Test-Path $CookingWorkflowPath)) {
    throw "[模块初始化失败] 未找到烹饪工作流配置文件: $CookingWorkflowPath"
}

try {
    $script:CookingWorkflow = Get-Content -Path $CookingWorkflowPath -Raw -ErrorAction Stop | ConvertFrom-Json -ErrorAction Stop
}
catch {
    throw "[模块初始化失败] 烹饪工作流配置加载或解析失败: $CookingWorkflowPath。详情: $($_.Exception.Message)"
}

$IngredientTaxonomyPath = if (-not [string]::IsNullOrWhiteSpace($script:RecipeConfig.IngredientTaxonomyPath)) {
    Join-Path $ScriptPath $script:RecipeConfig.IngredientTaxonomyPath
}
else {
    Join-Path $ScriptPath "Config\IngredientTaxonomy.json"
}

if (-not (Test-Path $IngredientTaxonomyPath)) {
    throw "[模块初始化失败] 未找到食材体系配置文件: $IngredientTaxonomyPath"
}

try {
    $script:IngredientTaxonomy = Get-Content -Path $IngredientTaxonomyPath -Raw -ErrorAction Stop | ConvertFrom-Json -ErrorAction Stop
}
catch {
    throw "[模块初始化失败] 食材体系配置加载或解析失败: $IngredientTaxonomyPath。详情: $($_.Exception.Message)"
}

$HerbalMedicineSchemaPath = if (-not [string]::IsNullOrWhiteSpace($script:RecipeConfig.HerbalMedicineSchemaPath)) {
    Join-Path $ScriptPath $script:RecipeConfig.HerbalMedicineSchemaPath
}
else {
    Join-Path $ScriptPath "Config\HerbalMedicineSchema.json"
}

if (-not (Test-Path $HerbalMedicineSchemaPath)) {
    throw "[模块初始化失败] 未找到药膳药材知识框架配置文件: $HerbalMedicineSchemaPath"
}

try {
    $script:HerbalMedicineSchema = Get-Content -Path $HerbalMedicineSchemaPath -Raw -ErrorAction Stop | ConvertFrom-Json -ErrorAction Stop
}
catch {
    throw "[模块初始化失败] 药膳药材知识框架配置加载或解析失败: $HerbalMedicineSchemaPath。详情: $($_.Exception.Message)"
}

$HerbalMaterialsPath = if (-not [string]::IsNullOrWhiteSpace($script:RecipeConfig.HerbalMaterialsPath)) {
    Join-Path $ScriptPath $script:RecipeConfig.HerbalMaterialsPath
}
else {
    Join-Path $ScriptPath "Data\HerbalMaterials.json"
}
$HerbalMaterialsRoot = if (-not [string]::IsNullOrWhiteSpace($script:RecipeConfig.HerbalMaterialsRoot)) {
    Join-Path $ScriptPath $script:RecipeConfig.HerbalMaterialsRoot
}
else {
    Join-Path $ScriptPath "Data\HerbalMaterials"
}
$HerbalMaterialsIndexPath = if (-not [string]::IsNullOrWhiteSpace($script:RecipeConfig.HerbalMaterialsIndexPath)) {
    Join-Path $ScriptPath $script:RecipeConfig.HerbalMaterialsIndexPath
}
else {
    Join-Path $HerbalMaterialsRoot "index.json"
}

$loadedFromShard = $false
if (Test-Path $HerbalMaterialsRoot) {
    try {
        $records = @()
        $hasShardInput = $false
        if (Test-Path $HerbalMaterialsIndexPath) {
            $hasShardInput = $true
            $indexRows = @(Get-Content -Path $HerbalMaterialsIndexPath -Raw -ErrorAction Stop | ConvertFrom-Json -ErrorAction Stop)
            foreach ($row in $indexRows) {
                $rowFile = [string]$row.file
                if ([string]::IsNullOrWhiteSpace($rowFile)) {
                    continue
                }
                $filePath = if ([System.IO.Path]::IsPathRooted($rowFile)) { $rowFile } else { Join-Path $ScriptPath $rowFile }
                if (-not (Test-Path $filePath)) {
                    throw "索引引用的药材文件不存在: $rowFile"
                }
                $records += @(Get-Content -Path $filePath -Raw -ErrorAction Stop | ConvertFrom-Json -ErrorAction Stop)
            }
        }
        else {
            $shardFiles = @(Get-ChildItem -Path $HerbalMaterialsRoot -Filter '*.json' -File -ErrorAction Stop | Where-Object { $_.Name -ne 'index.json' })
            if ($shardFiles.Count -gt 0) {
                $hasShardInput = $true
            }
            foreach ($file in $shardFiles) {
                $records += @(Get-Content -Path $file.FullName -Raw -ErrorAction Stop | ConvertFrom-Json -ErrorAction Stop)
            }
        }

        if ($hasShardInput -and @($records).Count -eq 0) {
            throw "检测到药材分片输入，但未能成功加载任何记录。"
        }

        if (@($records).Count -gt 0) {
            $script:HerbalMaterials = @($records)
            $loadedFromShard = $true
        }
    }
    catch {
        throw "[模块初始化失败] 药材分片数据加载或解析失败: $HerbalMaterialsRoot。详情: $($_.Exception.Message)"
    }
}

if (-not $loadedFromShard) {
    if (-not (Test-Path $HerbalMaterialsPath)) {
        throw "[模块初始化失败] 未找到药材数据文件，且药材分片目录不可用。单文件: $HerbalMaterialsPath；分片目录: $HerbalMaterialsRoot"
    }

    try {
        $script:HerbalMaterials = Get-Content -Path $HerbalMaterialsPath -Raw -ErrorAction Stop | ConvertFrom-Json -ErrorAction Stop
    }
    catch {
        throw "[模块初始化失败] 药材数据加载或解析失败: $HerbalMaterialsPath。详情: $($_.Exception.Message)"
    }
}

# 校验别名映射目标必须存在于标准技法集合，避免配置漂移
$CanonicalTechniques = @()
if ($null -ne $script:CookingTechniques.MediumBased) {
    foreach ($Medium in $script:CookingTechniques.MediumBased.PSObject.Properties.Name) {
        $CanonicalTechniques += @($script:CookingTechniques.MediumBased.$Medium)
    }
}

$DocsIndexPath = if (-not [string]::IsNullOrWhiteSpace($script:RecipeConfig.DocsIndexPath)) {
    Join-Path $ScriptPath $script:RecipeConfig.DocsIndexPath
}
else {
    Join-Path $ScriptPath "Docs\CategoryDocIndex.json"
}

if (Test-Path $DocsIndexPath) {
    try {
        $script:CategoryDocIndex = Get-Content -Path $DocsIndexPath -Raw -ErrorAction Stop | ConvertFrom-Json -ErrorAction Stop
    }
    catch {
        throw "[模块初始化失败] 文档索引加载或解析失败: $DocsIndexPath。详情: $($_.Exception.Message)"
    }
}
else {
    # 文档索引允许缺省，不阻塞核心 CRUD 能力
    $script:CategoryDocIndex = $null
}
if ($null -ne $script:CookingTechniques.HeatControl) {
    foreach ($Dimension in $script:CookingTechniques.HeatControl.PSObject.Properties.Name) {
        $CanonicalTechniques += @($script:CookingTechniques.HeatControl.$Dimension)
    }
}
if ($null -ne $script:CookingTechniques.Preparation) {
    foreach ($Prep in $script:CookingTechniques.Preparation.PSObject.Properties.Name) {
        $CanonicalTechniques += @($script:CookingTechniques.Preparation.$Prep)
    }
}
$CanonicalTechniques = $CanonicalTechniques | Select-Object -Unique

if ($null -ne $script:CookingTechniques.Aliases -and $null -ne $script:CookingTechniques.Aliases.AliasToCanonical) {
    foreach ($AliasKey in $script:CookingTechniques.Aliases.AliasToCanonical.PSObject.Properties.Name) {
        $Canonical = [string]$script:CookingTechniques.Aliases.AliasToCanonical.$AliasKey
        if ($CanonicalTechniques -notcontains $Canonical) {
            throw "[模块初始化失败] 烹饪技法别名映射非法: [$AliasKey] -> [$Canonical]，目标标准技法不存在。"
        }
    }
}

# 动态加载分层逻辑：Private -> Public -> UI
$Layers = @("Private", "Public", "UI")
foreach ($Layer in $Layers) {
    $Path = Join-Path $ScriptPath $Layer
    if (Test-Path $Path) {
        Get-ChildItem -Path $Path -Filter *.ps1 -Recurse | ForEach-Object { . $_.FullName }
    }
}

# 导出 Public 和 UI 目录下所有的脚本函数名

# 1. 使用 Join-Path 保证跨平台鲁棒性，构建多层级路径数组
$ExportTargets = @(
    (Join-Path $ScriptPath "Public"),
    (Join-Path $ScriptPath "UI")
)

# 2. 扫描并导出
$ExportFunctions = Get-ChildItem -Path $ExportTargets -Filter *.ps1 | ForEach-Object { $_.BaseName }
Export-ModuleMember -Function $ExportFunctions