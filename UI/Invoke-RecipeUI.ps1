function Invoke-RecipeUI {
    <#
    .SYNOPSIS
        启动图形化菜谱管理控制台 (全中文人性化界面)。
    .DESCRIPTION
        基于 GuardianTree v3.0 标准。执行严格的业务级视图投影：
        1. 消除技术噪音：隐藏 GUID、简码及原始变量名。
        2. 语境对齐：将字段名改为正式的中文业务术语，并添加计量单位。
        3. 逻辑映射：维持后台序号回溯机制，确保数据处理的精准性。
    #>
    [CmdletBinding()]
    param(
        [Parameter(Position = 0)]
        [string]$SearchKeyword
    )

    process {
        Write-Verbose "[UI 引擎] 正在通过契约层调取底层数据流..."
        
        # 1. 获取原始域模型数据 (Domain Model)
        $RawData = if ($SearchKeyword) { Get-Recipe -Name $SearchKeyword } else { Get-Recipe }

        if (-not $RawData) {
            Write-Warning "🍽️ 当前菜谱库为空，或未匹配到检索结果。"
            return
        }

        # 确保数据为数组格式，防止单条数据时索引失效
        $RawData = @($RawData)

        Write-Verbose "[UI 引擎] 执行人性化视图投影：统一业务语境..."

        # 2. 视图投影 (View Projection)：构建纯中文展示模型
        $Counter = 1
        $DisplayData = $RawData | ForEach-Object {
            # 食材配比扁平化处理：将 [对象数组] 转换为 [人性化字符串]
            $IngredientStr = if ($_.Ingredients) {
                ($_.Ingredients | ForEach-Object { "$($_.Item) ($($_.Amount))" }) -join " | "
            }
            else { "（未录入）" }

            # 标签美化：使用中文标点符号分隔
            $TagStr = if ($_.Tags) { $_.Tags -join "、" } else { "（无）" }

            # [核心完善]：定义全中文业务视图，添加单位后缀
            [PSCustomObject]@{
                "编号"   = $Counter++           # 后台回溯锚点
                "菜谱名称" = $_.Name
                "所属分类" = $_.Category
                "烹饪耗时" = "$($_.PrepTime) 分钟" # 增强可读性，添加单位
                "食材清单" = $IngredientStr
                "检索标签" = $TagStr
            }
        }

        # 3. 调起渲染容器
        Write-Verbose "[UI 引擎] 唤醒图形化交互窗口..."
        
        # 统一标题语境
        $WindowTitle = "守望者熔炉 - 菜谱管理中心 (当前已加载 $($DisplayData.Count) 项数据)"
        
        # 调起系统原生表格
        $Selection = $DisplayData | Out-GridView -Title $WindowTitle -PassThru

        # 4. 索引回溯映射 (Back-Tracking)
        if ($Selection) {
            # 基于“编号”还原原始对象的数组下标
            $SelectedIndex = $Selection.编号 - 1
            $ActualObject = $RawData[$SelectedIndex]

            Write-Host "`n[用户交互] 成功锁定菜谱：$($ActualObject.Name)" -ForegroundColor Green
            Write-Verbose "[后台追踪] 原始 ID 为: $($ActualObject.ID)"
            
            # 最终返回的是完整的、带 ID 的原始对象
            return $ActualObject
        }
        else {
            Write-Verbose "[用户交互] 窗口已关闭，未执行任何选择。"
        }
    }
}