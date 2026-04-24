function Get-Recipe {
    <#
    .SYNOPSIS
        查询与检索系统中的菜谱数据。
    .DESCRIPTION
        基于 GuardianTree v3.0 标准。
        本函数作为 Public 对外契约层，不直接操作磁盘，而是通过调用底层 Invoke-DataProvider 获取数据。
        支持多维度组合查询（名称模糊匹配、分类精准匹配、标签匹配），并支持管道符 (Pipeline) 级联操作。
    .PARAMETER Name
        要查询的菜谱名称（默认按子串模糊匹配）。
    .PARAMETER Category
        按分类筛选（如：炒菜、汤羹）。
    .PARAMETER Tag
        按标签筛选（如：快手菜、减脂）。
    .EXAMPLE
        PS> Get-Recipe
        获取系统中所有的菜谱。
    .EXAMPLE
        PS> Get-Recipe -Category "炒菜" -Tag "快手菜"
        组合查询：获取所有既是“炒菜”又带有“快手菜”标签的记录。
    .EXAMPLE
        PS> Get-Recipe -Name "番茄"
        模糊查询：名称中包含“番茄”的所有菜谱。
    .EXAMPLE
        PS> Get-Recipe -Name "^番茄.*蛋$" -Regex
        正则查询：按正则表达式筛选菜谱名称。
    #>
    [CmdletBinding()]
    param(
        # 允许从管道传递 Name，支持模糊搜索
        [Parameter(Position = 0, ValueFromPipeline = $true, ValueFromPipelineByPropertyName = $true)]
        [string]$Name,

        # 分类筛选
        [Parameter()]
        [string]$Category,

        # 标签筛选
        [Parameter()]
        [string]$Tag,

        # 名称匹配方式：默认模糊；指定后启用正则
        [Parameter()]
        [switch]$Regex
    )

    process {
        Write-Verbose "[检索引擎] 正在通过 Private 算子调取系统全量数据..."
        
        try {
            # 1. 委托给底层算子加载数据。注意：遇到非致命错误强制抛出
            $AllRecipes = Invoke-DataProvider -Load -ErrorAction Stop

            # 容错：如果数据库为空，优雅退出，不抛出红字
            if (-not $AllRecipes -or $AllRecipes.Count -eq 0) {
                Write-Verbose "[检索引擎] 当前系统无数据沉淀。"
                return
            }

            # 2. 构建动态过滤链 (Dynamic Filter Chain)
            $ResultSet = $AllRecipes

            # [维度 A：按名称模糊过滤]
            if ($PSBoundParameters.ContainsKey('Name')) {
                if ($Regex) {
                    Write-Verbose " -> 应用过滤规则: Name 正则匹配 [$Name]"
                    $ResultSet = $ResultSet | Where-Object { $_.Name -match $Name }
                }
                else {
                    Write-Verbose " -> 应用过滤规则: Name 包含 [$Name]"
                    $ResultSet = $ResultSet | Where-Object { $_.Name -like "*$Name*" }
                }
            }

            # [维度 B：按分类精准过滤]
            if ($PSBoundParameters.ContainsKey('Category')) {
                Write-Verbose " -> 应用过滤规则: Category 等于 [$Category]"
                $ResultSet = $ResultSet | Where-Object { $_.Category -eq $Category }
            }

            # [维度 C：按标签过滤 (处理数组包含关系)]
            if ($PSBoundParameters.ContainsKey('Tag')) {
                Write-Verbose " -> 应用过滤规则: Tags 包含 [$Tag]"
                $ResultSet = $ResultSet | Where-Object { 
                    $null -ne $_.Tags -and $_.Tags -contains $Tag 
                }
            }

            # 3. 输出最终结果至管道
            $MatchCount = if ($ResultSet) { @($ResultSet).Count } else { 0 }
            Write-Verbose "[检索引擎] 检索完毕。共命中 $MatchCount 条记录。"
            
            # 将结果推入管道，供下游（如 Out-GridView 或 Set-Recipe）继续处理
            $ResultSet
        }
        catch {
            Write-Error "[检索致命异常] 无法完成数据检索。详情: $_"
        }
    }
}