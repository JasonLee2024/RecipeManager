# ChineseTea 维护与扩展速查

对应配置文件：`Config/ChineseTea.json`

本文是 `02_ChineseTea_中国茶体系.md` 的操作补充，聚焦“中国茶与凉茶条目如何稳定维护与扩展”。

---

## 1. 适用场景

- 新增茶条目（如新增地方茶、拼配茶、草本饮）
- 调整条目分组（如从“花茶与拼配”迁移到“黑茶与普洱”）
- 排查 `BeverageStyle` 校验失败（茶条目相关）

---

## 2. 结构约定（当前版本）

`Config/ChineseTea.json` 当前结构：

- 顶层：`ChineseTeaSystem`
- 二级分组：
  - `凉茶与草本`
  - `绿茶`
  - `红茶`
  - `乌龙茶`
  - `白茶`
  - `黄茶`
  - `黑茶与普洱`
  - `花茶与拼配`
  - `调饮`
- 分组值：字符串数组（茶名条目）

约定：

- 条目尽量“单一标准名”，避免同义写法重复录入
- 跨分组归属优先明确主分组，减少多处复制
- 复杂属性（产地、工艺、等级）先放文档，不写入注释（JSON 不支持注释）

---

## 3. 维护 SOP（推荐）

1. 明确条目主分组（按当前分类语义）
2. 检查全文件是否已存在同名或近义条目
3. 插入条目后检查 JSON 结构合法
4. 执行模块测试，关注饮料分类与校验相关用例
5. 如分类语义有变化，同步更新：
   - `Docs/配置说明/02_ChineseTea_中国茶体系.md`
   - `Docs/配置说明/01_Beverages_饮料分类.md`（若影响引用说明）

---

## 4. 常见问题排查

### Q1：茶类 `BeverageStyle` 校验失败

检查顺序：

1. 条目是否在 `ChineseTea.json` 的任一分组中
2. 字符串是否完全一致（空格、全角半角、简繁差异）
3. 条目是否只写到了文档中但未写入配置

### Q2：`Get-BeverageTaxonomy -Type ChineseTea` 缺数据

优先检查：

- `Config/ChineseTea.json` 是否可解析
- `Config/Beverages.json` 中 `Tea.ChineseTeaTaxonomyPath` 是否指向该文件
- 模块是否重新加载（`Import-Module -Force`）

---

## 5. 扩展建议（未来版本）

如需更强检索和去重能力，可升级为对象数组结构，例如：

```json
{
  "Name": "西湖龙井",
  "Category": "绿茶",
  "Region": "杭州",
  "Aliases": [],
  "Notes": ""
}
```

升级前建议先确认：

- `Invoke-RecipeValidation` 对 `BeverageStyle` 的匹配逻辑是否同步升级
- 历史条目是否需要一次性迁移
- 是否引入“别名映射表”统一同义词

---

## 6. 关联文档

- 总体说明：`Docs/配置说明/02_ChineseTea_中国茶体系.md`
- 饮料总框架：`Docs/配置说明/01_Beverages_饮料分类.md`
- 饮料速查：`Docs/配置说明/01a_Beverages_维护与扩展速查.md`
- 模块入口：`Docs/README.md`

