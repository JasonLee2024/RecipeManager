function New-Recipe {
    <#
    .SYNOPSIS
        向系统录入一条全新的菜谱记录。
    .DESCRIPTION
        基于 GuardianTree v3.0 标准。
        1. 自动生成系统级元数据：唯一标识符 (GUID) 及 创建时间。
        2. 强制执行策略审计：在写入磁盘前调用 Invoke-RecipeValidation 进行合规性检查。
        3. 幂等性防护：自动检测同名菜谱，防止数据重复。
    .PARAMETER PassThru
        如果指定此参数，函数将返回新创建的菜谱对象。
    #>
    [CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact = 'Medium')]
    param(
        [Parameter(Mandatory = $true, ValueFromPipelineByPropertyName = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$Name,

        [Parameter(Mandatory = $true)]
        [string]$Category,

        [Parameter(Mandatory = $false)]
        [int]$PrepTime = 10,

        [Parameter(Mandatory = $false)]
        [PSCustomObject[]]$Ingredients = @(),

        [Parameter(Mandatory = $false)]
        [string[]]$Steps = @(),

        [Parameter(Mandatory = $false)]
        [string[]]$Tags = @(),

        [Parameter(Mandatory = $false)]
        [switch]$PassThru
    )

    process {
        Write-Verbose "[业务引擎] 启动录入流程: 目标名称 [$Name]"

        try {
            # 1. 调取并强制数组化现有数据 (防止 $null 导致的增量失败)
            [array]$AllRecipes = Invoke-DataProvider -Load -ErrorAction Stop

            # 2. 幂等性碰撞检测 (Name 唯一性检查)
            if ($AllRecipes | Where-Object { $_.Name -eq $Name }) {
                throw "[业务冲突] 菜谱库中已存在同名记录 [$Name]，请勿重复录入。"
            }

            # 3. 构造数据实体 (Domain Model)
            $NewObject = [PSCustomObject]@{
                ID          = [guid]::NewGuid().ToString()
                Name        = $Name
                Category    = $Category
                PrepTime    = $PrepTime
                Ingredients = $Ingredients
                Steps       = $Steps
                Tags        = $Tags
                CreateTime  = (Get-Date -Format "yyyy-MM-dd HH:mm:ss")
            }

            # 4. 【安检拦截】
            # 注意：此处必须带上 -ErrorAction Stop 以确保策略违规时能被 Catch 块捕获
            Invoke-RecipeValidation -Recipe $NewObject -ErrorAction Stop

            # 5. 【原子化持久注入】
            $OperationDesc = "向本地 JSON 数据库写入新菜谱: $Name"
            if ($PSCmdlet.ShouldProcess("菜谱: $Name", $OperationDesc)) {
                
                Write-Verbose "[I/O 准备] 正在合并数据流并推送到持久层..."
                $AllRecipes += $NewObject
                Invoke-DataProvider -SaveData $AllRecipes -ErrorAction Stop
                
                Write-Host "`n✅ [成功] 菜谱《$Name》已存入系统库。" -ForegroundColor Green
                Write-Verbose "[系统生成] 分配 ID: $($NewObject.ID)"

                # 6. 支持流水线输出
                if ($PassThru) { return $NewObject }
            }
        }
        catch {
            # 统一异常处理逻辑：区分系统错误与策略违规
            $ErrorMessage = if ($_.Exception.Message) { $_.Exception.Message } else { $_.ToString() }
            Write-Error "[录入失败] 操作被拦截。`n原因: $ErrorMessage"
        }
    }
}