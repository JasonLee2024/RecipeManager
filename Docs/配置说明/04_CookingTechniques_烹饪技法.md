# CookingTechniques（烹饪技法）说明

对应配置文件：`Config/CookingTechniques.json`

## 定位

该文件维护烹饪技法词库（独立维度），用于：

- 可选字段 `Techniques` 的合法性校验（先别名归一，再校验是否在词库中）
- 未来按技法维度检索/聚类菜谱

## 当前聚类结构

- `MediumBased`：按热力传递介质分类（`水介质` / `油介质` / `气介质` / `固体介质`）
- `HeatControl`：按温度与火候控制分类（`温度维度` / `时间维度`）
- `Preparation`：按食材状态与预处理分类（`切割技法` / `质感处理`）

## 别名归一（Aliases）

为避免同义词导致检索/校验不稳定，文件中维护别名映射：

- `AliasToCanonical`：别名 -> 标准词（用于运行时归一）
- `CanonicalToAliases`：标准词 -> 别名集合（用于文档化与人工维护）

维护原则：

- 标准词必须存在于上述三类技法集合之一（模块启动时会做一致性校验）。
- 别名仅用于“同义/近义归一”，不应替代新增标准词条。

## 与数据字段的关系

当菜谱对象包含可选字段 `Techniques`（字符串数组）时，校验流程为：

1. 先按 `Aliases.AliasToCanonical`（或由 `CanonicalToAliases` 反构建）进行**别名归一**  
2. 归一后的标准词必须存在于以下任意一个词库集合中：
   - `MediumBased.*`
   - `HeatControl.*`
   - `Preparation.*`

示例（仅示意）：

```powershell
New-Recipe -Name '示例' -Category '热菜' -Tags '经典' -PassThru |
  ForEach-Object { $_.Techniques = @('白灼','手撕'); $_ } |
  Invoke-RecipeValidation
```

## 维护约束（避免“词库失控”）

- **去重**：同一列表内避免重复条目（检索与校验会更稳定）。
- **标准词优先**：新增技法时优先补“标准词”，别名仅用于兼容常见叫法。
- **别名目标必须存在**：`AliasToCanonical` 指向的标准词必须存在于词库集合中，否则模块启动会失败（防止配置漂移）。

