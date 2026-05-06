<#
.SYNOPSIS
    仓库内指定「父目录」下的一级子目录命名风格门禁：若本次变更在某根路径下引入此前不存在的子目录名，则须与 base 上该父目录下已有子目录的主流命名风格一致。

.DESCRIPTION
    - 通过 -RootRelativePath 指定一个或多个**相对于仓库根**的父路径（正斜杠、无首尾斜杠），例如 `Docs`、`Data/Recipes`。默认仅 `Docs`。
    - 仅检查各父路径下**一级子目录**（git ls-tree <ref>:<path> 中 tree 条目）。
    - 主流风格：在 base 上统计子目录名是否含 CJK 统一表意文字（\p{IsCJKUnifiedIdeographs}）；多数含 CJK 则要求新增名也含 CJK；反之亦然；平局按 CJK。
    - CI 与 Test-ChangelogGate 类似：GITHUB_EVENT_NAME、PR/push SHA；push 的 before 为全零时跳过。
    - 本地默认工作区对比 BaseRef（含未跟踪）；-CommitRange 用于双提交区间。

.PARAMETER RootRelativePath
    要检查的父目录（仓库相对路径）。可传多个；与 CI 中多次调用或传数组等价。

.PARAMETER BaseRef
    比较起点。

.PARAMETER HeadRef
    比较终点，默认 HEAD。

.PARAMETER CommitRange
    使用 git diff BaseRef HeadRef。
#>
[CmdletBinding()]
param(
    [Parameter(Position = 0)]
    [string[]]$RootRelativePath = @('Docs'),

    [string]$BaseRef,
    [string]$HeadRef = 'HEAD',
    [switch]$CommitRange
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Get-RepoRoot {
    return (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
}

function Get-DiffNameOnly {
    param([string]$Base, [string]$Head)
    if ([string]::IsNullOrWhiteSpace($Base) -or [string]::IsNullOrWhiteSpace($Head)) {
        return @()
    }
    $out = @(git diff --name-only "$Base" "$Head" 2>$null)
    if ($LASTEXITCODE -ne 0) {
        throw "[DirNamingGate] git diff 失败: $Base $Head"
    }
    return $out | ForEach-Object { ([string]$_).Replace('\', '/') }
}

function Test-DirNameContainsCjk {
    param([string]$Name)
    return [regex]::IsMatch($Name, '\p{IsCJKUnifiedIdeographs}')
}

function Get-PeerNamingStyleFromDirNames {
    <#
    .OUTPUTS
        'Cjk' | 'Ascii' | $null
    #>
    param([string[]]$PeerDirNames)
    $list = @($PeerDirNames | Where-Object { -not [string]::IsNullOrWhiteSpace($_) } | Select-Object -Unique)
    if ($list.Count -eq 0) {
        return $null
    }
    $cjk = 0
    $ascii = 0
    foreach ($n in $list) {
        if (Test-DirNameContainsCjk -Name $n) { $cjk++ }
        else { $ascii++ }
    }
    if ($cjk -gt $ascii) { return 'Cjk' }
    if ($ascii -gt $cjk) { return 'Ascii' }
    return 'Cjk'
}

function Test-PeerDirNameMeetsStyle {
    param(
        [string]$Name,
        [ValidateSet('Cjk', 'Ascii')]
        [string]$RequiredStyle
    )
    $has = Test-DirNameContainsCjk -Name $Name
    if ($RequiredStyle -eq 'Cjk') {
        return $has
    }
    return -not $has
}

function Normalize-RootRelativePaths {
    param([string[]]$Paths)
    $out = [System.Collections.Generic.List[string]]::new()
    foreach ($raw in $Paths) {
        if ([string]::IsNullOrWhiteSpace($raw)) { continue }
        $normInput = $raw.Trim().Replace('\', '/')
        if ($normInput -match '\.\.' -or $normInput.StartsWith('/')) {
            throw "[DirNamingGate] 非法 RootRelativePath: $raw（禁止 .. 与绝对路径）"
        }
        $p = $normInput.TrimStart('.', '/').TrimEnd('/')
        if ([string]::IsNullOrWhiteSpace($p)) { continue }
        if ($p -match '\.\.') {
            throw "[DirNamingGate] 非法 RootRelativePath: $raw（规范化后仍含 ..）"
        }
        if (-not $out.Contains($p)) {
            $out.Add($p) | Out-Null
        }
    }
    if ($out.Count -eq 0) {
        throw "[DirNamingGate] RootRelativePath 解析后为空。"
    }
    return @($out)
}

function Get-TreeSubdirectoryNamesAtRef {
    param(
        [string]$Ref,
        [string]$RootRelativePath
    )
    git rev-parse --verify "${Ref}:${RootRelativePath}" 2>$null | Out-Null
    if ($LASTEXITCODE -ne 0) {
        return @()
    }
    $lines = @(git ls-tree "${Ref}:${RootRelativePath}" 2>$null)
    if ($LASTEXITCODE -ne 0) {
        return @()
    }
    $names = foreach ($ln in $lines) {
        if ($ln -match '^\S+\s+tree\s+[0-9a-f]+\s+(.+)$') {
            $Matches[1].Trim()
        }
    }
    return @($names | Where-Object { $_ })
}

function Get-NewFirstSegmentNamesUnderRoot {
    param(
        [string[]]$ChangedPaths,
        [string[]]$BasePeerDirNames,
        [string]$RootRelativePath
    )
    $reRoot = [regex]::Escape($RootRelativePath)
    $pattern = "^$reRoot/([^/]+)/"
    $baseSet = [System.Collections.Generic.HashSet[string]]::new(
        [StringComparer]::Ordinal
    )
    foreach ($x in $BasePeerDirNames) {
        if (-not [string]::IsNullOrWhiteSpace($x)) {
            $null = $baseSet.Add($x)
        }
    }
    $candidates = [System.Collections.Generic.HashSet[string]]::new([StringComparer]::Ordinal)
    foreach ($p in $ChangedPaths) {
        if ([string]::IsNullOrWhiteSpace($p)) { continue }
        if ($p -notmatch $pattern) { continue }
        $seg = $Matches[1]
        if (-not $baseSet.Contains($seg)) {
            $null = $candidates.Add($seg)
        }
    }
    return @($candidates)
}

function Test-ChangedPathsTouchRoot {
    param(
        [string[]]$ChangedPaths,
        [string]$RootRelativePath
    )
    $prefix = "$RootRelativePath/"
    foreach ($p in $ChangedPaths) {
        if ($p -eq $RootRelativePath) { return $true }
        if ($p.StartsWith($prefix, [StringComparison]::Ordinal)) {
            return $true
        }
    }
    return $false
}

function Invoke-DirectoryNamingGateMain {
    $repoRoot = Get-RepoRoot
    Set-Location $repoRoot

    $roots = @(Normalize-RootRelativePaths -Paths $RootRelativePath)

    $inCi = ($env:GITHUB_ACTIONS -eq 'true')
    $base = $BaseRef
    $head = $HeadRef
    $useCommitRange = $false
    $rangeLabel = ''

    if ($inCi) {
        $CommitRange = $true
        $useCommitRange = $true
        $ev = $env:GITHUB_EVENT_NAME
        if ($ev -eq 'pull_request' -and -not [string]::IsNullOrWhiteSpace($env:PR_BASE_SHA) -and -not [string]::IsNullOrWhiteSpace($env:PR_HEAD_SHA)) {
            $base = $env:PR_BASE_SHA
            $head = $env:PR_HEAD_SHA
            $rangeLabel = "PR $base .. $head"
        }
        elseif ($ev -eq 'push' -and -not [string]::IsNullOrWhiteSpace($env:PUSH_BEFORE_SHA) -and -not [string]::IsNullOrWhiteSpace($env:PUSH_AFTER_SHA)) {
            $z = '0' * 40
            if ($env:PUSH_BEFORE_SHA -eq $z) {
                Write-Host "[DirNamingGate] push before 为全零，跳过门禁。"
                exit 0
            }
            $base = $env:PUSH_BEFORE_SHA
            $head = $env:PUSH_AFTER_SHA
            $rangeLabel = "push $base .. $head"
        }
        else {
            Write-Host "[DirNamingGate] CI 环境未识别到 PR/push SHA，跳过门禁。"
            exit 0
        }
    }
    elseif ($CommitRange) {
        $useCommitRange = $true
        if ([string]::IsNullOrWhiteSpace($base)) {
            $base = 'origin/main'
        }
        if ([string]::IsNullOrWhiteSpace($head)) {
            $head = 'HEAD'
        }
        $rangeLabel = "$base .. $head"
    }
    else {
        if ([string]::IsNullOrWhiteSpace($base)) {
            $base = 'origin/main'
        }
        git rev-parse --verify $base 2>$null | Out-Null
        if ($LASTEXITCODE -ne 0) {
            Write-Host "[DirNamingGate] 无法解析引用 $base，跳过门禁。"
            exit 0
        }
        $rangeLabel = "worktree vs $base"
    }

    [string[]]$names = @()
    if ($useCommitRange) {
        $names = @(Get-DiffNameOnly -Base $base -Head $head)
    }
    else {
        $tracked = @(git diff --name-only "$base" 2>$null)
        if ($LASTEXITCODE -ne 0) {
            throw "[DirNamingGate] git diff --name-only $base 失败"
        }
        $untracked = @(git ls-files --others --exclude-standard 2>$null)
        $names = @($tracked + $untracked | ForEach-Object { ([string]$_).Replace('\', '/') } | Select-Object -Unique)
    }

    if ($names.Count -eq 0) {
        Write-Host "[DirNamingGate] 无文件变更，跳过。（$rangeLabel）"
        exit 0
    }

    $anyRootChecked = $false
    foreach ($root in $roots) {
        if (-not (Test-ChangedPathsTouchRoot -ChangedPaths $names -RootRelativePath $root)) {
            continue
        }
        $anyRootChecked = $true

        $baseDirs = @(Get-TreeSubdirectoryNamesAtRef -Ref $base -RootRelativePath $root)
        $style = Get-PeerNamingStyleFromDirNames -PeerDirNames $baseDirs
        if ($null -eq $style) {
            Write-Host "[DirNamingGate] base 上 $root/ 无子目录，无法推断风格，跳过该根。（$rangeLabel）"
            continue
        }

        $newNames = @(Get-NewFirstSegmentNamesUnderRoot -ChangedPaths $names -BasePeerDirNames $baseDirs -RootRelativePath $root)
        if ($newNames.Count -eq 0) {
            Write-Host "[DirNamingGate] 根 $root ：未引入新的一级子目录，通过。（$rangeLabel）"
            continue
        }

        $bad = @()
        foreach ($n in $newNames) {
            if (-not (Test-PeerDirNameMeetsStyle -Name $n -RequiredStyle $style)) {
                $bad += $n
            }
        }

        if ($bad.Count -gt 0) {
            $need = if ($style -eq 'Cjk') {
                '名称中须包含至少一个 CJK 统一表意文字，以与该父目录下多数同级子目录一致'
            }
            else {
                '名称须为纯拉丁等风格（不得含 CJK 统一表意文字），以与多数同级子目录一致'
            }
            Write-Error @"
[DirNamingGate] 失败：根「$root」下，本 diff 中新增的一级子目录名与 base 主流风格（推断为: $style）不一致。
不符合项: $($bad -join ', ')
要求: $need
比较范围: $rangeLabel
"@
            exit 1
        }

        Write-Host "[DirNamingGate] 根 $root ：新增一级目录命名与推断风格 ($style) 一致，通过。（$rangeLabel）；新增项: $($newNames -join ', ')。"
    }

    if (-not $anyRootChecked) {
        Write-Host "[DirNamingGate] 变更未触及任一监控根路径 ($($roots -join ', '))，跳过。（$rangeLabel）"
    }

    exit 0
}

if ($MyInvocation.InvocationName -ne '.') {
    Invoke-DirectoryNamingGateMain
}
