function Set-Recipe {
    <#
    .SYNOPSIS
        修改并更新现有的菜谱信息 (SRE 容错级实现)。
    .DESCRIPTION
        基于 GuardianTree v3.0 标准。
        本函数严格遵循幂等性设计，支持 -WhatIf 破坏性预测。
        所有底层 IO 操作已委托给 Private 层的 Invoke-DataProvider。
    .PARAMETER Name
        要修改的菜谱名称（主键检索标识）。
    .PARAMETER Category
        新的分类标签。
    .PARAMETER Ingredients
        新的食材列表。
    .EXAMPLE
        PS> Set-Recipe -Name "番茄炒蛋" -Category "热菜" -WhatIf
        模拟修改菜谱分类，安全审计系统状态而不产生实际副作用。
    #>
    
    # [防线 1：沙盒预测] 声明支持 -WhatIf 与 -Confirm 护航
    [CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact = 'Medium')]
    param(
        # [防线 2：防御前置] 强制参数校验，拦截 Null 或空字符串注入
        [Parameter(Mandatory = $true, ValueFromPipeline = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$Name,

        [Parameter(Mandatory = $false)]
        [string]$Category,

        [Parameter(Mandatory = $false)]
        [string[]]$Ingredients,

        [Parameter(Mandatory = $false)]
        [string[]]$Steps
    )

    process {
        Write-Verbose "[SRE 轨迹] 接收到状态修改指令。目标载体: [$Name]"

        try {
            # 1. 委托给底层的统一接口加载数据。
            # [防线 3：非致命转致命] 使用 -ErrorAction Stop 逼迫底层异常抛出到此处的 Catch 块
            $AllRecipes = Invoke-DataProvider -Load -ErrorAction Stop

            # 2. 状态检索
            $TargetRecipe = $AllRecipes | Where-Object { $_.Name -eq $Name }
            
            # [防线 4：状态防御] 如果目标不存在，不要报错，而是优雅退出（幂等性的一种变体）
            if (-not $TargetRecipe) {
                Write-Warning "[SRE 拦截] 未在数据库中检索到菜谱 [$Name]，系统状态无需变更。"
                return
            }

            # 3. [核心：绝对幂等性校验]
            # 检查用户传入的数据是否与现有数据完全一致。如果一致，直接拒绝执行无效的磁盘 IO。
            $StateChanged = $false

            # $PSBoundParameters 是一个魔法变量，它记录了用户到底在命令行里输入了哪些参数
            if ($PSBoundParameters.ContainsKey('Category') -and ($TargetRecipe.Category -ne $Category)) {
                $AllowedCategories = @($script:RecipeEnums.Categories)
                if ($AllowedCategories.Count -gt 0 -and $AllowedCategories -notcontains $Category) {
                    throw "[策略违规] 分类 [$Category] 不在允许集合中。合法集合: $($AllowedCategories -join ', ')"
                }
                $TargetRecipe.Category = $Category
                $StateChanged = $true
            }
            if ($PSBoundParameters.ContainsKey('Ingredients')) {
                $TargetRecipe.Ingredients = $Ingredients
                $StateChanged = $true
            }
            if ($PSBoundParameters.ContainsKey('Steps')) {
                $TargetRecipe.Steps = $Steps
                $StateChanged = $true
            }

            if (-not $StateChanged) {
                Write-Verbose "[SRE 轨迹] 传入数据与当前系统状态一致，拒绝触发无效的 IO 覆盖动作。"
                return
            }

            # 4. [护航中心] 调用 ShouldProcess 进行 -WhatIf 判定
            # 如果用户输入了 -WhatIf，引擎会在这里自动拦截并输出预测结果，内部代码不会执行！
            if ($PSCmdlet.ShouldProcess("菜谱: $Name", "将状态更新写入持久层数据库")) {
                
                Write-Verbose "[SRE 轨迹] 正在将更新后的状态推送到 Private 算子..."

                # 保存前复用统一策略校验，避免写入非法状态
                Invoke-RecipeValidation -Recipe $TargetRecipe -ErrorAction Stop
                
                # 委托给底层完成最终的写入和备份
                Invoke-DataProvider -SaveData $AllRecipes -ErrorAction Stop
                
                Write-Host "✅ 菜谱 [$Name] 状态更新成功。" -ForegroundColor Green
            }
        }
        catch {
            # [防线 5：犯罪现场封锁] 捕获一切爆炸，并格式化为标准告警
            Write-Error "[SRE 致命告警] 在尝试更新菜谱 [$Name] 时发生终止型异常。`n错误实体: $($_.Exception.Message)`n调用栈: $($_.ScriptStackTrace)"
        }
        finally {
            # 释放上下文
            Write-Verbose "[SRE 轨迹] Set-Recipe 业务生命周期结束。"
        }
    }
}