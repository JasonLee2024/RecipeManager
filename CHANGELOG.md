# 更新日志

本文档记录本项目的重要变更。

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
