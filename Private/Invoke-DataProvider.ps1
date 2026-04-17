function Invoke-DataProvider {
    <#
    .SYNOPSIS
        统一数据提供者 (Data Provider)。负责业务数据与物理存储的交互。
    .DESCRIPTION
        基于 GuardianTree v3.0 标准。
        本算子封装了底层 JSON 的序列化、反序列化、绝对路径解析以及冗余备份逻辑。
        具备 SRE 容错机制，任何外部接口均不可绕过此算子直接操作磁盘。
    .PARAMETER Load
        开关参数。触发数据读取逻辑。
    .PARAMETER SaveData
        传入需要持久化保存的 PSCustomObject 数组。
    #>
    [CmdletBinding(DefaultParameterSetName = 'LoadSet')]
    param(
        [Parameter(Mandatory = $true, ParameterSetName = 'LoadSet')]
        [switch]$Load,

        [Parameter(Mandatory = $true, ParameterSetName = 'SaveSet')]
        [PSCustomObject[]]$SaveData
    )

    process {
        if ($null -eq $script:RecipeConfig) {
            throw "[致命故障] 系统配置未加载。请重新 Import-Module。"
        }
        if ([string]::IsNullOrWhiteSpace($script:ModuleRoot)) {
            throw "[致命故障] 模块根路径未初始化，无法进行数据寻址。"
        }

        # 1. 动态寻址：基于模块根路径解析配置中的相对存储路径
        $RelativePath = $script:RecipeConfig.Storage.RecipePath
        $AbsolutePath = Join-Path $script:ModuleRoot $RelativePath

        # ==========================================
        # 逻辑分支 A：读取数据 (Read)
        # ==========================================
        if ($Load) {
            Write-Verbose "[I/O 寻址] 尝试从物理路径读取数据: $AbsolutePath"
            
            try {
                if (Test-Path $AbsolutePath) {
                    $RawJson = Get-Content -Path $AbsolutePath -Raw -Encoding UTF8 -ErrorAction Stop
                    
                    # 容错：防止空文件导致解析失败
                    if ([string]::IsNullOrWhiteSpace($RawJson)) { return @() }
                    
                    $ParsedData = $RawJson | ConvertFrom-Json
                    
                    # 强制返回数组，确保下游使用 .Count 或 foreach 时不会因为单条数据而报错
                    if ($ParsedData -is [array]) { return $ParsedData } else { return @($ParsedData) }
                }
                else {
                    Write-Verbose "[I/O 降级] 目标数据文件不存在，返回空集合以维持系统运行。"
                    return @()
                }
            }
            catch {
                Write-Error "[SRE 致命故障] 数据读取失败。文件可能被锁定或损坏。详情: $_"
                throw $_
            }
        }

        # ==========================================
        # 逻辑分支 B：写入与备份 (Write & Backup)
        # ==========================================
        if ($PSCmdlet.ParameterSetName -eq 'SaveSet') {
            Write-Verbose "[I/O 寻址] 准备向物理路径写入数据..."
            
            try {
                # 1. 确保父级目录 (Data 文件夹) 存在
                $ParentDir = Split-Path $AbsolutePath -Parent
                if (-not (Test-Path $ParentDir)) {
                    New-Item -Path $ParentDir -ItemType Directory -Force | Out-Null
                }

                # 2. 策略联动：执行冗余备份
                if ($script:RecipeConfig.Storage.BackupEnabled -and (Test-Path $AbsolutePath)) {
                    $BackupPath = "$AbsolutePath.bak"
                    Copy-Item -Path $AbsolutePath -Destination $BackupPath -Force -ErrorAction Stop
                    Write-Verbose "[I/O 策略] 已触发冗余备份: $BackupPath"
                }

                # 3. 先写入临时文件，再替换主文件，尽量降低并发写入下的损坏风险
                $TempPath = "$AbsolutePath.tmp"
                $SaveData | ConvertTo-Json -Depth 10 | Set-Content -Path $TempPath -Encoding UTF8 -ErrorAction Stop
                Move-Item -Path $TempPath -Destination $AbsolutePath -Force -ErrorAction Stop
                Write-Verbose "[I/O 成功] 内存数据已成功刷新至物理磁盘。"
            }
            catch {
                Write-Error "[SRE 致命故障] 数据持久化失败！可能存在权限不足或磁盘空间耗尽。详情: $_"
                throw $_
            }
        }
    }
}