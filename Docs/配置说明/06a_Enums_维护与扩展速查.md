# Enums 维护与扩展速查

对应配置文件：`Config/RecipeTaxonomy.json`（原 `Config/Enums.json`）

本文是 `06_Enums_分类与标签体系.md` 的操作补充，聚焦“分类枚举与标签体系如何稳定维护”。

---

## 1. 适用场景

- 新增或调整一级分类（`Categories`）
- 调整分类层级（`CategoryHierarchy`）
- 新增主标签或二级标签（`TagTaxonomy`）
- 排查 `Category`/`Tags` 校验失败

---

## 2. 结构约定（当前版本）

`Config/RecipeTaxonomy.json` 分三部分：

- `Categories`：一级分类枚举（菜谱 `Category` 的合法值来源）
- `CategoryHierarchy`：分类父子关系（用于文档层级和导航语义）
- `TagTaxonomy`
  - `PrimaryTags`
  - `SecondaryTagsByPrimary`（编码形式为 `主标签/二级标签`）

约定：

- 一级分类保持简洁稳定，不把二级语义塞入 `Categories`
- 分层关系通过 `CategoryHierarchy` 表达
- 标签遵循“主标签 + 二级标签”体系，避免扁平标签无限膨胀

---

## 3. 维护 SOP（推荐）

1. 明确变更维度（分类/层级/标签）
2. 若改分类：
   - 先改 `Categories`
   - 再同步检查 `CategoryHierarchy` 与文档目录结构
3. 若改标签：
   - 先补 `PrimaryTags`
   - 再补 `SecondaryTagsByPrimary`（如需）
4. 运行测试，重点关注 `Category` 与 `Tags` 相关用例
5. 若涉及结构语义变化，同步更新：
   - `Docs/配置说明/06_Enums_分类与标签体系.md`
   - `Docs/CategoryDocIndex.json`（如文档映射受影响）

---

## 4. 常见问题排查

### Q1：`Category` 校验失败

检查顺序：

1. 值是否在 `Categories` 中
2. 是否把二级分类误写到 `Category`（如写成“面食”而非“主食”）
3. 是否只更新了文档目录但未更新枚举

### Q2：`Tags` 校验失败

检查顺序：

1. 主标签是否存在于 `PrimaryTags`
2. 若使用 `主/次` 编码，次级标签是否在 `SecondaryTagsByPrimary.<主标签>` 中
3. 字符串是否一致（全角半角、空格、分隔符）

### Q3：分类与文档目录对不上

建议：

- `Category` 保持一级分类
- 目录细分用 `DocCategories` / 文档路径表达
- 用 `Docs/CategoryDocIndex.json` 做双向映射校验

---

## 5. 扩展建议（未来版本）

- 为标签体系引入“弃用标签”清单（兼容历史数据）
- 为分类体系增加版本号（便于迁移脚本识别）
- 建立分类/标签变更记录（谁改了什么、为何改）

---

## 6. 关联文档

- 总体说明：`Docs/配置说明/06_Enums_分类与标签体系.md`
- 文档映射：`Docs/CategoryDocIndex.json`
- 模块入口：`Docs/README.md`

