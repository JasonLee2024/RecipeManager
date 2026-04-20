# CookingTechniques 维护与扩展速查

对应配置文件：`Config/CookingTechniques.json`

本文是 `04_CookingTechniques_烹饪技法.md` 的操作补充，聚焦“技法词库如何扩展且不失控”。

---

## 1. 适用场景

- 新增标准技法词
- 新增同义词/别名映射
- 排查 `Techniques` 校验失败
- 排查模块启动时报“别名映射非法”

---

## 2. 结构约定（当前版本）

`Config/CookingTechniques.json` 由四部分组成：

- `MediumBased`：介质维度技法
- `HeatControl`：温度/时间火候维度
- `Preparation`：切割与质感处理维度
- `Aliases`：同义词归一映射
  - `CanonicalToAliases`
  - `AliasToCanonical`

约定：

- `AliasToCanonical` 的目标必须是“已存在标准词”
- 新增标准词后，再补别名，避免“先有别名后无标准词”
- 同一语义尽量固定一个标准词，降低检索歧义

---

## 3. 维护 SOP（推荐）

1. 先判断是“新标准词”还是“仅新增别名”
2. 若是标准词：写入对应维度分组（`MediumBased/HeatControl/Preparation`）
3. 若是别名：同步更新
   - `CanonicalToAliases`
   - `AliasToCanonical`
4. 执行测试，重点关注 `Techniques` 与别名归一相关用例
5. 若新增的是新概念，补充到 `Docs/配置说明/04_CookingTechniques_烹饪技法.md`

---

## 4. 常见问题排查

### Q1：模块导入失败，提示“别名映射非法”

检查：

1. `AliasToCanonical` 的目标词是否存在于三大词库
2. 是否拼写不一致（全角/半角或近似字）
3. 是否只更新了 `AliasToCanonical`，但漏了标准词或漏了另一侧映射

### Q2：菜谱 `Techniques` 校验失败

检查顺序：

1. 输入词是否能在 `AliasToCanonical` 找到归一目标
2. 归一后的标准词是否存在于任一词库集合
3. 是否误把工序描述写成非技法词（建议放步骤文本而不是 `Techniques`）

---

## 5. 扩展建议（未来版本）

- 引入独立“术语治理”策略（版本号 + 弃用词列表）
- 为标准词增加元数据（维度、说明、示例菜）
- 在文档层维护“新增词评审清单”（是否重复、是否跨维度混淆）

---

## 6. 关联文档

- 总体说明：`Docs/配置说明/04_CookingTechniques_烹饪技法.md`
- 工作流说明：`Docs/配置说明/08_CookingWorkflow_SOP_分盘与下锅顺序.md`
- 模块入口：`Docs/README.md`

