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

        # 1. 载入系统策略 (根据调试结果，Policy 与 Enums 是平级的)
        $Policy = $script:RecipeConfig.Policy
        $Enums = $script:RecipeConfig.Enums

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

        # 4. [关键修复] 标签枚举校验
        if ($null -ne $Recipe.Tags -and $Recipe.Tags.Count -gt 0) {
            $AllowedTags = $Enums.AllowedTags
            foreach ($Tag in $Recipe.Tags) {
                if ($AllowedTags -notcontains $Tag) {
                    $AllowedStr = $AllowedTags -join ', '
                    throw "[策略违规] 越权数据: 标签 [$Tag] 非法。合法池: ($AllowedStr)。"
                }
            }
        }

        Write-Verbose "[策略审计] 目标 [$($Recipe.Name)] 完美合规，准许注入持久层。"
        return $true
    }
}