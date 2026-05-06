$ErrorActionPreference = 'Stop'

$repoRoot = Resolve-Path (Join-Path $PSScriptRoot '..')
Set-Location $repoRoot

$changedRows = @(git diff --cached --name-status --diff-filter=AR)
if ($changedRows.Count -eq 0) {
    exit 0
}

if ($env:RECIPEMANAGER_SKIP_PRECOMMIT_CI_CHECKS -eq '1') {
    Write-Host 'pre-commit: 已跳过 CI 同源检查（RECIPEMANAGER_SKIP_PRECOMMIT_CI_CHECKS=1）。'
}
else {
    # 与 .github/workflows/quality.yml 顺序一致（RecipeManager.psm1 仅在此处再次导入以供 Pester）

    if ($env:RECIPEMANAGER_SKIP_PRECOMMIT_PESTER -ne '1') {
        Install-Module Pester -Force -Scope CurrentUser -MinimumVersion 5.0
        Import-Module (Join-Path $repoRoot 'RecipeManager.psd1') -Force
        Invoke-Pester (Join-Path $repoRoot 'Tests/RecipeManager.Tests.ps1') -CI
        if ($LASTEXITCODE -ne 0) {
            exit $LASTEXITCODE
        }
    }

    if ($env:RECIPEMANAGER_SKIP_PRECOMMIT_CHANGELOG_GATE -ne '1') {
        & (Join-Path $repoRoot 'Tools/Test-ChangelogGate.ps1') -StagedIndex
        if ($LASTEXITCODE -ne 0) {
            exit $LASTEXITCODE
        }
    }

    if ($env:RECIPEMANAGER_SKIP_PRECOMMIT_DIRECTORY_NAMING_GATE -ne '1') {
        & (Join-Path $repoRoot 'Tools/Test-DirectoryNamingGate.ps1') -RootRelativePath Docs -StagedIndex
        if ($LASTEXITCODE -ne 0) {
            exit $LASTEXITCODE
        }
    }

    if ($env:RECIPEMANAGER_SKIP_PRECOMMIT_TOOLS_DOC_GATE -ne '1') {
        & (Join-Path $repoRoot 'Tools/Test-ToolsDocsGate.ps1')
        if ($LASTEXITCODE -ne 0) {
            exit $LASTEXITCODE
        }
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

Write-Host 'pre-commit: 已同步 Docs/菜谱 文档对应的菜谱 JSON。'
exit 0
