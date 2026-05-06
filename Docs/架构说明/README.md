# RecipeManager 模块架构说明（Architecture）

本文描述 **PowerShell 模块仓库的目录职责、启动顺序与数据流**，便于新贡献者建立心智模型。菜谱写法、配置字段细节仍以 `Docs/菜谱`、`Docs/配置说明` 为准。

## 1. 仓库顶层鸟瞰

| 路径 | 职责 |
|------|------|
| `RecipeManager.psd1` | 模块清单：版本、`FunctionsToExport`、元数据。 |
| `RecipeManager.psm1` | **引导入口**：读取 `Config/Settings.json` 及各类 `Config/*.json` / 数据路径，注入 `$script:` 作用域变量，再按顺序点源 `Private`、`Public`、`UI` 下的脚本，最后 `Export-ModuleMember`。 |
| `Config/` | 策略与词库：分类标签、地域菜系、技法、饮料与茶、面食、食材 taxonomy、工作流、药膳 schema 等（JSON 无注释，说明在 `Docs/配置说明`）。 |
| `Data/Recipes/` | 菜谱**分片**：`Data/Recipes/<一级 Category>/<菜名>.json`，一条菜谱一个文件。 |
| `Data/HerbalMaterials.json` 与 `Data/HerbalMaterials/` | 药膳药材数据（支持分片与 `index.json` 索引，见 `RecipeManager.psm1` 加载逻辑）。 |
| `Docs/` | 人类可读文档：菜谱 Markdown、配置说明、最佳实践、**`Docs/架构说明`（本目录）**、**`Docs/工具说明`（与 `Tools/*.ps1` 对应的维护脚本文档）**、以及机器生成的 `CategoryDocIndex.json`。 |
| `Public/` | 对外导出的命令实现（`.ps1`），如 `Get-Recipe`、`Set-Recipe`、`Sync-RecipeDocs` 等。 |
| `Private/` | 内部实现：如 `Invoke-RecipeValidation`、数据提供者等，不导出。 |
| `UI/` | 与交互界面相关的脚本（与 `Public` 一并导出函数名）。 |
| `Tests/` | Pester 回归测试。 |
| `Tools/` | 维护与 CI 辅助脚本（如 `Migrate-RecipesToShardStorage.ps1`、`Test-ChangelogGate.ps1`、`Test-DirectoryNamingGate.ps1`、`Test-ToolsDocsGate.ps1`）。 |
| `.github/workflows/` | GitHub Actions（质量门禁：Pester、变更日志、`Docs` 一级目录命名、**Tools 与 `Docs/工具说明` 文档对齐**）。 |
| `.githooks/` | 可选本地钩子：`pre-commit` 在有暂存变更时按 **Quality** 工作流顺序运行 **Pester**、**`Test-ChangelogGate -StagedIndex`**、**`Test-DirectoryNamingGate -RootRelativePath Docs -StagedIndex`**、**`Test-ToolsDocsGate`**，再对暂存的 **`Docs/菜谱/**/*.md`** 运行 **`Sync-RecipeDocs`**（需 `git config core.hooksPath .githooks`）。 |

## 2. 模块启动与脚本分层

`RecipeManager.psm1` 在 `Import-Module` 时执行，核心顺序为：

1. 设定 `$script:ModuleRoot`（模块根目录）。
2. 加载 **`Config/Settings.json`**，得到存储路径、各维度 JSON 路径引用、策略开关（如 `Policy.StrictValidation`）。
3. 依次加载 **`RecipeTaxonomy`**（原 Enums 路径可配置）、**`Noodles`**、**`Beverages`**、**`ChineseTea`**、**`RegionalCuisines`**、**`RegionalCuisineAliases`**、**`CookingTechniques`**、**`CookingWorkflow`**、**`PreparationByIngredientState`**、**`IngredientTaxonomy`**、**`HerbalMedicineSchema`** 等；失败即 **throw**，模块无法导入。
4. 加载 **`HerbalMaterials`**（优先分片目录与索引，否则单体 JSON）。
5. 可选加载 **`Docs/CategoryDocIndex.json`**（缺失不阻塞 CRUD）。
6. 校验烹饪技法别名映射指向合法标准技法集合。
7. **点源脚本**：`Get-ChildItem` 递归加载 **`Private/*.ps1`** → **`Public/*.ps1`** → **`UI/*.ps1`**（GuardianTree 式分层）。
8. **`Export-ModuleMember`**：导出 `Public` 与 `UI` 下各 `.ps1` 的 `BaseName` 作为函数名。

因此：**业务规则与校验**多在 `Private`；**用户可调用的 cmdlet** 在 `Public`（及 `UI`）。

## 3. 菜谱数据与文档的对应关系

- **权威结构化数据**：`Data/Recipes/<Category>/<Name>.json` 中的 `Name`、`Category`、`Ingredients`、`Steps`、`Tags` 等。
- **人类可读菜谱**：`Docs/菜谱/<Category>/.../<Name>.md`，可选「推荐分类 / 推荐标签」行文；与 JSON 通过 **`DocPath`**（仓库相对路径）与 **`DocCategories`**（由 `Docs/菜谱` 子目录推导，如 `炒菜/鱼鲜`）对齐。
- **索引**：`Sync-RecipeDocs` 扫描 `Docs/菜谱` 下 Markdown，重建 **`Docs/CategoryDocIndex.json`**，并为缺失 JSON 生成骨架或补齐 `DocPath` / `DocCategories` / 地域标签等。

更细的「配置与数据关系」见 **`Docs/配置说明/00_总览.md`**。

## 4. 校验与扩展点

- **`Invoke-RecipeValidation`**（`Private`）：在策略开启时校验分类、标签（含 `TagTaxonomy`、`IngredientTaxonomy` 展开路径、地域菜系）、可选 `Techniques`、`ServingNote` 等。
- **`Update-RecipeIngredientTags`**（`Public`）：按 `Ingredients.Item` 与 `IngredientTaxonomy` 幂等补齐 `Tags` 中的食材路径。
- **新增命令**：在 `Public/`（或 `UI/`）添加 `.ps1` 后，须在 **`RecipeManager.psd1`** 的 `FunctionsToExport` 中登记，否则不会导出。

## 5. 质量与自动化

### 5.1 总览

自动化质量门禁由 **GitHub Actions** 工作流 **`.github/workflows/quality.yml`**（工作流名 **Quality**）实现，在 **`push` 与 `pull_request` 指向 `main` 或 `master`** 时，在 **`windows-latest`** 上使用 **`pwsh`** 顺序执行四步：**Pester 回归**、**变更日志门禁**、**一级子目录命名门禁**（**`Tools/Test-DirectoryNamingGate.ps1`**，CI 传入 **`-RootRelativePath Docs`**）、**工具脚本说明文档门禁**（**`Tools/Test-ToolsDocsGate.ps1`**，要求每个 **`Tools/*.ps1`** 对应 **`Docs/工具说明/<同名>.md`**）。根目录 **`CHANGELOG.md`** 记录面向使用者的版本级重要变更。

### 5.2 第一步：Pester 回归

1. `Install-Module Pester`（满足最低版本要求）。
2. `Import-Module ./RecipeManager.psd1 -Force`。
3. `Invoke-Pester ./Tests/RecipeManager.Tests.ps1 -CI`。

任一条测试失败则该 job 失败，与本地对同一测试文件的执行方式一致。

### 5.3 第二步：变更日志门禁（`Tools/Test-ChangelogGate.ps1`）

**检出**：`actions/checkout@v4` 使用 **`fetch-depth: 0`**，保证 `git diff` 能访问足够历史。

**传给脚本的环境变量**（由工作流写入，脚本在 `GITHUB_ACTIONS=true` 时进入「CI 模式」）：

| 变量 | 含义 |
|------|------|
| `GITHUB_EVENT_NAME` | `pull_request` 或 `push` 等。 |
| `PR_BASE_SHA` / `PR_HEAD_SHA` | PR 的 base / head 提交 SHA。 |
| `PUSH_BEFORE_SHA` / `PUSH_AFTER_SHA` | 推送前、推送后的提交 SHA。 |

**比较方式（CI）**：对 `pull_request` 使用 **PR base 与 head** 做一次 **`git diff --name-only`**；对 `push` 使用 **before 与 after**。若 **`PUSH_BEFORE_SHA` 为全零**（常见于新建分支首次推送等），脚本会**跳过**本门禁并直接通过，避免误杀。

**绑定规则**：若 diff 中出现的任一路径匹配脚本内 **`Test-TriggersChangelog`** 定义的前缀/文件（例如 `Docs/菜谱/`、`Data/Recipes/`、若干关键 `Config/*.json`、`Public/`、`Private/`、`RecipeManager.psd1` / `RecipeManager.psm1`、`Tests/RecipeManager.Tests.ps1`、`.github/workflows/`、`Tools/Test-ChangelogGate.ps1`、`CHANGELOG.md` 等；**完整列表以 `Tools/Test-ChangelogGate.ps1` 为准**），则要求 **同一次 diff 中必须包含 `CHANGELOG.md`**，否则脚本以**非零退出码**结束，job 失败。

**格式校验**：只要仓库中存在 **`CHANGELOG.md`**，脚本会校验其中至少有一行版本标题符合 **`## vX.Y.Z - YYYY-MM-DD`**（与是否触发「必须同批改 CHANGELOG」无关）。

**本地自检（与 CI 的差异）**：在**非 CI**环境下，默认用 **`git diff --name-only <base>`**（默认 `origin/main`）并合并 **未跟踪文件**；若要核对「上一笔提交」与当前 `HEAD` 的区间，请显式传入 **`-CommitRange`**，例如 `-BaseRef HEAD~1 -HeadRef HEAD`。详见脚本内注释。

### 5.4 第三步：一级子目录命名（`Tools/Test-DirectoryNamingGate.ps1`）

**目的**：对 **`-RootRelativePath`** 指定的每个仓库相对父路径（正斜杠、无首尾斜杠），在 base 提交上读取 **`git ls-tree <ref>:<路径>`** 中的 **一级子目录**（`tree` 条目），用子目录名是否含 **CJK 统一表意文字** `\p{IsCJKUnifiedIdeographs}` 做**多数决**推断主流风格；若本次 diff 在该父路径下出现**此前不存在的一级子目录名**，则新名须符合该风格（平局按含 CJK）。**默认参数为 `Docs`**，与同级的 `菜谱`、`配置说明` 等中文目录命名习惯对齐；也可传入 **`Data/Recipes`** 等路径以监控其它树（需在 CI 或本地显式增加参数；多根可传数组，例如 `-RootRelativePath Docs,Data/Recipes`）。

**比较范围与跳过条件**：与变更日志门禁相同（PR / push 的 SHA、`fetch-depth: 0`、push 的 `before` 为全零时跳过）；本地默认对比工作区与 `origin/main`（含未跟踪路径），可用 **`-CommitRange`**。若本次变更**未触及**任一监控根下的路径，则该根跳过；所有被触及的根均通过才整体成功。

**说明**：仅检查「**父路径 / 新增一级名 / …**」这一层；`RootRelativePath` 中禁止 `..` 与绝对路径。完整规则以脚本为准。

### 5.5 第四步：工具脚本与说明文档对齐（`Tools/Test-ToolsDocsGate.ps1`）

**目的**：保证 **`Tools/`** 目录下每个 **`.ps1`** 在 **`Docs/工具说明/`** 均有同名 **`.md`** 说明，且文档非空、正文至少包含一次脚本基名，避免「有脚本无文档」。索引与人类说明见 **`Docs/工具说明/00_总览.md`**。

**行为**：扫描当前工作区（与 CI 检出一致），**不依赖** git diff；新增脚本须同步新增对应 Markdown，否则推送失败。

**本地**：`pwsh Tools/Test-ToolsDocsGate.ps1`。

### 5.6 测试与验证状态

| 层级 | 说明 |
|------|------|
| **Pester** | 在仓库根目录执行 **`Invoke-Pester ./Tests/RecipeManager.Tests.ps1 -CI`**；含命名门禁与工具文档门禁**纯函数**用例（当前共 **55** 条测试）。 |
| **各门禁脚本** | 本地可执行 `Tools/Test-ChangelogGate.ps1`、`Tools/Test-DirectoryNamingGate.ps1`、`Tools/Test-ToolsDocsGate.ps1`；前两者在 CI 中与 PR/push SHA 联动，后者每次全量校验目录对齐。 |
| **GitHub Actions 整 job** | 是否在云端持续通过，以仓库 **Actions** 中 **Quality** 工作流的运行历史为准。 |

**结论**：脚本逻辑可在本地跑通；**端到端**以 **GitHub Actions** 实际结果为准。

## 6. 延伸阅读

- 文档总览与阅读顺序：`Docs/README.md`
- 新用户导读：`Docs/新手入门.md`
- 配置与数据总览：`Docs/配置说明/00_总览.md`
