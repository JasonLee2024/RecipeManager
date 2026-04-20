function Migrate-RecipeStorage {
    <#
    .SYNOPSIS
        将单体 Storage.RecipePath 指向的 JSON 数组迁移为 Storage.RecipeRoot 下的分片文件。
    .DESCRIPTION
        若 RecipeRoot 下已存在 .json 分片且未指定 -Force，则拒绝执行。
        迁移完成后将原单体文件重命名为 .legacy.bak（目标已存在则先删除）。
    .PARAMETER Force
        在已存在分片时仍执行（按当前单体内容全量重写分片）。
    #>
    [CmdletBinding(SupportsShouldProcess = $true)]
    param(
        [switch]$Force
    )

    if (-not (Test-RecipeShardStorageConfigured)) {
        throw 'Settings.json 中未配置 Storage.RecipeRoot，无法执行分片迁移。'
    }

    $legacyPath = Get-RecipeLegacyPathAbsolute
    if (-not $legacyPath -or -not (Test-Path -LiteralPath $legacyPath)) {
        Write-Warning "未找到单体菜谱文件，跳过迁移: $legacyPath"
        return
    }

    $shardRoot = Get-RecipeShardRootAbsolute
    if ((Test-Path -LiteralPath $shardRoot) -and -not $Force) {
        $shardFiles = @(Get-ChildItem -LiteralPath $shardRoot -Recurse -Filter '*.json' -File -ErrorAction SilentlyContinue)
        if ($shardFiles.Count -gt 0) {
            Write-Warning "目录下已存在分片文件 ($($shardFiles.Count) 个)。若需重新迁移请使用 -Force。"
            return
        }
    }

    $raw = Get-Content -LiteralPath $legacyPath -Raw -Encoding UTF8
    if ([string]::IsNullOrWhiteSpace($raw)) {
        Write-Warning '单体菜谱文件为空，未写入任何分片。'
        return
    }

    $parsed = $raw | ConvertFrom-Json
    $recipes = if ($parsed -is [array]) { @($parsed) } else { @($parsed) }

    $op = "将 $($recipes.Count) 条菜谱写入分片目录并归档单体文件"
    if (-not $PSCmdlet.ShouldProcess($shardRoot, $op)) {
        return
    }

    Invoke-DataProvider -SaveData $recipes -ErrorAction Stop

    $backupPath = "$legacyPath.legacy.bak"
    if (Test-Path -LiteralPath $backupPath) {
        Remove-Item -LiteralPath $backupPath -Force -ErrorAction Stop
    }
    Move-Item -LiteralPath $legacyPath -Destination $backupPath -Force -ErrorAction Stop
    Write-Host "迁移完成。分片根目录: $shardRoot"
    Write-Host "原单体文件已归档为: $backupPath"
}
