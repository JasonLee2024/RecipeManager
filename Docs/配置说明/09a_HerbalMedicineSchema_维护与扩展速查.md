# HerbalMedicineSchema 维护与扩展速查

对应配置文件：`Config/HerbalMedicineSchema.json`

本文是 `09_HerbalMedicineSchema_药膳药材知识框架.md` 的操作补充，聚焦“如何从框架走向可落地药材知识库”。

---

## 1. 适用场景

- 新增/调整药材知识字段
- 统一术语口径（如功效分类、体质、禁忌）
- 准备接入药膳菜谱检索与校验前的结构治理

---

## 2. 维护 SOP（推荐）

1. 明确变更类型：结构变更 or 内容扩充
2. 结构变更优先保证“向后兼容”（新增字段优先，慎改字段名）
3. 内容扩充时，按六大维度逐步完善，不跨层混填
4. 对高风险字段（毒性、禁忌、剂量）进行二次人工复核
5. 同步更新 `09_HerbalMedicineSchema_药膳药材知识框架.md`

---

## 3. 常见问题排查

### Q1：字段语义重叠（例如功效与主治混写）

建议：

- `核心功效` 记录“作用机制/方向”
- `主治病症` 记录“中医病证/症候”
- `现代适应症` 记录“现代疾病/临床适应”

### Q2：药膳应用和药理研究混写

建议：

- 药膳应用聚焦“配伍、体质、时令、禁忌人群”
- 现代研究聚焦“成分、药理、临床证据、质量标准”

### Q3：禁忌信息冲突

建议：

- 先保守记录“更严格”的禁忌描述
- 在文档层补充来源与版本说明，避免口径漂移

---

## 4. 扩展建议（下一阶段）

- 新增药材实体数据文件：`Data/HerbalMaterials.json`
- 增加查询命令：`Get-HerbalMaterial`
- 增加校验命令：`Test-HerbalMaterial`（检查必填、枚举值、禁忌字段）
- 引入证据字段（来源、文献级别、更新时间）

---

## 5. 关联文档

- 主说明：`Docs/配置说明/09_HerbalMedicineSchema_药膳药材知识框架.md`
- 总览导航：`Docs/配置说明/00_总览.md`
- 模块入口：`Docs/README.md`

---

## 6. 命令速查（药材查询与校验）

### 1）查看全部药材

```powershell
Get-HerbalMaterial
```

### 2）按名称检索

```powershell
Get-HerbalMaterial -Name "黄"
Get-HerbalMaterial -Name "^枸杞子$" -Regex
```

### 3）按体质筛选

```powershell
Get-HerbalMaterial -Constitution "气虚质"
```

### 4）执行校验（汇总）

```powershell
Test-HerbalMaterial
```

### 5）执行校验（逐条明细）

```powershell
Test-HerbalMaterial -Detailed
```

### 6）导出校验结果 CSV

```powershell
Test-HerbalMaterial -Detailed -ExportCsv ".\out\herbal-validation.csv"
```

### 7）导出并自动打开 CSV

```powershell
Test-HerbalMaterial -Detailed -ExportCsv ".\out\herbal-validation.csv" -OpenCsv
```

### 8）推荐使用顺序

1. 先 `Get-HerbalMaterial` 确认数据是否已加载
2. 再 `Test-HerbalMaterial` 看整体健康度
3. 需要排错时切到 `-Detailed`
4. 交付或复核前导出 CSV 归档

