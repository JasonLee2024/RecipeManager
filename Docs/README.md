# RecipeManager 文档说明

## 本地加载模块：须用 PowerShell 7（`pwsh`）

本仓库中的 **RecipeManager** 模块在 **`RecipeManager.psd1`** 里声明了 **`PowerShellVersion = '7.0'`**，因此在本机执行 **`Import-Module RecipeManager`**（或 `Import-Module .\RecipeManager.psd1`）、**`Sync-RecipeDocs`**、**`Get-Recipe`** 等命令时，**必须使用 PowerShell 7 或更高版本**。

| 终端 | 能否加载本模块 |
|------|----------------|
| **PowerShell 7**（可执行文件名为 **`pwsh`**；Windows 终端里常显示为「PowerShell」且版本为 7.x） | 可以 |
| **Windows PowerShell 5.1**（系统自带的「Windows PowerShell」） | **不可以**（会提示版本不满足或无法导入模块） |

**建议操作**：在 Windows 终端、VS Code / Cursor 集成终端等处，**选用 PowerShell 7 配置文件**，或在任意终端先运行 **`pwsh`** 再执行 `Import-Module`。验证版本可运行：`$PSVersionTable.PSVersion`（`Major` 应为 **7** 及以上）。若尚未安装 PowerShell 7，请参阅微软文档：[在 Windows 上安装 PowerShell](https://learn.microsoft.com/powershell/scripting/install/installing-powershell-on-windows)。

**说明**：只阅读 **`Docs/菜谱/`** 下的 Markdown 菜谱时，**不依赖** PowerShell 7；**只有**要使用模块提供的命令与数据接口时，才需要 `pwsh` 环境。

---

本目录用于存放四类内容：

1. **菜谱文档**：按分类层级归档的 Markdown 菜谱（例如 `主食/面食/水饺.md`）。
2. **配置说明**：对 `Config/*.json` 的结构、用途、字段含义做简明解释，便于协作与长期维护。
3. **最佳实践**：跨菜谱复用的方法论文献（例如工作流、质控、动线、排产建议）。
4. **工具说明**：与仓库根目录 **`Tools/*.ps1`** 维护脚本一一对应的 Markdown（**`Docs/工具说明/<脚本基名>.md`**）；索引见 **`Docs/工具说明/00_总览.md`**。

新手（下厨跟做者 / 终端检索用户 / 菜谱维护人员）请先读：**`Docs/新手入门.md`**。

模块目录与启动分层（架构总览）：**`Docs/架构说明/README.md`**。

建议阅读顺序：

- `Docs/新手入门.md`（三类用户分节导读）
- `Docs/架构说明/README.md`（仓库与模块结构）
- `Docs/工具说明/00_总览.md`（维护脚本与 CI 门禁说明）
- `Docs/配置说明/00_总览.md`
- `Docs/配置说明/01_Beverages_饮料分类.md`
- `Docs/配置说明/01a_Beverages_维护与扩展速查.md`
- `Docs/配置说明/02_ChineseTea_中国茶体系.md`
- `Docs/配置说明/02a_ChineseTea_维护与扩展速查.md`
- `Docs/配置说明/03_Noodles_面食条目库.md`
- `Docs/配置说明/03a_Noodles_维护与扩展速查.md`
- `Docs/配置说明/04_CookingTechniques_烹饪技法.md`
- `Docs/配置说明/04a_CookingTechniques_维护与扩展速查.md`
- `Docs/配置说明/05_RegionalCuisines_地域菜系.md`
- `Docs/配置说明/05a_RegionalCuisines_维护与扩展速查.md`
- `Docs/配置说明/06_Enums_分类与标签体系.md`
- `Docs/配置说明/06a_Enums_维护与扩展速查.md`
- `Docs/配置说明/07_PreparationByIngredientState_备料预处理工作流.md`
- `Docs/配置说明/08_CookingWorkflow_SOP_分盘与下锅顺序.md`
- `Docs/配置说明/09_HerbalMedicineSchema_药膳药材知识框架.md`
- `Docs/配置说明/09a_HerbalMedicineSchema_维护与扩展速查.md`

最佳实践入口：

- `Docs/最佳实践/工作流/01_中餐烹饪标准工作流_SOP_大师级增强版.md`

工作流命令速查：

- `Docs/配置说明/08_CookingWorkflow_SOP_分盘与下锅顺序.md`（含 `Get-CookingWorkflow` 的分区读取、表格化、CSV 导出与自动打开示例）

药材命令速查：

- `Docs/配置说明/09a_HerbalMedicineSchema_维护与扩展速查.md`（含 `Get-HerbalMaterial` 与 `Test-HerbalMaterial` 的查询、校验、CSV 导出与自动打开示例）

