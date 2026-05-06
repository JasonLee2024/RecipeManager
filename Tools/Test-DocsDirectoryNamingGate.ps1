<#
.SYNOPSIS
    Docs 顶层子目录命名风格门禁：若本次变更在 `Docs/<顶层>/` 下引入此前不存在的顶层目录名，则该名称须与变更前 `Docs/` 下已有子目录的「主流命名风格」一致。

.DESCRIPTION
    - 适用范围：仅 `Docs/` 下**一级子目录**（通过 `git ls-tree <ref>:Docs` 中 `tree` 类型条目识别）。
    - 主流风格：在 base 提交上统计各子目录名是否包含 CJK 统一表意文字（\p{IsCJKUnifiedIdeographs}）；含 CJK 的条目多于纯拉丁等条目时，要求新增名也含 CJK；反之亦然；平局时按含 CJK 处理。
    - CI 与 `Tools/Test-ChangelogGate.ps1` 类似：使用 GITHUB_EVENT_NAME 与 PR/push SHA；push 的 before 为全零时跳过。
    - 本地默认对比工作区与 BaseRef（含未跟踪路径）；可用 -CommitRange 核对提交区间。

.PARAMETER BaseRef
    比较起点；非 -CommitRange 时用于 git diff 的参照提交。

.PARAMETER HeadRef
    比较终点，默认 HEAD。

.PARAMETER CommitRange
    使用 git diff BaseRef HeadRef（与 CI 行为一致）。本地核对上一笔提交请加本开关。
#>
[CmdletBinding()]
param(
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
        throw "[DocsNamingGate] git diff 失败: $Base $Head"
    }
    return $out | ForEach-Object { ([string]$_).Replace('\', '/') }
}

function Test-DirNameContainsCjk {
    param([string]$Name)
    return [regex]::IsMatch($Name, '\p{IsCJKUnifiedIdeographs}')
}

function Get-DocsNamingStyleFromPeerDirNames {
    <#
    .OUTPUTS
        'Cjk' | 'Ascii' | $null（无同级目录可供推断时）
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

function Test-DocsTopLevelDirNameMeetsStyle {
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

function Get-DocsTreeSubdirectoryNamesAtRef {
    param([string]$Ref)
    git rev-parse --verify "${Ref}:Docs" 2>$null | Out-Null
    if ($LASTEXITCODE -ne 0) {
        return @()
    }
    $lines = @(git ls-tree "${Ref}:Docs" 2>$null)
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

function Get-NewDocsTopLevelDirNames {
    param(
        [string[]]$ChangedPaths,
        [string[]]$BasePeerDirNames
    )
    $baseSet = [System.Collections.Generic.HashSet[string]]::new(
        [string[]]$BasePeerDirNames,
        [StringComparer]::Ordinal
    )
    $candidates = [System.Collections.Generic.HashSet[string]]::new([StringComparer]::Ordinal)
    foreach ($p in $ChangedPaths) {
        if ([string]::IsNullOrWhiteSpace($p)) { continue }
        if ($p -notmatch '^Docs/([^/]+)/') { continue }
        $seg = $Matches[1]
        if (-not $baseSet.Contains($seg)) {
            $null = $candidates.Add($seg)
        }
    }
    return @($candidates)
}

function Invoke-DocsDirectoryNamingGateMain {
    $repoRoot = Get-RepoRoot
    Set-Location $repoRoot

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
                Write-Host "[DocsNamingGate] push before 为全零，跳过门禁。"
                exit 0
            }
            $base = $env:PUSH_BEFORE_SHA
            $head = $env:PUSH_AFTER_SHA
            $rangeLabel = "push $base .. $head"
        }
        else {
            Write-Host "[DocsNamingGate] CI 环境未识别到 PR/push SHA，跳过门禁。"
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
            Write-Host "[DocsNamingGate] 无法解析引用 $base，跳过门禁。"
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
            throw "[DocsNamingGate] git diff --name-only $base 失败"
        }
        $untracked = @(git ls-files --others --exclude-standard 2>$null)
        $names = @($tracked + $untracked | ForEach-Object { ([string]$_).Replace('\', '/') } | Select-Object -Unique)
    }

    if ($names.Count -eq 0) {
        Write-Host "[DocsNamingGate] 无文件变更，跳过。（$rangeLabel）"
        exit 0
    }

    $baseDirs = @(Get-DocsTreeSubdirectoryNamesAtRef -Ref $base)
    $style = Get-DocsNamingStyleFromPeerDirNames -PeerDirNames $baseDirs
    if ($null -eq $style) {
        Write-Host "[DocsNamingGate] base 上 Docs/ 无子目录，无法推断风格，跳过。（$rangeLabel）"
        exit 0
    }

    $newNames = @(Get-NewDocsTopLevelDirNames -ChangedPaths $names -BasePeerDirNames $baseDirs)
    if ($newNames.Count -eq 0) {
        Write-Host "[DocsNamingGate] 未引入新的 Docs/ 顶层子目录，通过。（$rangeLabel）"
        exit 0
    }

    $bad = @()
    foreach ($n in $newNames) {
        if (-not (Test-DocsTopLevelDirNameMeetsStyle -Name $n -RequiredStyle $style)) {
            $bad += $n
        }
    }

    if ($bad.Count -gt 0) {
        $need = if ($style -eq 'Cjk') { '名称中须包含至少一个 CJK 统一表意文字（与 `菜谱`、`配置说明` 等同级目录一致）' } else { '名称须为纯拉丁等风格（不得含 CJK 统一表意文字），以与多数同级目录一致' }
        Write-Error @"
[DocsNamingGate] 失败：以下为本 diff 中新增的 Docs/ 一级子目录名，但与 base 上既有子目录的主流命名风格（推断为: $style）不一致。
不符合项: $($bad -join ', ')
要求: $need
比较范围: $rangeLabel
"@
        exit 1
    }

    Write-Host "[DocsNamingGate] 新增顶层目录命名与推断风格 ($style) 一致，通过。（$rangeLabel）；新增项: $($newNames -join ', ')。"
    exit 0
}

if ($MyInvocation.InvocationName -ne '.') {
    Invoke-DocsDirectoryNamingGateMain
}
