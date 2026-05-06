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
| `Docs/` | 人类可读文档：菜谱 Markdown、配置说明、最佳实践、**本架构目录**、以及机器生成的 `CategoryDocIndex.json`。 |
| `Public/` | 对外导出的命令实现（`.ps1`），如 `Get-Recipe`、`Set-Recipe`、`Sync-RecipeDocs` 等。 |
| `Private/` | 内部实现：如 `Invoke-RecipeValidation`、数据提供者等，不导出。 |
| `UI/` | 与交互界面相关的脚本（与 `Public` 一并导出函数名）。 |
| `Tests/` | Pester 回归测试。 |
| `Tools/` | 维护与 CI 辅助脚本（如 `Migrate-RecipesToShardStorage.ps1`、`Test-ChangelogGate.ps1`）。 |
| `.github/workflows/` | GitHub Actions（质量门禁：Pester + 变更日志检查）。 |
| `.githooks/` | 可选本地钩子（如提交前对 `Docs/菜谱` 触发 `Sync-RecipeDocs`）。 |

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

自动化质量门禁由 **GitHub Actions** 工作流 **`.github/workflows/quality.yml`**（工作流名 **Quality**）实现，在 **`push` 与 `pull_request` 指向 `main` 或 `master`** 时，在 **`windows-latest`** 上使用 **`pwsh`** 顺序执行两步：**Pester 回归**与**变更日志门禁**。根目录 **`CHANGELOG.md`** 记录面向使用者的版本级重要变更。

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

### 5.4 测试与验证状态

| 层级 | 说明 |
|------|------|
| **Pester** | 开发门禁时已多次在仓库根目录执行 **`Invoke-Pester ./Tests/RecipeManager.Tests.ps1`**（含与 CI 第一步等价的 `-CI` 流程），当前套件为 **44 条**测试；与 CI 第一步一致。 |
| **变更日志脚本** | 已在本地验证 **`Test-ChangelogGate.ps1`** 在「工作区相对 `origin/main`」及「双提交区间」等场景下的行为；逻辑与 CI 注入的环境变量分支一致。 |
| **GitHub Actions 整 job** | 工作流随代码进入仓库后，由 **GitHub Actions** 在云端执行；是否在**你们仓库**上持续通过，请在 GitHub 仓库页的 **Actions** 中查看 **Quality** 工作流的运行历史（依赖 Runner、网络、`Install-Module` 等，与本地环境仍可能有细微差别）。 |

**结论**：门禁中的 **Pester 与变更日志脚本逻辑已在本地按设计跑通**；**端到端是否在 GitHub 上始终绿灯**，以 **Actions 上的实际运行结果**为准。

## 6. 延伸阅读

- 文档总览与阅读顺序：`Docs/README.md`
- 新用户导读：`Docs/新手入门.md`
- 配置与数据总览：`Docs/配置说明/00_总览.md`
