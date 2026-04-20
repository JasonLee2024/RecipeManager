# Beverages（饮料总称）分类说明

本说明用于解释 `Config/Beverages.json` 的分类设计。该文件定位为**饮料总类目框架**，用于统一承载“饮料大类”的结构，而不是直接塞入所有具体条目。

## 顶层分类（参考树）

```text
Beverages（饮料总称）
├── 含酒精饮料 Alcoholic Beverages
│   ├── 葡萄酒 Wine
│   ├── 啤酒 Beer
│   ├── 烈酒 Spirits（威士忌、伏特加等）
│   └── 鸡尾酒 Cocktails
│
└── 无酒精饮料 Non-alcoholic Beverages
    ├── 水 Water
    ├── 咖啡 Coffee
    ├── 茶 Tea
    ├── 果汁 Juice
    ├── 碳酸饮料 Soft drinks / Soda
    ├── 能量饮料 Energy drinks
    ├── 乳制品饮料 Dairy beverages
    └── 植物奶 Plant-based milk
```

## 文件设计要点

- **总类目文件**：`Config/Beverages.json` 只负责大类结构与路径引用。
- **地方体系外置**：以“茶”为例，中国茶体系拆分为独立文件：`Config/ChineseTea.json`，并在 `Beverages.json` 中通过路径引用。

## Tea（茶）分支的外部引用

在 `Beverages.json` 的 `Tea` 节点中，使用字段：

- `ChineseTeaTaxonomyPath`: 指向 `Config/ChineseTea.json`（中国茶/凉茶体系）
- `GlobalTea`: 预留用于未来加入“非中国茶”条目（例如英式红茶、抹茶、伯爵茶等）

这样做的好处：

- 中国茶体系可独立演进（条目多、结构复杂）
- 饮料总类目保持稳定、通用、易读

## 字段结构（Schema 摘要）

`Config/Beverages.json` 的关键结构如下（示意）：

```json
{
  "Beverages": {
    "AlcoholicBeverages": { "Wine": [], "Beer": [], "Spirits": [], "Cocktails": [] },
    "NonAlcoholicBeverages": {
      "Water": [],
      "Coffee": [],
      "Tea": { "ChineseTeaTaxonomyPath": "Config/ChineseTea.json", "GlobalTea": [] },
      "Juice": [],
      "SoftDrinks": [],
      "EnergyDrinks": [],
      "DairyBeverages": [],
      "PlantBasedMilk": []
    }
  }
}
```

说明：

- 所有叶子节点默认使用**字符串数组**承载具体条目（例如未来在 `Juice` 中加入“橙汁、苹果汁”等）。
- `Tea` 为对象节点，用于承载**外部引用**（中国茶体系）与全局茶条目（`GlobalTea`）。

## 与代码的关系（加载与检索）

- 模块启动时会加载：
  - `Beverages.json` 到 `$script:Beverages`
  - `ChineseTea.json` 到 `$script:ChineseTea`（路径来自 `Tea.ChineseTeaTaxonomyPath`，缺省回退到 `Config/ChineseTea.json`）

- 统一检索命令：
  - `Get-BeverageTaxonomy`
  - `Get-BeverageTaxonomy -Type Beverage`
  - `Get-BeverageTaxonomy -Type ChineseTea`

## 约束与建议

- **不要在 JSON 内写注释**：JSON 标准不支持注释；需要说明请写在本 `Docs/配置说明/` 文档中。
- **总类目不要膨胀**：`Beverages.json` 应保持“框架与引用”为主；复杂地方体系（如中国茶）应拆分独立文件维护。

