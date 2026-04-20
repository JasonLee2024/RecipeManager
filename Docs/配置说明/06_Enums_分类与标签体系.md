# Enums（分类与标签体系）说明

对应配置文件：`Config/Enums.json`

## Categories（一级分类）

`Categories` 为菜谱的一级分类枚举（例如：热菜、主食、汤羹等）。写入 `Data/Recipes.json` 时的 `Category` 字段必须属于该集合（启用严格校验时）。

## CategoryHierarchy（分类层级）

为实现“主食 > 面食 > 水饺”等层级关系，使用 `CategoryHierarchy` 描述父子关系。它主要用于：

- Docs 归档结构设计（目录层级与分类语义对齐）
- 未来扩展“二级/三级分类”检索与导航

注意：当前菜谱数据的 `Category` 仍为一级分类；更细层级建议放入 `DocCategories`（文档归档链）或扩展字段中维护。

## TagTaxonomy（标签体系）

为降低扁平标签耦合，采用：

- `PrimaryTags`：主标签集合（例如：主食类、快手菜等）
- `SecondaryTagsByPrimary`：二级标签（例如：`主食类/米粉`）

标签校验逻辑会同时允许：

- 主标签本身（如 `主食类`）
- 以及编码后的二级标签（如 `主食类/米粉`）

