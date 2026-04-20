# 中餐工作流 SOP：备料分盘与下锅顺序模板

本文件用于把“中餐烹饪”抽象成可重复的工作流，降低手忙脚乱、串味出水与火候失控的概率。

适用范围：家常炒菜/炒粉/炒面/盖浇类（以“炒”为主的高并发动作）。

关联文献（建议配套阅读）：

- 上位方法论文献：`Docs/最佳实践/工作流/01_中餐烹饪标准工作流_SOP_大师级增强版.md`
- 备料阶段细则：`Docs/配置说明/07_PreparationByIngredientState_备料预处理工作流.md`
- 程序化配置：`Config/CookingWorkflow.json`

---

## 一、备料分盘模板（推荐）

目标：上灶后只做“火候与翻锅”，不再做“找东西/补切/补洗/补量”。

### 盘 1：香料与起锅油

- 蒜末/姜末/葱段/葱花
- 干辣椒/花椒（可选）
- 起锅油（或提前量好）

**注意**：香料极易糊，必须单独分盘，避免与主料混在一起导致下锅顺序混乱。

### 盘 2：蛋白类（肉/禽/水产）

- 已完成“码味/上浆/静置”的蛋白
- 或已“滑油/过油”预处理的蛋白（若菜式需要）

**注意**：蛋白类决定“鲜嫩窗口”，必须优先控温控时。

### 盘 3：耐炒蔬菜（先下锅）

典型：根茎类、胡萝卜、莲藕片、较厚的菌菇等。

### 盘 4：易熟/高含水蔬菜（后下锅）

典型：叶菜类（包菜、生菜等）、茄果类（番茄/青椒等）。

**注意**：这盘必须“沥/控/吸干”后再靠近灶台，避免出水拖慢锅温。

### 盘 5：主食载体（炒粉/炒面）

- 米粉/面条：泡发/煮熟 → 过凉 → 沥干 → 拌少许油防粘（按需要）

### 盘 6：调味料（建议按“阶段”分装）

建议分成两小碟更稳：

- **调味 A（入锅早）**：生抽/老抽/蚝油（用于上色与挂味）
- **调味 B（出锅前）**：盐/白胡椒/糖/香油/醋（用于校正与提香）

---

## 二、下锅顺序模板（通用）

> 口诀：**先香后蛋白，先耐后嫩，先干后湿，先控温后调味**。

### 1）热锅冷油（默认）或热锅热油（按菜式）

- 让锅温上来，避免一开始就“焖锅出水”。
- 统一口径建议：以锅温阈值判断为准，默认先把锅温建立到可稳定爆香的状态，再按菜式选择用油方式。

### 2）爆香（盘 1）

- 蒜姜葱等入锅，快速出香即可
- 有花椒/干辣椒时更要短时，防糊发苦

### 3）下蛋白（盘 2）

- 先定型再翻炒，避免频繁翻动导致出水
- 如需“滑油/过油”，应在上灶前完成

### 4）下耐炒蔬菜（盘 3）

- 让耐炒食材先走成熟度，减少后续“叶菜等太久塌软”

### 5）下易熟/高含水蔬菜（盘 4）

- 快速大火翻炒到“断生”
- 若锅温不足会立刻出水，出现“炒变煮”的根因

### 6）下主食（盘 5）

- 米粉/面条最后入锅，避免吸水后发坨

### 7）分段调味（盘 6）

- 先用调味 A（上色/挂味），再用调味 B（校正咸淡/提香）
- 若需更细颗粒顺序，可参考增强版中的调味建议作为 A/B 内部顺序规则。

### 8）收尾与出锅

- 快速翻匀后立刻出锅，避免余温继续出水或过熟

---

## 三、常见场景模板

### 场景 A：炒粉/炒面（如“包菜炒粉”）

推荐顺序：

1. 爆香蒜末
2. 加工肉类先煸香（火腿/腊肠/培根等）
3. 洋葱等耐炒配菜
4. 包菜断生（保持脆嫩）
5. 米粉入锅
6. 生抽/老抽/蚝油快速翻匀
7. 出锅前补盐/白胡椒（按口味）

### 场景 B：叶菜快炒

关键控制点：

- 洗净后必须控水/吸干
- 切得过细更易出汤
- 大火快炒只要断生即可

### 场景 C：肉片快炒（嫩滑优先）

关键控制点：

- 逆丝切 + 上浆/打水 + 静置
- 大火快炒时间短，先定型再翻

---

## 四、命令速查（Get-CookingWorkflow）

以下命令用于读取、表格化与导出 `Config/CookingWorkflow.json`。

### 1）查看完整配置

```powershell
Get-CookingWorkflow
```

### 2）查看指定工作流

```powershell
Get-CookingWorkflow -Name 'StirFriedRiceNoodles'
```

### 3）按分区读取（默认工作流为 GenericWokWorkflow）

```powershell
Get-CookingWorkflow -Section KPI
Get-CookingWorkflow -Section TemperatureGuidelines
```

### 4）表格友好输出

```powershell
Get-CookingWorkflow -Section KPI -AsTable | Format-Table -AutoSize
Get-CookingWorkflow -Section CriticalControlPoints -AsTable | Format-Table -Wrap
Get-CookingWorkflow -Section ParallelizableSteps -AsTable | Format-Table -AutoSize
```

### 5）导出 CSV

```powershell
Get-CookingWorkflow -Section KPI -AsTable -ExportCsv ".\out\kpi.csv"
Get-CookingWorkflow -Section TemperatureGuidelines -AsTable -ExportCsv ".\out\temperature.csv"
```

### 6）导出并自动打开 CSV

```powershell
Get-CookingWorkflow -Section KPI -AsTable -ExportCsv ".\out\kpi.csv" -OpenCsv
```

### 7）参数约束提示

- `-AsTable` 必须与 `-Section` 一起使用
- `-ExportCsv` 必须与 `-Section` 一起使用
- `-OpenCsv` 必须与 `-ExportCsv`（及 `-Section`）一起使用


