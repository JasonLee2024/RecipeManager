# Beverages 维护与扩展速查

对应配置文件：`Config/Beverages.json`

本文是 `01_Beverages_饮料分类.md` 的操作补充，聚焦“饮料分类框架如何安全维护”。

---

## 1. 适用场景

- 新增饮料大类或子类（框架层）
- 调整 `Tea` 的外部引用路径
- 排查 `BeverageStyle` 校验失败

---

## 2. 结构约定（当前版本）

`Config/Beverages.json` 定位为“总类目框架”：

- 顶层：`Beverages`
- 二级：`AlcoholicBeverages` / `NonAlcoholicBeverages`
- 叶子默认：字符串数组（如 `Juice`、`SoftDrinks`）
- 特例：`Tea` 为对象节点，包含：
  - `ChineseTeaTaxonomyPath`
  - `GlobalTea`

约定：

- 框架文件优先保持稳定，避免把过多细分条目直接塞进来
- 地方化、复杂体系（如中国茶）应放在独立文件维护
- 路径字段使用模块内相对路径（例如 `Config/ChineseTea.json`）

---

## 3. 维护 SOP（推荐）

1. 明确变更类型：框架变更 or 条目扩展
2. 若是框架变更，优先评估是否应该拆分独立文件而非继续膨胀主文件
3. 修改 `Beverages.json` 后检查：
   - JSON 语法合法
   - `Tea.ChineseTeaTaxonomyPath` 路径可解析
4. 运行测试，重点关注 `BeverageStyle` 与 `Get-BeverageTaxonomy` 相关用例
5. 同步更新 `Docs/配置说明/01_Beverages_饮料分类.md`（若结构有变化）

---

## 4. 常见问题排查

### Q1：`BeverageStyle` 校验失败

检查顺序：

1. 值是否存在于 `Beverages.json` 或 `ChineseTea.json` 的任意条目
2. 字符串是否有全角/半角差异或空白差异
3. 是否把条目写进了文档但未写入配置文件

### Q2：`Get-BeverageTaxonomy` 返回缺失

优先检查：

- `Beverages.json` 是否成功加载
- `Tea.ChineseTeaTaxonomyPath` 是否指向有效文件
- `ChineseTea.json` 是否可被解析

---

## 5. 扩展建议（未来版本）

若后续需要更强检索能力，可逐步引入对象结构，例如：

```json
{
  "Name": "西湖龙井",
  "Category": "Tea",
  "SubType": "绿茶",
  "Region": "杭州",
  "Aliases": []
}
```

升级前建议先确认：

- `Invoke-RecipeValidation` 对 `BeverageStyle` 的匹配策略是否需要升级
- 现有历史值是否需要迁移或建立别名映射
- 文档与测试是否同步更新

---

## 6. 关联文档

- 总体说明：`Docs/配置说明/01_Beverages_饮料分类.md`
- 中国茶细则：`Docs/配置说明/02_ChineseTea_中国茶体系.md`
- 模块入口：`Docs/README.md`

