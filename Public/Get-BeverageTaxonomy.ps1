function Get-BeverageTaxonomy {
    <#
    .SYNOPSIS
        获取饮料总类目与中国茶体系。
    .DESCRIPTION
        返回模块启动时加载的饮料配置。支持按类型查看总类目、中国茶或两者合并结果。
    .PARAMETER Type
        指定返回的数据范围：
        - Beverage: 仅返回 Beverages.json
        - ChineseTea: 仅返回 ChineseTea.json
        - All: 返回两者聚合对象（默认）
    #>
    [CmdletBinding()]
    param(
        [Parameter()]
        [ValidateSet('All', 'Beverage', 'ChineseTea')]
        [string]$Type = 'All'
    )

    process {
        if ($null -eq $script:Beverages) {
            throw "[致命故障] 饮料配置未加载。请执行 Import-Module -Force 重新初始化模块。"
        }
        if ($null -eq $script:ChineseTea) {
            throw "[致命故障] 中国茶配置未加载。请执行 Import-Module -Force 重新初始化模块。"
        }

        switch ($Type) {
            'Beverage' { return $script:Beverages }
            'ChineseTea' { return $script:ChineseTea }
            default {
                return [PSCustomObject]@{
                    Beverages = $script:Beverages
                    ChineseTea = $script:ChineseTea
                }
            }
        }
    }
}
