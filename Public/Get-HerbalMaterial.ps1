function Get-HerbalMaterial {
    <#
    .SYNOPSIS
        查询药膳药材数据。
    .DESCRIPTION
        从 `Data/HerbalMaterials.json` 读取模块加载后的药材数据，支持名称模糊匹配、正则匹配与体质过滤。
    .PARAMETER Name
        按药材名模糊匹配（默认）或正则匹配（配合 -Regex）。
    .PARAMETER Regex
        启用 Name 的正则匹配模式。
    .PARAMETER Constitution
        按适宜体质过滤（匹配字段：药膳应用.适宜体质）。
    #>
    [CmdletBinding()]
    param(
        [Parameter()]
        [string]$Name,

        [Parameter()]
        [switch]$Regex,

        [Parameter()]
        [string]$Constitution
    )

    process {
        if ($null -eq $script:HerbalMaterials) {
            throw "[致命故障] 药材数据未加载。请执行 Import-Module -Force 重新初始化模块。"
        }

        $Result = @($script:HerbalMaterials)

        if (-not [string]::IsNullOrWhiteSpace($Name)) {
            if ($Regex) {
                $Result = @($Result | Where-Object { [string]$_.药材名 -match $Name })
            }
            else {
                $Result = @($Result | Where-Object { [string]$_.药材名 -like "*$Name*" })
            }
        }

        if (-not [string]::IsNullOrWhiteSpace($Constitution)) {
            $Result = @(
                $Result | Where-Object {
                    $Constitutions = @($_.药膳应用.适宜体质)
                    $Constitutions -contains $Constitution
                }
            )
        }

        return $Result
    }
}

