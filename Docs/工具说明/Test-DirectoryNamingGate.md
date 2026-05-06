# Test-DirectoryNamingGate.ps1

对应仓库脚本：**`Tools/Test-DirectoryNamingGate.ps1`**。

## 用途

**一级子目录命名门禁**：对 **`-RootRelativePath`** 指定的仓库相对父路径（如 **`Docs`**、**`Data/Recipes`**），在 base 提交上根据既有子目录名的 **CJK / 非 CJK** 多数决推断「主流风格」；若本次 diff 在该父路径下引入 **此前不存在的一级子目录名**，则新名须符合该风格。

## 用法

默认只检查 **`Docs`**：

```powershell
pwsh Tools/Test-DirectoryNamingGate.ps1
```

指定其它根或多个根：

```powershell
pwsh Tools/Test-DirectoryNamingGate.ps1 -RootRelativePath Data/Recipes
pwsh Tools/Test-DirectoryNamingGate.ps1 -RootRelativePath Docs,Data/Recipes
```

提交区间模式：

```powershell
pwsh Tools/Test-DirectoryNamingGate.ps1 -CommitRange -BaseRef HEAD~1 -HeadRef HEAD
```

## CI

**Quality** 工作流中当前传入 **`-RootRelativePath Docs`**。路径中禁止 **`..`**。push 的 **`before`** 为全零时与其他门禁一致会跳过。
