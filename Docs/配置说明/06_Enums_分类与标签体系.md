# Enums（分类与标签体系）说明

对应配置文件：`Config/RecipeTaxonomy.json`（原 `Config/Enums.json`）

## Categories（一级分类）

`Categories` 为菜谱的一级分类枚举（例如：热菜、主食、汤羹等）。写入菜谱数据（`Data/Recipes/{Category}/*.json` 分片或历史单体 `Data/Recipes.json`）时的 `Category` 字段必须属于该集合（启用严格校验时）。

## CategoryHierarchy（分类层级）

为实现“主食 > 面食 > 水饺”等层级关系，使用 `CategoryHierarchy` 描述父子关系。它主要用于：

- Docs 归档结构设计（目录层级与分类语义对齐）
- 未来扩展“二级/三级分类”检索与导航

注意：当前菜谱数据的 `Category` 仍为一级分类；更细层级建议放入 `DocCategories`（文档归档链）或扩展字段中维护。

## TagTaxonomy（标签体系）

为降低扁平标签耦合，采用：

- `PrimaryTags`：主标签集合（例如：快手菜、下饭菜等）
- `SecondaryTagsByPrimary`：二级标签（编码形式为 `主标签/二级标签`，用于跨分类的细分标签；不要用于重复表达分类层级）

标签校验逻辑会同时允许：

- 主标签本身（如 `快手菜`）
- 以及编码后的二级标签（如 `口味/酸辣`，示例）

### 食材标签（多级路径）

食材标签不再通过 `SecondaryTagsByPrimary` 维护，而是由独立的 `Config/IngredientTaxonomy.json` 提供多级树形体系。  
编码形式为：`食材/<大类>/<中类>/<具体>`（可继续向下细化），例如：

- `食材/植物/蔬菜/叶菜/白菜`
- `食材/动物/蛋类/鸡蛋`

## ServingNote（可选佐餐说明）

`servingNote` 在 JSON 中字段名为 **`ServingNote`**：可选自由文本，用于上桌搭配、口感总结等，**不参与** `TagTaxonomy` 校验；与操作性的 `Steps` 分离。启用严格校验时，若存在该字段且内容非空白，长度上限为 4000 字符。
