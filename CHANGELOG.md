# Change Log

## Unreleased - Stability-first public MCP

- Added PLC build capability guidance to `PlcBuildAndImport`: responses now include `CapabilityDecision`, `CapabilityWarnings`, and `RecommendedNextActions` so clients can route complex SCL away from the narrow XML DSL before users hit TIA compile errors.
- Changed `ApplyUnifiedHmiScreenDesignJson` to support strict mode, defaulting to fail-closed through the MCP entrypoint. Unsupported HMI property writes no longer appear as false success.
- Added a small stable Unified HMI control-property guard for common generated items. For example, Rectangle `ForeColor` and `Font` are rejected with actionable guidance instead of silently producing ugly or incomplete screens.
- Added explicit Unified HMI tag binding verification. Stable generation now requires readback status `SymbolicVerified` or `AbsoluteVerified`; internal-only/unverified HMI tags fail with guidance.
- Cleaned the built-in motor demo HMI design so it uses only stable Rectangle/Text properties under strict HMI apply.

## [0.0.31] - 2026-05-28

### 版本能力层（Capability layer）

- 新增 `Siemens/Capability.cs`：把"某功能在当前连接的 TIA 版本上是否可用"收口为单一真源。`TiaFeature` 枚举（`HardwareHmiConnection` 需 V21+、`DocumentExport` 需 V20+）+ `IsSupported`/`RequireSupported`/`Describe`/`Snapshot`。
- 新增错误码 `PortalErrorCode.NotSupportedOnVersion`；`Portal.cs` 中 `ExportAsDocuments` 的手写 `<20` 守卫改走 `Capability.RequireSupported(DocumentExport)`；`ProbeCreateHardwareHmiConnection` 的 V20 降级提示改走 `Capability.Describe`（统一文案来源）。
- `Bootstrap` 响应新增 `Capabilities` 字段：AI 模型一上来就能看到当前版本能干什么，无需靠失败调用试探。**已在 V20/V21 两份 exe 上实测**：V20 上 `HardwareHmiConnection.supported=false`、`DocumentExport.supported=true`；V21 上两者皆 true。

### "Did you mean" 候选提示整合

- 把原先内联在 `ExportBlock` 里的块名候选提示抽成可复用助手，并复活此前为死代码的 `Guard.DidYouMean`。
- 新增 `BuildTypeDidYouMean` 并应用到 `ExportType` 的 NotFound（此前只返回 "Type not found." 无候选）。

### HTTP transport 修复（此前 POST 完全不可用）

- **根因**：请求体读取与 HTTP↔MCP 内部管道的写入走 APM 包装的异步 I/O，在 .NET Framework `HttpListener` 输入流上会无限挂起，导致每个 `POST /mcp` 永久阻塞（此前只有 `GET /mcp/health` 可用）。
- **修复**：请求体读取、管道写入改为同步；响应读取改为 `Task.Run` 内同步 `ReadLine` 并与 30s 超时竞速（超时返回 504，不再无限挂起）。
- **已用 curl 端到端实测**：`initialize`→200+会话、`notifications/initialized`→202、`tools/call Bootstrap`→200 且返回 Capabilities。

## [0.0.28] - 2026-05-26

### V20 + V21 双版本支持

- **现实**：V21 把 `Siemens.Engineering.dll` 拆成 `Siemens.Engineering.Base/Step7/WinCC/...` 多个 DLL，V20 仍是单体 `Siemens.Engineering.dll`。同一份 exe 不能同时支持两者（IL 硬绑定不同 assembly identity）。结论：**两份 exe** 分别编译。
- 新增 `TiaMcpServer.V20.csproj`：引用 `Siemens.Collaboration.Net.TiaPortal.Packages.Openness 20.0.1744190253`，定义 `TIA_V20` 编译符号，输出到 `bin-v20/`。
- `Siemens/Portal.cs`：用 `#if TIA_V20` 把 `Siemens.Engineering.HW.CommunicationConnections.*`（V21-only）改成 `Type.GetType()` 反射查找，找不到时硬件级 HMI 连接功能降级为 no-op（其他工具不受影响）。
- 新 CLI 参数 `--tia-portal-location <path>`（两份 exe 都支持）：显式指定 TIA Portal 安装根目录，解决博途装在非默认位置（如 `D:\app\TIA20\Portal V20`）时注册表/`TiaPortalLocation` 环境变量缺失的问题。
- `Engineering.GetTiaPortalInstallPath`：优先级调整为 **CLI override → `TiaPortalLocation` env → 注册表 `HKLM\...\TIAP{N}\TIA_Opns\Path`**。
- `Engineering.DetectTiaMajorVersion`：把 CLI override 加入候选源。

### S7DCL/SCL 文本格式专用 MCP 工具

- 新增 4 个工具：`ExportBlockAsScl`, `ExportBlocksAsScl`, `ImportBlockFromScl`, `ImportBlocksFromScl`，是 `ExportAsDocuments`/`ExportBlocksAsDocuments`/`ImportFromDocuments`/`ImportBlocksFromDocuments` 的薄别名。Description 强调「PREFERRED on V21+」「SIMATIC SD textual format (.s7dcl + .s7res)」，让 AI 更容易首选文本格式。
- 原 `*Documents` 工具保持原样，向后兼容。

### 端到端验证

- V21：DemoProjects/MCP_Demo_Rich_20260523，ExportBlocksAsScl 导出 8 块（含 LAD/SCL/DB），ImportBlocksFromScl 全部 8 块回环成功（14.7s）。
- V20：江夏测试5T车_V20，CompileSoftware → ExportBlocksAsScl，**51 个 .s7dcl + 33 个 .s7res 全量导出成功**。LAD 块格式正确（`RUNG / I_Contact / Coil / TON{...}`）。

## [0.0.27] - 2026-05-09

### Audit Pass — Stability, Tool Surface, Online Operations

**Online operations (T1) — gap analysis + targeted implementation**

- Static API feasibility report against `D:\app\TIA21\Portal V21\PublicAPI\V21\net48\*.xml`. Confirmed: CPU RUN/STOP control, fault buffer read, ClearForces, and selective per-block download are **not** exposed by Openness PublicAPI. Captured in new `docs/openness-limitations.md` so AI agents stop attempting unreachable operations.
- New: `CompareSoftwareToOnline(softwarePath, maxDepth, maxEntries)` — wraps `PlcSoftware.CompareToOnline()` and walks the resulting `CompareResult` tree via reflection. Returns `ResponseCompare { IsOnline, Entries[], Summary, Truncated }` where each entry has `{ Path, LeftName, RightName, Status, Details }`. Validated live against a 1212C: 26 entries returned, real `PLC tags ObjectsDifferent` correctly surfaced.
- New: `password` parameter on `GoOnline` and `DownloadToPlc`. Hooks `ConnectionConfiguration.OnlineLegitimation` with a `SecureString`-backed handler responding to `OnlinePasswordConfiguration` prompts. `IDisposable`-scoped to guarantee handler unsubscription.

**Bug fix: OnlineProvider/DownloadProvider resolution on nested 1200/1500 CPUs**

- 1200/1500 CPUs in nested device groups expose Online/Download providers on the CPU `DeviceItem`, not on `PlcSoftware`. Previous code only queried `plcSoftware.GetService<T>()` and reported "service not available" / "Offline" even when the PLC was online via TIA Portal UI.
- New helper `Portal.ResolvePlcService<T>(softwarePath, plcSoftware)` walks `SoftwareContainer.Parent` DeviceItem chain when the direct lookup fails. Applied to all 6 call sites: `GetOnlineState`, `GoOnline`, `GoOffline`, `DownloadToPlc`, `CheckDownloadReadiness`, `CompareSoftwareToOnline`.
- Verified: `GetOnlineState` now correctly reports `Online` against the live PLC where it previously misreported `Offline`.

**Error handling — silent failures eliminated on critical paths**

- `Portal.cs`: 6 silent `catch (Exception)` sites now log instead of swallowing — `Dispose()` ×2, `CreateProject`, `OpenSession`, `GetBlocks`, `GetUserDefinedTypes`. Inner-loop catch in `ImportBlocksFromDocuments` logs per-file failures rather than silently skipping.
- Reflection-heavy probe-then-skip patterns (regex validation, parent traversal, multi-SDK-version probes) intentionally left silent — adding logs there is noise without signal.

**Tool surface — `[Category]` 100% coverage + vocabulary normalization**

- 53 → 180 tools tagged with canonical `[Category]` prefix (100% coverage).
- 9 inconsistent prefixes normalized: `Hardware/Network` → `Hardware`, `Plc/Build` → `PLC-Builders`, `HmiUnified/Theme|Layout` → `HMI-Unified`, `HmiUnified/GlobalLibrary[Template]` → `HMI-Library`, `Online/ReadOnly` → `Online-Monitoring`, `PLC-Build+Import` and `PLC-Tags` → `PLC-Software`.
- Two coexisting tag formats: simple `[Category]` (~85 tools) and elaborate `[Category:NAME][flags][PreCondition:...]` (~20 tools, primarily `PLC-Online` / `PLC-Alarms` / `PLC-OpcUA` / `PLC-TechnologyObjects`). Elaborate format is the target convention; full migration deferred.

**Typed Response surface (M3, partial)**

- `ResponseJsonReport` enriched with optional well-known fields: `Errors[]`, `Warnings[]`, `OutputPath`, `OutputFiles[]`. AI clients now have a stable contract for the most common builder/validator outputs across ~36 tools that still use the catch-all type.
- `GetTechnologyObjects` migrated off `ResponseJsonReport` to dedicated `ResponseTechnologyObjectList { Ok, SoftwarePath, Count, Items[] }` with `TechnologyObjectInfo { Name, OfSystemLibElement, OfSystemLibVersion, TypeHint }`. Reference pattern for future migrations.
- New `ResponseCompare` + `CompareEntry` types for `CompareSoftwareToOnline`.

**Test infrastructure**

- New `tests/TiaMcpServer.Test/TestCompareToOnlineLive.cs` — live validation against running TIA Portal session.
- `AssemblyHooks.cs`: `[AssemblyInitialize]` now installs Openness resolver AND a manual `AppDomain.AssemblyResolve` fallback for `Siemens.Engineering*` assemblies (probes `TiaPortalLocation` env var). Required because the package-provided resolver doesn't always hook in time under MSTest's test host.
- `App.config`: removed broken `privatePath` probing pointing to a hardcoded V20 path that was never reachable (privatePath only honors AppBase-relative paths).

**Documentation**

- New `docs/openness-limitations.md` enumerates which TIA Openness capabilities are documented vs require OPC UA / are unreachable. Useful for AI agents to redirect users when a request maps to an out-of-scope capability.
- README aligned with current state: tool count 175+ → 180; new Online operations bullet covers Compare and password support; V21 default; link to openness-limitations.

**Repo hygiene**

- Root `.gitignore` covers `dist/`, IDE noise (`.idea/`, `*.user`, `*.suo`), NuGet (`packages/`, `*.nupkg`), OS files (`Thumbs.db`, `.DS_Store`). `bin/`/`obj/` continue to be handled by per-project `.gitignore`.

## [0.0.26] - 2026-05-09

### T2-E: Technology Objects (3 new tools)
- New: `GetTechnologyObjects` — list all TOs with name, type (OfSystemLibElement), firmware version
- New: `ExportTechnologyObject` — export single TO to XML (follows same pattern as ExportBlock)
- New: `ExportTechnologyObjectsToDirectory` — batch export with regex filter
- Portal.cs: `ResolveTechnologyObjectCollection` helper + `GetTechnologyObjects`, `ExportTechnologyObject`, `ExportTechnologyObjectsToDirectory`
- T2-C skipped: Safety program compilation not accessible via public Openness API (AddIn framework only)

### T3-D: Nullable Warning Elimination
- Build now produces **0 warnings, 0 errors** (previously 32 warnings)
- Fixes applied across Portal.cs, McpServer.cs, Program.cs:
  - CS8602: Added `!` null-forgiving after `IsNullOrWhiteSpace`/`IsNullOrEmpty` guards (14 sites)
  - CS8604: Added `!` / `?? ""` at null-argument call sites (8 sites)
  - CS8619: `Array.ConvertAll(args!, a => a!)` for `object?[]` → `object[]` (3 sites)
  - CS8620: `ReferenceEqualityComparer.Instance!` for IEqualityComparer nullability (2 sites)
  - CS8601: `ipAddress!` in reflection Invoke call (1 site)
  - Program.cs: `LogDiag(x.Message ?? "...")` for nullable Message properties (4 sites)

## [0.0.24] - 2026-05-08

### T2-B: OPC UA Server Configuration (4 new tools)
- New: `GetOpcUaConfig` — inventory of all OPC UA server interfaces, SIMATIC interfaces, reference namespaces with Enabled state
- New: `SetOpcUaInterfaceEnabled` — enable/disable any interface type; takes effect after DownloadToPlc
- New: `ExportOpcUaInterface` — export ServerInterface/SimaticInterface/ReferenceNamespace to XML
- New: `ImportOpcUaInterface` — create or update an interface from XML file
- Portal.cs: `#region opcua` with `GetOpcUaConfig`, `SetOpcUaInterfaceEnabled`, `ExportOpcUaInterface`, `ImportOpcUaInterface`; uses `OpcUaProvider` via GetService + reflection chain through CommunicationGroup → ServerInterfaceGroup

## [0.0.23] - 2026-05-08

### T2-A: Alarm Text Management (5 new tools)
- New: `ExportAlarmClasses` / `ImportAlarmClasses` — alarm class definitions export/import
- New: `ExportAlarmTextLists` / `ImportAlarmTextLists` — all text lists as XLSX (multi-language)
- New: `ExportAlarmInstanceTexts` — instance-level alarm texts as XLSX with configurable columns
- Portal.cs: `#region alarms` with 5 methods; uses AlarmClassDataProvider/PlcAlarmTextProvider via GetService + PlcAlarmTextlistGroup via reflection

### T3-C: TIA Version Auto-Detection
- Engineering.cs: `DetectTiaMajorVersion()` — scans env var, registry (TIAP* keys), and filesystem (Portal V* dirs); returns highest installed version
- Program.cs: use auto-detected version when `--tia-major-version` not specified; logs source of version; falls back to 21 with warning

## [0.0.22] - 2026-05-08

### T3-A: Operation.Run — Centralized Exception Handling
- New: `src/TiaMcpServer/Siemens/Operation.cs` — `Operation.Run(logger, name, action)` / `Run<T>(...)` / `RunValue<T>(...)` with PortalException-aware logging
- Applied to `DisconnectPortal()` as the canonical example
- Full rollout across 60+ Portal.cs methods tracked in TODO.md (T3-A)

## [0.0.21] - 2026-05-08

### T1-B: Watch/Force Table Variable Configuration
- New: `GetPlcForceTables` MCP tool — list force tables (previously only watch tables were exposed)
- New: `SetWatchTableModifyValue` MCP tool — configure a watch table entry (address + value + trigger); write applied when online
- New: `SetForceTableEntry` MCP tool — configure a force table entry (address + forced value); force applied continuously while online
- Portal.cs: `GetPlcForceTables()`, `EnsureWatchTableEntry()`, `EnsureForceTableEntry()` + helpers
  - `FindOrCreateWatchTable`, `FindOrCreateForceTable`, `FindOrCreateTableEntry`, `TryInvokeMethodByName`, `SetEnumPropertyByName`
- API note: Watch/Force Table in TIA Portal Openness is declarative config — actual write/force occurs when TIA Portal is online

## [0.0.20] - 2026-05-08

### T1-A: Download to CPU
- New: `DownloadToPlc` MCP tool — downloads compiled PLC program to physical CPU via `DownloadProvider`
- New: `CheckDownloadReadiness` MCP tool — pre-flight check (DownloadProvider available, network config present) without actual download
- New: `ResponseDownload`, `ResponseCheckDownload` response types
- Portal.cs: `DownloadToPlc()`, `CheckDownloadReadiness()` with auto-accepting download configuration delegates (StopModules, StartModules, DataBlockReinitialization, ConsistentBlocksDownload, CheckBeforeDownload, etc.)
- Reflection-based `Download()` invocation to bypass compile-time ConnectionConfiguration→IConfiguration type mismatch

### T1-C: CPU Online State
- New: `GetOnlineState` MCP tool — reads OnlineProvider.State (Offline/Online/Incompatible/NotReachable/Protected)
- New: `GoOnline` MCP tool — establishes online connection, optional custom IP address
- New: `GoOffline` MCP tool — disconnects online session
- New: `ResponseOnlineState` response type
- Note: CPU operating mode (RUN/STOP) is NOT exposed in TIA Portal public API; documented in tool description

## [0.0.19] - 2026-05-08

- New: HTTP transport (`--transport http --http-prefix http://127.0.0.1:8765/ --http-api-key <secret>`)
- Fix: CliOptions `Logging` comment updated to reflect numeric modes (1=stderr, 2=Debug, 3=EventLog)
- Docs: CHANGELOG typo "Narketplace" → "Marketplace"

## [0.0.16] - 2025-09-02

- New: ImportFromDocuments and ImportBlocksFromDocuments (V20+)
- Guard: Version checks for export/import as documents (V20+)
- UX: Pre-check .s7res for missing en-US tags; warnings surfaced in responses
- Docs: README updates, prompts note V20+ and known LAD en-US limitation
- Refactor: Updated all McpException throws to SDK signature with McpErrorCode
- Chore: Added TODOs for tests/docs

## [0.0.15] - 2025-08-30

- prompts improved
- long running tasks as async tasks

## [0.0.14] - 2025-08-18

- better structure/tree format
- new GetSoftwareTree()
- bugfixes

## [0.0.13] - 2025-08-14

- logging integrated
- prompts added

## [0.0.12] - 2025-08-07

- export path fixed

## [0.0.11] - 2025-08-07

- project structure formatted as markdown code

## [0.0.10] - 2025-08-07

- tool responses improved

## [0.0.9] - 2025-08-04

- export of blocks and types with 'preservePath' option
- new tools
- some infos with attributes

## [0.0.8] - 2025-08-01

- improved jsonrpc responses
- updated dependencies

## [0.0.7] - 2025-07-18

- new GetState()
- return values fixed

## [0.0.6] - 2025-07-16

- refactored code to use new TIA Portal API
- only blocks (OB/FB/FC/DB) and types (UDT) are now retrieved from the PLC software
- use regex to filter blocks and types
- import of blocks and types to PLC software

## [0.0.5] - 2025-07-11

- locating of plc software by softwarePath. This makes it possible to access plc software in groups/subgroups
- new tool: retrieving of project structure as text
- new tool: compile plc software

## [0.0.4] - 2025-06-30

- opens local session or projects, depending on project file extension

## [0.0.3] - 2025-06-23

- Release on Visual Studio Code Marketplace
