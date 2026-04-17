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