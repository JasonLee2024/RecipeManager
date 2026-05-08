# 更新日志

本文档记录本项目的重要变更。

与菜谱文档、分片数据或模块核心代码同批变更时，请同步更新本文件。CI 在 `.github/workflows/quality.yml` 中运行 Pester、本门禁、`Tools/Test-DirectoryNamingGate.ps1`（默认监控 `Docs`）与 **`Tools/Test-ToolsDocsGate.ps1`**（`Tools/*.ps1` 与 **`Docs/工具说明/*.md`** 对齐）。启用 **`.githooks`** 后，本地 **`git commit`**（有暂存时）按 **Quality** 同源顺序运行上述检查（变更日志与目录命名使用 **`-StagedIndex`**，见 **`Docs/工具说明/Test-ToolsDocsGate.md`**）。本地可执行：`pwsh Tools/Test-ChangelogGate.ps1`（默认对比 `origin/main` 与当前工作区，含未跟踪文件）；核对上一笔提交请使用 `-CommitRange`，例如 `-BaseRef HEAD~1 -HeadRef HEAD`。

## v1.2.11 - 2026-05-08

### 新增
- **专题：土豆肉丝三做法**（`Docs/菜谱/炒菜/专题/专题_土豆肉丝三做法.md` / `Data/Recipes/炒菜/专题_土豆肉丝三做法.json`）：青椒清淡版、酸辣版、红烧家常版步骤与通用技巧；文档注明地域归属不唯一故不单列菜系标签。`Docs/CategoryDocIndex.json` 已随 `Sync-RecipeDocs` 更新。

## v1.2.10 - 2026-05-06

### 变更
- **红烧鲈鱼**（`Docs/菜谱/炒菜/鱼鲜/红烧鲈鱼.md` / `Data/Recipes/炒菜/红烧鲈鱼.json`）：补充「拍粉用干粉还是湿粉」完整问答、干拍粉步骤与淀粉/面粉取舍；`ServingNote` 与文述对齐。

## v1.2.9 - 2026-05-06

### 工程与质量
- **pre-commit**：仅在检测到本机未安装 **Pester 5+** 时执行 **`Install-Module Pester`**；已安装则直接 **`Import-Module`**，缩短日常提交耗时。

## v1.2.8 - 2026-05-06

### 工程与质量
- **`Test-ChangelogGate.ps1` / `Test-DirectoryNamingGate.ps1`**：新增 **`-StagedIndex`**（`git write-tree` 与基准比较），供 pre-commit 只对「即将提交」的暂存区做门禁。
- **`.githooks/pre-commit.ps1`**：与 CI 一致依次运行 Pester、变更日志门禁、**`Docs`** 目录命名门禁、`Test-ToolsDocsGate`；可用 **`RECIPEMANAGER_SKIP_PRECOMMIT_CI_CHECKS`** 等环境变量跳过（见 **`Docs/工具说明/Test-ToolsDocsGate.md`**）。

## v1.2.7 - 2026-05-06

### 工程与质量
- **`.githooks/pre-commit`**：存在暂存变更时先于菜谱同步执行 **`Tools/Test-ToolsDocsGate.ps1`**（与 CI 同源）；可通过 **`RECIPEMANAGER_SKIP_PRECOMMIT_TOOLS_DOC_GATE=1`** 单次跳过。

## v1.2.6 - 2026-05-06

### 新增
- **`Docs/工具说明/`**：与 `Tools/*.ps1` 一一对应的维护说明（含 **`00_总览.md`**）。
- **`Tools/Test-ToolsDocsGate.ps1`**：CI 与本地校验「每个 `Tools/*.ps1` 必有 `Docs/工具说明/<同名>.md` 且正文提及脚本基名」。

### 工程与质量
- **Quality** 工作流增加 **Tools script documentation gate**；变更日志门禁触发列表补充 `Tools/Test-ToolsDocsGate.ps1` 与 `Docs/工具说明/`。

## v1.2.5 - 2026-05-06

### 工程与质量
- **一级子目录命名门禁泛化**：`Tools/Test-DirectoryNamingGate.ps1` 取代 `Tools/Test-DocsDirectoryNamingGate.ps1`，通过 **`-RootRelativePath`** 指定仓库内任意父路径（可多个；禁止 `..`）。CI 调用 `-RootRelativePath Docs`；若需同时约束 `Data/Recipes` 等，可在工作流中追加参数或第二步调用。

## v1.2.4 - 2026-05-06

### 新增
- **上海青**系列：清炒、蒜蓉蚝油、香菇、白灼、凉拌、油豆腐、腊肉及 `主食/焖饭/上海青菜饭`；专题 `专题_上海青家常与经典做法`。
- **葛根粉条**专题与菜谱：凉拌、杂锦炒、韩式杂菜、花蛤炒、粉条煲、豆角香肠炖、五花肉焖等（文档 + `Data/Recipes`）；`Config/IngredientTaxonomy.json` 增补 `上海青`、`菌菇/香菇`、`粉丝`、`葛根粉条`、`玉米淀粉`，`海鲜/鲈鱼`。
- **鱼鲜导航**：`Docs/菜谱/炒菜/鱼鲜/`、`Docs/菜谱/汤羹/鱼鲜/` 子目录，`DocCategories` 含 `炒菜/鱼鲜`、`汤羹/鱼鲜`（豆瓣鲫/鲤、红烧鲈鱼、带鱼、水煮鱼、花蛤炒粉条、鲮鱼猪骨汤等）。
- **红烧鲈鱼**（干拍粉煎制要点）及对应分片数据。
- **仓库卫生**：根目录 `.gitignore` 忽略 `*.bak`、`testResults.xml`；清理误生成的无 `专题_` 前缀重复菜谱 JSON。

### 变更
- 多份专题与家常菜谱 JSON 与文档路径、食材标签对齐（含 `Update-RecipeIngredientTags` / `Sync-RecipeDocs` 工作流结果）。

### 工程与质量
- **自动化质量门禁**：新增 `Tools/Test-ChangelogGate.ps1`（触及 `Docs/菜谱`、`Data/Recipes`、关键 `Config`、`Public`/`Private`、模块清单或本工作流时，要求同 diff 包含 `CHANGELOG.md`；并校验最新版节标题格式）。
- **`Docs/` 顶层目录命名门禁**：新增 `Tools/Test-DocsDirectoryNamingGate.ps1`（若 diff 引入此前不存在的 `Docs/<一级>/` 目录名，须与 base 上既有子目录的主流命名风格一致；含 CJK 与纯拉丁的多数决）。架构文档目录由 `Docs/Architecture` 更名为 **`Docs/架构说明`**，与同级的 `菜谱`、`配置说明` 等命名风格一致。
- GitHub Actions **Quality** 工作流：Windows 运行 Pester、变更日志门禁与上述 `Docs/` 命名门禁。

## v1.2.3 - 2026-05-03

### 新增
- 凉菜：`拍黄瓜`、`东北老虎菜`（文档与 `Data/Recipes/凉菜` 分片）。
- 凉菜专题：`专题_旱黄瓜与小黄瓜家常吃法总览`（生食凉拌、热炒与腌制思路导航，链向上述配方）。
- `Config/RecipeTaxonomy.json`：`CategoryHierarchy.凉菜` 补充 `拍黄瓜`、`东北老虎菜`。
- `Docs/CategoryDocIndex.json`：已随 `Sync-RecipeDocs` 重建（含 `凉菜/专题`）。

## v1.2.2 - 2026-04-27

### 新增
- 食材多级体系配置：`Config/IngredientTaxonomy.json`（支持任意深度 `食材/...` 路径标签）。
- 新公共命令 `Update-RecipeIngredientTags`：基于 `Ingredients.Item` 自动补齐菜谱 `Tags` 中的 `食材/...` 路径标签，支持 `-WhatIf` / `-PassThru`。
- 新增菜谱与拆分索引：
  - 苦瓜系列：`苦瓜去苦与经典做法`（索引）、`苦瓜炒鸡蛋`、`豆豉蒜蓉炒苦瓜`、`苦瓜酿肉`
  - 茄子系列：`茄子省油与经典做法`（索引）、`家常红烧茄子`、`肉末茄子煲`、`风味茄子`、`蒜香烤茄子`、`蒜泥手撕茄子`
  - 新增：`醋溜大白菜`

### 变更
- 分类与标签配置文件更名：`Config/Enums.json` -> `Config/RecipeTaxonomy.json`（并更新 `Settings.json` 的 `EnumsPath` 与相关文档引用）。
- 标签规范统一：
  - `经典` -> `经典菜`
  - `待客` -> `待客菜`
  - `减脂` -> `减脂菜`
  - `下饭` -> `下饭菜`
- 食材标签校验升级：`Invoke-RecipeValidation` 支持从 `IngredientTaxonomy` 自动展开允许集合并校验多级 `食材/...` 标签。
- 菜谱目录与索引更新：新增 `凉菜`、`烤菜` 分类；`凉拌苦瓜` 迁移至 `Docs/菜谱/凉菜/` 并同步数据与索引。

### 数据
- `Docs/CategoryDocIndex.json`：已随新增/迁移文档重建。
- 多个 `Data/Recipes/**.json`：同步补齐标签（含调味品路径标签）并完成标签命名统一。

## v1.2.1 - 2026-04-20

### 新增
- 菜谱可选字段 **`ServingNote`**（佐餐/搭配说明等自由文本，与 `Steps` 分离）；`Invoke-RecipeValidation` 对非空值校验长度（≤4000 字符），禁止仅空白。
- **`New-Recipe`**、**`Set-Recipe`** 增加可选参数 `-ServingNote`；`Set-Recipe` 传入空字符串可清除已保存的 `ServingNote`。

### 数据
- `Data/Recipes/蒸菜/五花肉蛋羹.json`、`粉蒸肉.json`：原写在 `Steps` 末条的佐餐说明已迁至 **`ServingNote`**。

## v1.2.0 - 2026-04-19

### 新增
- `Settings.json` 增加 `Storage.RecipeRoot`（默认 `Data/Recipes`），菜谱以「一级分类目录 + 每菜一 JSON」分片持久化；`Storage.RecipePath` 保留为历史单体文件路径与迁移入口。
- `Private/0-RecipeShardPersistence.ps1`：分片加载、按 ID 对齐的原子写入（`.tmp` + 替换）、改名/改类后的旧文件清理、文件名与目录段非法字符净化。
- 公共命令 `Migrate-RecipeStorage` 与 `Tools/Migrate-RecipesToShardStorage.ps1`：将单体 `Recipes.json` 写入分片并归档为 `Recipes.json.legacy.bak`。

### 变更
- `Invoke-DataProvider`：在已配置 `RecipeRoot` 时优先加载分片目录下所有 `.json`；若分片目录下尚无菜谱文件则回退读取 `RecipePath` 单体数组；保存时写入分片（全量对齐，删除已从库中移除的分片文件）。

### 备注
- 分片路径解析中避免使用与自动变量 `$Input` 冲突的参数名（曾导致路径退化为 `uncategorized/recipe.json`）。

## v1.1.0 - 2026-04-17

### 新增
- 新增 `Tests/RecipeManager.Tests.ps1`，补充查询行为与参数集用法的 Pester 回归测试。
- 在 `RecipeManager.psd1` 中补充显式模块元数据：`GUID`、`PowerShellVersion`、`Description`，以及显式 `FunctionsToExport` 列表。

### 变更
- 优化 `RecipeManager.psm1` 模块引导流程，增加配置缺失/解析失败的快速失败机制，并初始化模块根路径。
- 更新 `Invoke-DataProvider`，数据路径改为基于模块根目录解析，并采用临时文件替换方式提升写入安全性。
- 更新 `Set-Recipe`，分类校验改为基于运行时配置枚举，并在保存前统一执行 `Invoke-RecipeValidation`。
- 更新 `Remove-Recipe`，支持 `ByName` 与 `ById` 两种参数集。
- 更新 `Get-Recipe`，默认名称匹配改为子串模糊匹配（`-like`），并新增可选 `-Regex` 模式。

### 备注
- 优化前基线提交：`6ceb6cc`。
- 可靠性优化提交：`639fb85`。
