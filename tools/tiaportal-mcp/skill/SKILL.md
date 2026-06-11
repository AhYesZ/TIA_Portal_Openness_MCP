---
name: tia-portal-automation
description: "End-to-end TIA Portal V20/V21 project creation: hardware (PLC, HMI, drives), PROFINET networking, PLC programming via PlcBuildAndImport and S7DCL, HMI Unified and Classic screen design with button actions and tag bindings. Covers XML version compatibility, import pitfalls, stability recovery, and online monitoring."
triggers:
  - Create or build a TIA Portal project with PLC HMI or drive hardware
  - Add S7-1200 S7-1500 Unified Comfort panel or SINAMICS V90 to a TIA project
  - Configure PROFINET subnet and connect devices in TIA
  - Create PLC blocks DB FC FB UDT tag table via Openness or SCL import
  - Create LAD blocks via BuildS7dclLadBlock (JSON→.s7dcl) or S7DCL text
  - Create CTU/CTD/CTUD counter blocks (LAD with P_Trig + lowercase pins, or SCL with uppercase pins)
  - Validate .s7dcl/.s7res files offline with ValidateS7dclDocuments
  - Import .s7dcl LAD blocks via ImportBlocksFromDocuments
  - Design WinCC Unified HMI screens with buttons IO fields indicators
  - Design WinCC Classic/Basic HMI screens via XML import
  - Bind HMI tags to PLC DB members with verified absolute addresses
  - Troubleshoot TIA Portal import errors (XML version, StructuredText tokens)
  - Recover from TIA Portal session crashes or disposed-object errors
  - Resolve HMI tag binding and data type compatibility issues
---

# ⚠️ LAD 编程 — 强制规则（Claude Code 必须先读这里）

**当用户说"写 LAD 程序" / "创建梯形图" / "添加逻辑" 时，严格按以下步骤：**

## 步骤 0 — 准备工作区
1. 确认或创建 .s7dcl 工作目录：
   ```
   <TIA项目路径>\PLC_1\程序块\     ← 所有 .s7dcl/.s7res 输出到这里
   ```
2. 建议用 Git 管理：`cd <项目路径> && git init && git add -A`
3. 检查是否已有 .s7dcl 文件——若存在，在此基础上修改而非重写

## 步骤 1 — BuildS7dclLadBlock 生成（禁止手写）
```
BuildS7dclLadBlock(json, outputDirectory, dryRun=true)   ← 先验证
BuildS7dclLadBlock(json, outputDirectory, dryRun=false)  ← 生成文件
```

## 步骤 2 — 离线校验
```
ValidateS7dclDocuments(outputDirectory)    ← 31种陷阱检测
```
必须全部通过才能继续。

## 步骤 3 — 导入 + 编译
```
ImportBlocksFromDocuments(softwarePath="PLC_1", groupPath="", importPath=outputDirectory)
CompileSoftware("PLC_1")
```

## 绝对禁止
- ❌ 手写 .s7dcl 文本（用 BuildS7dclLadBlock JSON 代替）
- ❌ 用 ComposePlcLadFcBlockXml（不支持触点/线圈/定时器/计数器）
- ❌ 跳过 dryRun 直接生成
- ❌ 跳过 ValidateS7dclDocuments 直接导入

## Claude Code 最容易犯的错（生成前对照检查）
| 错误 | 正确 |
|------|------|
| `timeType := Time` | `time_type := Time` |
| `countType := DInt` | `value_type := Int` |
| `CMP >=(in1:=, in2:=)` | `GT(in1:=, in2:=, out=>)` |
| `Negated(#Var)` | 不存在！用 I_Contact 或 Contact→Not |
| LAD 计数器 `cu:=` 显式赋值 | P_Trig 驱动，小写 r/pv/cv |
| 变量 `#SET` 无引号 | `#"SET"` |
| 改 .s7dcl 不管 .s7res | 同步 .s7res |

# TIA Portal Project Automation (V20/V21)

End-to-end workflow for creating TIA Portal projects programmatically through the MCP bridge. Covers V20 and V21, Unified and Classic HMI.

## 1. Bootstrap and Connect

**Prerequisite**: The TIA MCP server binary must be properly installed. Both Hermes and Claude Code
share a unified binary at `C:\TIA-MCP项目\tools\tiaportal-mcp\src\TiaMcpServer\bin\Release\net48\TiaMcpServer.exe`.
See `references/mcp-server-setup.md` for full configuration details.

```
Bootstrap -> Connect -> (CreateProject | OpenProject)
```

- `Bootstrap` is always first. Returns TIA version, connection state, recommended next tool.
- After `Connect`, call `GetProjectTree` to discover device/software paths.
- For an already-open project: `AttachToOpenProject` instead of `OpenProject`.

## 2. Hardware Catalog and Device Insertion

### Searching
- `SearchHardwareCatalog` for Siemens devices (PLC, HMI, drives). Use MLFB/order number for exact matches, or descriptive keywords.
- `SearchInstalledGsdDevices` for third-party GSDML devices.
- Pay attention to `typeIdentifier` and `version`; multiple versions of the same MLFB exist.

### Insertion
- **PLC / Siemens drives**: `AddDevice` with exact `orderNumber` and `version` from catalog.
- **HMI panels**: Prefer `AddHardwareCatalogDeviceWithProbe`. The order number often has asterisk wildcards (e.g. `6AV2128-3GB06-0AX*`). Pass the exact article number as keyword.
- **Third-party GSD devices**: `AddGsdDeviceWithProbe`.
- For natural-language "add an S7-1200 CPU": `AddDeviceWithFallback` with `family` hint.

### V90 PN Drive
V90 PN drives appear in BOTH sources. **Prefer `SearchHardwareCatalog`** (not GSDML) — it inserts as `System:Device.SinamicsV90PN` with proper rack structure and telegram configuration UI. For 200W incremental encoder: `6SL3 210-5FB10-2UFx`.

## 3. PROFINET Networking

### Connecting two devices
Use `ConnectDeviceNodesToProfinetSubnet` for the first pair:

```
firstRootPath=PLC_1
secondRootPath=HMI_1/HMI_1.IE_CP_1   (note: IE_CP device item, not device root)
subnetName=PN_IE_1
```

The second root path must point to the PROFINET-capable device item (e.g. `HMI_1/HMI_1.IE_CP_1`), not the device root.

### Adding more devices to existing subnet
Use `AttachDeviceNodeToSubnet`:

```
deviceItemPath=V90_1       (device root; tool scans for PROFINET nodes)
interfaceIndex=0           (zero-based index among discovered PN nodes)
subnetName=PN_IE_1
```

### 3+ devices pattern
For three devices (PLC + HMI + V90), call `ConnectDeviceNodesToProfinetSubnet` twice:
1. First call: PLC as firstRootPath, HMI as secondRootPath → creates subnet
2. Second call: PLC as firstRootPath, V90 as secondRootPath → attaches to existing subnet

The tool auto-detects that PLC is already connected and reuses the subnet.

### Finding the right path
Paths discovered during `AttachDeviceNodeToSubnet` show the actual internal structure. The full DeviceItem path includes the intermediate device item (e.g. `PLC_1/PLC_1/PROFINET 接口_1`).

### ⚠ Chinese character path failures (CRITICAL)
DeviceItem paths containing Chinese characters fail with `GetDeviceItemInfo`, `GetDeviceItemNetworkInfo`, `SetDeviceItemAttribute`, and `SetCpuCommonSettings`:
- `PLC_1/PROFINET 接口_1` → "Device item not found"
- `V90_Servo/PROFINET接口` → "Device item not found"
- `V90_Servo/驱动对象` → "Device item not found"

**Workaround**: Use reflection tools that bypass path parsing:
1. `DescribeObject(objectKind="DeviceItem", objectPath="PLC_1")` → see members
2. `ListObjectChildren(collectionProperty="Items", ...)` → get child names
3. `InvokeObject(methodName="GetAttributeInfos", ...)` → read attributes
4. For non-Chinese sub-paths (e.g. `HMI_TP1200/HMI_TP1200.IE_CP_1/PROFINET Interface_1`), standard tools work

When Chinese paths block an operation, fall back to TIA Portal UI with exact click-path instructions.

### ⚠ IP address configuration
S7-1200 IP addresses live on the **PROFINET interface DeviceItem**, not the CPU DeviceItem. `SetCpuCommonSettings` with `IpAddress`/`SubnetMask` at the CPU level will be rejected — the attributes don't exist there. Use `GetDeviceItemInfo` on the PROFINET interface to discover exact writable attribute names first. For Comfort Panels, IP attributes are also not directly accessible via Openness — set via TIA Portal UI.

## 4. PLC Programming

### 4a. Creating SCL blocks with PlcBuildAndImport

**ALWAYS dryRun=true first**, then review, then dryRun=false.

Supported kinds: `globaldb`, `fc`, `fb`, `udt`, `tagtable`. **Note: PlcBuildAndImport only does SCL (structuredText) for FC/FB — it does NOT build LAD networks.**

Example - Global DB:
```json
{"dbName":"DB_HMI","dbNumber":1,"staticMembers":[{"name":"Field","datatype":"Bool","startValue":"TRUE","commentZhCn":"描述"}]}
```

Example - FC with SCL:
```json
{"blockName":"FC_MotorControl","blockNumber":1,
 "inputs":[...],"outputs":[...],
 "structuredText":{"operations":[...]}}
```

**Pitfall — FC blocks require `inputs` and `outputs`**: Even if empty, both arrays MUST be present:
```json
{"blockName":"FC_Name","blockNumber":1,"inputs":[],"outputs":[],"structuredText":{"operations":[...]}}
```
Without them: "Missing required JSON array: $.inputs"

**Pitfall — StructuredText JSON DSL limits**: Operations use `"variable"` for IF conditions and `"condition"` for the expression string. `"assignment"` uses `"target"` and either `"literalValue"` or `"value"`. No bit-level member access (`V90Data.STW1.7`), no complex expressions. Use `op:"token"` sparingly — see section 4c for token restrictions.

**Compile**: Set `compileAfter=true` on the final import. A single warning (e.g. "parameter might not be initialized") with 0 errors is acceptable.

### 4b. V20/21 XML Version Mismatch (CRITICAL)

Build/Compose tools generate XML with wrong Engineering version. TIA Portal V20 rejects anything other than V20.

| Tool | Generates | Fix to |
|------|-----------|--------|
| PlcBuildAndImport (all kinds) | V21 | V20 |
| BuildPlcGlobalDbXml | V21 | V20 |
| BuildClassicHmiTagTableXml | V21 | V20 |
| BuildClassicHmiScreenXml | V18 | V20 |

Error: `The engineering version 'V21' in line 3, position 16 is not supported.`

**Workaround — dryRun → patch → ImportBlock**:
1. Run `PlcBuildAndImport` with `dryRun=true` — generates XML without importing.
2. The XML path is in the response under `writtenFiles`.
3. `patch` the file: `<Engineering version="V21" />` → `<Engineering version="V20" />`.
4. Use `ImportBlock` (not PlcBuildAndImport) to import the patched XML.
5. Never use PlcBuildAndImport directly with dryRun=false on V20.

Example:
```
PlcBuildAndImport(kind="globaldb", dryRun=true, ...)
→ writtenFiles: ["C:\...\DB_Name.xml"]
patch(path="C:\...\DB_Name.xml",
      old_string='  <Engineering version="V21" />',
      new_string='  <Engineering version="V20" />')
ImportBlock(softwarePath="PLC_1", groupPath="", importPath="C:\...\DB_Name.xml")
```

For Classic HMI screens: patch `version="V18"` → `version="V20"` using the same pattern.

### 4c. StructuredText XML Token Restrictions (CRITICAL)

The TIA Openness StructuredText XML parser (v4 format) rejects tokens that are legal in SCL source text:

| Pattern | Example | Result |
|---------|---------|--------|
| Comment token | `<Token Text="// comment" />` | "token not supported" |
| Bit-access Component | `<Component Name="%X0" />` | "token not supported" |
| Special chars in token | `<Token Text="// --- V90 ---" />` | "token not supported" |
| FC call as assignment | `assignment(target='"FC_Name"()', ...)` | "Missing literalValue" |

**What IS allowed** in Token elements:
- SCL keywords: `IF`, `THEN`, `ELSE`, `END_IF`, `FOR`, `WHILE`, `CASE`, `OF`
- Operators/delimiters: `:=`, `;`, `(`, `)`

**Workaround — whole-word assignment**:
```pascal
// DO NOT use bit access (fails in XML):
"DB_Servo".ControlWord.%X0 := TRUE;

// DO use whole-word constant assignment (works):
"DB_Servo".ControlWord := 16#047F;  // Run
"DB_Servo".ControlWord := 16#047E;  // Stop
```

**Workaround — no inline comments**: Include only executable code in StructuredText XML. Use CompileUnit Comment multilingual text for block-level documentation. For complex logic with comments/bit-access/FC calls, either write SCL directly in TIA Portal UI or export a working block, modify only variable accesses, and re-import.

### 4d. External SCL Import (for complex logic)

When PlcBuildAndImport can't handle the logic (bit access, complex expressions):
1. Write a `.scl` file with the full SCL source (UTF-8 with BOM for Chinese comments, Windows line endings).
2. Call `ImportPlcExternalSource` with `groupPath=""` (empty string, not omitted).
3. Call `GenerateBlocksFromExternalSource` with the `.scl` filename including extension.
4. Compile with `CompileAndDiagnosePlc`.

SCL bit access syntax: `V90Data.STW1.%X7` (not `.7` or `(X)`).

### 4e. V90 Drive Control (Standard Telegram 1)

The V90 telegram (报文) is at `V90_1/V90_1/驱动对象/报文`. Use `DescribeObject` → `InvokeObject` → `ChangeType` with target TypeIdentifier. Standard Telegram 1 = PZD-2/2 (4 bytes in / 4 bytes out: STW1+NSOLL_A ↔ ZSW1+NIST_A).

**V90 path note**: the drive object lives at `V90_1/V90_1/驱动对象/报文` — the intermediate `V90_1` DeviceItem is required.

**Control word pattern:**
```
STW1 = 16#047E  →  ON + Enable operation + PLC control (ready)
STW1 = 16#047F  →  above + operating condition (run)
STW1 = 16#04FE  →  above + bit7=1, rising edge (fault acknowledge)
STW1 = 16#047C  →  keep Enable, remove ON (coast stop)
ZSW1 AND 16#0004 → bit 2 = operation enabled
ZSW1 AND 16#0008 → bit 3 = fault present
Speed normalization: NSOLL_A = SpeedRpm × 16384 / RatedSpeed
```

**OB1 SCL pattern for V90 PN** (whole-word, no bit access):
```pascal
// --- HMI bridge ---
"DB_Servo".Enable    := "DB_HMI".Hmi_Enable;
"DB_Servo".FaultAck  := "DB_HMI".Hmi_FaultReset;

// --- V90 STW1 control word ---
IF "DB_Servo".Enable THEN
    "DB_Servo".ControlWord := 16#047F;
ELSE
    "DB_Servo".ControlWord := 16#047E;
END_IF;

// --- Telegram I/O (uncomment after configuring V90 telegram) ---
// "DB_Servo".StatusWord := %IWxxx;     // ZSW1 input
// "DB_Servo".ActualPosition := %IDxxx; // G1_XIST1
// %QWxxx := "DB_Servo".ControlWord;    // STW1 output

// --- Status feedback to HMI ---
"DB_HMI".Hmi_ActualSpeed := "DB_Servo".ActualSpeed;
"DB_HMI".Hmi_MotorRunning := ("DB_Servo".StatusWord AND 16#0004) <> 0;
```

Full STW1/ZSW1 bit maps and speed formulas → `references/v90-control-reference.md`. Complete SCL template → `templates/FC_V90_Control.scl`.

If `ChangeType` is blocked (API doesn't expose V90-specific telegram TypeIdentifiers), configure the telegram manually in TIA Portal UI.

### 4f. LAD 编程 — DS 文件格式（.s7dcl）为唯一主路径

> **MANDATORY**: 编写 LAD 程序**必须**使用 S7DCL/DS 文件格式链路。XML 方式（ComposePlcLadFcBlockXml）仅支持 FC 调用网络，不支持触点/线圈/比较/数学/定时器/计数器等 90%+ 指令。DS 方式覆盖 99 条 LAD 指令中的 90+，比 XML 多 4 倍覆盖。

**建议工作区设置**（方便自动导入导出管理）：
```bash
# 建议用户在 TIA 项目内建工作目录
mkdir C:\TIA_test\<project>\PLC_1\程序块    # .s7dcl/.s7res 输出目录
# 然后用 Git 管理该目录，每次迭代 commit
cd C:\TIA_test\<project> && git init && git add -A
```

**DS vs XML 能力对比**：

| 指令类别 | DS (.s7dcl) | XML (SimaticML) |
|---------|------------|-----------------|
| 触点 Contact/Not/I_Contact | ✅ | ❌ |
| 线圈 Coil/S_Coil/R_Coil | ✅ | ❌ |
| 比较触点 GT/LT/EQ/NE/GE/LE_Contact | ✅ | ❌ |
| 比较盒 GT/LT/EQ/NE/GE/LE | ✅ | ❌ |
| 数学 Add/Sub/Mul/Div/Mod | ✅ | ❌ |
| 传送 Move/Convert | ✅ | ❌ |
| 选择器 MIN/MAX/LIMIT/SEL/MUX | ✅ | ❌ |
| 定时器 TON/TOF/TP/TONR | ✅ | ❌ |
| 计数器 CTU/CTD/CTUD (LAD) | ✅ | ❌ |
| 计数器 CTU/CTD/CTUD (SCL) | ✅ | ❌ |
| 字逻辑 AND/OR/XOR/移位 SHR/SHL | ✅ | ❌ |
| P_Trig/N_Trig 边沿检测 | ✅ | ❌ |
| FC/FB 调用 | ✅ | ✅ |
| 仅 FC 调用网络 | ✅ | ✅ |

**结论**: 如果用户说"帮我写 LAD 程序"，**唯一正确的回答是走 DS 链路**。XML 方式仅用于单一 FC 调用网络这一种窄场景。

### 4g. Creating LAD blocks — PREFERRED: JSON → `BuildS7dclLadBlock`

**NEVER hand-write .s7dcl text from scratch.** Claude Code testing (2026-06-10) proved

**Decision rule:**
| You want… | Use | Why |
|---|---|---|
| Create a **new** LAD block from scratch | `BuildS7dclLadBlock(dryRun=true)` → review → `dryRun=false` | JSON schema, auto-generates both files, auto-MLC |
| Validate .s7dcl/.s7res before TIA import | `ValidateS7dclDocuments(dir)` | Offline, 14 checks, catches BOM/MLC/wire/pragma errors |
| Modify an existing exported block | `ExportAsDocuments` → edit text → `ImportFromDocuments` | Round-trip pattern |
| Import generated/validated files | `ImportBlocksFromDocuments` or `ImportFromDocuments` | TIA import, requires Connect+OpenProject |

**Complete LAD workflow (4 steps):**
```
BuildS7dclLadBlock(json, outputDirectory, dryRun=true)     ← validate JSON in 1s
BuildS7dclLadBlock(json, outputDirectory, dryRun=false)    ← write .s7dcl + .s7res
ValidateS7dclDocuments(outputDirectory)                     ← 14 offline checks, must pass
ImportBlocksFromDocuments(softwarePath, groupPath="", importPath=outputDirectory)
CompileSoftware
```

**JSON schema:**
```jsonc
// Minimal FC: series contact → coil
{"blockKind":"fc","blockName":"FC_StartStop","blockNumber":1,
 "inputs":[{"n":"Start","t":"Bool"},{"n":"Stop","t":"Bool"}],
 "outputs":[{"n":"Run","t":"Bool"}],
 "networks":[
   {"t":"启保停","c":"串联触点→置位",
    "e":[{"i":"Contact","o":"#Start"},{"i":"I_Contact","o":"#Stop"},{"i":"S_Coil","o":"#Run"}]},
   {"t":"并联OR","c":"wire#w1分支",
    "e":[{"i":"Contact","o":"#A"},{"wire":"w1"},{"i":"Coil","o":"#Out"}],
    "b":[[{"i":"Contact","o":"#B"}],[{"i":"Contact","o":"#C"}]]},
   {"t":"比较+数学",
    "e":[{"i":"GT_Contact","tp":"SrcType := Int","p":{"in1":"#Val","in2":"100"}},
         {"i":"Add","tp":"SrcType := Int","p":{"in1":"#V1","in2":"#V2","out":"#Sum"}},
         {"i":"Coil","o":"#Done"}]}
 ]}
```

**CRITICAL — Template naming by instruction family:**

| Instruction family | Template | Example |
|---|---|---|
| Add/Sub/Mul/Div/Mod, GT/LT/EQ/NE/GE/LE_Contact, Calculate | `SrcType` | `{ S7_Templates := "SrcType := Int" }` |
| GT/LT/EQ/NE/GE/LE (comparison boxes) | `SrcType` | `{ S7_Templates := "SrcType := Int" }` ⚠️ NOT CMP! |
| MIN/MAX/LIMIT/SEL | `value_type` | `{ S7_Templates := "value_type := Int" }` ⚠️ NOT SrcType! |
| MUX | `SrcType` | `{ S7_Templates := "SrcType := Int" }` ⚠️ MUX is SrcType, not value_type! |
| TON/TOF/TP/TONR | `time_type` | `{ S7_Templates := "time_type := Time" }` ⚠️ underscore! |
| CTU/CTD/CTUD (SCL) | N/A | `#inst.CTU(CU:=#, R:=#, PV:=#, Q=>#, CV=>#)` — SCL大写参数 |
| CTU/CTD/CTUD (LAD + P_Trig) | `value_type` | `{ S7_Templates := "value_type := Int" }` ⚠️ 小写引脚名(r/pv/cv)! |
| Shr/Shl/ROR/ROL, NEG | `SrcType` | `{ S7_Templates := "SrcType := DWord" }` ⚠️ NOT template-free! |
| AND/OR/XOR/INV, Move | **no template** | Omit pragma entirely |
| Convert | Array | `{ S7_Templates := "[SrcType := Int, DestType := Real]" }` |
| JMP/LABEL/RET | — | **Not importable via S7DCL!** |

Full template classification table and all 99 instructions → `references/s7dcl-lad-reference.md`.

Element keys: `i`=instruction, `o`=operand (1-op contacts/coils), `p`=params object (multi-param boxes), `tp`=template pragma, `inst`=Q-box instance prefix (`c.S_RS`), `wire`=wire label. Parallel OR: `b`=array of branch element arrays.

For FB: add `"statics":[{"n":"tonInst","t":"TON_TIME"}]`. IEC timer: `{"i":"TON","tp":"time_type := Time","p":{"pt":"T#2s","et":"#elapsed"}}`. Simatic counter: `{"i":"S_Cu","p":{"cu":"#Up","pv":"C#100","cv":"#Value"}}`.
Edge detection (box-type): `{"i":"P_Trig","o":"#edgeMem"}` — placed in rung after a Contact.

### 4h. Counter blocks — LAD (edge-triggered) + SCL dual mode

**LAD mode** (P_Trig edge-triggered, lowercase pins, `value_type` template):
```jsonc
{"i":"P_Trig","o":"#edgeMem"},                                     ← edge trigger
{"i":"CTU","inst":"ctuEdgeInst","tp":"value_type := Int",         ← lowercase pins!
 "p":{"r":"#Reset","pv":"#PresetValue","cv":"#CTU_CV"}},
{"i":"Coil","o":"#CTU_Q"}                                          ← Q via Coil
```

**SCL mode** (full pin control, uppercase pins):
```scl
{ S7_Language := "SCL" }
NETWORK
    #"ctuInst".CTU(CU := #"CountUp",
                   R := #"Reset",
                   PV := #"PresetValue",
                   Q => #"CTU_Q",
                   CV => #"CTU_CV");
END_NETWORK
```

**Critical rules:**
- LAD: lowercase (`r`/`pv`/`cv`/`ld`/`cd`/`qd`), count pin (`cu`/`cd`) driven by rung EN
- SCL: uppercase (`CU`/`R`/`PV`/`Q`/`CV`), all pins explicit in one statement
- Static types: `CTU_INT`, `CTD_INT`, `CTUD_INT` — NOT `IEC_COUNTER`

### 4i. OB1 modification
OB1 is LAD by default. For adding FB/FC calls to OB1:
1. **Export OB1 as S7DCL document** via `ExportAsDocuments`, modify the text, reimport via `ImportFromDocuments`
2. OR author the call in a new SCL FC and call it from a cyclic OB (OB30)
3. OR tell the user to manually add the call in TIA Portal UI

## 5. HMI Setup

### 5a. Unified HMI

#### Connection
`EnsureUnifiedHmiConnection` creates the PLC-HMI link:
```
hmiSoftwarePath=HMI_RT_1
plcName=PLC_1
connectionName=HMI_Connection_1
```

#### Tag Table
`EnsureUnifiedHmiTagTable` creates the tag table. Call before adding tags.

#### HMI Tags (CRITICAL binding recipe)

Tags MUST pass ALL four of these or binding fails with `InternalOnly`:
```
connectionName=HMI_Connection_1    (REQUIRED)
plcName=PLC_1                      (REQUIRED)
address=%DB1.DBX0.0               (REQUIRED; absolute address)
plcTag="DB_HMI".MotorRun           (REQUIRED; DB name in double-quotes!)
hmiDataType=Bool
```

**Pitfall**: Without `connectionName` and `plcName`, tags are created as internal (`Connection=<内部变量>`) and binding fails. The `plcTag` must wrap the DB name in double-quotes: `"DB_HMI".MemberName`.

**Address calculation for non-optimized DBs**: Bools take 1 bit, Reals take 4 bytes (DWORD-aligned). Example DB1 layout: MotorRun(DBX0.0), MotorStop(DBX0.1), SpeedSet(DBD2), MotorRunning(DBX6.0), ActualSpeed(DBD8), Fault(DBX12.0), FaultReset(DBX12.1).

#### Screen and Controls

1. `EnsureUnifiedHmiScreen` creates screen with width/height.
2. `ApplyUnifiedHmiScreenDesignJson` batch-creates controls:
   - Items are created even when property writes fail.
   - Rectangle items: BackColor works, but ForeColor/Text/FontSize do NOT. Use separate HmiText items for text overlays.
   - Colors: use ARGB decimal (e.g. green = 4278247424 = 0xFF00AA00).
   - If strict mode fails, controls still exist; proceed with tag bindings.
3. `EnsureUnifiedHmiScreenItem` creates individual controls if needed.

#### Button Actions
`EnsureUnifiedHmiButtonAction` parameter recipe:
```
actionKind=set-bit|reset-bit|toggle-bit
eventType=Down|Up|Tapped    (NOT Pressed/Released)
targetTag=HMI tag name
```

Typical momentary button: Down -> set-bit, Up -> reset-bit. SyntaxCheck runs automatically when tags exist.

#### Tag Dynamization (IO Fields, indicators)
`BindUnifiedHmiTagDynamization`:
```
propertyName=ProcessValue    (for IO fields showing tag value)
tagName=HMI tag name
dataType=Real|Bool|Int
```

### 5b. Classic HMI (Comfort/Basic Panels)

#### HMI Comfort Panel limitations
**ConnectionComposition has no Create method**: `DescribeHmiSoftware` → `Connections` → `DescribeObjectProperty("Connections")` reveals only `Import` and `Find`. There is no `Create` for Comfort Panel connections.

**Workaround**: HMI connections must be created in TIA Portal UI (HMI_RT_1 → 连接 → 添加连接), or by importing a connection XML via `ImportHmiConnection`.

#### HMI tag data type compatibility
WinCC Comfort does not support all PLC data types:

| PLC type | Comfort type | Notes |
|----------|-------------|-------|
| Bool | Bool | OK |
| Real | Real | OK |
| DInt | DInt | May fail; use Real if needed |
| Word | UInt | Word not found in Comfort |
| String | String | OK |

When building tag tables with `BuildClassicHmiTagTableXml`, verify every DataType against this table. Error: "The data type Word was not found."

#### HMI tag import: internal vs PLC-bound
Tag tables with `Connection` and `ControllerTag` links fail if the referenced connection does not exist:
```
Connection HMI_Connection_1 of the Hmi_Enable tag was not found.
```

**Workflow**: Import tags as internal (remove Connection and ControllerTag from XML), then after user creates the connection in TIA Portal UI, rebind tags to PLC addresses. Use sed:
```bash
sed -i '/<Connection TargetID="@OpenLink">/,/<\/Connection>/d' TagTable.xml
sed -i '/<ControllerTag TargetID="@OpenLink">/,/<\/ControllerTag>/d' TagTable.xml
```

#### Classic HMI Screen XML Import Pitfalls

**Screen number uniqueness**: Screen `<Number>` must be unique. Check existing screens with `GetHmiProgramInfo` before import. Error: `The "screen number '1' for screen 'Main' is not unique for this device.` Fix: Patch `<Number>1</Number>` → `<Number>2</Number>` (any unused number).

**Button `Visible` property not supported**: Classic HMI Button objects do not support `set_Visible` via Openness import. Error: `'set_Visible' is not supported by type 'Siemens.Engineering.Hmi.Screen.Button'.` Fix: Strip all `<Visible>true</Visible>` and `<Visible>false</Visible>` elements before import (regex: `\s*<Visible>(true|false)</Visible>\s*`).

**Other unsupported properties**: If a different property fails with `'set_X' is not supported`, identify the offending property and strip the XML element. Common offenders: `Visible`, `Enabled`, `Password`, `TooltipText`.

## 6. Verification and Save

- `CompileAndDiagnosePlc` after every block import — catches interface mismatches early.
- `ValidateAutomationContext` for end-of-session health check.
- `GetSoftwareTree` to confirm block hierarchy before and after changes.
- `SaveProject` persists before disconnecting.

## 7. TIA Portal Stability Recovery

When TIA Portal returns "Access to a disposed object" or MCP server becomes unreachable after repeated errors:

1. **`SaveProject` first** if possible — in-memory changes (tag imports, screen imports) are lost on disconnect.
2. `Disconnect`
3. Wait 30-60s if MCP says unreachable
4. `Connect`
5. `OpenProject` with full `.apXX` path
6. **Re-verify HMI/PLC state** — re-import anything that was added before the crash.
7. Retry the failed operation

## 8. Efficiency Rules

1. **Batch HMI tag creation**: all tags can be called in parallel after the first one confirms the parameter pattern.
2. **PlcBuildAndImport dryRun check**: the "discovered" / "classified" fields tell you whether the JSON was valid BEFORE spending time on import.
3. **HMI property writes are spotty**: don't fight them — focus on functional bindings (tags, actions) and skip visual styling for generated projects.
4. **Internet search for Siemens catalog data**: when unsure about order numbers, SearchHardwareCatalog is the authoritative source. For speed/torque curves and mechanical specs, web search Siemens industry mall PDFs.

## 9. Device Selection Quick Reference

| Device | OrderNumber | Type |
|--------|------------|------|
| S7-1215C DC/DC/DC | 6ES7 215-1AG40-0XB0 | CPU 1215C |
| TP1200 Comfort | 6AV2 124-0MC01-0AX0 | HMI Comfort |
| V90 PN 200W | 6SL3 210-5FB10-2UFx | SINAMICS Drive |

## 10. Support Files

- `references/mcp-server-setup.md` — MCP server binary installation and Hermes/Claude Code configuration.
- `references/motor-control-db-layout.md` — DB layout reference for motor control.
- `references/v90-control-reference.md` — STW1/ZSW1 bit maps, speed normalization formulas, OB1 call pattern.
- `references/s7dcl-lad-reference.md` — Full S7DCL grammar: 99+ instructions, template table (16 rows), 31 traps, comparison boxes GT/LT/EQ/NE/GE/LE, LAD+SCL counter dual mode, chain calculation, complex OR patterns. Cross-validated: PDF Entry ID 109994073 + 0-error reference FB + FB_CompleteInstructionGallery (67 networks, 0 errors) + Claude Code TIA V21 import sessions (2026-06-11).
- `references/claude-code-s7dcl-import-errors.md` — Root cause catalog from 10 Claude Code TIA V21 import iterations: 10 error patterns with wrong→right syntax, verified correct patterns, template quick-check table.
- `references/s7dcl-template-verification.md` — Template verification methodology: how to cross-check template names against a 0-error reference program, corrected template table for all 12 families, verified instruction shapes (P_Trig vs P_Contact, LIMIT pins, S7_GenerateENO), and newly discovered patterns (chained ENO-boxes, multi-output coils, complex OR).
- `references/ds-sd-support-analysis.md` — DS (.s7dcl) tooling inventory, XML-vs-DS capability gap, and development roadmap.
- `references/siemens-doc-sources.md` — Siemens documentation sources and catalog references.
- `templates/FC_V90_Control.scl` — Complete SCL source template for V90 PN control via standard telegram 1.

For architecture reference and developer workflows, load skill `tia-mcp-dev`.

## 11. Common Pitfalls

| Symptom | Cause | Fix |
|---------|-------|-----|
| HMI tag `InternalOnly` | Missing connectionName/plcName | Pass all 4: connectionName, plcName, address, plcTag |
| Property write fails on Rectangle | ForeColor/FontSize unsupported | Use separate HmiText item or accept defaults |
| Button event handler wrong | Used "Pressed" enum value | Use "Down" or "Up"; not "Pressed"/"Released" |
| PlcBuildAndImport dryRun fails | Wrong JSON structure | FC requires inputs+outputs arrays; check BuildPlc*Xml format |
| Device path not found | Path missing intermediate DeviceItem | Use `PLC_1/PLC_1/PROFINET 接口_1` not `PLC_1/PROFINET 接口_1` |
| Import fails: "engineering version V21 not supported" | V20 TIA, V21 XML header | dryRun → patch version → ImportBlock (see 4b) |
| Import fails: "token not supported" | Comment/bit-access in SCL XML | Use whole-word assignments, no inline comments (see 4c) |
| GetDeviceItemInfo fails on Chinese paths | Path-based tools can't resolve Chinese chars | Use reflection tools: DescribeObject/ListObjectChildren |
| Screen import: number not unique | Duplicate screen <Number> | Patch <Number> to unused value |
| Screen import: set_Visible not supported | Classic Button has no Visible setter | Strip <Visible> elements from XML |
| Tag import: "data type Word not found" | Comfort doesn't support Word | Replace with UInt |
| Tag import: "connection not found" | Classic HMI connection doesn't exist | Remove Connection/ControllerTag from XML, import as internal |
| "Access to a disposed object" | TIA Portal session corrupted | Follow stability recovery in section 7 |
| read_file in execute_code returns dedup | Hermes dedup cache | Use `terminal("cat path")` inside execute_code |
| SetCpuCommonSettings IP rejected | IP is on PROFINET interface, not CPU | GetDeviceItemInfo on interface DeviceItem first |
| s7dcl import fails silently | .s7dcl/.s7res has BOM/MLC/wire/pragma errors | Run `ValidateS7dclDocuments(dir)` offline before importing |
| MIN/MAX/LIMIT/SEL template error | Used `SrcType` instead of `value_type` | Use `value_type := Int` (see §4f template table) |
| MUX template error | Used `value_type` for MUX | MUX uses `SrcType := Int` — different from other selectors! |
| Timer template error | Used `timeType` (camelCase) | Use `time_type := Time` (underscore, not camelCase!) |
| Counter template error | Used `countType` | Use `value_type := Int` |
| Shift/Rotate/NEG missing template | Omitted template pragma | Use `SrcType := DWord` (Shr/Shl) or `SrcType := Real` (NEG) |
| Convert template error | Used `inType`/`outType` | Use `SrcType`/`DestType` in array format |
| P_Contact "Pin 'bit' missing" | Missing edge memory bit parameter | Use `P_Contact(operand:=sig, bit:=#mem)` |
| JMP/LABEL/RET import rejected | Not importable via S7DCL | Edit in TIA Portal UI directly |
| Used CMP >= / CMP <= box syntax | S7DCL has no CMP box! | Use `GT(in1:=,in2:=,out=>)` with SrcType |
| Contact(Negated(#Var)) in s7dcl | Negated() does not exist in S7DCL | Use `Not()` after Contact, or `I_Contact` |
| Not() at RUNG start position | LAD requires preceding contacts | Put after Contact: `Contact → Not → Coil` |
| wire# between Contact and Box | Breaks EN / pre pin connection | Box directly after preceding element |
| Two boxes in same RUNG series | ENO→EN does not chain | Split into separate networks |
| CTU/CTD/CTUD LAD inline cu/r/cd/ld uppercase | Uppercase pins in LAD | LAD用小写(`r`/`pv`/`cv`); SCL用大写(`CU`/`R`/`PV`/`CV`) — see §4h |
| Counter SCL split assignment | Parameter "already used" error | All pins in one statement: `inst.CTU(CU:=...,PV:=...,Q=>...)` |
| Counter Static uses IEC_COUNTER | Wrong type | Use `CTU_INT`/`CTD_INT`/`CTUD_INT` |

## 12. Claude Code LAD Internal Errors (AI Confusion Patterns)

> Based on 10 Claude Code TIA V21 import iteration sessions (2026-06-11).
> These are patterns the AI will tend to hallucinate — intercept them before code generation.

| # | AI Tendency | Why It's Wrong | Correct |
|---|------------|----------------|---------|
| 1 | Wraps into non-existent functions | `Negated(#Var)` looks like valid S7DCL nesting | No nesting: `I_Contact` or `Contact→Not` |
| 2 | Puts `Not()` at RUNG start | SCL-style thinking (NOT can be first in SCL) | LAD needs preceding contact: `Contact→Not→Coil` |
| 3 | Uses `CMP >=(in1:=,in2:=)` | Naive translation of TIA UI comparison box | `GT(in1:=,in2:=,out=>)` — different name + output pin |
| 4 | Inserts `wire#` between Contact and Box | Thinks wire# is "serial connector" | Box must DIRECTLY follow — wire# only for PARALLEL branches |
| 5 | Uses SCL-style `inst.CU:=; inst(); inst.Q` | Familiar SCL pattern | S7DCL SCL must use `inst.CTU(CU:=...,Q=>...);` — method call in one statement |
| 6 | Tries `cu:=` inline in LAD counter | Assumes all pins are inline-assignable | LAD: count pin driven by EN; only `r`/`pv`/`cv` explicit with lowercase |
| 7 | Omits double-quotes on var names | `#SET` looks cleaner | MUST use `#"SET"` — TIA requires quotes |
| 8 | Invents comparison boxes as contacts | Puts `GT_Contact` where a box should be, then `GT()` without `out=>` | Contact form: `GT_Contact + Coil`; Box form: `GT(..., out=>)` |
| 9 | Forgets P_Trig before counter | Assumes CTU counts on EN level | LAD CTU needs `P_Trig` for edge-triggered counting |
| 10 | Leaves stale MLC in .s7res after editing .s7dcl | Incremental edit only touches .s7dcl | MUST sync .s7res — remove unused MLC, add new ones |
