function Invoke-DataProvider {
    <#
    .SYNOPSIS
        统一数据提供者 (Data Provider)。负责业务数据与物理存储的交互。
    .DESCRIPTION
        基于 GuardianTree v3.0 标准。
        本算子封装了底层 JSON 的序列化、反序列化、绝对路径解析以及冗余备份逻辑。
        当 Storage.RecipeRoot 已配置时，菜谱以分片形式存储于该目录树下（每文件一条菜谱，JSON 为单对象）；
        否则回退为 Storage.RecipePath 单体数组文件。
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
        [object[]]$SaveData
    )

    process {
        if ($null -eq $script:RecipeConfig) {
            throw "[致命故障] 系统配置未加载。请重新 Import-Module。"
        }
        if ([string]::IsNullOrWhiteSpace($script:ModuleRoot)) {
            throw "[致命故障] 模块根路径未初始化，无法进行数据寻址。"
        }

        if ($Load) {
            Write-Verbose "[I/O 寻址] 加载菜谱存储（分片优先，其次单体文件）..."
            try {
                return Import-RecipeStorageCollection
            }
            catch {
                Write-Error "[SRE 致命故障] 数据读取失败。详情: $_"
                throw $_
            }
        }

        if ($PSCmdlet.ParameterSetName -eq 'SaveSet') {
            Write-Verbose "[I/O 寻址] 准备持久化菜谱数据..."
            try {
                if (Test-RecipeShardStorageConfigured) {
                    Export-RecipeShardCollection -SaveData $SaveData
                }
                else {
                    Export-RecipeLegacyCollection -SaveData $SaveData
                }
                Write-Verbose "[I/O 成功] 内存数据已成功刷新至物理磁盘。"
            }
            catch {
                Write-Error "[SRE 致命故障] 数据持久化失败！可能存在权限不足或磁盘空间耗尽。详情: $_"
                throw $_
            }
        }
    }
}
