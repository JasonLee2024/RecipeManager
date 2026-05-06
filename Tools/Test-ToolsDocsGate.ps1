<#
.SYNOPSIS
    工具脚本说明文档门禁：要求仓库内每个 Tools/*.ps1 在 Docs/工具说明/ 下存在同名 Markdown 说明，且正文须至少提及脚本基名。

.DESCRIPTION
    - 约定：`Tools/<Name>.ps1` 对应 `Docs/工具说明/<Name>.md`（一级 Tools 目录，不含子目录）。
    - 校验：文件存在、非空白、内容包含脚本基名（避免占位空文档）。
    - 在 CI 与本地均扫描当前工作区（检出树）；无需 git diff。
    - 新增维护脚本时请同时增加对应说明文档，否则本门禁失败。

.PARAMETER ToolsRelativePath
    工具脚本目录（相对仓库根），默认 Tools。

.PARAMETER DocsToolsRelativeDir
    说明文档所在目录（相对仓库根），默认 Docs/工具说明。
#>
[CmdletBinding()]
param(
    [string]$ToolsRelativePath = 'Tools',
    [string]$DocsToolsRelativeDir = 'Docs/工具说明'
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Get-RepoRoot {
    return (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
}

function Get-ToolsPs1Basenames {
    param([string]$ToolsDirectoryAbsolutePath)
    if (-not (Test-Path -LiteralPath $ToolsDirectoryAbsolutePath)) {
        throw "[ToolsDocsGate] 未找到工具目录: $ToolsDirectoryAbsolutePath"
    }
    return @(Get-ChildItem -LiteralPath $ToolsDirectoryAbsolutePath -Filter '*.ps1' -File | ForEach-Object { $_.BaseName })
}

function Get-ExpectedToolsDocRelativePath {
    param(
        [string]$ScriptBaseName,
        [string]$DocsToolsRelativeDir
    )
    $dir = $DocsToolsRelativeDir.Trim().TrimStart('.', '/').Replace('\', '/').TrimEnd('/')
    return "$dir/$ScriptBaseName.md"
}

function Test-ToolsDocBodyMentionsScript {
    param(
        [string]$MarkdownContent,
        [string]$ScriptBaseName
    )
    return $MarkdownContent.Contains($ScriptBaseName)
}

function Invoke-ToolsDocsGateMain {
    $repoRoot = Get-RepoRoot
    $toolsAbs = Join-Path $repoRoot $ToolsRelativePath
    $missing = [System.Collections.Generic.List[string]]::new()
    $emptyOrBad = [System.Collections.Generic.List[string]]::new()

    $basenames = @(Get-ToolsPs1Basenames -ToolsDirectoryAbsolutePath $toolsAbs)
    if ($basenames.Count -eq 0) {
        Write-Warning "[ToolsDocsGate] Tools 目录下未发现 .ps1，跳过。"
        exit 0
    }

    foreach ($bn in $basenames) {
        $rel = Get-ExpectedToolsDocRelativePath -ScriptBaseName $bn -DocsToolsRelativeDir $DocsToolsRelativeDir
        $segments = $rel -split '/' | Where-Object { $_ }
        $full = $repoRoot
        foreach ($seg in $segments) {
            $full = Join-Path $full $seg
        }

        if (-not (Test-Path -LiteralPath $full)) {
            $missing.Add($rel) | Out-Null
            continue
        }

        $raw = Get-Content -LiteralPath $full -Raw -Encoding UTF8
        if ([string]::IsNullOrWhiteSpace($raw)) {
            $emptyOrBad.Add("$rel（空白）") | Out-Null
            continue
        }
        if (-not (Test-ToolsDocBodyMentionsScript -MarkdownContent $raw -ScriptBaseName $bn)) {
            $emptyOrBad.Add("$rel（正文须至少包含脚本基名 $bn）") | Out-Null
        }
    }

    if ($missing.Count -gt 0 -or $emptyOrBad.Count -gt 0) {
        $msg = @(
            '[ToolsDocsGate] 失败：Tools 脚本与 Docs/工具说明 说明文档未对齐。',
            '缺失文件:',
            ($missing | ForEach-Object { "  - $_" }) -join "`n",
            '内容不合格:',
            ($emptyOrBad | ForEach-Object { "  - $_" }) -join "`n",
            ('约定: Tools 下每个 .ps1 须有「{0}/<脚本基名>.md」，且正文包含该基名。' -f $DocsToolsRelativeDir)
        ) -join "`n"
        Write-Error $msg
        exit 1
    }

    Write-Host "[ToolsDocsGate] 通过：$($basenames.Count) 个 Tools/*.ps1 均已对应说明文档。（$DocsToolsRelativeDir）"
    exit 0
}

if ($MyInvocation.InvocationName -ne '.') {
    Invoke-ToolsDocsGateMain
}
