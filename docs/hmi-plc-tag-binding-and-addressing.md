# HMI 与 PLC 变量绑定规范

交付包默认采用“符号说明 + 绝对地址读写”的方式建立 WinCC Unified 与 PLC 的变量连接。HMI 变量必须同时带有：

- `plcTag`：PLC 侧符号路径，例如 `DB_HMI_Interface.CmdEnable`。
- `address`：HMI 运行时访问地址，例如 `%DB200.DBX0.0`。
- `connectionName`：已验证的 HMI 连接，例如 `HMI_Connection_1`。

## 前提

| 项目 | 要求 |
|---|---|
| HMI 接口 DB | `DB_HMI_Interface`，DB 编号 `200` |
| DB 访问方式 | `MemoryLayout = Standard`，用于稳定的绝对地址 |
| HMI 连接 | 先调用 `EnsureUnifiedHmiConnection`，并确认驱动与 PLC 系列匹配 |
| 子网 | PLC PN 口与 HMI PN 口位于同一 PROFINET 子网 |
| 编译 | PLC 编译错误为 0，HMI 画面与变量可读回 |

## 地址清单

| HMI Tag | 数据类型 | PLC 符号 | 绝对地址 |
|---|---|---|---|
| `HMI_CmdEnable` | Bool | `DB_HMI_Interface.CmdEnable` | `%DB200.DBX0.0` |
| `HMI_CmdDisable` | Bool | `DB_HMI_Interface.CmdDisable` | `%DB200.DBX0.1` |
| `HMI_CmdReset` | Bool | `DB_HMI_Interface.CmdReset` | `%DB200.DBX0.2` |
| `HMI_CmdApply` | Bool | `DB_HMI_Interface.CmdApply` | `%DB200.DBX0.3` |
| `HMI_StatusActive` | Bool | `DB_HMI_Interface.StatusActive` | `%DB200.DBX1.0` |
| `HMI_StatusError` | Bool | `DB_HMI_Interface.StatusError` | `%DB200.DBX1.1` |
| `HMI_StatusWarning` | Bool | `DB_HMI_Interface.StatusWarning` | `%DB200.DBX1.2` |
| `HMI_StepNo` | Int | `DB_HMI_Interface.StepNo` | `%DB200.DBW2` |
| `HMI_ValueSetpoint` | Real | `DB_HMI_Interface.ValueSetpoint` | `%DB200.DBD4` |
| `HMI_ValueActual` | Real | `DB_HMI_Interface.ValueActual` | `%DB200.DBD8` |
| `HMI_ValueOutput` | Real | `DB_HMI_Interface.ValueOutput` | `%DB200.DBD12` |
| `HMI_OutputMin` | Real | `DB_HMI_Interface.OutputMin` | `%DB200.DBD16` |
| `HMI_OutputMax` | Real | `DB_HMI_Interface.OutputMax` | `%DB200.DBD20` |
| `HMI_CounterPreset` | DInt | `DB_HMI_Interface.CounterPreset` | `%DB200.DBD24` |
| `HMI_CounterValue` | DInt | `DB_HMI_Interface.CounterValue` | `%DB200.DBD28` |

## MCP 调用规则

创建 PLC 侧 HMI 变量时，直接在 `EnsureUnifiedHmiTag` 中传入 `address`。不要先创建空变量，再用 `InvokeObject` 单独补 `LogicalAddress`。

```text
EnsureUnifiedHmiConnection(
  hmiSoftwarePath="HMI_RT_1",
  connectionName="HMI_Connection_1",
  plcName="<GetProjectTree 中的 PLC 软件节点>"
)

EnsureUnifiedHmiTagTable(
  hmiSoftwarePath="HMI_RT_1",
  tagTableName="HMI_Interface_Tags"
)

EnsureUnifiedHmiTag(
  hmiSoftwarePath="HMI_RT_1",
  tagTableName="HMI_Interface_Tags",
  tagName="HMI_CmdEnable",
  hmiDataType="Bool",
  plcName="PLC_1",
  plcTag="DB_HMI_Interface.CmdEnable",
  connectionName="HMI_Connection_1",
  address="%DB200.DBX0.0"
)
```

## 验收条件

- `DescribeObject(HmiConnection)` 或连接读回中，`CommunicationDriver` 必须匹配实际 PLC 系列。
- S7-1200 / S7-1500 项目中，`CommunicationDriver` 不得为 `SIMATIC S7 300/400`。
- 每个 HMI Tag 读回 `Connection=HMI_Connection_1`。
- 每个 HMI Tag 读回 `Address` 或 `LogicalAddress`，值等于蓝图中的 `%DB200...` 地址。
- 若 `Address` 与 `LogicalAddress` 都为空，该 Tag 视为未绑定，必须重新创建或重新运行绑定流程。

## 常见问题

| 现象 | 处理 |
|---|---|
| 单个 Tag 红字 | 核对地址字宽、字节偏移、DB 编号和 DB 标准访问设置 |
| 全部 Tag 红字 | 先检查 HMI 连接驱动、Partner、Station、Node、PROFINET 子网 |
| 地址栏为空 | 重新调用 `EnsureUnifiedHmiTag`，必须传入 `address` 参数 |
| 符号能写入但运行时无值 | 以绝对地址读回为准，确认 `Address` 或 `LogicalAddress` 非空 |
