# 更新日志

本文档记录本项目的重要变更。

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
