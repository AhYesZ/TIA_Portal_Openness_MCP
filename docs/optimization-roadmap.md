# TIA Portal MCP Server — 产品化优化路线图

> 生成日期：2026-05-08  
> 基于：160 个已有 MCP 工具 + `D:\app\TIA21\Portal V21\PublicAPI\V21` 全量 API 扫描

---

## 总体目标

让任何 AI 模型都能通过这个 MCP 服务，对 Siemens TIA Portal 实现**全生命周期自动化**：
工程设计 → 编程 → 编译 → **下载部署** → 在线监控 → **变量调试** → 诊断维护。

当前最大缺口是"在线操作"这一环——模型无法下载程序到 CPU，无法写/强制变量，无法查 CPU 状态。
补全这三点后，MCP 服务才算真正闭环。

---

## 现状速览

| 维度 | 现状 |
|---|---|
| 已有工具数量 | 160 个 |
| 离线工程操作 | 覆盖完整（项目/设备/块/类型/HMI/标签/库） |
| 在线只读监控 | 部分覆盖（WatchTable 读值） |
| **在线写入/下载** | **完全缺失** |
| 报警、OPC UA、安全、运动 | 未覆盖 |
| HTTP 传输 | 已实现 MVP（2026-05-08） |
| 架构质量 | 有改进空间（异常处理重复、空值警告） |

---

## Tier 1 — 在线操作（最高优先级，产品完整性缺口）

### T1-A：下载程序到 CPU

**对应 API**：`Siemens.Engineering.Download`  
**为什么最重要**：没有下载，"编写→编译→部署"的闭环无法完成，所有工程操作都停在离线阶段。

#### Portal.cs 新增方法

```csharp
// 下载单个软件对象到 CPU
public ResponseDownload DownloadToPlc(
    string softwarePath,
    bool consistentBlocksOnly = true,      // true=仅一致块, false=所有块
    bool keepActualValues = true,           // 保留 DB 实际值
    bool startModuleAfterDownload = true,   // 下载后自动启动 CPU
    bool stopModuleBeforeDownload = true,   // 下载前先停 CPU
    bool checkBeforeDownload = true);       // 预检验证

// 批量下载（含重试和详细结果）
public ResponseDownloadBatch DownloadBlocksToPlc(
    string softwarePath,
    string[]? blockPaths = null,            // null = 全部块
    bool consistentBlocksOnly = true,
    bool keepActualValues = true);
```

#### McpServer.cs 新增工具

```
DownloadToPlc         — 下载整个 PLC 软件到 CPU
DownloadBlocksToPlc   — 选择性下载指定块
CheckDownloadReadiness — 下载前预检（不实际下载）
```

#### 响应结构

```csharp
public class ResponseDownload
{
    public bool? Ok { get; set; }
    public string? Message { get; set; }
    public string? CpuState { get; set; }           // RUN/STOP/STARTUP
    public int? BlocksDownloaded { get; set; }
    public string[]? Warnings { get; set; }
    public string[]? Errors { get; set; }
    public JsonObject? Meta { get; set; }
}
```

#### 安全约束（Description 中必须注明）

- 下载会导致 CPU 短暂停机，**必须**先调用 `GetState` 确认无人在线操作
- 对安全 CPU（Safety CPU）禁用此工具，需走 `CompileSafetyProgram` 单独流程
- `keepActualValues=false` 会重置所有 DB 实际值，操作不可逆

---

### T1-B：在线变量强制写入

**对应 API**：`Siemens.Engineering.SW.WatchAndForceTables`  
**为什么重要**：调试时必须能写变量，否则只能看不能改，调试闭环断裂。

#### Portal.cs 新增方法

```csharp
// 单变量写值（Watch Table，非强制，CPU RUN 时生效一次）
public ResponseMessage WriteWatchValue(
    string softwarePath,
    string address,     // e.g. "DB1.DBX0.0" or "%M0.0"
    string value,
    string trigger = "Permanent");

// 强制变量（Force Table，持续强制，CPU 重启后失效）
public ResponseMessage ForceVariable(
    string softwarePath,
    string address,
    string value);

// 清除所有强制值
public ResponseMessage ClearForces(string softwarePath);

// 批量强制（从 JSON 数组）
public ResponseForce ForceVariables(
    string softwarePath,
    ForceEntry[] entries);   // [{address, value}, ...]

// 读取当前强制状态
public ResponseForceStatus GetForceStatus(string softwarePath);
```

#### McpServer.cs 新增工具

```
WriteWatchValue     — 单次写值（非持续）
ForceVariable       — 强制单个变量（持续）
ForceVariables      — 批量强制变量
ClearForces         — 清除所有强制
GetForceStatus      — 查询当前强制状态
```

#### 安全约束

- Force 操作对真实设备危险，Description 必须包含 `[ONLINE-WRITE][DANGER]` 标签
- 需要 CPU 处于 RUN 模式（部分型号）
- 安全 CPU 的安全区域变量禁止强制

---

### T1-C：CPU 在线状态与诊断

**对应 API**：`Siemens.Engineering.Online`  
**为什么重要**：下载前/后必须知道 CPU 状态；调试时需要故障诊断信息。

#### Portal.cs 新增方法

```csharp
// 连接在线（可带凭据）
public ResponseOnlineConnect ConnectOnline(
    string devicePath,
    string? username = null,
    string? password = null);

// 断开在线
public bool DisconnectOnline(string devicePath);

// 获取 CPU 运行状态
public ResponseCpuState GetCpuOnlineState(string devicePath);

// 获取故障缓冲区
public ResponseFaultBuffer GetFaultBuffer(string devicePath);

// 修改 CPU 运行模式
public ResponseMessage SetCpuMode(string devicePath, string mode); // "RUN" | "STOP"
```

#### McpServer.cs 新增工具

```
GetCpuOnlineState   — 查询 CPU 当前状态（RUN/STOP/FAULT/STARTUP）
GetFaultBuffer      — 读取故障缓冲区（最近 N 条故障）
SetCpuMode          — 切换 CPU 运行模式（RUN ↔ STOP）
ConnectOnline       — 建立在线连接（支持密码保护 CPU）
DisconnectOnline    — 断开在线连接
```

#### 响应结构

```csharp
public class ResponseCpuState
{
    public string? State { get; set; }          // "RUN"|"STOP"|"STARTUP"|"HOLD"|"FAULT"
    public string? DevicePath { get; set; }
    public string? CpuType { get; set; }
    public string? FirmwareVersion { get; set; }
    public bool? SafetyEnabled { get; set; }
    public DateTime? Timestamp { get; set; }
}
```

---

## Tier 2 — API 覆盖扩展（工程完整性）

### T2-A：报警文本库管理

**对应 API**：`Siemens.Engineering.SW.Alarms`

```
GetAlarmClasses(softwarePath)                           — 列出报警类别
ExportAlarmTexts(softwarePath, exportPath, format)      — 导出报警文本（支持 XLSX）
ImportAlarmTexts(softwarePath, importPath)              — 导入报警文本
GetAlarmTextList(softwarePath, textListName)            — 读取文本列表内容
```

**价值**：多语言工程必用，报警文本通常由 Excel 维护，自动导入节省大量手工操作。

---

### T2-B：OPC UA 服务器配置

**对应 API**：`Siemens.Engineering.SW.OpcUa`

```
GetOpcUaConfig(softwarePath)                            — 读取 OPC UA 配置
EnableOpcUaServer(softwarePath, enabled)                — 启用/禁用 OPC UA 服务器
ExportOpcUaInterface(softwarePath, exportPath)          — 导出 OPC UA 接口定义
AddOpcUaNamespace(softwarePath, namespaceUri)           — 添加自定义命名空间
SetOpcUaAccessRole(softwarePath, role, permissions[])   — 配置访问权限
```

**价值**：工业 IoT 集成标配，客户要求"接 SCADA"时必须配置 OPC UA。

---

### T2-C：安全程序编译

**对应 API**：`Siemens.Engineering.Safety` + `Siemens.Engineering.AddIn.Safety`

```
CompileSafetyProgram(softwarePath)          — 安全程序独立编译
ValidateSafetyProgram(softwarePath)         — 安全验证（SafetyValidation 框架）
GetSafetyCompileResult(softwarePath)        — 读取编译/验证结果
GetSafetySignature(softwarePath)            — 读取安全签名（用于审计）
```

**价值**：安全 PLC（F-CPU）工程必需，普通 CompileSoftware 无法编译安全块。

---

### T2-D：连接配置自动化

**对应 API**：`Siemens.Engineering.Connection`

```
ConfigureProfinetSubnet(projectName, subnetName, address, mask)  — 配置 PROFINET 子网
ConfigureGateway(devicePath, gatewayAddress)                     — 设置网关
SetDeviceIpAddress(devicePath, interfaceName, ip, mask)          — 修改设备 IP
GetNetworkTopology(projectName)                                   — 读取网络拓扑
```

**价值**：设备 IP 修改是工程师最频繁的操作之一，目前只能通过博途 UI 手动完成。

---

### T2-E：运动控制/工艺对象

**对应 API**：`Siemens.Engineering.SW.TechnologicalObjects`

```
GetTechnologyObjects(softwarePath)                      — 列出所有工艺对象（轴、凸轮等）
ConfigureAxisHardware(softwarePath, toName, hwPath)     — 配置轴硬件连接
ExportCamData(softwarePath, toName, exportPath)         — 导出凸轮数据
ImportCamData(softwarePath, toName, importPath)         — 导入凸轮数据
GetAxisParameters(softwarePath, toName)                 — 读取轴参数
```

**价值**：运动控制工程（包装机、传送带、机器人）是 S7-1500T 的核心应用场景。

---

## Tier 3 — 架构质量改进

### T3-A：统一异常处理辅助类 `Operation.Run`

**当前问题**：Portal.cs 有 60+ 个几乎相同的 `try/catch` 块：

```csharp
// 现在（重复 60+ 次）
try
{
    _project = null;
    _portal?.Dispose();
    return true;
}
catch (Exception)
{
    return false;
}
```

**目标（引入 `Operation.Run`）**：

```csharp
// 改后：单行，统一日志和错误上下文
return Operation.Run(_logger, "DisconnectPortal", () =>
{
    _project = null;
    _portal?.Dispose();
});
```

**实现**：新建 `src/TiaMcpServer/Siemens/Operation.cs`：

```csharp
internal static class Operation
{
    public static bool Run(ILogger? logger, string operationName, Action body)
    {
        try
        {
            body();
            return true;
        }
        catch (PortalException pex)
        {
            logger?.LogWarning(pex, "{Op} failed: {Msg}", operationName, pex.Message);
            return false;
        }
        catch (Exception ex)
        {
            logger?.LogError(ex, "{Op} unexpected failure", operationName);
            return false;
        }
    }

    public static T? Run<T>(ILogger? logger, string operationName, Func<T> body)
        where T : class
    {
        try { return body(); }
        catch (Exception ex)
        {
            logger?.LogError(ex, "{Op} unexpected failure", operationName);
            return null;
        }
    }
}
```

**收益**：减少约 200 行重复代码，统一日志结构，消除静默失败。

---

### T3-B：Guard 空值检查辅助类

**当前问题**：大量重复的 `if (x == null) return false;` 散布全文件。

```csharp
// 改前
var device = GetDevice(devicePath);
if (device == null)
{
    _logger?.LogWarning("Device not found: {Path}", devicePath);
    return false;
}

// 改后
var device = Guard.RequireDevice(GetDevice(devicePath), devicePath);
// 抛 PortalException(NotFound) → MCP 层统一处理为 InvalidParams
```

**实现**：新建 `src/TiaMcpServer/Siemens/Guard.cs`

---

### T3-C：TIA 版本自动检测

**当前问题**：用户必须手动传 `--tia-major-version 21`，忘了就报错。

**方案**：

```csharp
// Engineering.cs 中增加
public static int? DetectTiaVersion()
{
    // 1. 扫描 %TiaPortalLocation% 环境变量路径中的版本号
    // 2. 扫描注册表 HKLM\SOFTWARE\Siemens\Automation\Openness
    // 3. 扫描 C:\Program Files\Siemens\Automation\Portal V*
    // 返回最高版本号，找不到返回 null
}
```

**CLI 行为**：`--tia-major-version` 未指定时自动检测，检测失败再报错提示手动指定。

---

### T3-D：修复 Nullable 编译警告

Portal.cs 和 McpServer.cs 当前有 25+ 个 CS8602/CS8604 警告。  
逐步用 null-forgiving 运算符（`!`）或 Guard 替换，目标：构建 0 警告。

---

## Tier 4 — 开发者体验与文档

### T4-A：每工具独立文档

在 `docs/tools/` 下为每类工具创建文档（格式已有 `hardware-network.md` 作为模板）：

| 文档 | 内容 |
|---|---|
| `docs/tools/download.md` | DownloadToPlc、CheckDownloadReadiness |
| `docs/tools/online-write.md` | ForceVariable、WriteWatchValue、ClearForces |
| `docs/tools/online-state.md` | GetCpuOnlineState、GetFaultBuffer、SetCpuMode |
| `docs/tools/alarms.md` | 报警文本管理工具 |
| `docs/tools/opc-ua.md` | OPC UA 配置工具 |
| `docs/tools/safety.md` | 安全程序编译工具 |
| `docs/tools/export-blocks.md` | ExportBlock、ExportBlocks（已有工具补文档） |
| `docs/tools/import-blocks.md` | ImportBlock、ImportBlocksFromDirectory |

每个文档包含：Overview、前置条件、参数说明、调用序列、错误处理、Mermaid 流程图、curl/JSON 示例。

---

### T4-B：XML 文档注释 + IDE Tooltip

在 `TiaMcpServer.csproj` 中启用：

```xml
<PropertyGroup>
  <DocumentationFile>bin\$(Configuration)\net48\TiaMcpServer.xml</DocumentationFile>
</PropertyGroup>
```

对 McpServer.cs 中所有 `[McpServerTool]` 方法添加 `/// <summary>` 注释。

---

### T4-C：自然语言配方扩充

在 `docs/TIA_NL_INTENT_RECIPES.md` 中新增场景：

```
13. 下载程序到 CPU
    "把程序下载到 PLC" →
    GetState → CompileSoftware → CheckDownloadReadiness → DownloadToPlc → GetCpuOnlineState

14. 强制变量调试
    "把 DB1.DBX0.0 强制为 TRUE" →
    GetCpuOnlineState → ForceVariable → GetForceStatus → (验证后) ClearForces

15. 报警文本批量更新
    "把 Excel 里的报警文本导入博途" →
    GetSoftwareInfo → ImportAlarmTexts → CompileSoftware

16. OPC UA 一键配置
    "给 PLC 配置 OPC UA 服务器" →
    GetSoftwareInfo → EnableOpcUaServer → AddOpcUaNamespace → ExportOpcUaInterface
```

---

### T4-D：HTTP Transport 规范对齐（后续）

- SSE 端点支持（`GET /mcp/sse`）供支持流式的客户端使用
- `Mcp-Session-Id` 请求头处理（多会话隔离）
- `MCP-Protocol-Version` 请求头验证
- `/mcp` `GET` 返回服务器能力信息（已有基础实现）

---

## 实施顺序建议

```
阶段 1（当前sprint）：T1-A Download + T1-C CPU状态  ← 完成部署闭环
阶段 2：T1-B 变量强制写入                           ← 完成调试闭环
阶段 3：T3-A Operation.Run + T3-B Guard             ← 代码质量，为后续扩展打基础
阶段 4：T2-A 报警 + T2-B OPC UA                    ← 工程完整性
阶段 5：T2-C 安全 + T2-D 连接配置 + T2-E 运动控制  ← 高级功能
阶段 6：T4-A~D 文档、注释、配方                    ← 交付质量
```

---

## 新工具影响范围汇总

| 新工具 | 新增 Portal.cs 方法 | 新增 McpServer.cs 工具 | 新增响应类型 |
|---|---|---|---|
| Download to CPU | 2 | 3 | 2 |
| Force/Write 变量 | 5 | 5 | 2 |
| CPU 在线状态 | 5 | 5 | 2 |
| 报警文本管理 | 4 | 4 | 1 |
| OPC UA 配置 | 5 | 5 | 2 |
| 安全程序编译 | 4 | 4 | 1 |
| 连接配置 | 4 | 4 | 1 |
| 运动控制/TO | 5 | 5 | 2 |
| **合计** | **34** | **35** | **13** |

完成后，工具总数从 **160 → 约 195**，覆盖范围从"离线工程"扩展到"完整生命周期自动化"。

---

## 文件变更清单（参考）

```
src/TiaMcpServer/
├── Siemens/
│   ├── Portal.cs                   ← 新增 34 个方法
│   ├── Operation.cs                ← 新建（T3-A）
│   ├── Guard.cs                    ← 新建（T3-B）
│   ├── PortalErrorCode.cs          ← 可能新增错误码
│   └── PortalException.cs          ← 不变
├── ModelContextProtocol/
│   ├── McpServer.cs                ← 新增 35 个工具
│   ├── Responses.cs                ← 新增 13 个响应类
│   └── McpPrompts.cs               ← 新增下载/调试相关 Prompt
└── TiaMcpServer.csproj             ← 启用 DocumentationFile

docs/
├── optimization-roadmap.md         ← 本文件
├── TIA_NL_INTENT_RECIPES.md        ← 新增 4 个场景（T4-C）
├── tool-capability-matrix.md       ← 补充新工具行
└── tools/
    ├── download.md                 ← 新建
    ├── online-write.md             ← 新建
    ├── online-state.md             ← 新建
    ├── alarms.md                   ← 新建
    ├── opc-ua.md                   ← 新建
    ├── safety.md                   ← 新建
    ├── export-blocks.md            ← 新建
    └── import-blocks.md            ← 新建
```
