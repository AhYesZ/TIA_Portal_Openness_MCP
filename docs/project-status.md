# TIA Portal MCP Server — 项目进度与计划

> 最后更新：2026-05-09  
> 当前版本：v0.0.26  
> 工具总数：~182 个 MCP 工具（起始 160，累计新增 ~22）  
> 构建状态：**0 警告 0 错误**

---

## 项目目标

让任何 AI 模型都能通过这个 MCP 服务，对 Siemens TIA Portal 实现**全生命周期自动化**：

```
工程设计 → PLC/HMI 编程 → 编译 → 下载部署 → 在线监控 → 变量调试 → 诊断维护
```

关键约束：
- 目标框架：.NET Framework 4.8（TIA Portal Openness 要求）
- 传输层：stdio（默认）+ HTTP（已实现 MVP）
- API 来源：`D:\app\TIA21\Portal V21\PublicAPI\V21`（官方公开 API）

---

## 整体架构说明

```
TiaMcpServer.exe
├── McpServer.cs          — MCP 工具注册层（~179 个 [McpServerTool]）
├── McpPrompts.cs         — 30+ 个 MCP Prompt 定义
├── Responses.cs          — 所有工具的返回类型
├── Portal.cs             — Siemens Openness API 封装层（~12,000 行）
├── Engineering.cs        — 程序集解析 + TIA 版本检测
├── Operation.cs          — 统一异常处理辅助（新）
├── Guard.cs              — 空值断言辅助（新）
├── PortalException.cs    — 内部异常类型
├── PortalErrorCode.cs    — 错误码枚举
├── McpBlockingStream.cs  — HTTP 传输用阻塞流（新）
├── CliOptions.cs         — 命令行参数解析
└── Program.cs            — 启动逻辑（stdio / HTTP 分支）
```

**数据流**:
```
AI 模型
  └─→ MCP 协议（stdio 或 HTTP POST /mcp）
        └─→ McpServer.[ToolName]()
              └─→ Portal.[Method]()
                    └─→ Siemens Openness API → TIA Portal 进程
```

---

## 已完成任务

### 轮次一（2026-05-08 第一轮）— v0.0.18 基础优化

| 项目 | 内容 | 文件 |
|---|---|---|
| Tool Description 全面改写 | 25 个核心工具加 [Category]、前置条件、何时使用 | McpServer.cs |
| McpPrompts 扩充 | 从 12 个扩展到 30+ 个，覆盖完整工作流 | McpPrompts.cs |
| 自然语言配方 | 创建 TIA_NL_INTENT_RECIPES.md，12 个场景 | docs/ |
| 工具能力矩阵 | 创建 tool-capability-matrix.md | docs/ |
| ImportBlock/ImportType 异常 | 改用 PortalException 模式，弃 return false | Portal.cs |
| 错误码扩展 | 添加 ImportFailed、OpennessError | PortalErrorCode.cs |
| README 更新 | 添加 Features 列表和文档链接 | README.md |

---

### 轮次二（2026-05-08 第二轮）— v0.0.19

| 项目 | 内容 | 文件 |
|---|---|---|
| ✅ **HTTP Transport MVP** | `--transport http --http-prefix ... --http-api-key ...`；`McpBlockingStream` + `WithStreamServerTransport`；`RunHttpHost` + `HandleHttpMcpRequest` | Program.cs, McpBlockingStream.cs |
| ✅ CliOptions 修正 | Logging 注释修正；添加 Transport/HttpPrefix/HttpApiKey 三个参数 | CliOptions.cs |
| ✅ Bug 修复 | McpServer.cs:5113 `pex.ErrorCode` → `pex.Code` | McpServer.cs |
| ✅ CHANGELOG 修复 | "Narketplace" → "Marketplace" | CHANGELOG.md |
| ✅ README 更新 | CLI Options 表格、Build and Run 节、Transports 节（含 curl 示例） | README.md |

---

### 轮次三（2026-05-08 第三轮）— v0.0.20

| 任务 | 状态 | 工具 | 关键实现细节 |
|---|---|---|---|
| **T1-A** Download to CPU | ✅ 完成 | `DownloadToPlc`, `CheckDownloadReadiness` | `DownloadProvider.GetService<>` + 反射调用 `Download()` 绕过 ConnectionConfiguration→IConfiguration 类型不匹配；12 种下载配置自动接受 |
| **T1-C** CPU 在线状态 | ✅ 完成 | `GetOnlineState`, `GoOnline`, `GoOffline` | `OnlineProvider.GetService<>` + `GoOnline()` / `GoOffline()`；注：CPU RUN/STOP 模式不在公开 API 中 |

---

### 轮次四（2026-05-08 第四轮）— v0.0.21~v0.0.22

| 任务 | 状态 | 工具 | 关键实现细节 |
|---|---|---|---|
| **T1-B** Watch/Force 变量 | ✅ 完成 | `GetPlcForceTables`, `SetWatchTableModifyValue`, `SetForceTableEntry` | Watch/Force Table API 是声明式配置；`FindOrCreateWatchTable`/`FindOrCreateForceTable` + `TryInvokeMethodByName`；TIA Portal 联机后自动执行 |
| **T3-A** Operation.Run | ✅ 完成（示范阶段）| — | `Operation.cs` 创建；已应用到 `DisconnectPortal()`；全面推广待后续 |

---

### 轮次六（2026-05-09）— v0.0.25~v0.0.26

| 任务 | 状态 | 工具 | 关键实现细节 |
|---|---|---|---|
| **T2-E** 运动控制/TO 扩展 | ✅ 完成 | `GetTechnologyObjects`, `ExportTechnologyObject`, `ExportTechnologyObjectsToDirectory` | `PlcSoftware.TechnologicalObjectGroup.TechnologicalObjects`（反射链）；`TechnologicalInstanceDB.Export()` |
| **T2-C** 安全程序编译 | ❌ 不可行 | — | Safety 编译仅通过 AddIn 插件框架，公开 API 不暴露 `ISafetyCompilable`；已记录为已知限制 |
| **T3-D** 消除 Nullable 警告 | ✅ 完成 | — | 32 个警告 → **0 警告**；修复范围：Portal.cs×25、McpServer.cs×2、Program.cs×5；主要手法：null-forgiving `!`、`?? ""`、`Array.ConvertAll` |

---

### 轮次五（2026-05-08 第五轮）— v0.0.23~v0.0.24

| 任务 | 状态 | 工具 | 关键实现细节 |
|---|---|---|---|
| **T2-A** 报警文本管理 | ✅ 完成 | `ExportAlarmClasses`, `ImportAlarmClasses`, `ExportAlarmTextLists`, `ImportAlarmTextLists`, `ExportAlarmInstanceTexts` | `AlarmClassDataProvider` via GetService；`PlcAlarmTextlistGroup` via 反射；`PlcAlarmTextProvider` via GetService；反射调用 flags enum for export options |
| **T3-C** TIA 版本自动检测 | ✅ 完成 | — | `Engineering.DetectTiaMajorVersion()`：env var → 注册表 TIAP* keys → 文件系统 Portal V*；`Program.cs` 自动使用，fallback 到 21 |
| **T2-B** OPC UA 配置 | ✅ 完成 | `GetOpcUaConfig`, `SetOpcUaInterfaceEnabled`, `ExportOpcUaInterface`, `ImportOpcUaInterface` | `OpcUaProvider` via GetService → 反射链 CommunicationGroup → ServerInterfaceGroup → 集合 |
| **T3-B** Guard 辅助类 | ✅ 完成（示范阶段）| — | `Guard.cs`：`RequireNotNull`/`RequireNonEmpty`/`Require`/`DidYouMean`；已应用到 `ExportBlock`/`ExportType` |
| **T4-C** NL 配方扩充 | ✅ 完成 | — | 新增配方 13（部署流）、14（Force 调试）、15（报警文本）、16（OPC UA 配置） |
| **tool-capability-matrix** 更新 | ✅ 完成 | — | 新增 Online Operations、Alarm Text Management、OPC UA Configuration 三节 |

---

## 当前工具覆盖地图

```
✅ 已覆盖          ⚠️ 部分覆盖         ❌ 未覆盖
─────────────────────────────────────────────────────
工程设计层
  ✅ 项目管理（创建/打开/保存/关闭）
  ✅ 设备管理（PLC/HMI 添加、硬件目录搜索、GSD）
  ✅ 网络配置（PROFINET 子网、设备连接）

PLC 编程层
  ✅ 块管理（FB/FC/OB/GlobalDB 导入导出、批量操作）
  ✅ 类型管理（UDT 导入导出）
  ✅ 标签表（导入导出、批量操作）
  ✅ 外部源（导入、生成块）
  ✅ 工艺对象（导入导出、列举）    ← GetTechnologyObjects + Export（新）
  ✅ 编译（CompileSoftware、CompileAndDiagnosePlc）
  ✅ 交叉引用（GetCrossReferences）

HMI 层
  ✅ Unified HMI（页面/标签/连接/动态化/按钮事件）
  ✅ Classic HMI（页面/标签/连接 导入导出）
  ✅ HMI 模板分析（布局、绑定验证）

在线操作层（本轮新增）
  ✅ 连接管理（GoOnline / GoOffline / GetOnlineState）
  ✅ 程序下载（DownloadToPlc / CheckDownloadReadiness）
  ✅ 变量调试（SetWatchTableModifyValue / SetForceTableEntry）
  ❌ CPU 运行模式切换（RUN/STOP）— 公开 API 不支持
  ❌ 故障缓冲区读取 — 公开 API 不支持
  ❌ 在线变量实时读取（Watch Table 只能读静态配置值）

报警与安全
  ✅ 报警文本（导出/导入 XLSX 和 XML）
  ✅ 报警类别（导出/导入）
  ❌ 安全程序专项编译 — **公开 API 不支持**（AddIn 插件框架专用，无 ISafetyCompilable 接口）
  ❌ 安全签名读取 — 同上

系统集成
  ✅ OPC UA 配置（查看/启停/导出/导入接口）
  ❌ OPC UA 访问控制（角色权限配置）
  ❌ OPC UA 命名空间（ReferenceNamespace 创建含 XML）

架构与传输
  ✅ stdio 传输（默认）
  ✅ HTTP 传输 MVP（--transport http）
  ✅ TIA 版本自动检测
  ✅ Operation.Run 统一异常辅助（示范应用）
  ✅ Guard 空值检查辅助（示范应用）
  ✅ **0 编译警告**（T3-D 完成，32→0）
  ❌ HTTP SSE 支持（服务器推送通知）
  ❌ Mcp-Session-Id 会话隔离
```

---

## 剩余任务清单

### P1 — 较高价值，下一批次优先

#### T2-C：安全程序专项编译 ❌ 已确认不可行

> 探索结论：TIA Portal 公开 API 中不存在 `ISafetyCompilable` 接口，安全编译只能通过 AddIn 插件框架（`SafetyCompileAddInProvider`）触发，该框架是为构建 TIA Portal 插件设计的，不适合从外部脚本调用。  
> **建议**：在工具描述中明确告知用户，安全 F-CPU 工程需要手动在 TIA Portal UI 触发安全编译。

---

#### T2-C（实际 P1）：安全编译限制文档化

**背景**：F-CPU（安全 PLC）的安全块需要独立编译步骤，普通 `CompileSoftware` 不包含安全签名生成。  
**API**：`Siemens.Engineering.Safety`（`ISafetyCompilable`？）+ `Siemens.Engineering.AddIn.Safety.SafetyCompileAddInProvider`  
**注意**：AddIn 框架 API 是为构建 TIA 插件设计的，不确定是否可直接调用。需要探索 `ISafetyCompilable` 是否存在于 PlcSoftware 的 GetService 接口列表中。

待实现工具：
```
CompileSafetyProgram(softwarePath)   — 触发安全程序专项编译
GetSafetySignature(softwarePath)     — 读取当前安全签名（CRC/Hash）
```

---

#### T2-E：运动控制/工艺对象进阶扩展（P1 剩余）

**已完成**：`GetTechnologyObjects` + `ExportTechnologyObject` + `ExportTechnologyObjectsToDirectory`（v0.0.26）

**待实现（CamData 和轴参数读取）**：
```
GetAxisParameters(softwarePath, toName)        — 读取轴参数（需反射 Parameters 集合）
ExportCamData(softwarePath, toName, path)      — 导出凸轮数据（SaveCamData 方法）
ImportCamData(softwarePath, toName, path)      — 导入凸轮数据（LoadCamData 方法）
```

**API**：`CamDataSupport` 服务（via GetService 或反射）
- `SaveCamData(FileInfo, CamDataFormat, CamDataFormatSeparator)` — MCD/Scout/PointList 格式
- `LoadCamData(FileInfo, CamDataFormatSeparator)` — 从 Scout/MCD 格式导入

---

#### T2-D：设备 IP 地址配置

**背景**：`SetCpuCommonSettings` 可设置 DeviceItem 级别的属性，但 IP 地址位于 Node 对象（NetworkInterface 下），需要单独导航路径。  
**API**：`Siemens.Engineering.HW.Node` + `SetAttribute("Address", ipAddress)`  
**注意**：与现有 `GetDeviceItemNetworkInfo` + `SetDeviceItemAttribute` 有功能交叉，需确认 Node 属性是否可通过现有工具设置。

待实现工具：
```
GetDeviceIpConfig(deviceItemPath)               — 读取网口 IP/掩码/网关
SetDeviceIpConfig(deviceItemPath, ip, mask, gw) — 离线修改设备 IP 配置
```

---

### P2 — 中等价值，条件成熟时实施

#### T3-D：Nullable 警告 ✅ 已完成（v0.0.26）

32 个警告已全部消除，详见 CHANGELOG v0.0.26。

---

#### T3-A：Operation.Run 全面推广

**背景**：`Operation.cs` 已创建，`DisconnectPortal()` 已作为示范。Portal.cs 中还有 60+ 处几乎相同的 `try/catch (Exception) { return false; }` 模式。  
**目标**：将这些 silent-swallow 块替换为 `Operation.Run(...)` 调用，统一日志输出，消除静默失败。  
**风险**：每个方法需要单独确认行为不变，不能批量替换。

**推荐方式**：按 `#region` 分批进行，每批构建验证一次。

---

#### T3-B：Guard 全面推广

**背景**：`Guard.cs` 已创建，已应用到 `ExportBlock`/`ExportType`。Portal.cs 中还有 21 处 `if (plc == null) return ...` + 若干 `throw new PortalException(NotFound)` 模式。  
**目标**：用 `Guard.RequireNotNull(...)` 替换手写 null 检查 + throw，减少重复代码，统一错误消息格式。

---

#### T3-D：修复 Nullable 编译警告

**背景**：构建当前有 32 个 CS8602/CS8604 nullable 警告，全部来自 Portal.cs 和 McpServer.cs 中的旧代码路径。  
**目标**：将警告数量降到 0，提高代码安全性。  
**方式**：逐个添加 null-forgiving 运算符（`!`）或 Guard 断言。

---

### P3 — 较低价值 / 探索性

#### HTTP Transport 规范对齐

- **SSE 支持**：`GET /mcp/sse` 端点供支持流式推送的客户端使用
- **Mcp-Session-Id**：多客户端会话隔离（当前所有请求共享一个 MCP session）
- **MCP-Protocol-Version**：请求头验证与版本协商

当前 HTTP 实现已满足基本场景（单客户端、请求-响应模式），以上为进阶合规需求。

---

#### 每工具独立文档

**路径**：`docs/tools/`  
**已有模板**：`docs/tools/hardware-network.md`、`docs/tools/plc-builders.md` 等

待补充文档（优先级从高到低）：
```
docs/tools/download.md          — DownloadToPlc + CheckDownloadReadiness
docs/tools/online-write.md      — Force/Watch table + GoOnline/GoOffline
docs/tools/alarms.md            — 5 个报警工具
docs/tools/opc-ua.md            — 4 个 OPC UA 工具
docs/tools/export-blocks.md     — ExportBlock + ExportBlocks（已有工具补文档）
docs/tools/import-blocks.md     — ImportBlock + ImportBlocksFromDirectory
```

每个文档包含：Overview、前置条件、参数说明、调用序列、错误处理、Mermaid 流程图、curl/JSON 示例。

---

#### 启用 XML 文档注释

在 `TiaMcpServer.csproj` 中添加：
```xml
<DocumentationFile>bin\$(Configuration)\net48\TiaMcpServer.xml</DocumentationFile>
```

对 McpServer.cs 中所有 `[McpServerTool]` 方法补 `/// <summary>` 注释，使 IDE tooltip 显示工具说明。

---

## 关键工作流（可直接给 AI 模型使用）

### 完整部署流

```
Connect → OpenProject → CompileSoftware
→ CheckDownloadReadiness → DownloadToPlc(keepActualValues=true)
→ GetOnlineState → SaveProject
```

### 在线变量调试流

```
Connect → OpenProject → GoOnline
→ SetForceTableEntry(address, value)     ← Force 持续生效
→ SetWatchTableModifyValue(address, value, trigger)  ← 单次写值
→ GoOffline
```

### 报警文本多语言更新流

```
Connect → OpenProject
→ ExportAlarmTextLists(→ Excel 文件)     ← 备份
→ [用户翻译 Excel]
→ ImportAlarmTextLists(← 翻译后 Excel)
→ CompileSoftware → SaveProject
```

### OPC UA 接口配置流

```
Connect → OpenProject
→ GetOpcUaConfig                         ← 查现有接口
→ SetOpcUaInterfaceEnabled(name, true)   ← 启用接口
→ DownloadToPlc                          ← 下载生效
→ ExportOpcUaInterface(→ XML)            ← 导出供 SCADA 使用
```

---

## 版本历史摘要

| 版本 | 日期 | 核心变化 |
|---|---|---|
| v0.0.16 | 2025-09-02 | ImportFromDocuments/ImportBlocksFromDocuments (V20+) |
| v0.0.18 | 2026-05-08 | Tool Description 改写、Prompts 扩充、NL 配方、工具矩阵 |
| v0.0.19 | 2026-05-08 | **HTTP Transport MVP** |
| v0.0.20 | 2026-05-08 | **T1-A DownloadToPlc + T1-C GoOnline/GetOnlineState** |
| v0.0.21 | 2026-05-08 | **T1-B Force/Watch 变量配置** + T3-A Operation.Run |
| v0.0.22 | 2026-05-08 | T3-A Operation.Run 辅助类（示范） |
| v0.0.23 | 2026-05-08 | **T2-A 报警文本（5 工具）** + **T3-C TIA 版本自动检测** |
| v0.0.24 | 2026-05-08 | **T2-B OPC UA（4 工具）** + T3-B Guard + T4-C NL 配方扩充 |
| v0.0.26 | 2026-05-09 | **T2-E TO 扩展（3 工具）** + **T3-D 0 警告达成** |

---

## 快速参考：新增工具一览

| 工具名 | 类别 | 版本引入 |
|---|---|---|
| `GetOnlineState` | Online | v0.0.20 |
| `GoOnline` | Online | v0.0.20 |
| `GoOffline` | Online | v0.0.20 |
| `CheckDownloadReadiness` | Online | v0.0.20 |
| `DownloadToPlc` | Online-Write | v0.0.20 |
| `GetPlcForceTables` | Online | v0.0.21 |
| `SetWatchTableModifyValue` | Online-Write | v0.0.21 |
| `SetForceTableEntry` | Online-Write | v0.0.21 |
| `ExportAlarmClasses` | Alarms | v0.0.23 |
| `ImportAlarmClasses` | Alarms | v0.0.23 |
| `ExportAlarmTextLists` | Alarms | v0.0.23 |
| `ImportAlarmTextLists` | Alarms | v0.0.23 |
| `ExportAlarmInstanceTexts` | Alarms | v0.0.23 |
| `GetOpcUaConfig` | OPC-UA | v0.0.24 |
| `SetOpcUaInterfaceEnabled` | OPC-UA | v0.0.24 |
| `ExportOpcUaInterface` | OPC-UA | v0.0.24 |
| `ImportOpcUaInterface` | OPC-UA | v0.0.24 |
| `GetTechnologyObjects` | TechnologyObjects | v0.0.26 |
| `ExportTechnologyObject` | TechnologyObjects | v0.0.26 |
| `ExportTechnologyObjectsToDirectory` | TechnologyObjects | v0.0.26 |

---

## 文件变更总览（本轮新增/修改）

```
src/TiaMcpServer/
├── Siemens/
│   ├── Portal.cs              — 新增 #region download / #region online
│   │                            #region opcua / #region alarms
│   │                            共 ~30 个新方法 + 反射辅助函数
│   ├── Engineering.cs         — DetectTiaMajorVersion() 自动检测
│   ├── Operation.cs           ← 新建：统一异常处理辅助
│   ├── Guard.cs               ← 新建：空值断言辅助
│   └── PortalErrorCode.cs     — 不变
├── ModelContextProtocol/
│   ├── McpServer.cs           — 新增 17 个 [McpServerTool]
│   └── Responses.cs           — 新增 ResponseDownload / ResponseCheckDownload
│                                ResponseOnlineState
├── McpBlockingStream.cs       ← 新建：HTTP 传输用阻塞流
├── CliOptions.cs              — 新增 Transport/HttpPrefix/HttpApiKey
└── Program.cs                 — RunHttpHost + TIA 版本自动检测

docs/
├── project-status.md          ← 本文件（新建）
├── optimization-roadmap.md    — 原始路线图（保留参考）
├── TIA_NL_INTENT_RECIPES.md   — 扩充至 16 个场景
└── tool-capability-matrix.md  — 新增 3 个分类节
```
