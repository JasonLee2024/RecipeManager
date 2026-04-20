# 更新日志

本文档记录本项目的重要变更。

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
