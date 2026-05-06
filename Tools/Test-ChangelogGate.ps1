<#
.SYNOPSIS
    变更日志质量门禁：在 CI 或本地比较两次提交之间，若触及菜谱/数据/核心模块路径，则要求 CHANGELOG.md 同期变更。

.DESCRIPTION
    - 触发路径：Docs/菜谱、Data/Recipes、关键 Config、Public、Private、模块清单等。
    - 若存在触发文件且 CHANGELOG.md 未出现在同一次 diff 中，以非零退出码失败。
    - 若 CHANGELOG.md 在仓库中存在，校验其首条版本标题格式：## vX.Y.Z - YYYY-MM-DD

.PARAMETER BaseRef
    比较起点（提交或引用）。默认由环境变量或 origin/main 推断。

.PARAMETER HeadRef
    比较终点，默认 HEAD。

.PARAMETER AllowMissingChangelog
    跳过「必须包含 CHANGELOG.md」检查（仅用于本地排障，CI 不应设置）。

.PARAMETER CommitRange
    使用「双提交」比较（git diff BaseRef HeadRef）。本地默认改为「工作区相对 BaseRef」（含未跟踪文件），与 CI 行为区分；需核对上一笔提交时请显式加本开关。
#>
[CmdletBinding()]
param(
    [string]$BaseRef,
    [string]$HeadRef = 'HEAD',
    [switch]$AllowMissingChangelog,
    [switch]$CommitRange
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Get-RepoRoot {
    $here = $PSScriptRoot
    return (Resolve-Path (Join-Path $here '..')).Path
}

function Get-DiffNameOnly {
    param([string]$Base, [string]$Head)
    if ([string]::IsNullOrWhiteSpace($Base) -or [string]::IsNullOrWhiteSpace($Head)) {
        return @()
    }
    $out = @(git diff --name-only "$Base" "$Head" 2>$null)
    if ($LASTEXITCODE -ne 0) {
        throw "[ChangelogGate] git diff 失败: $Base $Head"
    }
    return $out | ForEach-Object { ([string]$_).Replace('\', '/') }
}

function Test-TriggersChangelog {
    param([string[]]$Paths)
    $patterns = @(
        '^Docs/菜谱/',
        '^Data/Recipes/',
        '^Config/IngredientTaxonomy\.json$',
        '^Config/RecipeTaxonomy\.json$',
        '^Config/RegionalCuisines\.json$',
        '^Config/RegionalCuisineAliases\.json$',
        '^Config/CookingTechniques\.json$',
        '^Config/Settings\.json$',
        '^Config/Noodles\.json$',
        '^Config/Beverages\.json$',
        '^Config/ChineseTea\.json$',
        '^Config/Herbal',
        '^Config/Preparation',
        '^Public/',
        '^Private/',
        '^RecipeManager\.psd1$',
        '^RecipeManager\.psm1$',
        '^CHANGELOG\.md$',
        '^Tests/RecipeManager\.Tests\.ps1$',
        '^\.github/workflows/',
        '^Tools/Test-ChangelogGate\.ps1$'
    )
    foreach ($p in $Paths) {
        if ([string]::IsNullOrWhiteSpace($p)) { continue }
        foreach ($re in $patterns) {
            if ($p -match $re) {
                return $true
            }
        }
    }
    return $false
}

function Test-ChangelogHeaderFormat {
    param([string]$ChangelogPath)
    if (-not (Test-Path -LiteralPath $ChangelogPath)) {
        throw "[ChangelogGate] 未找到 $ChangelogPath"
    }
    $raw = Get-Content -LiteralPath $ChangelogPath -Raw -Encoding UTF8
    if ([string]::IsNullOrWhiteSpace($raw)) {
        throw "[ChangelogGate] CHANGELOG.md 为空"
    }
    foreach ($line in ($raw -split "`r?`n")) {
        $t = $line.Trim()
        if ($t -match '^##\s+v\d+\.\d+\.\d+\s+-\s+\d{4}-\d{2}-\d{2}\s*$') {
            return $true
        }
    }
    throw "[ChangelogGate] CHANGELOG.md 中未找到符合「## vX.Y.Z - YYYY-MM-DD」的版本标题（建议紧接在「# 更新日志」之下）"
}

$repoRoot = Get-RepoRoot
Set-Location $repoRoot

$inCi = ($env:GITHUB_ACTIONS -eq 'true')
$base = $BaseRef
$head = $HeadRef
$rangeLabel = ''

if ($inCi) {
    $CommitRange = $true
    $ev = $env:GITHUB_EVENT_NAME
    if ($ev -eq 'pull_request' -and -not [string]::IsNullOrWhiteSpace($env:PR_BASE_SHA) -and -not [string]::IsNullOrWhiteSpace($env:PR_HEAD_SHA)) {
        $base = $env:PR_BASE_SHA
        $head = $env:PR_HEAD_SHA
        $rangeLabel = "PR $base .. $head"
    }
    elseif ($ev -eq 'push' -and -not [string]::IsNullOrWhiteSpace($env:PUSH_BEFORE_SHA) -and -not [string]::IsNullOrWhiteSpace($env:PUSH_AFTER_SHA)) {
        $z = '0' * 40
        if ($env:PUSH_BEFORE_SHA -eq $z) {
            Write-Host "[ChangelogGate] push before 为全零，跳过门禁（多为新建分支首次推送）。"
            exit 0
        }
        $base = $env:PUSH_BEFORE_SHA
        $head = $env:PUSH_AFTER_SHA
        $rangeLabel = "push $base .. $head"
    }
    else {
        Write-Host "[ChangelogGate] CI 环境未识别到 PR/push SHA，跳过门禁。"
        exit 0
    }
}
elseif ($CommitRange) {
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
        Write-Host "[ChangelogGate] 无法解析引用 $base，跳过门禁。"
        exit 0
    }
    $rangeLabel = "worktree vs $base"
}

[string[]]$names = @()
if ($CommitRange) {
    $names = @(Get-DiffNameOnly -Base $base -Head $head)
}
else {
    $tracked = @(git diff --name-only "$base" 2>$null)
    if ($LASTEXITCODE -ne 0) {
        throw "[ChangelogGate] git diff --name-only $base 失败"
    }
    $untracked = @(git ls-files --others --exclude-standard 2>$null)
    $names = @($tracked + $untracked | ForEach-Object { ([string]$_).Replace('\', '/') } | Select-Object -Unique)
}

if ($names.Count -eq 0) {
    Write-Host "[ChangelogGate] 无文件变更，跳过。（$rangeLabel）"
    exit 0
}

$changelogPath = Join-Path $repoRoot 'CHANGELOG.md'
Test-ChangelogHeaderFormat -ChangelogPath $changelogPath | Out-Null

$needChangelog = Test-TriggersChangelog -Paths $names
if (-not $needChangelog) {
    Write-Host "[ChangelogGate] 变更未触及门禁路径，通过。"
    exit 0
}

$cl = 'CHANGELOG.md'
$hasChangelog = $names | Where-Object { $_ -eq $cl -or $_ -like "*/$cl" }
if ($hasChangelog) {
    Write-Host "[ChangelogGate] 已检测到 $cl 与菜谱/数据/模块变更同期修改，通过。"
    exit 0
}

if ($AllowMissingChangelog) {
    Write-Warning "[ChangelogGate] 已使用 -AllowMissingChangelog，跳过 CHANGELOG 同期检查。"
    exit 0
}

Write-Error @"
[ChangelogGate] 失败：以下路径变更要求同步更新根目录 CHANGELOG.md（加入新版本小节并简述变更）。
本次 diff 触及门禁路径，但未包含 CHANGELOG.md。
比较范围: $rangeLabel
变更文件数: $($names.Count)
"@
exit 1
