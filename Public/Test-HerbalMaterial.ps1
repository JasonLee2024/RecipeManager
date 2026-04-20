function Test-HerbalMaterial {
    <#
    .SYNOPSIS
        校验药材数据结构与关键枚举值。
    .DESCRIPTION
        基于模块已加载的 `HerbalMedicineSchema` 与 `HerbalMaterials` 执行基础校验，
        包括必填字段、关键对象存在性，以及部分中医药性枚举值合法性。
    .PARAMETER Name
        指定药材名（默认模糊匹配；配合 -Regex 使用正则）。
    .PARAMETER Regex
        启用 Name 的正则匹配。
    .PARAMETER Detailed
        返回逐条校验结果；默认返回汇总结果。
    .PARAMETER ExportCsv
        导出校验结果到 CSV 文件。建议与 -Detailed 搭配使用。
    .PARAMETER OpenCsv
        导出后自动用系统默认程序打开 CSV。必须与 -ExportCsv 同时使用。
    #>
    [CmdletBinding()]
    param(
        [Parameter()]
        [string]$Name,

        [Parameter()]
        [switch]$Regex,

        [Parameter()]
        [switch]$Detailed,

        [Parameter()]
        [string]$ExportCsv,

        [Parameter()]
        [switch]$OpenCsv
    )

    process {
        if ($null -eq $script:HerbalMedicineSchema) {
            throw "[致命故障] 药膳药材知识框架未加载。请执行 Import-Module -Force。"
        }
        if ($null -eq $script:HerbalMaterials) {
            throw "[致命故障] 药材数据未加载。请执行 Import-Module -Force。"
        }
        if ($OpenCsv -and [string]::IsNullOrWhiteSpace($ExportCsv)) {
            throw "[参数错误] 使用 -OpenCsv 时必须同时指定 -ExportCsv。"
        }

        $materials = @($script:HerbalMaterials)
        if (-not [string]::IsNullOrWhiteSpace($Name)) {
            if ($Regex) {
                $materials = @($materials | Where-Object { [string]$_.药材名 -match $Name })
            }
            else {
                $materials = @($materials | Where-Object { [string]$_.药材名 -like "*$Name*" })
            }
        }

        $schema = $script:HerbalMedicineSchema.HerbalMedicineSchema
        $validSources = @('植物', '动物', '矿物', '菌类')
        $validFourQi = @($schema.中医药性.四气)
        $validFiveTaste = @($schema.中医药性.五味)
        $validMeridian = @($schema.中医药性.归经)
        $validToxicity = @($schema.中医药性.毒性分级)

        $results = @()
        foreach ($m in $materials) {
            $errors = @()

            if ([string]::IsNullOrWhiteSpace([string]$m.药材名)) { $errors += '缺少必填字段：药材名' }
            if ([string]::IsNullOrWhiteSpace([string]$m.拉丁学名)) { $errors += '缺少必填字段：拉丁学名' }
            if ([string]::IsNullOrWhiteSpace([string]$m.来源)) { $errors += '缺少必填字段：来源' }
            if ([string]::IsNullOrWhiteSpace([string]$m.药用部位)) { $errors += '缺少必填字段：药用部位' }
            if ($null -eq $m.中医药性) { $errors += '缺少必填对象：中医药性' }
            if ($null -eq $m.功效主治) { $errors += '缺少必填对象：功效主治' }
            if ($null -eq $m.药膳应用) { $errors += '缺少必填对象：药膳应用' }

            if (-not [string]::IsNullOrWhiteSpace([string]$m.来源) -and ($validSources -notcontains [string]$m.来源)) {
                $errors += "来源非法：$($m.来源)"
            }

            if ($null -ne $m.中医药性) {
                foreach ($v in @($m.中医药性.四气)) {
                    if (-not [string]::IsNullOrWhiteSpace([string]$v) -and ($validFourQi -notcontains [string]$v)) {
                        $errors += "四气非法：$v"
                    }
                }
                foreach ($v in @($m.中医药性.五味)) {
                    if (-not [string]::IsNullOrWhiteSpace([string]$v) -and ($validFiveTaste -notcontains [string]$v)) {
                        $errors += "五味非法：$v"
                    }
                }
                foreach ($v in @($m.中医药性.归经)) {
                    if (-not [string]::IsNullOrWhiteSpace([string]$v) -and ($validMeridian -notcontains [string]$v)) {
                        $errors += "归经非法：$v"
                    }
                }
                if (-not [string]::IsNullOrWhiteSpace([string]$m.中医药性.毒性分级) -and ($validToxicity -notcontains [string]$m.中医药性.毒性分级)) {
                    $errors += "毒性分级非法：$($m.中医药性.毒性分级)"
                }
            }

            $results += [PSCustomObject]@{
                药材名 = [string]$m.药材名
                IsValid = ($errors.Count -eq 0)
                ErrorCount = $errors.Count
                Errors = @($errors)
            }
        }

        $output = if ($Detailed) {
            $results
        }
        else {
            [PSCustomObject]@{
                Total = @($results).Count
                Valid = @($results | Where-Object { $_.IsValid }).Count
                Invalid = @($results | Where-Object { -not $_.IsValid }).Count
                FailedMaterials = @($results | Where-Object { -not $_.IsValid } | Select-Object -ExpandProperty 药材名)
            }
        }

        if (-not [string]::IsNullOrWhiteSpace($ExportCsv)) {
            $csvParent = Split-Path -Path $ExportCsv -Parent
            if (-not [string]::IsNullOrWhiteSpace($csvParent) -and -not (Test-Path $csvParent)) {
                New-Item -Path $csvParent -ItemType Directory -Force | Out-Null
            }
            @($output) | Export-Csv -Path $ExportCsv -NoTypeInformation -Encoding UTF8
            if ($OpenCsv) {
                Start-Process -FilePath $ExportCsv | Out-Null
            }
        }

        return $output
    }
}

