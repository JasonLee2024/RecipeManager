function Remove-Recipe {
    <#
    .SYNOPSIS
        从系统中物理删除指定的菜谱记录。
    .DESCRIPTION
        基于 GuardianTree v3.0 标准的高危操作算子。
        1. 支持多维度定位：可通过名称或 GUID 执行删除。
        2. 强制安全防护：默认触发确认提示，支持 -WhatIf 模拟删除。
        3. 管道集成：支持接收来自 Get-Recipe 或 Invoke-RecipeUI 的对象直接删除。
    .PARAMETER Name
        菜谱名称。
    .PARAMETER ID
        菜谱的唯一标识符 (GUID)。
    .EXAMPLE
        PS> Remove-Recipe -Name "鱼香肉丝"
        通过名称删除。
    .EXAMPLE
        PS> Invoke-RecipeUI | Remove-Recipe
        图形化选择并删除（终极工作流）。
    #>
    [CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact = 'High')]
    param(
        [Parameter(Mandatory = $true, ParameterSetName = 'ByName', ValueFromPipeline = $true, ValueFromPipelineByPropertyName = $true)]
        [string]$Name,

        [Parameter(Mandatory = $true, ParameterSetName = 'ById', ValueFromPipelineByPropertyName = $true)]
        [string]$ID
    )

    process {
        try {
            # 1. 加载全量数据
            [array]$AllRecipes = Invoke-DataProvider -Load -ErrorAction Stop
            
            # 2. 定位目标
            $Target = if ($ID) {
                $AllRecipes | Where-Object { $_.ID -eq $ID }
            }
            else {
                $AllRecipes | Where-Object { $_.Name -eq $Name }
            }

            # 3. 容错：如果目标不存在
            if (-not $Target) {
                Write-Warning "[删除拦截] 未找到匹配的菜谱 [$($Name)$($ID)]，系统状态未变更。"
                return
            }

            # 4. 安全确认与执行
            $ActionDesc = "从本地数据库永久移除菜谱: $($Target.Name) (ID: $($Target.ID))"
            if ($PSCmdlet.ShouldProcess($Target.Name, $ActionDesc)) {
                
                # 执行过滤操作，保留除目标以外的所有数据
                $NewData = $AllRecipes | Where-Object { $_.ID -ne $Target.ID }
                
                # 写入持久层
                Invoke-DataProvider -SaveData $NewData -ErrorAction Stop
                
                Write-Host "`n🔥 [销毁成功] 菜谱《$($Target.Name)》已从系统中彻底移除。" -ForegroundColor Yellow
            }
        }
        catch {
            Write-Error "[删除失败] 执行物理销毁时发生异常。详情: $_"
        }
    }
}