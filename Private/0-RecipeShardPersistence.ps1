# 菜谱分片存储（Data/Recipes/{Category}/*.json）内部实现；必须在 Invoke-DataProvider 之前加载。

function Test-RecipeShardStorageConfigured {
    $rootRel = $script:RecipeConfig.Storage.RecipeRoot
    return -not [string]::IsNullOrWhiteSpace($rootRel)
}

function Get-RecipeShardRootAbsolute {
    if (-not (Test-RecipeShardStorageConfigured)) { return $null }
    Join-Path $script:ModuleRoot ([string]$script:RecipeConfig.Storage.RecipeRoot).Trim()
}

function Get-RecipeLegacyPathAbsolute {
    $rel = $script:RecipeConfig.Storage.RecipePath
    if ([string]::IsNullOrWhiteSpace($rel)) { return $null }
    Join-Path $script:ModuleRoot $rel.Trim()
}

function ConvertTo-RecipeFileSystemSegment {
    param(
        [AllowEmptyString()]
        [Alias('Text')]
        [string]$Segment,
        [string]$Default = 'item',
        [int]$MaxLength = 120
    )
    $invalid = [System.IO.Path]::GetInvalidFileNameChars()
    $s = if ([string]::IsNullOrWhiteSpace($Segment)) { $Default } else { $Segment.Trim() }
    foreach ($ch in $invalid) {
        $s = $s.Replace([string]$ch, '_')
    }
    $s = $s.Trim('.', ' ')
    if ([string]::IsNullOrWhiteSpace($s)) { $s = $Default }
    if ($s.Length -gt $MaxLength) { $s = $s.Substring(0, $MaxLength).TrimEnd('.', ' ') }
    $s
}

function Get-RecipeShardFileAbsolutePath {
    param(
        [Parameter(Mandatory = $true)]
        [object]$Recipe
    )
    $root = Get-RecipeShardRootAbsolute
    if (-not $root) { throw '[内部错误] RecipeRoot 未配置，无法解析分片路径。' }

    $cat = ConvertTo-RecipeFileSystemSegment -Segment ([string]$Recipe.Category) -Default 'uncategorized'
    $dir = Join-Path $root $cat
    $base = ConvertTo-RecipeFileSystemSegment -Segment ([string]$Recipe.Name) -Default 'recipe'
    $idNorm = ([string]$Recipe.ID) -replace '-', ''
    $id8 = if ($idNorm.Length -ge 8) { $idNorm.Substring(0, 8) } else { $idNorm.PadRight(8, '0') }

    $primary = Join-Path $dir "$base.json"
    if (-not (Test-Path -LiteralPath $primary)) {
        return $primary
    }
    try {
        $raw = Get-Content -LiteralPath $primary -Raw -Encoding UTF8 -ErrorAction Stop
        if ([string]::IsNullOrWhiteSpace($raw)) { return $primary }
        $existing = $raw | ConvertFrom-Json -ErrorAction Stop
        if ($null -ne $existing -and [string]$existing.ID -eq [string]$Recipe.ID) {
            return $primary
        }
    }
    catch {
        return (Join-Path $dir "${base}__${id8}.json")
    }
    $suffixPath = Join-Path $dir "${base}__${id8}.json"
    if (-not (Test-Path -LiteralPath $suffixPath)) { return $suffixPath }
    try {
        $raw2 = Get-Content -LiteralPath $suffixPath -Raw -Encoding UTF8 -ErrorAction Stop
        if ([string]::IsNullOrWhiteSpace($raw2)) { return $suffixPath }
        $ex2 = $raw2 | ConvertFrom-Json -ErrorAction Stop
        if ($null -ne $ex2 -and [string]$ex2.ID -eq [string]$Recipe.ID) {
            return $suffixPath
        }
    }
    catch { return $suffixPath }

    $fullId = ([string]$Recipe.ID) -replace '-', ''
    return (Join-Path $dir "${base}__${fullId}.json")
}

function Get-RecipeShardJsonFiles {
    param([string]$RootAbsolute)
    if (-not (Test-Path -LiteralPath $RootAbsolute)) { return @() }
    @(Get-ChildItem -LiteralPath $RootAbsolute -Recurse -Filter '*.json' -File -ErrorAction SilentlyContinue)
}

function Import-RecipeShardCollection {
    param([string]$RootAbsolute)
    $list = [System.Collections.Generic.List[object]]::new()
    foreach ($file in (Get-RecipeShardJsonFiles -RootAbsolute $RootAbsolute)) {
        try {
            $raw = Get-Content -LiteralPath $file.FullName -Raw -Encoding UTF8 -ErrorAction Stop
            if ([string]::IsNullOrWhiteSpace($raw)) { continue }
            $one = $raw | ConvertFrom-Json -ErrorAction Stop
            if ($null -eq $one) { continue }
            if ($one -is [System.Collections.IEnumerable] -and $one -isnot [string] -and $one -isnot [System.Collections.IDictionary]) {
                foreach ($row in @($one)) { if ($null -ne $row) { $list.Add($row) } }
            }
            else {
                $list.Add($one)
            }
        }
        catch {
            Write-Verbose "[RecipeShard] 跳过无法解析的文件: $($file.FullName) — $($_.Exception.Message)"
        }
    }
    if ($list.Count -eq 0) { return @() }
    return $list.ToArray()
}

function Import-RecipeLegacyCollection {
    param([string]$AbsolutePath)
    if (-not $AbsolutePath -or -not (Test-Path -LiteralPath $AbsolutePath)) { return @() }
    $RawJson = Get-Content -LiteralPath $AbsolutePath -Raw -Encoding UTF8 -ErrorAction Stop
    if ([string]::IsNullOrWhiteSpace($RawJson)) { return @() }
    $ParsedData = $RawJson | ConvertFrom-Json
    if ($ParsedData -is [array]) { return $ParsedData } else { return @($ParsedData) }
}

function Import-RecipeStorageCollection {
    if (Test-RecipeShardStorageConfigured) {
        $root = Get-RecipeShardRootAbsolute
        if ($root -and (Test-Path -LiteralPath $root)) {
            $files = Get-RecipeShardJsonFiles -RootAbsolute $root
            if ($files.Count -gt 0) {
                return (Import-RecipeShardCollection -RootAbsolute $root)
            }
        }
    }
    $legacy = Get-RecipeLegacyPathAbsolute
    return (Import-RecipeLegacyCollection -AbsolutePath $legacy)
}

function Export-RecipeShardCollection {
    param(
        [object[]]$SaveData
    )

    $root = Get-RecipeShardRootAbsolute
    if (-not $root) { throw '[致命故障] Storage.RecipeRoot 未配置，无法写入分片。' }

    if (-not (Test-Path -LiteralPath $root)) {
        New-Item -Path $root -ItemType Directory -Force | Out-Null
    }

    $backupEnabled = $false
    if ($null -ne $script:RecipeConfig.Storage.BackupEnabled) {
        $backupEnabled = [bool]$script:RecipeConfig.Storage.BackupEnabled
    }

    $diskIdToPath = @{}
    foreach ($file in (Get-RecipeShardJsonFiles -RootAbsolute $root)) {
        try {
            $raw = Get-Content -LiteralPath $file.FullName -Raw -Encoding UTF8 -ErrorAction Stop
            if ([string]::IsNullOrWhiteSpace($raw)) { continue }
            $obj = $raw | ConvertFrom-Json -ErrorAction Stop
            if ($null -eq $obj -or [string]::IsNullOrWhiteSpace([string]$obj.ID)) { continue }
            $diskIdToPath[[string]$obj.ID] = $file.FullName
        }
        catch { }
    }

    $desiredIdToPath = @{}
    $recipes = @()
    if ($null -ne $SaveData) { $recipes = @($SaveData | ForEach-Object { $_ }) }
    foreach ($r in $recipes) {
        if ($null -eq $r -or [string]::IsNullOrWhiteSpace([string]$r.ID)) { continue }
        $desiredIdToPath[[string]$r.ID] = (Get-RecipeShardFileAbsolutePath -Recipe $r)
    }

    foreach ($path in $desiredIdToPath.Values | Select-Object -Unique) {
        $parent = Split-Path -Path $path -Parent
        if (-not (Test-Path -LiteralPath $parent)) {
            New-Item -Path $parent -ItemType Directory -Force | Out-Null
        }
    }

    foreach ($r in $recipes) {
        if ($null -eq $r -or [string]::IsNullOrWhiteSpace([string]$r.ID)) { continue }
        $targetPath = $desiredIdToPath[[string]$r.ID]
        if ($backupEnabled -and (Test-Path -LiteralPath $targetPath)) {
            Copy-Item -LiteralPath $targetPath -Destination "$targetPath.bak" -Force -ErrorAction SilentlyContinue
        }
        $tempPath = "$targetPath.tmp"
        $r | ConvertTo-Json -Depth 10 | Set-Content -LiteralPath $tempPath -Encoding UTF8 -ErrorAction Stop
        Move-Item -LiteralPath $tempPath -Destination $targetPath -Force -ErrorAction Stop
    }

    foreach ($entry in $diskIdToPath.GetEnumerator()) {
        $id = $entry.Key
        $oldPath = $entry.Value
        if (-not $desiredIdToPath.ContainsKey($id)) {
            if (Test-Path -LiteralPath $oldPath) {
                Remove-Item -LiteralPath $oldPath -Force -ErrorAction SilentlyContinue
            }
            continue
        }
        $newPath = $desiredIdToPath[$id]
        if ($oldPath -ne $newPath -and (Test-Path -LiteralPath $oldPath)) {
            Remove-Item -LiteralPath $oldPath -Force -ErrorAction SilentlyContinue
        }
    }
}

function Export-RecipeLegacyCollection {
    param(
        [object[]]$SaveData
    )
    $AbsolutePath = Get-RecipeLegacyPathAbsolute
    if (-not $AbsolutePath) { throw '[致命故障] Storage.RecipePath 未配置，无法写入单体文件。' }

    $ParentDir = Split-Path -Path $AbsolutePath -Parent
    if (-not (Test-Path -LiteralPath $ParentDir)) {
        New-Item -Path $ParentDir -ItemType Directory -Force | Out-Null
    }

    if ($script:RecipeConfig.Storage.BackupEnabled -and (Test-Path -LiteralPath $AbsolutePath)) {
        $BackupPath = "$AbsolutePath.bak"
        Copy-Item -LiteralPath $AbsolutePath -Destination $BackupPath -Force -ErrorAction Stop
    }

    $TempPath = "$AbsolutePath.tmp"
    $payload = if ($null -eq $SaveData) { @() } else { @($SaveData) }
    $payload | ConvertTo-Json -Depth 10 | Set-Content -LiteralPath $TempPath -Encoding UTF8 -ErrorAction Stop
    Move-Item -LiteralPath $TempPath -Destination $AbsolutePath -Force -ErrorAction Stop
}

function Test-RecipeUseShardPersistence {
    Test-RecipeShardStorageConfigured
}
