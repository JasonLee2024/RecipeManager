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

仓库 **`.githooks/pre-commit`** 在有暂存变更时会调用本脚本（与 CI 同一校验）。请先启用钩子路径：

```powershell
git config core.hooksPath .githooks
```

单次提交若需跳过本检查（不推荐）：将环境变量 **`RECIPEMANAGER_SKIP_PRECOMMIT_TOOLS_DOC_GATE`** 设为 **`1`** 后再执行 **`git commit`**。
