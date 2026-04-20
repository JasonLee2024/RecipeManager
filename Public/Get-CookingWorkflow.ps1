function Get-CookingWorkflow {
    <#
    .SYNOPSIS
        获取中餐烹饪工作流（结构化 SOP）。
    .DESCRIPTION
        返回模块启动时加载的 `Config/CookingWorkflow.json` 内容，可按场景取对应工作流。
    .PARAMETER Name
        指定工作流名称键（如：GenericWokWorkflow、StirFriedRiceNoodles）。
        省略则返回完整工作流配置对象。
    .PARAMETER Section
        指定要提取的工作流维度（如：KPI、CriticalControlPoints、TemperatureGuidelines、ParallelizableSteps）。
        若仅指定 Section 且未指定 Name，则默认读取 GenericWokWorkflow。
    .PARAMETER AsTable
        将指定 Section 转为表格友好对象输出（适合接 `Format-Table`）。
        当前主要面向 KPI、CriticalControlPoints、ParallelizableSteps、TemperatureGuidelines。
    .PARAMETER ExportCsv
        将输出结果导出为 CSV 文件路径。
        建议与 -Section 搭配使用；若同时指定 -AsTable，将优先导出表格友好结构。
    .PARAMETER OpenCsv
        在导出 CSV 后，尝试用系统默认程序打开该文件。
        仅在同时指定 -ExportCsv 时有效。
    #>
    [CmdletBinding()]
    param(
        [Parameter()]
        [string]$Name,

        [Parameter()]
        [ValidateSet('PlatingTemplate', 'Timeline', 'WokOrder', 'TemperatureGuidelines', 'ParallelizableSteps', 'CriticalControlPoints', 'KPI', IgnoreCase = $true)]
        [string]$Section,

        [Parameter()]
        [switch]$AsTable,

        [Parameter()]
        [string]$ExportCsv,

        [Parameter()]
        [switch]$OpenCsv
    )

    process {
        if ($null -eq $script:CookingWorkflow) {
            throw "[致命故障] 烹饪工作流配置未加载。请执行 Import-Module -Force 重新初始化模块。"
        }

        if ([string]::IsNullOrWhiteSpace($Name) -and [string]::IsNullOrWhiteSpace($Section)) {
            if (-not [string]::IsNullOrWhiteSpace($ExportCsv)) {
                throw "[参数错误] 使用 -ExportCsv 时必须同时指定 -Section。"
            }
            if ($OpenCsv) {
                throw "[参数错误] 使用 -OpenCsv 时必须同时指定 -ExportCsv 与 -Section。"
            }
            return $script:CookingWorkflow
        }

        $Workflows = $script:CookingWorkflow.Workflows
        $TargetName = if (-not [string]::IsNullOrWhiteSpace($Name)) { $Name } else { 'GenericWokWorkflow' }
        if ($null -eq $Workflows -or $null -eq $Workflows.$TargetName) {
            $Available = if ($null -ne $Workflows) { $Workflows.PSObject.Properties.Name -join ', ' } else { '' }
            throw "[未找到] 工作流 [$TargetName] 不存在。可用列表: $Available"
        }

        $TargetWorkflow = $Workflows.$TargetName
        if ([string]::IsNullOrWhiteSpace($Section)) {
            if ($AsTable) {
                throw "[参数错误] 使用 -AsTable 时必须同时指定 -Section。"
            }
            if (-not [string]::IsNullOrWhiteSpace($ExportCsv)) {
                throw "[参数错误] 使用 -ExportCsv 时必须同时指定 -Section。"
            }
            if ($OpenCsv) {
                throw "[参数错误] 使用 -OpenCsv 时必须同时指定 -ExportCsv 与 -Section。"
            }
            return $TargetWorkflow
        }

        if ($OpenCsv -and [string]::IsNullOrWhiteSpace($ExportCsv)) {
            throw "[参数错误] 使用 -OpenCsv 时必须同时指定 -ExportCsv。"
        }

        if ($null -eq $TargetWorkflow.$Section) {
            throw "[未找到] 工作流 [$TargetName] 未定义分区 [$Section]。"
        }

        $Value = $TargetWorkflow.$Section
        $Output = if (-not $AsTable) {
            $Value
        }
        else {
            switch ($Section) {
                'KPI' {
                    @($Value) | ForEach-Object {
                        [PSCustomObject]@{
                            指标 = $_.Metric
                            家庭目标 = $_.HomeTarget
                            餐厅目标 = $_.RestaurantTarget
                            测量方法 = $_.Method
                        }
                    }
                }
                'CriticalControlPoints' {
                    @($Value) | ForEach-Object {
                        [PSCustomObject]@{
                            风险点 = $_.Risk
                            控制措施 = (@($_.Controls) -join '；')
                            纠偏行动 = (@($_.CorrectiveActions) -join '；')
                        }
                    }
                }
                'ParallelizableSteps' {
                    @($Value) | ForEach-Object {
                        [PSCustomObject]@{
                            阶段 = $_.Phase
                            可并行任务 = $_.Task
                            可并行对象 = $_.CanRunWith
                            约束 = $_.Constraint
                        }
                    }
                }
                'TemperatureGuidelines' {
                    $Value.PSObject.Properties | ForEach-Object {
                        [PSCustomObject]@{
                            项目 = $_.Name
                            阈值 = [string]$_.Value
                        }
                    }
                }
                default {
                    $Value
                }
            }
        }

        if (-not [string]::IsNullOrWhiteSpace($ExportCsv)) {
            $CsvParent = Split-Path -Path $ExportCsv -Parent
            if (-not [string]::IsNullOrWhiteSpace($CsvParent) -and -not (Test-Path $CsvParent)) {
                New-Item -Path $CsvParent -ItemType Directory -Force | Out-Null
            }
            @($Output) | Export-Csv -Path $ExportCsv -NoTypeInformation -Encoding UTF8
            if ($OpenCsv) {
                Start-Process -FilePath $ExportCsv | Out-Null
            }
        }

        return $Output
    }
}

