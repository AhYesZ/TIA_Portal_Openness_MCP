# Tank Control Demo
Generated: 2026-05-10T23:10:26.7841993+08:00
Project: MCP_TankCtrl_20260510_230937
Path: C:\Users\XL626\Desktop\testtia\mcp-tank_20260510_230937

## By status
- FAIL: 1
- LOGIC_FAIL: 1
- OK: 23

| # | Tool | Status | ms | Note | Msg |
|---|---|---|---|---|---|
| 1 | Connect | OK | 766 |  | OK |
| 2 | CreateProject | OK | 6387 |  | OK |
| 3 | AddDeviceWithFallback | OK | 4694 | CPU 1211C | OK |
| 4 | AddHardwareCatalogDeviceWithProbe | OK | 8283 | KTP700 Basic | OK |
| 5 | ConnectDeviceNodesToProfinetSubnet | OK | 1734 | PROFINET PN_IE_1 | OK |
| 6 | PlcBuildAndImport | OK | 1764 | DefaultTagTable 10 个变量 | OK |
| 7 | ImportType | OK | 956 | UDT_TankStatus 7 字段中文 | OK |
| 8 | PlcBuildAndImport | OK | 1530 | DB_Tank 6 个成员 | OK |
| 9 | PlcBuildAndImport | OK | 1519 | FC_StartStop（SCL builder） | OK |
| 10 | PlcBuildAndImport | OK | 1354 | FC_LevelControl（比较+嵌套） | OK |
| 11 | PlcBuildAndImport | OK | 1370 | FC_Alarm（锁存+复位） | OK |
| 12 | PlcBuildAndImport | OK | 1164 | FC_Scaling（IF+浮点比较+限幅） | OK |
| 13 | PlcBuildAndImport | OK | 1210 | FC_StateMachine（CASE） | OK |
| 14 | PlcBuildAndImport | OK | 2355 | FC_LampPattern（位移+MOD） | OK |
| 15 | ComposePlcLadFcBlockXml | OK | 19 | compose LAD FC offline | OK |
| 16 | ImportBlock | OK | 1397 | FC_Manual_LAD 真灌入 | OK |
| 17 | PlcBuildAndImport | OK | 1379 | Cyclic_Main 调度 FC | OK |
| 18 | CompileSoftware | LOGIC_FAIL | 1813 | 最终编译 - 期待 0 错 0 警 | success=false (见 fullText) |
| 19 | SaveProject | OK | 1240 | Save before HMI | OK |
| 20 | BuildClassicHmiTagTableXml | OK | 11 | HMI 变量表 7 个 | OK |
| 21 | ImportHmiTagTable | OK | 1319 | ImportHmiTagTable | OK |
| 22 | BuildClassicHmiScreenXml | OK | 25 | HMI 主画面 8 个控件 | OK |
| 23 | ImportHmiScreen | FAIL | 755 | ImportHmiScreen | An error occurred invoking 'ImportHmiScreen': Failed importing HMI screen from 'C:\Users\XL626\AppData\Local\Temp\mcp_tank_hmi_screen_202605... |
| 24 | SaveProject | OK | 956 | Save 2 final | OK |
| 25 | Disconnect | OK | 50 |  | OK |
