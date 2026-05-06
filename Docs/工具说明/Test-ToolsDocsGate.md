# Test-ToolsDocsGate.ps1

对应仓库脚本：**`Tools/Test-ToolsDocsGate.ps1`**。

## 用途

**工具脚本说明文档门禁**：确保每个 **`Tools/*.ps1`** 在 **`Docs/工具说明/`** 下存在同名 **`*.md`**，且 Markdown **非空**且正文至少包含一次 **脚本基名**（与 `Migrate-RecipesToShardStorage.ps1` 等脚本文档约定一致）。

## 用法

在仓库根目录：

```powershell
pwsh Tools/Test-ToolsDocsGate.ps1
```

默认约定：**`Tools/<Name>.ps1`** ↔ **`Docs/工具说明/<Name>.md`**。可通过 **`-ToolsRelativePath`**、**`-DocsToolsRelativeDir`** 覆盖（一般无需修改）。

## CI

由 **Quality** 工作流在 Pester、变更日志门禁、目录命名门禁之后运行；每次推送/PR 均扫描当前检出树，无需 git diff。

## 本地 pre-commit

仓库 **`.githooks/pre-commit`** 在有暂存变更时，按 **`.github/workflows/quality.yml`** 相同顺序执行：

1. **Pester**（若本机尚无 **Pester 5+** 则 `Install-Module Pester`；否则直接 **`Import-Module Pester`**，再 **`Import-Module RecipeManager`** + **`Invoke-Pester ... -CI`**）
2. **`Test-ChangelogGate.ps1 -StagedIndex`**
3. **`Test-DirectoryNamingGate.ps1 -RootRelativePath Docs -StagedIndex`**
4. **`Test-ToolsDocsGate.ps1`**（本脚本）

随后若暂存区含 **`Docs/菜谱/**/*.md`**，仍会 **`Sync-RecipeDocs`** 并 **`git add`** 索引与分片（与原先行为一致）。

启用钩子路径：

```powershell
git config core.hooksPath .githooks
```

**跳过（不推荐）**

| 环境变量 | 作用 |
|----------|------|
| **`RECIPEMANAGER_SKIP_PRECOMMIT_CI_CHECKS=1`** | 跳过上述 1～4 步（仅保留菜谱同步逻辑） |
| **`RECIPEMANAGER_SKIP_PRECOMMIT_PESTER=1`** | 仅跳过 Pester |
| **`RECIPEMANAGER_SKIP_PRECOMMIT_CHANGELOG_GATE=1`** | 仅跳过变更日志门禁 |
| **`RECIPEMANAGER_SKIP_PRECOMMIT_DIRECTORY_NAMING_GATE=1`** | 仅跳过目录命名门禁 |
| **`RECIPEMANAGER_SKIP_PRECOMMIT_TOOLS_DOC_GATE=1`** | 仅跳过本脚本 |
