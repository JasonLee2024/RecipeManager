# Test-ChangelogGate.ps1

对应仓库脚本：**`Tools/Test-ChangelogGate.ps1`**。

## 用途

**变更日志门禁**：在一次变更（PR、push 或本地工作区对比基准分支）中，若修改触及菜谱文档、分片数据、关键配置或模块核心代码等路径，则要求 **同一次 diff 中包含根目录 `CHANGELOG.md`**；并对 **`CHANGELOG.md`** 中版本标题格式做校验（`## vX.Y.Z - YYYY-MM-DD`）。

## 用法

本地默认对比 **`origin/main`** 与当前工作区（含未跟踪文件）：

```powershell
pwsh Tools/Test-ChangelogGate.ps1
```

仅核对上一提交区间：

```powershell
pwsh Tools/Test-ChangelogGate.ps1 -CommitRange -BaseRef HEAD~1 -HeadRef HEAD
```

排障时可使用 **`-AllowMissingChangelog`**（CI 不应使用）。

## CI

由 **`.github/workflows/quality.yml`** 在 **Quality** 工作流中调用；环境变量 **`GITHUB_EVENT_NAME`**、**`PR_BASE_SHA`** / **`PR_HEAD_SHA`**、**`PUSH_BEFORE_SHA`** / **`PUSH_AFTER_SHA`** 由 Actions 注入。触及清单以脚本内 **`Test-TriggersChangelog`** 为准。
