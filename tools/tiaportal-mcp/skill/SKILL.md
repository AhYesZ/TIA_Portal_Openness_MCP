---
name: tiaportal-mcp
description: Drive Siemens TIA Portal (鍗氶€? end-to-end through the TiaMcpServer MCP plugin. Use whenever the user mentions TIA Portal, 鍗氶€? STEP 7, WinCC, S7-1200/1500, PLC, HMI, SCL, LAD, STL, Openness, or asks to create/modify/compile/download a project. Always start by calling the `Bootstrap` tool 鈥?it returns environment status and the recommended next tool.
---

# TIA Portal MCP 鈥?Single Skill

This is the operating skill for TIA Portal MCP automation. The
companion plugin lives at `tools/tiaportal-mcp/`. It exposes on the order of
**184** MCP tools in this bundle snapshot (exact runtime set: call `tools/list` on the running server) covering
project, hardware, PLC, HMI, and online operations.

## 0. Always start here

```
1. Call Bootstrap                        鈫?returns env, project state, next step
2. Follow RecommendedNextTool            鈫?e.g. Connect, AttachToOpenProject
3. Call GetProjectTree                   鈫?resolve real paths (PLC_1, HMI_RT_1)
4. Read-before-write loop                鈫?inspect, smallest change, compile, save
```

**浜や粯鍖呭唴鏈€鐭矾寰勶紙浠呰鍖呭唴鏂囦欢鏃讹級**  
鏍圭洰褰?`README.md`锛堜笁姝ヤ笂鎵嬶級鈫?`scripts/Validate-Bundle.ps1`锛堣劚鏈烘牎楠岋級鈫?鐢?`cursor-mcp.example.json` 鎶?`command` 鎸囧埌鍖呭唴 `TiaMcpServer.exe` 鈫?鎵ц椤哄簭瑙?`docs/full-project-generation-runbook.md` 涓?`templates/project-blueprints/full_plc_hmi_project.json`銆?
Never guess paths. Never invent SCL/LAD XML. If a tool exists for the task, use
it; otherwise inspect with `DescribeObject`/`DescribeService` first, then call
`InvokeObject`/`InvokeService`.

## 1. Tool layers

The `Description` of every tool starts with one of three layer tags:

| Tag | Meaning | When to use |
|---|---|---|
| `[L0]` | Bootstrap / read-only diagnostics | First call of a session, environment checks |
| `[L1]` | Common workflow tool | 80% of normal sessions only need L0+L1 |
| `[L2]` | Domain / advanced tool | Reach for these by name only after L0/L1 fails or when a specific need arises |

Core L0/L1 set:

```
L0  Bootstrap, GetState, RunCapabilitySelfTest, RunOnlineMonitoringSafetySelfTest,
    GenerateAcceptanceReport, GenerateErrorReport
L1  Connect, Disconnect, AttachToOpenProject, OpenProject, CreateProject,
    SaveProject, CloseProject, GetProjectTree, GetSoftwareTree, GetSoftwareInfo,
    PlcBuildAndImport, CompileSoftware, CompileAndDiagnosePlc,
    DownloadToPlc, CheckDownloadReadiness, GoOnline, GoOffline, GetOnlineState,
    EnsureOpennessUserGroup, ListPortalProcessProjects, GetProject,
    GetDevices, AddDeviceWithFallback, SearchHardwareCatalog,
    ImportBlock, ImportType, ImportPlcTagTable,
    ConnectDeviceNodesToProfinetSubnet, ValidateAutomationContext
```

## 2. Connecting an AI client to the MCP server

### stdio (Claude Desktop, Cursor, VS Code MCP)

```json
{
  "mcpServers": {
    "tia-portal": {
      "command": "C:\\path\\to\\TiaMcpServer.exe",
      "args": []
    }
  }
}
```

### HTTP (any client that speaks JSON-RPC)

```powershell
TiaMcpServer.exe --transport http --http-prefix http://127.0.0.1:8765/ --http-api-key <secret>
```

Endpoints:

| Method + Path | Purpose |
|---|---|
| `POST /mcp` | One JSON-RPC message per request |
| `GET /mcp/health` | Liveness + session count + build version |
| `DELETE /mcp` | Terminate session (best-effort) |

Auth (when `--http-api-key` is set): either header works 鈥?pick whichever your
client supports:

```
Authorization: Bearer <secret>
X-API-Key: <secret>
```

Set `Accept: text/event-stream` to get the response wrapped as a single SSE
message event (for spec-compliant clients). Otherwise the response is plain JSON.

`Mcp-Session-Id` is generated on the first call and echoed back; subsequent
calls may include it for client-side correlation. State is **not** isolated
across sessions because TIA Portal itself is process-wide.

### 璋冪敤鏂瑰紡鎬庝箞閫夛紙閬垮厤韪╁潙锛?
| 鍦烘櫙 | 鎺ㄨ崘 |
|------|------|
| **Cursor / Claude Desktop / VS Code锛圡CP stdio锛?* | `mcpServers.command` 鎸囧悜鍖呭唴 `TiaMcpServer.exe`锛宍args: []`銆傜敱瀹㈡埛绔畬鎴?MCP 鎻℃墜锛岀洿鎺ヨ皟 `tools/call`銆?|
| **鍋ュ悍妫€鏌?/ 鏄惁宸插惎鍔?* | `GET /mcp/health`锛堜粎鎺㈡椿锛屼笉鏇夸唬 MCP 鍗忚锛?|
| **HTTP 鑷啓鑴氭湰** | 闇€瀹炵幇 **瀹屾暣** MCP JSON-RPC 浼氳瘽锛堝 `initialize`銆侀儴鍒嗗満鏅笅 SSE / `Mcp-Session-Id`锛夛紝**涓嶈**瀵?`POST /mcp` 鍙彂鍗曟潯瑁?`tools/call` 灏辨湡鏈涜繑鍥烇紝鍚﹀垯鏄撻暱鏃堕棿闃诲銆?|

## 3. Read-before-write workflow (the only one that matters)

```
GetProjectTree                       resolve PLC/HMI paths
ExportBlock|GetBlockInfo|...         inspect what already exists
PlcBuildAndImport (kind=fc|udt|...)  smallest safe change
CompileSoftware                      must end with errors=0 warnings=0
SaveProject                          persist to disk
```

`PlcBuildAndImport` is the preferred entry for declarative PLC objects (UDT,
tag table, GlobalDB, FC, FB) 鈥?it generates Openness XML and imports in one
call. Use the lower-level `ImportBlock`/`ImportType`/`ImportPlcTagTable` only
when you already have hand-crafted XML.

## 4. What this MCP cannot do (V21 PublicAPI limits)

These have NO Openness API 鈥?do not try to invent reflection workarounds:

- Read or change CPU operating mode (RUN/STOP/STARTUP) 鈫?use OPC UA
- Read CPU fault/diagnostic buffer 鈫?use OPC UA
- ClearForces / Unforce / per-block selective download
- Trigger Safety F-CPU compile (must be done in TIA UI manually)

Force/Watch table tools edit the project-side definition; values become
effective only after the project is online and the table trigger fires.

Full list (this bundle): `鎵嬪唽/openness-limitations.md` (bundle root: same folder as `README.md`).

## 5. Encoding & PowerShell traps (script drivers only)

- The server itself sets `Console.InputEncoding = Console.OutputEncoding = UTF-8`
  on startup (since v0.0.27 + the 2026-05-11 patch). Without that, Chinese
  project names / device names / `commentZhCn` payloads become `???` over stdio.
  If you fork an older build, you must add it yourself.
- Generated `.scl` external sources and any Chinese text destined for TIA
  import must be **UTF-8 with BOM**.
- PowerShell 5.1 reads `.ps1` as the system code page (GBK on zh-CN Windows)
  unless the file is UTF-8-with-BOM. Any path containing Chinese (e.g.
  Chinese characters) breaks `Process.Start` if the script itself is bare UTF-8.
- `.NET Framework 4.8` does NOT have `ProcessStartInfo.StandardInputEncoding`
  (Core-only API). To send UTF-8 to a child server's stdin from PowerShell:

  ```powershell
  $proc = [System.Diagnostics.Process]::Start($psi)
  $stdinUtf8 = New-Object System.IO.StreamWriter(
      $proc.StandardInput.BaseStream,
      (New-Object System.Text.UTF8Encoding($false)))
  $stdinUtf8.AutoFlush = $true
  $stdinUtf8.WriteLine($jsonRpcLine)   # use this; do NOT use $proc.StandardInput
  ```

- Reading stdio responses: cache the pending `ReadLineAsync` task between
  iterations. Calling `ReadLineAsync` twice on the same stream before the
  first one completes throws `"娴佹鍦ㄧ敱鍏朵笂鐨勫墠涓€鎿嶄綔浣跨敤"`.

  ```powershell
  if ($null -eq $script:pending) { $script:pending = $proc.StandardOutput.ReadLineAsync() }
  if (-not $script:pending.Wait($remainMs)) { continue }
  $line = $script:pending.Result; $script:pending = $null
  ```

- Tool failures often surface as `result.isError = true` with
  `content[0].text = "An error occurred invoking 'X'"` rather than as a
  JSON-RPC `error`. Check both shapes; the real exception text is on stderr.
- Don't read tool-call response text via regex 鈥?the server JSON-encodes
  Chinese as `\uXXXX`. Always `ConvertFrom-Json` the `text` field first, then
  read named properties (`.items[0].name`, `.tree`, ...).

## 6. Bundle-only docs + copy-paste JSON for `PlcBuildAndImport` / Unified HMI

Paths below are relative to the **delivery bundle root** (the folder that contains `README.md`, `鎵嬪唽/`, and `tools/`).

### 6.1 Authoritative files shipped in this bundle

| Need | Path |
|---|---|
| Setup + MCP wiring | `鎵嬪唽/quickstart.md` |
| What Openness cannot do | `鎵嬪唽/openness-limitations.md` |
| Error model | `鎵嬪唽/error-model.md` |
| NL 鈫?tool sequences (16 scenarios) | `鎵嬪唽/TIA_NL_INTENT_RECIPES.md` |
| Static tool roster | `manifest/tools-list.json` |
| Tool capability matrix | `docs/tool-capability-matrix.md` |
| Full PLC+HMI project blueprint | `templates/project-blueprints/full_plc_hmi_project.json` |
| Full project runbook | `docs/full-project-generation-runbook.md` |
| Offline bundle validation (no TIA start) | `scripts/Validate-Bundle.ps1` |
| IDE-neutral MCP + tool list authority | `docs/mcp-ide-and-tool-visibility.md` |
| HMI鈫擯LC symbolic / absolute / red-tag troubleshooting | `docs/hmi-plc-tag-binding-and-addressing.md` |
| Optional `reference/` sample projects (outside bundle) | `docs/optional-reference-materials.md` |
| PLC network & instruction expansion patterns | `docs/plc-network-patterns-expanded.md` |
| Importable LAD XML samples | `tools/tiaportal-mcp/skill/lad-cookbook/*.xml` |
| External SCL sources (UTF-8 BOM on disk) | `tools/tiaportal-mcp/skill/scl-cookbook/*.scl` |

The static files are for planning and parser grounding; run `tools/list` on the
live MCP server for the authoritative runtime roster. There is **no** bundled
Siemens STEP7/WinCC manual tree.

### 6.2 `PlcBuildAndImport` 鈥?minimal `json` shapes (always `dryRun=true` first)

Pass `json` as a **string** (escape quotes in MCP args). Replace
`softwarePath` / group paths with values from `GetProjectTree`.

**`kind=udt`**

```json
{"name":"UDT_MCP_Demo","members":[{"name":"Speed","datatype":"Int","externalWritable":false}]}
```

**`kind=tagtable`**

```json
{"tableName":"MCP_DemoTags","tags":[{"name":"DemoRun","dataTypeName":"Bool","logicalAddress":"%M0.0"}]}
```

**`kind=globaldb`**

```json
{"dbName":"GDB_MCP_Demo","dbNumber":1,"staticMembers":[{"name":"Counter","datatype":"Int","startValue":"0"}]}
```

**`kind=fc`** (ST body from `structuredText.operations`; `op` includes `if`,
`elsif`, `else`, `endif`, `assignment`, `line`, 鈥?

```json
{
  "blockName":"FC_MCP_Demo",
  "blockNumber":1,
  "inputs":[{"name":"InRun","datatype":"Bool"}],
  "outputs":[{"name":"OutOk","datatype":"Bool"}],
  "structuredText":{"operations":[{"op":"assignment","target":"OutOk","literalValue":"TRUE"}]}
}
```

**`kind=fb`**

```json
{
  "blockName":"FB_MCP_Demo",
  "blockNumber":2,
  "inputs":[{"name":"En","datatype":"Bool"}],
  "outputs":[{"name":"Busy","datatype":"Bool"}],
  "statics":[],
  "structuredText":{"operations":[{"op":"assignment","target":"Busy","literalValue":"FALSE"}]}
}
```

### 6.3 Unified HMI 鈥?minimal `designJson` for `ApplyUnifiedHmiScreenDesignJson`

Keys are **lowercase**. Colors: ARGB hex strings like `0xAARRGGBB`. Call
`EnsureUnifiedHmiScreen` before apply. Button bit actions:
`EnsureUnifiedHmiButtonAction` with `eventType` **`Down` / `Up` / `Tapped`**
( **`Pressed` / `Released` are wrong** ). Full recipe + schema: **搂12** below.

```json
{
  "screen":{"BackColor":"0xFFF8FAFC"},
  "items":[
    {"type":"Rectangle","name":"Panel","left":24,"top":80,"width":400,"height":200,"properties":{"BackColor":"0xFFFFFFFF","BorderWidth":1}},
    {"type":"Text","name":"Lbl","left":40,"top":100,"width":200,"height":28,"text":"Demo","font":{"Size":16}},
    {"type":"Button","name":"StartBtn","left":40,"top":160,"width":120,"height":44,"text":"Start"},
    {"type":"IOField","name":"SpFld","left":180,"top":160,"width":100,"height":40}
  ]
}
```

## 7. Common end-to-end shapes

### Build a minimal new project

```
Bootstrap 鈫?Connect 鈫?CreateProject(<dir>, <name>_<timestamp>)
鈫?AddDeviceWithFallback(CPU)
鈫?AddHardwareCatalogDeviceWithProbe(HMI)       (optional)
鈫?ConnectDeviceNodesToProfinetSubnet           (optional)
鈫?PlcBuildAndImport(kind=tagtable, ...)
鈫?PlcBuildAndImport(kind=globaldb, ...)
鈫?PlcBuildAndImport(kind=fc|fb, ...)           (one per logic unit)
鈫?CompileSoftware                              (must be 0/0)
鈫?SaveProject 鈫?Disconnect
```

### Deploy to a real CPU

```
Bootstrap 鈫?AttachToOpenProject
鈫?CompileSoftware
鈫?CheckDownloadReadiness
鈫?DownloadToPlc(keepActualValues=true)
鈫?GetOnlineState 鈫?SaveProject
```

### Watch/Force values

```
Bootstrap 鈫?AttachToOpenProject 鈫?GoOnline
鈫?SetForceTableEntry(address, value)           force, persistent until cleared
鈫?SetWatchTableModifyValue(address, value)     one-shot modify
鈫?GoOffline
```

For more scenarios (alarms, OPC UA, multi-language text, Unified HMI pages)
see `鎵嬪唽/TIA_NL_INTENT_RECIPES.md` (bundle root).

## 8. Frequently used tools 鈥?exact parameter names

The table below lists **exact parameter names** that commonly trip parsers. When
in doubt, confirm with `tools/list` / `Bootstrap` on your build.

| Layer | Tool | Required args (verified names) | Notes |
|---|---|---|---|
| L0 | `Bootstrap` | 鈥?| Read-only orientation; returns `{ready, environment, portal, recommendedNextTool, toolLayers, knownLimits}` |
| L0 | `GetState` | 鈥?| Cheap probe; returns `{isConnected, project, session}` |
| L0 | `RunCapabilitySelfTest` | `inspectPortalProcesses=false`, `includeProjectTree=false` | ~15 ms when light; sets pass/fail per capability |
| L1 | `Connect` | 鈥?| Attaches to a running TIA process; first call may pop Openness auth dialog in TIA UI |
| L1 | `AttachToOpenProject` | `projectName` (must match the leaf shown in TIA window title) | Cleanest path when a project is already open. Avoids `CreateProject` pollution |
| L1 | `GetProject` | 鈥?| Lists open projects + multi-user sessions |
| L1 | `GetProjectTree` | 鈥?| Returns ASCII tree string 鈥?parse with `Devices`/`PLC Software` markers |
| L1 | `GetDevices` | 鈥?| Returns `items[].name` (e.g. `PLC_1`) and `description` |
| L1 | `SearchHardwareCatalog` | `keyword` (e.g. `"1211C"`) | ~500 ms; needs Connect; returns `count` + `items[]` |
| L1 | `GetSoftwareInfo` | `softwarePath` (e.g. `"PLC_1"`) | Returns class name (e.g. `Siemens.Engineering.SW.PlcSoftware`) |
| L1 | `GetSoftwareTree` | `softwarePath` | Returns ASCII tree with `Program blocks`, `PLC tags`, etc. |
| L1 | `GetBlocks` | `softwarePath` | Returns `items[]` with `typeName`/`name`/`programmingLanguage` (LAD/SCL/STL) |
| L1 | `PlcBuildAndImport` | `softwarePath`, `kind=tagtable`, `json={tableName,tags:[{name,dataTypeName,logicalAddress}]}`, `dryRun=true` | dryRun writes XML to `%TEMP%\tia_mcp_plc_build_import_*` without touching project |
| L1 | `PlcBuildAndImport` | `softwarePath`, `kind=globaldb`, `json={dbName,dbNumber,staticMembers:[{name,datatype,startValue}]}`, `dryRun=true` | Same pattern |
| L1 | `PlcBuildAndImport` | `softwarePath`, `kind=fc`, `json={blockName,blockNumber,inputs,outputs,structuredText:{operations:[...]}}`, `dryRun=true` | `op` 鈭?`if`/`elsif`/`endif`/`assignment`/`line` |
| L2 | `BuildPlcTagTableXml` | `tagTableJson` (note: NOT `tableJson`) | Pure offline; returns `{xml}` |
| L2 | `ComposePlcFcBlockXml` | `fcBlockJson` | Pure offline; returns `{xml}` |
| L2 | `BuildClassicHmiScreenXml` | `designJson={Screen:{Name,Width,Height},Items:[{Type,Name,Left,Top,Width,Height,Text}]}` (PascalCase) | Pure offline; for Classic/Basic HMI |
| L2 | `GetOnlineState` | `softwarePath` | Returns `{state:"Offline"\|"Online", isOnline, isReachable, message}` |
| L2 | `CheckDownloadReadiness` | `softwarePath` | Returns `{ready, hasDownloadProvider, hasConfiguration, isConsistent}` |
| L1 | `SaveProject` | 鈥?| Verified safe on attached project |
| L1 | `Disconnect` | 鈥?| Always end with this |

### Attach-mode workflow (no pollution, preferred when TIA already has a project open)

```
Bootstrap                                     鈫?env + recommendedNextTool
Connect                                       鈫?may need Openness UI click on first call
GetProject  鈫? items[0].name                  鈫?internal Project.Name; TIA window title may differ
AttachToOpenProject(projectName=<that name>)  鈫?reuse existing project
GetProjectTree                                鈫?never guess paths
                                               regex 'PlcSoftware:\s*([^\s\[]+)' 鈫?all PLC softwarePaths
GetDevices                                    鈫?returns station containers, not CPUs
                                               鈫?use GetProjectTree to find real PLC names
GetSoftwareTree / GetBlocks / GetSoftwareInfo 鈫?inspect
PlcBuildAndImport(dryRun=true)                鈫?validate XML without modifying project
GetOnlineState / CheckDownloadReadiness       鈫?read-only diagnostics
Disconnect
```

### Real-write on a Chinese-named device (verified 2026-05-11 against `瀹夊叏PLC`)

```
Connect
GetProject                                     鈫?"姹熷娴嬭瘯椤圭洰V21-260511"
AttachToOpenProject(projectName="姹熷娴嬭瘯椤圭洰V21-260511")
GetProjectTree                                鈫?discover "PlcSoftware: 瀹夊叏PLC"
PlcBuildAndImport(softwarePath="瀹夊叏PLC", kind="tagtable", json=鈥? dryRun=false) 鈫?10s, ok
PlcBuildAndImport(softwarePath="瀹夊叏PLC", kind="globaldb", json=鈥? dryRun=false) 鈫?5s, ok
PlcBuildAndImport(softwarePath="瀹夊叏PLC", kind="fc",       json=鈥? dryRun=false) 鈫?5s, ok
GetBlocks(softwarePath="瀹夊叏PLC", namePattern="MCPVerify_*") 鈫?confirms imported blocks
CompileSoftware(softwarePath="瀹夊叏PLC")        鈫?18s, errorCount=0 (warnings ok)
CheckDownloadReadiness / GetOnlineState        鈫?ready=true / state=Offline
SaveProject 鈫?Disconnect
```

Use a unique prefix (`MCPVerify_`, `MCP_`, etc.) for any object you write into a
real shared project 鈥?the user can find and delete them in TIA UI later.

### Common parameter-name traps

| Tool | Wrong (silently 500s) | Correct |
|---|---|---|
| `BuildPlcTagTableXml` | `tableJson` | `tagTableJson` |
| `BuildClassicHmiScreenXml` | `screenJson` | `designJson` |
| `ComposePlcFcBlockXml` | `blockJson` | `fcBlockJson` |
| `AttachToOpenProject` | `name` | `projectName` |

PowerShell-side: call shape that works with `tools/call`:

```powershell
$resp = Send-Request 'tools/call' @{ name='PlcBuildAndImport'; arguments=@{
    softwarePath='PLC_1'; kind='tagtable'; dryRun=$true
    json='{"tableName":"DefaultTagTable","tags":[{"name":"Start","dataTypeName":"Bool","logicalAddress":"%I0.0"}]}'
} } 30000
```

## 9. LAD native instructions (verified 2026-05-11 against `瀹夊叏PLC`)

LAD blocks live in `<FlgNet xmlns="http://.../FlgNet/v5">` with two collections:
`Parts` (operands + instructions) and `Wires` (pin-to-pin energy flow).

A 7-network reference FC that imports cleanly (`errorCount=0`) and covers the
core instruction set is at:

```
tools/tiaportal-mcp/skill/lad-cookbook/MCPVerify_FC_LAD.xml
```

It exercises:

| Network | Instruction(s) | Part Name(s) | Pin set |
|---|---|---|---|
| 1 | Two contacts in series 鈫?coil | `Contact`, `Contact`, `Coil` | `in/out/operand` |
| 2 | Two contacts in parallel (OR) 鈫?coil | `Contact`, `Contact`, `O`, `Coil` | OR-box: `in1/in2/out` |
| 3 | Set coil | `Contact`, `SCoil` | `in/operand` |
| 4 | Reset coil | `Contact`, `RCoil` | `in/operand` |
| 5 | Compare `>` literal 鈫?coil | `Gt` (`<TemplateValue Name="SrcType" Type="Type">Int</TemplateValue>`), `Coil` | Compare: `pre/in1/in2/out` |
| 6 | Move literal 鈫?variable | `Move` (`<TemplateValue Name="Card" Type="Cardinality">1</TemplateValue>`) | Move: `en/eno/in/out1` |
| 7 | Add Int+Int 鈫?Int | `Add` (SrcType+Card templates) | Add/Sub/Mul/Div: `en/eno/in1/in2/out` |

Verified `Part Name` registry (more exist; these are the ones live-tested):

```
Contact          甯稿紑瑙︾偣 (add <Negated Name="operand"/> for 甯搁棴)
Coil / SCoil / RCoil   绾垮湀 / 缃綅 / 澶嶄綅
O                骞惰仈 OR-box (TemplateValue Name="Card" = inputs count)
PBox / NBox      涓婂崌娌?/ 涓嬮檷娌?Gt / Lt / Eq / Ne / Ge / Le   姣旇緝 (TemplateValue SrcType=Int|DInt|Real|Word|...)
Add / Sub / Mul / Div         绠楁湳 (SrcType + Card templates)
Move             浼犻€?(Card=1 normally)
TON / TOF / TP   IEC 瀹氭椂鍣?(require <Instance Scope="LocalVariable|GlobalVariable" UId="鈥?><Component Name="..."/></Instance>; only inside FB or with explicit IDB)
Calc             琛ㄨ揪寮忓潡 (<Equation>...</Equation> + Card + SrcType)
Serialize / Deserialize / SCATTER / GATHER   瀛楄妭绾ц浆鎹?```

Connection reference (`Wires` rules):

```
<Wire UId="鈥?>
  <Powerrail/>                宸︾姣嶇嚎锛堣兘娴佸叆鍙ｏ級
  <NameCon UId="P" Name="鈥?/> 鎺ュ埌 Part P 鐨勫懡鍚嶅紩鑴?  <NameCon UId="P2" Name="鈥?/> 澶氫釜 NameCon = 骞惰仈鍚屾椂椹卞姩澶氫釜 Part
</Wire>

<Wire><IdentCon UId="V"/><NameCon UId="P" Name="operand"/></Wire>
                                     鍙橀噺/瀛楅潰閲?V 鎺ュ埌 P 鐨?operand/in/...
<Wire><NameCon UId="P1" Name="out"/><NameCon UId="P2" Name="in"/></Wire>
                                     P1.out 涓茶仈鍒?P2.in
```

### LAD pitfalls (these all bit me 鈥?read once, save hours)

1. **`UId` inside `<FlgNet>` MUST be decimal `xs:int`**, NOT hex. Block-level
   `ID` attributes ARE hex strings (`"A"`, `"B"`, `"10"`, `"1A"`...) and they
   live in a separate namespace. Mixing them gives the cryptic Simatic ML
   error: `UId 灞炴€ф棤鏁?- 绫诲瀷 鈥MLSchema:int 鐨勫€?"2A" 鏃犳晥`.
2. **Strip every `<!-- -->` XML comment** before import 鈥?Openness rejects them.
3. **Escape `&` `<` `>`** in any `<Text>`/comment 鈥?TIA reports
   `鍒嗘瀽 EntityName 鏃跺嚭閿欍€?绗?N`.
4. The `ProgrammingLanguage` element appears **twice**: once at block level
   (`<SW.Blocks.FC>/AttributeList/ProgrammingLanguage>LAD`) and once per
   `CompileUnit` (`AttributeList/ProgrammingLanguage>LAD`). Mixing SCL and LAD
   networks is allowed if you set the per-CompileUnit value accordingly.
5. Importing `Contact + Coil + Compare/Move/Add` to a **safety PLC** standard
   block group works 鈥?these are standard instructions; safety F-FCs need
   different builders we don't ship yet.
6. After `ImportBlock`, server now surfaces the real Openness exception
   chain (Portal.cs `UnwrapImportError`, since 2026-05-11). Don't reinterpret
   `"Import failed"` 鈥?read everything after the colon.

To create a new LAD FC, copy `MCPVerify_FC_LAD.xml`, change `Name`, `Number`,
`Interface/Sections`, and rebuild networks. Then:

```
ImportBlock(softwarePath="<plc>", groupPath="", importPath="<your.xml>")
CompileSoftware(softwarePath="<plc>")        鈫?errorCount must be 0
```

## 10. SCL via DSL (verified 2026-05-11)

`PlcBuildAndImport(kind=fc, json={鈥tructuredText.operations})` is the supported
DSL. Verified ops: `assignment`, `if`, `else`, `endif`, `line`, `token`,
`blank`, `newline`, `symbol`, `local`, `global`, `literal`.

```jsonc
{
  "blockName": "MyFc", "blockNumber": 902,
  "inputs":  [{"name":"Reset","datatype":"Bool"}, {"name":"Speed","datatype":"Real"}],
  "outputs": [{"name":"Out","datatype":"Real"}, {"name":"Mode","datatype":"Int"}],
  "structuredText": { "operations": [
    {"op":"assignment","target":"Out","literalValue":"0.0"},
    {"op":"if","condition":"Reset"},
      {"op":"assignment","target":"Out","literalValue":"0.0","indent":1},
      {"op":"assignment","target":"Mode","literalValue":"0","indent":1},
    {"op":"else"},
      {"op":"line","indent":1,"items":[
        {"sym":"Out"},{"token":":="},{"sym":"Speed"},{"token":"*"},{"lit":"1.5"}
      ]},
      {"op":"assignment","target":"Mode","literalValue":"1","indent":1},
    {"op":"endif"}
  ]}
}
```

### SCL DSL limits (known)

- `if/elsif` `condition` accepts a **single boolean variable name** only 鈥?NOT
  expressions like `Mode = 1`. For multi-variable conditions, fall back to
  `op:"line"` (free-form token list, but it always appends `;` and newline,
  so it can't emit standalone `IF cond THEN` headers).
- `for`, `while`, `case`, `return`, `exit`, `continue`, `repeat` are NOT
  supported by the DSL. For these, hand-write the `<StructuredText>` token AST
  directly (or use a generic `op:"line"` chain 鈥?but the AST path is cleaner).
- `String`/`WString` outputs may compile-error in some safety standard groups;
  test with `dryRun=true` first.

## 11. LAD v2 鈥?extended instructions (verified 2026-05-11 against `瀹夊叏PLC`, errorCount=0)

A second cookbook FC adds 10 more instructions on top of 搂9. Imports cleanly
and compiles with errorCount=0 on Safety PLC standard side:

```
tools/tiaportal-mcp/skill/lad-cookbook/MCPVerify_FC_LAD_v2.xml   鈫?FC 902
```

| Network | Instruction | Part Name + required template values | Wire pin set |
|---|---|---|---|
| 1 | Eq Int | `Eq` `<TemplateValue Name="SrcType" Type="Type">Int</TemplateValue>` | `pre/in1/in2/out` |
| 2 | Ne Int | `Ne` SrcType=Int | same |
| 3 | Le Int | `Le` SrcType=Int | same |
| 4 | Ge Int | `Ge` SrcType=Int | same |
| 5 | Sub Int | `Sub` `DisabledENO="true"` SrcType=Int | `en/eno/in1/in2/out` |
| 6 | Mul Int | `Mul` SrcType=Int + `Card=2` | same |
| 7 | Div Int | `Div` SrcType=Int | same |
| 8 | Mod Int | `Mod` SrcType=Int | same |
| 9 | Convert Int鈫扲eal | `Convert` `<TemplateValue Name="SrcType">Int</TemplateValue>` `<TemplateValue Name="DestType">Real</TemplateValue>` | `en/eno/in/out` |
| 10 | Negated contact | `Contact` + child `<Negated Name="operand"/>` | `in/out/operand` |

Combined with 搂9, the verified native-LAD instruction set is:
contacts (NO/NC) 路 S/R coils 路 OR-box 路 Compare (Eq/Ne/Lt/Gt/Le/Ge) 路
Math (Add/Sub/Mul/Div/Mod) 路 Convert 路 Move.

Import `skill/lad-cookbook/MCPVerify_FC_LAD.xml` via `ImportBlock` and compile;
the FC encodes the v2 instruction sweep (8 networks).

### LAD v3 鈥?timers **must not** live in FC `Temp` on F-CPU; use FB `Static` or DB

**Rule (F-CPU / 瀹夊叏 PLC):** `TON` / `TOF` / `TP` **IEC timer instances** must
**not** be declared in an **FC** `Temp` section (not allowed 鈫?compile errors).
Valid options: **(1)** `TON_TIME` in **`FB` 鈫?`Static`** (with `SetPoint` on the
static member when the export shows it 鈥?see `Speed_Ctrl.xml`), **(2)** timer
in a **global DB** and `Instance Scope="GlobalVariable"` in LAD (see
`07-鎿嶄綔閫夋嫨.xml`), **(3)** author in TIA and `ExportBlock`.

**Repo layout:**

| File | Role |
|---|---|
| `skill/lad-cookbook/MCPVerify_FC_LAD_v3.xml` | FC **59990**, **Lt** only 鈥?quick LAD import sanity check |
| `skill/lad-cookbook/MCPVerify_FB_LAD_v3.xml` | FB **59989**, **Static** `tonInst : TON_TIME` + networks **TON**, **`PBox`**, **`Not`**, **`Lt`** |

Stage both XML files to a temp folder, import **FC then FB** with
`ImportBlock` into the PLC software path from `GetProjectTree`, then
`CompileSoftware` until `errorCount=0`.

**`PBox` wiring:** same operand for contact and `bit` needs **two** `Access`
entries with **different** `UId`s (two `IdentCon`s) 鈥?see `07-鎿嶄綔閫夋嫨.xml` in a
full repo export if you have one; otherwise follow the `MCPVerify_FB_LAD_v3`
export in `lad-cookbook`.

## 12. Unified HMI workflow (verified 2026-05-11 against `HMI_RT_1`, 20/20 PASS)

The project's HMI is **WinCC Unified**, NOT Classic. The `BuildClassicHmi*` /
`ImportHmi*` tools are Classic-only and will silently fail on Unified targets.
Use the `EnsureUnifiedHmi*` family.

### End-to-end aesthetic screen recipe

```
EnsureUnifiedHmiConnection(hmiSoftwarePath="HMI_RT_1",
                           connectionName="HMI_Conn_X",
                           plcName="<PLC name from GetProjectTree>")
EnsureUnifiedHmiTagTable(hmiSoftwarePath="HMI_RT_1", tagTableName="MyTags")
EnsureUnifiedHmiTag(hmiSoftwarePath="HMI_RT_1", tagTableName="MyTags",
                    tagName="StartCmd", hmiDataType="Bool",
                    plcName="<PLC software node>",
                    plcTag="DB_HMI_Interface.CmdEnable",
                    connectionName="HMI_Conn_X",
                    address="%DB200.DBX0.0")
                    鈫?omit PLC binding if PLC tag does not yet exist
EnsureUnifiedHmiScreen(hmiSoftwarePath="HMI_RT_1",
                       screenName="Main", width=1024, height=768)
ApplyUnifiedHmiScreenDesignJson(hmiSoftwarePath="HMI_RT_1",
                                screenName="Main",
                                designJson="<see schema below>")
EnsureUnifiedHmiButtonAction(hmiSoftwarePath="HMI_RT_1", screenName="Main",
                             buttonName="StartBtn",
                             eventType="Down", actionKind="set-bit",
                             targetTag="StartCmd")
SaveProject
```

### `ApplyUnifiedHmiScreenDesignJson` schema (verified)

All keys are **lowercase**. Colors are TIA ARGB hex `0xAARRGGBB` strings.

```jsonc
{
  "screen": { "BackColor": "0xFFF8FAFC" },
  "items": [
    {
      "type": "Rectangle" | "Text" | "Button" | "IOField" | "<full CLR type>",
      "name": "TitleBar",                    // unique on this screen
      "left": 0, "top": 0, "width": 1024, "height": 72,
      "text": "鍙€夋枃鏈紝鑷姩鍖呮垚 zh-CN MultilingualText",
      "textProperty": "Text",                // optional, default "Text"
      "properties": {                         // forwarded to reflection setter
        "BackColor": "0xFF0F172A",
        "ForeColor": "0xFFF8FAFC",
        "BorderColor": "0xFFCBD5E1",
        "BorderWidth": 1
      },
      "font":    { "Size": 22 },             // 鈫?ScreenItem.Font part
      "content": { "..." : "..." },          // 鈫?ScreenItem.Content part
      "padding": { "..." : "..." }           // 鈫?ScreenItem.Padding part
    }
  ]
}
```

Returns `meta.changed[]` (created/updated items) and `meta.failed[]` (per-property
write failures, e.g. unknown property name).

### `HmiButtonEventType` (probed from V21 Openness 鈥?only these are accepted)

```
None, Activated, Deactivated, Tapped, KeyDown, KeyUp, Down, Up, ContextTapped
```

`Down` = press, `Up` = release. **`Pressed` / `Released` / `Press` / `Release` /
`Click` are NOT valid** in V21 and produce `System.ArgumentException: 鏈壘鍒拌姹傜殑鍊糮
deep inside `SetUnifiedHmiButtonEventScriptCode`.

### `EnsureUnifiedHmiButtonAction` `actionKind` values

`set-bit`, `reset-bit`, `toggle-bit` (other recipes are rejected by the safety
gate). The tool builds and applies the script via
`SetUnifiedHmiButtonEventScriptCode` 鈥?i.e. it actually writes JS to the event
handler, then runs SyntaxCheck.

Command buttons must have visible event scripts. For Start/Stop/Enable/Disable/Reset/Apply,
create explicit `Down`/`Up` or `Press`/`Release` actions with
`EnsureUnifiedHmiButtonAction`: the down/press event uses `set-bit`, and the up/release
event uses `reset-bit`. `BindUnifiedHmiButtonPressedTag` may be kept as an auxiliary
pressed-state binding, but it is not sufficient by itself because the button will look
empty in the Events tab.

### Unified HMI pitfalls

1. `EnsureUnifiedHmiConnection` 鈥?`plcName` must be the **PLC software** node name
   from `GetProjectTree` (e.g. `"PLC_1"` or `"PLC_Main"`). The tool resolves the actual
   PLC device, station, PROFINET node and CPU family from the project before writing
   `Partner` / `Station` / `Node` and `CommunicationDriver`. Re-run it after hardware
   insertion or subnet changes, then check readback for the real PLC partner instead of
   blank Partner/Station/Node.
   For S7-1200/S7-1500 projects the readback `CommunicationDriver` must contain a
   1200/1500-style driver. A `SIMATIC S7 300/400` readback is a failed connection,
   not an acceptable default.
2. `EnsureUnifiedHmiTag` 鈥?for the delivery blueprint, pass both `plcTag` and `address`.
   `plcTag` is the symbolic DB member such as `DB_HMI_Interface.CmdEnable`; `address` is
   the verified runtime address such as `%DB200.DBX0.0`. The HMI interface DB is standard
   access (`MemoryLayout=Standard`, `DB200`), so absolute HMI addresses connect to real
   PLC memory even when Unified symbolic readback is empty on a local TIA build.
   Do not create an empty HMI tag and patch the address later. The `address` parameter
   belongs in the `EnsureUnifiedHmiTag` call, and `Address` or `LogicalAddress` must read
   back non-empty before the screen binding is considered complete.
3. `EnsureStartStopUnifiedHmi` 鈥?浼氬厛璋冪敤 `EnsureUnifiedHmiConnection`锛屽啀鐢ㄤ笌
   `EnsureUnifiedHmiTag` **鐩稿悓** 鐨勮鍒欏啓 **绗﹀彿浜掕繛**锛堟竻鎺夐敊璇殑 `%DB1鈥 缁濆鍦板潃锛夛紝
   鍙€夊弬鏁帮細`plcName`銆乣connectionName`锛堥粯璁?`HMI_Connection_1`锛夈€侶MI 鏍囩琛ㄥ悕
   榛樿 `榛樿鍙橀噺琛╜锛孭LC 绗﹀彿闇€涓?`StartPB`/`StopPB`/`EStop`/`RunOut` 涓€鑷淬€?4. **Full visuals vs. 鈥渃hat minimal JSON鈥?* 鈥?`ApplyUnifiedHmiScreenDesignJson` only draws
   what you pass in `designJson`. The **curated multi-page layouts** live under
   `templates/hmi/unified_*.json` (shadows, cards, IO fields, footers). For production-like
   screens, **read a template file 鈫?minify 鈫?pass as `designJson`**, then bind
   dynamizations and `EnsureUnifiedHmiButtonAction` / `SetUnifiedHmiButtonEventScriptCode`.
   A few rectangles in chat are **not** 鈥渢he template is ugly鈥? they skip the template.
5. Apply layout BEFORE wiring button actions. The button must exist as a
   ScreenItem before `EnsureUnifiedHmiButtonAction` can resolve it; otherwise
   you get `Screen item 'StartBtn' not found on screen '...'`.
6. `BackColor` etc. on `properties` use ARGB hex like `0xFFRRGGBB`. RGB triples
   (`"30, 41, 59"`) silently land in `meta.failed[]`.
7. Probe the available API surface with
   `ListUnifiedHmiApiTypes(nameContains="<filter>")` when you hit an enum or
   property name you're not sure about 鈥?example:
   `nameContains="ButtonEvent"` returned `HmiButtonEventType` enum and family.

End-to-end recipe (Connect 鈫?tags 鈫?screen 鈫?design 鈫?button actions 鈫?Save)
matches **搂12** in this file; exercise it on your own Unified RT project.

## 13. Real download 鈥?V21 cast bug (KNOWN ISSUE, 2026-05-11)

`DownloadToPlc(softwarePath=鈥?` currently fails with:

```
绫诲瀷 "Siemens.Engineering.Connection.ConnectionConfiguration" 鐨勫璞?鏃犳硶杞崲涓虹被鍨?"Siemens.Engineering.Connection.IConfiguration"
```

Root cause: V21 Openness changed the `DownloadProvider.Configuration` type
hierarchy. `Portal.cs::DownloadToPlc` invokes the `Download(IConfiguration,鈥?`
overload via reflection but passes the raw `ConnectionConfiguration` instance
which V21 no longer makes castable to `IConfiguration`. The right binding is
likely `provider.Configurations.TargetConfigurations[0]` or similar 鈥?needs a
focused V21 API audit.

Workaround until fixed: use the TIA Portal UI for the actual CPU download.
`CheckDownloadReadiness` still works correctly (`ready=true` means project
side is consistent and the network configuration exists; it does NOT mean the
CPU is currently reachable 鈥?check `GetOnlineState.isReachable`).

## 14. SCL external source files (`DeletePlcExternalSource` / `ImportPlcExternalSource` / `GenerateBlocksFromExternalSource`)

**Root cause (fixed in plugin, 2026-05-11):** Siemens documents
`PlcExternalSourceComposition.CreateFromFile(string name, string path)` 鈥?the
**first argument is the external-source name** (usually `MyBlock.scl`), the
second is the **full path** on disk. The MCP server previously built
`(string, string)` argument lists as `(FullPath, titleWithoutExtension)`, which
invokes the wrong overload order and surfaces as a misleading *"method 鈥?Create
鈥?not supported by the current version"* `EngineeringTargetInvocationException`.

**Fix in `Portal.cs`:** `BuildExternalSourceImportArguments` now emits
`(fi.Name, fi.FullName)` and `(fileTitleWithoutExtension, fi.FullName)` for
two-string signatures; `ImportPlcExternalSource` tries the `ExternalSources`
composition **before** the parent group; `GenerateBlocksFromExternalSource`
tries `GenerateBlocks()` then `GenerateBlocksFromSource(PlcBlockUserGroup,
GenerateBlockOption)` via reflection when a zero-parameter generator is absent.

**Verification:** with TIA running and a project open, import the UTF-8 BOM
`.scl` files from `skill/scl-cookbook/` via `ImportPlcExternalSource`, run
`GenerateBlocksFromExternalSource`, then `CompileSoftware` until
`errorCount=0`. If Connect/`GetProject` fails, fix the environment first 鈥?that is **not** evidence that the import pipeline is wrong.

**Operational notes:**

- `.scl` on disk for import should be **UTF-8 with BOM** (TIA expectation; same
  as user rule for generated SCL in this repo).
- `GetPlcExternalSources` returns names **with extension** (e.g. `Ramp.scl`).
  Pass the same string to `GenerateBlocksFromExternalSource`; the server also
  matches `MCPVerify_FC_SCL_v2` 鈫?`MCPVerify_FC_SCL_v2.scl`.
- Re-importing the same file name fails with **鈥淭he name is not unique鈥?* 鈥?  call `DeletePlcExternalSource(softwarePath, name)` first (idempotent: OK if
  the source was never imported).
- For logic that still does not fit `PlcBuildAndImport` DSL (搂10), prefer
  **external `.scl` + generate** or **UI authorship + `ExportBlock` +
  `ImportBlock`**; hand-writing `<StructuredText v4>` token XML is possible but
  extremely verbose.

## 15. Hard rules

1. **Never** call write tools before `Bootstrap` + `GetProjectTree`.
2. **Never** use a temporary/timestamped path on the user's real working
   project 鈥?use a separate scratch directory.
3. **Never** invent Openness reflection calls for items listed in 搂4.
4. **Always** end an editing session with `CompileSoftware` showing
   `errors=0` (warnings allowed) and `SaveProject` returning success.
5. **Always** quote Description tags exactly when filtering tools by layer
   (`[L0]`, `[L1]`, `[L2]`).

If a step takes longer than 90 seconds with no output, stop. The most likely
cause is an Openness authorization dialog the user did not click. Report it,
do not loop.

## 16. HMI Template Choice

For quick compatibility tests, use the original files under
`templates/hmi/unified_*.json`.

For cleaner industrial HMI screens, use the SICAR-style template set:

- `templates/hmi/unified_minimal_sicar_page_set.json`
- `templates/hmi/theme_minimal_sicar_tokens.json`
- `templates/hmi/hmi_minimal_sicar_bindings.json`
- `docs/hmi-minimal-sicar-template.md`

The SICAR-style set contains six pages: `Overview`, `Operation`, `Parameters`,
`Trend`, `Diagnostics`, and `Events`. Create each screen, pass the matching
screen object as `designJson`, then apply button actions and dynamization from
`hmi_minimal_sicar_bindings.json`.
