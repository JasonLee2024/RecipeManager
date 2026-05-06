$ErrorActionPreference = 'Stop'

$repoRoot = Resolve-Path (Join-Path $PSScriptRoot '..')
Set-Location $repoRoot

$changedRows = @(git diff --cached --name-status --diff-filter=AR)
if ($changedRows.Count -eq 0) {
    exit 0
}

# 与 CI 中 Tools script documentation gate 相同：每个 Tools/*.ps1 须对应 Docs/工具说明/<同名>.md
if ($env:RECIPEMANAGER_SKIP_PRECOMMIT_TOOLS_DOC_GATE -ne '1') {
    $toolsDocGate = Join-Path $repoRoot 'Tools/Test-ToolsDocsGate.ps1'
    & $toolsDocGate
    if ($LASTEXITCODE -ne 0) {
        exit $LASTEXITCODE
    }
}

$docPaths = [System.Collections.Generic.List[string]]::new()
foreach ($row in $changedRows) {
    if ([string]::IsNullOrWhiteSpace($row)) { continue }
    $parts = @($row -split "`t")
    if ($parts.Count -lt 2) { continue }

    $status = $parts[0]
    $path = if ($status -like 'R*' -and $parts.Count -ge 3) { $parts[2] } else { $parts[1] }
    $normalized = ([string]$path).Replace('\', '/')
    if ($normalized -like 'Docs/菜谱/*.md' -or $normalized -like 'Docs/菜谱/**/*.md') {
        $docPaths.Add($normalized) | Out-Null
    }
}

if ($docPaths.Count -eq 0) {
    exit 0
}

Import-Module (Join-Path $repoRoot 'RecipeManager.psd1') -Force
Sync-RecipeDocs -DocPaths @($docPaths.ToArray()) | Out-Null

git add Docs/CategoryDocIndex.json
git add Data/Recipes

Write-Host "pre-commit: 已同步 Docs/菜谱 文档对应的菜谱 JSON。"
exit 0
