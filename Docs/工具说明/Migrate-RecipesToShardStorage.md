# Migrate-RecipesToShardStorage.ps1

对应仓库脚本：**`Tools/Migrate-RecipesToShardStorage.ps1`**。

## 用途

将历史的单体 **`Data/Recipes.json`** 一次性迁移为 **`Data/Recipes/<Category>/<菜名>.json`** 分片结构。脚本在模块根目录导入 **`RecipeManager.psd1`** 后调用公共命令 **`Migrate-RecipeStorage`**，避免在模块外直接调用私有数据提供者时的参数展开问题。

## 用法

在仓库根目录执行：

```powershell
pwsh Tools/Migrate-RecipesToShardStorage.ps1
```

若目标分片已存在但仍需覆盖迁移：

```powershell
pwsh Tools/Migrate-RecipesToShardStorage.ps1 -Force
```

可通过 **`-ModuleRoot`** 指定含 **`RecipeManager.psd1`** 的目录（默认为脚本上一级目录）。

## 依赖

- PowerShell 7+（脚本含 `#Requires -Version 7.0`）。
- 模块可正常 **`Import-Module`**。
