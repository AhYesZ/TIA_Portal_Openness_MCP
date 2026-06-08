# PLC Builder 现状（2026-05-10）

## 一句话

PLC 端基本可用：UDT、PLC 变量表、Global DB、SCL FC、SCL FB（builder 直造）、LAD FC（新 composer）、SCL OB（调用 FC）全部能造、能 import、能 0 错 0 警编译；HMI 端走的是 Build* offline + ImportHmi* 路线，KTP700 Basic 上变量表能进，画面 import 还有 1 个 transient flake。

## 已验证能力

### 离线 SCL 指令矩阵 30 / 30 通过

`e2e_scl_matrix.ps1` 跑 30 个 SCL 指令模式，全部生成合规 V21 XML：

- 字面赋值（局部 / 全局）、ELSIF 链、IF/ELSE/END_IF 嵌套
- 符号位移赋值（`"Q4" := "Q3"`）、自由表达式 `(a OR b) AND NOT c`
- 算术 + 比较（+ - * /、< <= > >= = <>）、一元 NOT
- 函数调用（REAL_TO_INT、SQRT、MIN、ABS）
- TIME 字面（`T#1S`）、字符串字面、整型/浮点
- DB 多段成员（`"DB.member"` → 多 Component）
- 局部多段成员（`#trig.Q` → 多 Component）
- CASE / FOR / WHILE / RETURN / EXIT 控制流
- 多实例 FB 调用（raw token 拼，等待一等公民版）

### 在线真实样本回归（用户 5T车 项目）21 / 25 通过

`e2e_real_samples.ps1` 用真实 V20 导出 XML 当输入：

| 类别 | 通过 | 备注 |
|---|---|---|
| UDT (4 个) | 4/4 | 含中文 MultilingualText、嵌套 Member |
| PLC 变量表 (5 个) | 5/5 | %M / %I / %Q 各类地址、中文表名 |
| 简单块 (OB / FC / GlobalDB, 7 个) | 7/7 | Cyclic interrupt / Diagnostic / Time error / Control_FC / 21_数据转换 / Global_Data / Main |
| 复杂 SCL FB (3 个) | **0/3** | FB_DualLoopPID, FB_AntiSway_SpeedCtl, FB_Crane_AntiSway — 见下方限制 |

> 编译 success=false 是预期：导入的真实块依赖工程其他符号（DB、UDT、其他 FB），新建的最小项目没有这些符号。

### 在线 demo 24 / 25 通过

`e2e_demo_full.ps1` 全自动建项目：S7-1200 + KTP700 + PROFINET + UDT/Tag/DB/SCL FC/LAD FC/OB → **编译 0 错 0 警** → SaveProject。

## 已知限制（来自真实测试）

### 复杂 SCL FB 的 .xml-only import

3 个 FB（`FB_DualLoopPID` 等）从 V20 项目导出时，body 在 `.scl` 文件，`.xml` 只含 interface（无 CompileUnit）。`ImportBlock` 报：

> `Language of 'SCL' have to have at least one compile unit.`

可走的 3 条路（**都不在 MCP 当前能力内**）：

1. **从 TIA UI 重新导出**，在导出选项里勾"导出所有 ...（含代码体）"，让 SCL 嵌入 XML。
2. **走 `.s7dcl` 路径**：用 `ImportFromDocuments` 接 SD 文档容器，但用户当前 export 是 `.scl` 文本不是 `.s7dcl`。
3. **`ImportPlcExternalSource` + `GenerateBlocksFromExternalSource`**：TIA Openness V21 的 `PlcExternalSourceComposition.Create` 这条 API **未导出**（`The method is not supported by the current version`）。这是 Siemens 那边的盲点，MCP 改不了。

> 实用建议：用户做项目时，让 TIA 导出选项设为 `WithDefaults`（含 SCL 体），就能直接走 `ImportBlock`。

### HMI Classic（KTP700 Basic）

- HMI 变量表 import OK（无 PLC 绑定）
- HMI 画面 import 有 transient `Access to a disposed Project` 错误（一过性，retry 通常过）
- HMI Connection 不会随 PROFINET 子网自动创建；要绑定 PLC 必须先 `ImportHmiConnection` 一个连接 XML（**MCP 缺连接 XML 模板**）
- 按钮事件 / 动画绑定：Classic 没有 MCP 一等工具（Unified 有），需要在画面 XML 里手写 `<Hmi.Event.Event>`

## SCL builder JSON 速查

```json
// 起保停（全局变量 + ELSIF + 块/网络中文注释）
{
  "blockName":"FC_StartStop", "blockNumber":10,
  "commentZhCn":"起保停：急停 > 停止 > 启动 三段优先级",
  "titleZhCn":"起保停核心 FC",
  "networkTitleZhCn":"IF/ELSIF/ELSIF/END_IF",
  "inputs":[], "outputs":[],
  "structuredText":{ "operations":[
    {"op":"if",        "condition":"\"I_EStop\""},
    {"op":"assignment","target":"\"Q_Run\"","literalValue":"FALSE","indent":2},
    {"op":"elsif",     "condition":"\"I_Stop\""},
    {"op":"assignment","target":"\"Q_Run\"","literalValue":"FALSE","indent":2},
    {"op":"elsif",     "condition":"\"I_Start\""},
    {"op":"assignment","target":"\"Q_Run\"","literalValue":"TRUE", "indent":2},
    {"op":"endif"}
  ]}
}
```

```json
// 自由表达式（DB 成员 + 算术 + 字面）
{"op":"line","items":[
  {"sym":"\"DB_Motor.Counter\""},{"token":":="},
  {"sym":"\"DB_Motor.Counter\""},{"token":"+"},{"lit":"1"},{"token":";"}
]}
```

```json
// 符号到符号赋值（位移）
{"op":"assignment","target":"\"Q_RunLamp4\"","source":"\"Q_RunLamp3\""}
```

约定：
- `"name"`（带引号）→ GlobalVariable，若含 `.` 自动多 Component
- `name`（无引号）→ LocalVariable；若含 `.` 也自动多 Component（用于 `#trig.Q`）

## 工具调用方法表（按已验证签名）

| 目的 | 工具 | 必填参数 |
|---|---|---|
| Connect TIA | `Connect` | — |
| 建项目 | `CreateProject` | `directoryPath`, `projectName` |
| 加 PLC | `AddDeviceWithFallback` | `preferredMlfb`, `preferredVersion`, `deviceName`, `family` |
| 加 HMI | `AddHardwareCatalogDeviceWithProbe` | `keyword`, `deviceName` |
| PROFINET 互联 | `ConnectDeviceNodesToProfinetSubnet` | `firstRootPath`, `secondRootPath`（HMI 端要 `HMI_x/HMI_x.IE_CP_1`）|
| Build+Import 一体 | `PlcBuildAndImport` | `softwarePath`, `kind`(udt/tagtable/globaldb/fc/fb), `json`, `dryRun` |
| 直接导 XML 块 | `ImportBlock` | `softwarePath`, `groupPath`, `importPath` |
| 直接导 UDT | `ImportType` | `softwarePath`, `groupPath`, `importPath` |
| 直接导 PLC 变量表 | `ImportPlcTagTable` | `softwarePath`, **`folderPath`**（不是 groupPath！）, `importPath` |
| 编译 | `CompileSoftware` | `softwarePath` |
| HMI 画面/变量表 | `ImportHmiScreen`/`ImportHmiTagTable` | `softwarePath`, **`folderPath`**, `importPath` |

## 待补能力（v1 → v1.1）

按优先级：

1. **HMI Classic Connection XML 模板**（拦路虎；不补则 PLC↔HMI 绑定走不通）
2. **HMI Classic 事件 / 动画 一等工具**（按钮 SetBit、范围动态绑定）
3. **多实例 FB 一等 Call XML**（替换 raw token 拼，让 TIA UI 看着干净）
4. **静态 R_TRIG/TON/TOF 实例声明**（FB Static 节加 InstructionName 属性）
5. **带 SCL 体的 FB 重新导出工作流文档**（指引用户怎么导）

## 相关回归脚本

- `e2e_scl_matrix.ps1` — 30 项 SCL 指令离线测试（≈6s）
- `e2e_offline_builder.ps1` — Builder 主路径离线确认
- `e2e_offline_marquee.ps1` — 跑马灯 FC 离线生成
- `e2e_offline_line.ps1` — 自由表达式行
- `e2e_demo_full.ps1` — 端到端在线 demo（建项目 + 编译，需 TIA 在线）
- `e2e_real_samples.ps1` — 用真实 5T车 XML 跑回归
