# TIA Portal MCP 使用 Skill

> 给下一个模型 / 工程师的操作手册。读完它你应该能：在不破坏用户原项目的前提下，新建一个 S7-1200 + KTP700 项目，用 builder 直造 UDT + 变量表 + GlobalDB + SCL FC + LAD FC + SCL OB，编译 0 错 0 警，把 HMI 变量灌进去；并且知道哪些路 MCP 走得通、哪些路因 V21 Openness API 限制走不通。

最后更新：基于 v0.0.27.0 + audit-pass-2026-05-09 分支（含 11 个 fix/feat commits）。

---

## 1. 启动前必读：环境与边界

### 1.1 硬性前置（不满足直接返工）
- Windows + .NET Framework 4.8
- TIA Portal **V21**（也支持 V20，但样本最多在 V21 上验证）
- 当前用户在 Windows 本地组 `Siemens TIA Openness`
- 环境变量 `TiaPortalLocation` 指向 TIA 安装根（如 `D:\app\TIA21\Portal V21`）
- 在仓库根 `dotnet build src/TiaMcpServer/TiaMcpServer.csproj -c Debug`（产物在 `bin/Debug/net48/TiaMcpServer.exe`）

### 1.2 不要触碰用户实际工作的项目
- 一律用 `C:\Users\XL626\Desktop\testtia\<时间戳子目录>` 的临时项目
- 项目名加时间戳后缀避免文件锁
- 写脚本时用 `$(Get-Date -Format yyyyMMdd_HHmmss)` 拼路径

### 1.3 TIA Openness 授权弹窗
- 第一次或长时间空闲后 `Connect` 会让 TIA 弹"是否允许 Openness 访问"对话框
- 用户不在前面时不要无限重试 —— **超时阈值 90s，到点退出**
- 90s 是经验值，超过它通常就是用户离开了；脚本要尊重这点别死磕

### 1.4 V21 Openness API 已知盲点（MCP 改不了）
- `PlcExternalSourceComposition.Create*` 在 V21 没暴露 → 无法用 `ImportPlcExternalSource` 导入 .scl 源码
- 复杂 SCL FB 如果导出时勾的是 `ExportSetting=None`，body 在 .scl 文件里、.xml 只有接口 → `ImportBlock` 报 `Language of 'SCL' have to have at least one compile unit`
  - **解决办法（非 MCP）**：让用户在 TIA UI 重新导出时选 `WithDefaults`，让 SCL 嵌入 XML
- HMI Classic 连接（`HMI_Connection_1`）**不会**随 PROFINET 子网自动创建
  - 必须先 `ImportHmiConnection` 一份连接 XML，才能让 HMI 变量 `Connection + ControllerTag` 绑定 PLC

---

## 2. 协议层踩坑（脚本驱动者必读）

### 2.1 PowerShell 5.1 + 中文路径
- `.ps1` 必须存为 **UTF-8 with BOM**，否则 PS 5.1 按系统码页（GBK）读，路径里的中文（`PID博途块`）会乱码 → `Process.Start` 报 "找不到文件"
- 写完用：
  ```powershell
  $c = [System.IO.File]::ReadAllText($p, [System.Text.Encoding]::UTF8)
  [System.IO.File]::WriteAllText($p, $c, (New-Object System.Text.UTF8Encoding($true)))
  ```

### 2.2 stdio 子进程读取
- **不要用 `Register-ObjectEvent -Action`** —— 它在独立 runspace 跑，访问不到 `$script:` 变量，队列永远空，永远超时
- 用 `$proc.StandardOutput.ReadLineAsync().Wait(timeoutMs)`：
  ```powershell
  while ([DateTime]::UtcNow -lt $deadline) {
      $task = $proc.StandardOutput.ReadLineAsync()
      if (-not $task.Wait($remain)) { continue }
      $line = $task.Result
      if ($null -eq $line) { throw "stdout closed" }
      $j = $line | ConvertFrom-Json
      if ($j.id -eq $id) { return $j }
  }
  ```
- stderr 用 `$proc.StandardError.ReadToEndAsync()` 异步缓存，进程退出后取 `.Result`。**遇到工具失败必查 stderr 真实异常**（控制台 message 经常被 SDK 兜底成 "An error occurred invoking ..." 这种没用的）

### 2.3 `$Args` 是 PowerShell 自动变量
- 函数参数不要用 `[hashtable]$Args`，会被覆盖。改名 `$ToolArgs` / `$Params` 之类
- 同理 foreach 循环变量不要用 `$p` —— 会盖掉外层 `$proc`

### 2.4 工具失败 ≠ result.error
MCP SDK 把工具内部抛的异常包成 `result.content[0].text="An error occurred invoking 'X'"` 加 `result.isError=true`，**不**走 JSON-RPC error 通道。检测要包含三种：

```powershell
if ($resp.error) { FAIL }                                # JSON-RPC 协议级
elseif ($null -eq $resp.result) { FAIL '空 result' }
else {
    $isErr = ($resp.result.isError -eq $true) -or ($text -like 'An error occurred*')
    if ($isErr) { FAIL $text }
    elseif ($text -match '"success"\s*:\s*false') { LOGICAL_FAIL }
    else { OK }
}
```

### 2.5 Project handle 短暂 dispose
- HMI 大操作（变量表 import 之类）后 1-3 秒内 `Project` handle 在 server 端可能 transient `EngineeringObjectDisposedException`
- 缓解：HMI 操作之间 `Start-Sleep -Milliseconds 2000`
- 或：用 `try/catch` + `AttachToOpenProject` 重新拿 handle

---

## 3. 工具调用方法（按已验证签名，别照抄文档）

### 3.1 Portal / Project
| 工具 | 必填 | 备注 |
|---|---|---|
| `Connect` | — | 必首调；超时 90s 内不响应说明授权弹窗你没点 |
| `CreateProject` | `directoryPath`, `projectName` | 用时间戳避免锁 |
| `SaveProject` | — | HMI 操作前后各保存一次更稳 |
| `Disconnect` | — | |

### 3.2 Hardware
```js
AddDeviceWithFallback({
  preferredMlfb: "6ES7211-1BE40-0XB0",  // CPU 1211C MLFB
  preferredVersion: "V4.7",
  deviceName: "PLC_1",
  family: "S7-1200"   // 也支持 "S7-1500"
})

AddHardwareCatalogDeviceWithProbe({
  keyword: "KTP700 Basic PN",
  deviceName: "HMI_1"
})

ConnectDeviceNodesToProfinetSubnet({
  firstRootPath: "PLC_1",
  secondRootPath: "HMI_1/HMI_1.IE_CP_1"   // ⚠️ HMI 端要写到 IE_CP_1
})
```

### 3.3 PLC Build & Import（**主推**）
统一入口 `PlcBuildAndImport`，`kind=udt|tagtable|globaldb|fc|fb`：

```js
PlcBuildAndImport({
  softwarePath: "PLC_1",
  kind: "fc",
  json: <见 4 节 JSON 速查>,
  dryRun: false,           // true 只生成 XML 不导入；调试用
  compileAfter: false      // 我们自己控编译时机
})
```

### 3.4 Direct XML import（手工 XML 时用）
| 工具 | 必填 | ⚠️ 易错 |
|---|---|---|
| `ImportType` | `softwarePath`, `groupPath`, `importPath` | groupPath="" 表根 |
| `ImportBlock` | 同上 | 同上 |
| `ImportPlcTagTable` | `softwarePath`, **`folderPath`**, `importPath` | **不是 groupPath** |
| `ImportHmiTagTable` | 同上 | **不是 groupPath** |
| `ImportHmiScreen` | 同上 | 同上 |

### 3.5 LAD / 梯形图
```js
ComposePlcLadFcBlockXml({
  ladFcBlockJson: '{
    "blockName": "FC_Manual_LAD",
    "blockNumber": 50,
    "commentZhCn": "...",
    "titleZhCn": "梯形图入口",
    "networks": [{
      "titleZhCn": "调用起保停",
      "commentZhCn": "...",
      "callJson": { "callName": "FC_StartStop", "parameters": [] }
    }]
  }'
})
// 然后取返回的 xml 字段，写到临时文件，调 ImportBlock
```

### 3.6 编译
```js
CompileSoftware({ softwarePath: "PLC_1" })
// 看返回的 state="Success", errorCount=0, warningCount=0
```

---

## 4. SCL Builder JSON 速查

### 4.1 全局 / 局部 变量约定（关键）

| 写法 | 解析为 |
|---|---|
| `"I_Start"` | GlobalVariable，单段，带 `HasQuotes=true` 标记 |
| `"DB.member"` 整体引号 | GlobalVariable，多段（自动加 `<Token Text="."/>` 分隔）|
| `"DB".member` 部分引号 | 同上（含 `"` 即视为全局，剩下按 `.` 拆）|
| `var` 无引号 | LocalVariable，单段 |
| `var.member` / `#trig.Q` | LocalVariable，多段 |

### 4.2 已验证的 SCL 操作（30 / 30 离线通过）

```json
// 起保停
{ "blockName": "FC_StartStop", "blockNumber": 10,
  "commentZhCn": "起保停：急停>停止>启动", "titleZhCn": "...",
  "networkTitleZhCn": "三段优先级", "networkCommentZhCn": "...",
  "inputs": [], "outputs": [],
  "structuredText": { "operations": [
    { "op": "if",        "condition": "\"I_EStop\"" },
    { "op": "assignment","target": "\"Q_Run\"", "literalValue": "FALSE", "indent": 2 },
    { "op": "elsif",     "condition": "\"I_Stop\"" },
    { "op": "assignment","target": "\"Q_Run\"", "literalValue": "FALSE", "indent": 2 },
    { "op": "elsif",     "condition": "\"I_Start\"" },
    { "op": "assignment","target": "\"Q_Run\"", "literalValue": "TRUE",  "indent": 2 },
    { "op": "endif" }
  ]}
}

// DB 成员算术（用 line op）
{ "op": "line", "items": [
  {"sym":"\"DB_Tank\".CycleCount"}, {"token":":="},
  {"sym":"\"DB_Tank\".CycleCount"}, {"token":"+"}, {"lit":"1"}, {"token":";"}
]}

// 比较 + IF
{ "op": "line", "items": [
  {"token":"IF"}, {"sym":"\"Tank_Level\""}, {"token":">="},
  {"sym":"\"DB_Tank\".HighLimit"}, {"token":"THEN"}
]}

// 符号位移（位移寄存器）
{ "op": "assignment", "target": "\"Q_RunLamp4\"", "source": "\"Q_RunLamp3\"" }

// 函数调用（REAL_TO_INT、SQRT、MIN、ABS）
{ "op": "line", "items": [
  {"sym":"a"}, {"token":":="}, {"token":"SQRT"},
  {"raw":"("}, {"sym":"b"}, {"raw":")"}, {"token":";"}
]}

// CASE / FOR / WHILE 用 line 拼
{ "op": "line", "items": [{"token":"CASE"}, {"sym":"x"}, {"token":"OF"}] }
// 后面跟 case 项 line / END_CASE line
```

### 4.3 line op 自动空格规则
- 项目之间默认插 `Blank`
- `)` `,` `;` 紧贴前一项，不加 Blank
- `(` 后面不强制紧贴（用 `raw` 才不加 Blank）
- 末尾自动补 `;` 和 `newline`，除非最后已是 `;`

### 4.4 中文注释三层

```json
{
  "blockName": "FC_X", ...,
  "commentZhCn": "块级中文注释",        // ObjectList 第一个 MultilingualText
  "titleZhCn":   "块级中文标题",         // ObjectList 最后一个 MultilingualText（顺序：Comment→CompileUnit→Title）
  "networkCommentZhCn": "网络级中文注释",
  "networkTitleZhCn":   "网络级中文标题",
  "inputs": [
    { "name":"Start", "datatype":"Bool", "commentZhCn":"启动按钮（瞬时）" }
  ]
}
```

**SCL inline comments**（`// 注释` 在代码体里）目前 builder 不支持 —— TIA SCL/v4 schema 没有 Comment token；inline 注释通常存在 .scl 源文本而非 XML 中。需要时只能 hand-craft XML 或留到块/网络级注释表达。

---

## 5. LAD Builder JSON 速查

```json
{
  "blockName": "FC_Manual_LAD",
  "blockNumber": 50,
  "commentZhCn": "手动梯形图入口",
  "titleZhCn":   "...",
  "inputs":  [{ "name":"En", "datatype":"Bool" }],   // 可选
  "outputs": [{ "name":"Done", "datatype":"Bool" }],
  "networks": [
    {
      "titleZhCn":   "网络 1：调起保停 FC",
      "commentZhCn": "...",
      "callJson": {
        "callName":  "FC_StartStop",
        "parameters": []
      }
    },
    {
      "titleZhCn": "网络 2：调液位控制 FC",
      "callJson": { "callName": "FC_LevelControl", "parameters": [] }
    }
  ]
}
```

每个 network 走 `BuildFlgNetCallXml` 内部，再被包到完整 `<SW.Blocks.FC ProgrammingLanguage=LAD>`。0 参数调用是允许的（V21 OK）。

---

## 6. UDT / DB / Tag Table JSON

### 6.1 UDT（hand-crafted XML 当前最稳）
最佳做法：仿 demo-assets/plc/UDT_TankStatus.xml。结构：
```
<SW.Types.PlcStruct>
  <AttributeList>
    <Interface>
      <Sections>
        <Section Name="None">
          <Member Name="X" Datatype="Real">
            <AttributeList><BooleanAttribute Name="ExternalWritable">true|false</BooleanAttribute></AttributeList>
            <Comment><MultiLanguageText Lang="zh-CN">中文注释</MultiLanguageText></Comment>
          </Member>
        </Section>
      </Sections>
    </Interface>
    <Name>UDT_X</Name>     <!-- 必填，否则 Import 拒收 -->
    <Namespace />
  </AttributeList>
  <ObjectList>
    <MultilingualText CompositionName="Comment">...zh-CN Text...</MultilingualText>
    <MultilingualText CompositionName="Title">...zh-CN Text...</MultilingualText>
  </ObjectList>
</SW.Types.PlcStruct>
```

### 6.2 GlobalDB（builder 推荐）
```json
{
  "dbName": "DB_Tank", "dbNumber": 1,
  "commentZhCn": "...",
  "staticMembers": [
    { "name":"TargetLevel", "datatype":"Real", "startValue":"50.0", "commentZhCn":"目标液位" },
    { "name":"AlarmHigh",   "datatype":"Bool", "startValue":"FALSE", "commentZhCn":"高液位报警" }
  ]
}
```

### 6.3 PLC Tag Table（builder 推荐）
```json
{
  "tableName": "DefaultTagTable",
  "tags": [
    { "name":"I_Start", "dataTypeName":"Bool", "logicalAddress":"%I0.0" },
    { "name":"Tank_Level", "dataTypeName":"Real", "logicalAddress":"%MD20" }
  ]
}
```

---

## 7. HMI Classic（KTP700 Basic）状态与边界

### 7.1 已通的部分
- HMI 变量表 import：用 `BuildClassicHmiTagTableXml` → 写文件 → `ImportHmiTagTable softwarePath="HMI_1" folderPath="" importPath=...`
- DataType 必须匹配 PLC 类型字节数（IEC 61131）：Bool=1, Int=2, Real=4, LReal=8 等。`DefaultLength` 已经按 IEC 自动配，**不要手填错**

### 7.2 没通 / 待补的部分（v1 → v1.1 backlog）
1. **HMI_Connection_1 不自动创建** —— 即使 PROFINET 子网把 HMI 和 PLC 连一起，TIA Openness 不会自动建 HMI 通信连接
   - 暂时方案：HMI 变量不带 `Connection + ControllerTag` 字段（纯内部变量）
   - 长期方案：写一个 `Hmi.Communication.Connection` XML 模板（schema 待逆向）+ `ImportHmiConnection` 调用之
2. **HMI 画面 import 各控件 schema 严格度比预想高**
   - V21 KTP700 对 `Hmi.Screen.Button` / `TextField` / `IOField` / `Rectangle` 各自接受的属性集都不同，且和真实 export 必须像素级匹配
   - 目前 BuildClassicHmiScreenXml 走过的修复：TextOff/TextOn 替代 Text、`<body><p>...</p></body>` HTML 包装、Rectangle 不带 Font / ForeColor / Enabled / TabIndex / Visible、TextField 不带 Visible / TabIndex / Enabled
   - **还有待解决**：Button 的某些属性还会触发 `Cannot create the 'Hmi.Screen.Button' object`（具体哪个属性需逐项 trim 或对照真实 export）
   - 长期方案：把 BuildClassicHmiScreenXml 改成"参考真实导出做模板"而不是"通用属性表"

### 7.3 替代方案（如果非 KTP 可换）
- **WinCC Unified Comfort Panel**（如 TP700 Comfort）走 Unified runtime，MCP 有完整一等工具：`EnsureUnifiedHmiScreen`, `EnsureUnifiedHmiTag`, `EnsureUnifiedHmiConnection`, `EnsureUnifiedHmiButtonAction(set/reset/toggle bit)`, `BindUnifiedHmiTagDynamization` 等
- 前提：用户 TIA 装了 WinCC Unified V21 选件包

---

## 8. 用户工作流（推荐顺序）

### 8.1 新建一个 demo 项目（PLC 端，最小可工作版）
```
Connect
→ CreateProject(临时路径, 时间戳名)
→ AddDeviceWithFallback(CPU)            // S7-1200 / S7-1500
→ AddHardwareCatalogDeviceWithProbe(HMI) // 可选
→ ConnectDeviceNodesToProfinetSubnet     // 可选；HMI 端要 IE_CP_1
→ PlcBuildAndImport(kind=tagtable)       // 全局变量
→ ImportType(UDT.xml)                    // 或 PlcBuildAndImport kind=udt
→ PlcBuildAndImport(kind=globaldb)       // 全局 DB
→ PlcBuildAndImport(kind=fc)*N           // SCL FCs
→ ComposePlcLadFcBlockXml + ImportBlock  // LAD FC 入口
→ PlcBuildAndImport(kind=fc, name=Cyclic_Main, blockNumber=200)  // SCL OB200 主循环
→ CompileSoftware    // 必须 errors=0 warnings=0
→ SaveProject
→ Disconnect
```

### 8.2 加 HMI（v1 限制版）
```
↓ 在上面 SaveProject 之后
→ Sleep 2s（让 project handle 稳定）
→ BuildClassicHmiTagTableXml + ImportHmiTagTable     // 纯内部变量；不带 Connection 字段
→ Sleep 2s
→ BuildClassicHmiScreenXml + ImportHmiScreen          // 仅放 Button + Rectangle 等已通过类型，不放 TextField
→ SaveProject
→ Disconnect
```

### 8.3 验收标准
- `CompileSoftware` 返回 `state=Success errorCount=0 warningCount=0`
- 在 TIA UI 打开项目能看到 PLC 程序树完整、点开 FC 看到中文块级注释
- HMI 变量表存在（暂不绑 PLC）
- HMI 画面（如果通过）有按钮 + 灯，按钮文字正确

---

## 9. 调试工具箱

仓库里有几个可直接 run 的回归脚本，新人/新模型上来先跑一遍确认环境：

| 脚本 | 跑什么 | 期望 | 用途 |
|---|---|---|---|
| `e2e_scl_matrix.ps1` | 30 项 SCL 离线 build 检查 | 30/30 PASS | 改 SCL builder 后必跑 |
| `e2e_offline_schema_check.ps1` | 多段 Symbol + HasQuotes 检验 | 全 True | V21 schema 正确性 |
| `e2e_offline_marquee.ps1` | 跑马灯 FC 离线生成 | ALL CHECKS PASSED | 复杂 SCL 逻辑覆盖 |
| `e2e_offline_line.ps1` | line op 表达式生成 | 测试 A/B PASS | 自由表达式构造 |
| `e2e_real_samples.ps1` | 真实 V20 export 批量 import | UDT/Tag 全过、3 复杂 FB 失败（已知） | 真实 schema 兼容 |
| `e2e_demo_full.ps1` | 端到端：S7-1200+KTP700+SCL FCs+LAD FC+OB200+HMI tag | 24/25 OK，PLC 编译 0/0 | 上线前最终验证 |
| `e2e_tank_control.ps1` | 工况：液位控制全套 | 21/22 OK | 真实工况验证（自原创非样本） |

---

## 10. 当前已知 / 重要 commits

```
95be01b fix(hmi-classic-screen): per-control attribute schema; add Tank Control demo
e9a5589 fix(hmi-classic-tag): correct Length per IEC 61131 data type
e0c1814 fix(scl-builder): V21 Symbol schema — Token "." between, HasQuotes, ObjectList ordering
4cd0733 docs+tests: PLC builder regression suite + status doc
b722778 feat(scl-builder): local multi-component path (#trig.Q)
c6e0c05 feat(scl-builder): symbol-to-symbol assignment
c400302 feat(scl-builder): free-form expression line op
5860fbe feat(scl-builder): global variables, ELSIF, free-form ops
6f1b79d feat(plc-builders): LAD FC composer + Chinese comment plumbing
a202568 fix(plc-builders): UDT name + FB ObjectList placement
10f935c fix(helper): GetAttributeList JSON cycle + per-attr robustness
```

---

## 11. 给下一个迭代者的建议

### 11.1 优先级（按"用户能不能食用"排序）
1. **HMI Connection XML 模板**（拦路虎；不补则 PLC↔HMI 绑定永远走不通）
2. **HMI 画面 Builder 重写**（参考真实 export 做模板，而不是当前的通用属性表）
3. **静态 R_TRIG / TON 实例支持**（解锁 timer / edge detection）
4. **多实例 FB 一等 Call XML**（替换 raw token 拼，画面更干净）
5. **SCL inline comments**（如果 v4 schema 真的支持 Comment token）

### 11.2 千万别做的事
- 别再扫 `e2e_real_samples.ps1` 里那 3 个失败的 FB —— 是用户 export 时没勾"含代码体"，不是 MCP 问题
- 别用同名项目反复重建 —— TIA 文件会锁，改用时间戳
- 别在 PowerShell 5.1 用事件 runspace 读 stdout —— 见 §2.2
- 别给 builder JSON 里手写 `Length` 字段并填错 —— 让 `DefaultLength` 自动按 IEC 类型推

### 11.3 用了多少 round 才到这（别重复同样错误）
| 教训 | 关键节点 |
|---|---|
| 第一次 stdio 读 0 字节 | Register-ObjectEvent 死路（→ §2.2） |
| FB 一直 import 失败 | composer 把 ObjectList 当兄弟节点（commit a202568） |
| GetDevices "An error occurred" | Helper.cs 序列化 CultureInfo 死循环（commit 10f935c） |
| 复杂 FB 报 `Language of 'SCL' have to have at least one compile unit` | 用户 export 设置问题，不是 MCP |
| 真实 schema vs builder 默认 | V21 多 Component 间要 Token "."（commit e0c1814） |
| HMI tag Length=2 报 4-byte mismatch | DefaultLength 没按 IEC（commit e9a5589） |

---

## 附录 A：常用 MLFB 速查

| 设备 | MLFB | 版本 |
|---|---|---|
| S7-1200 1211C DC/DC/DC | `6ES7211-1AE40-0XB0` | V4.7 |
| S7-1200 1211C AC/DC/RLY | `6ES7211-1BE40-0XB0` | V4.7 |
| S7-1200 1214C DC/DC/DC | `6ES7214-1AG40-0XB0` | V4.7 |
| S7-1500 1511-1 PN | `6ES7511-1AK02-0AB0` | V3.0 |
| KTP700 Basic PN | `6AV2123-2GB03-0AX0` | — |
| TP700 Comfort | `6AV2124-0GC01-0AX0` | — |

> 不知道精确 MLFB 时用 `SearchHardwareCatalog(keyword="...")` 先搜，或直接 `AddDeviceWithFallback(family="S7-1200")` 让它探。
