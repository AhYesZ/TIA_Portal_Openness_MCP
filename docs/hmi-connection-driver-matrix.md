# HMI 连接驱动选择规范

`EnsureUnifiedHmiConnection` 用于创建或修正 WinCC Unified HMI 与 PLC 的连接。驱动必须根据实际 PLC 设备类型选择，不能保留 TIA 默认值。

## 驱动矩阵

| PLC 系列 | 典型订货号前缀 | 必须匹配的 CommunicationDriver |
|---|---|---|
| S7-1200 | `6ES7 21x-...` | `SIMATIC S7-1200/1500` 或等效 1200/1500 枚举 |
| S7-1500 | `6ES7 5xx-...` | `SIMATIC S7-1200/1500` 或等效 1200/1500 枚举 |
| ET 200SP CPU | `6ES7 51x-...` | `SIMATIC S7-1200/1500` 或等效 1500 枚举 |
| S7-300 | `6ES7 31x-...` | `SIMATIC S7 300/400` |
| S7-400 | `6ES7 41x-...` | `SIMATIC S7 300/400` |

交付包默认面向 S7-1200 / S7-1500。PLC 系列无法识别时，也按 S7-1200/1500 处理，避免落到 `SIMATIC S7 300/400`。

## 调用规则

`plcName` 必须来自 `GetProjectTree` 中的 PLC 软件节点，不要使用目录显示名或手写站点名。

```text
EnsureUnifiedHmiConnection(
  hmiSoftwarePath="HMI_RT_1",
  connectionName="HMI_Connection_1",
  plcName="PLC_1"
)
```

工具会从 PLC 软件节点反查设备、站点、PROFINET 节点和 CPU `TypeIdentifier`，再写入：

- `Partner`
- `Station`
- `Node`
- `InitialAddress` 或对应 IP 字段
- `CommunicationDriver`

## 验收条件

- S7-1200 / S7-1500 项目读回的 `CommunicationDriver` 必须包含 `1200`、`1500`、`S712`、`S715` 或等效枚举名。
- S7-1200 / S7-1500 项目读回 `300/400` 视为失败，必须重新运行连接创建或替换为新编译的 `TiaMcpServer.exe`。
- `Partner`、`Station`、`Node` 至少应读回实际 PLC 设备、站点或 PN 接口相关值。
- 创建 HMI Tag 前必须先完成连接验收。

## 根因速查

| 现象 | 常见原因 | 处理 |
|---|---|---|
| S7-1200 项目显示 `300/400` | 旧版工具未识别带空格的订货号，例如 `6ES7 211...` | 使用本包内新编译的 MCP，可执行文件已按去空格规则识别 |
| 驱动为空 | TIA 当前 API 未暴露可写枚举或连接未创建成功 | 重新运行 `EnsureUnifiedHmiConnection`，失败时检查返回信息 |
| Tag 全部红字 | 驱动、Partner、Node 或子网不正确 | 先修正连接，再创建 HMI Tag |
| 仅部分 Tag 红字 | DB 编号、地址偏移或数据类型不一致 | 按 `hmi-plc-tag-binding-and-addressing.md` 核对地址 |
