# MCP Full Demo (KTP700) — Validation
Generated: 2026-05-10T16:43:32.5093709+08:00
Project: MCP_Full_20260510_164233  Path: C:\Users\XL626\Desktop\testtia\mcp-full_20260510_164233

## By status
- FAIL: 1
- OK: 24

## Step-by-step
| # | Tool | Status | ms | Note | Message |
|---|---|---|---|---|---|
| 1 | Connect | OK | 1636 |  | OK |
| 2 | CreateProject | OK | 10197 |  | OK |
| 3 | AddDeviceWithFallback | OK | 4751 | CPU 1211C V4.7 | OK |
| 4 | AddHardwareCatalogDeviceWithProbe | OK | 9125 | KTP700 Basic PN | OK |
| 5 | ConnectDeviceNodesToProfinetSubnet | OK | 2498 | PROFINET PN_IE_1 | OK |
| 6 | PlcBuildAndImport | OK | 1257 | DefaultTagTable | OK |
| 7 | ImportType | OK | 1802 | UDT_Motor (中文注释) | OK |
| 8 | PlcBuildAndImport | OK | 1464 | DB_Motor | OK |
| 9 | PlcBuildAndImport | OK | 1486 | FC_StartStop via builder (全局变量 + 中文注释) | OK |
| 10 | ComposePlcLadFcBlockXml | OK | 22 | compose LAD FC offline | OK |
| 11 | ImportBlock | OK | 1197 | FC_Manual_LAD (LAD via composer) | OK |
| 12 | ImportBlock | OK | 1081 | Cyclic_Main OB200 SCL calls FC | OK |
| 13 | CompileSoftware | OK | 1152 | PLC compile - expect 0 errors | OK |
| 14 | SaveProject | OK | 13329 | save after PLC clean compile | OK |
| 15 | GetHmiConnections | OK | 72 | discover auto-created HMI connections | OK |
| 16 | GetHmiTagTables | OK | 54 | list HMI tag tables | OK |
| 17 | GetHmiScreens | OK | 41 | list HMI screens | OK |
| 18 | BuildClassicHmiTagTableXml | OK | 8 | build HMI tag table XML | OK |
| 19 | ImportHmiTagTable | OK | 1585 | ImportHmiTagTable | OK |
| 20 | BuildClassicHmiScreenXml | OK | 21 | build HMI screen XML | OK |
| 21 | ImportHmiScreen | FAIL | 1292 | ImportHmiScreen | An error occurred invoking 'ImportHmiScreen': Failed importing HMI screen from 'C:\Users\XL626\AppData\Local\Temp\mcp_fu... |
| 22 | GetHmiTagTables | OK | 41 | final state check | OK |
| 23 | GetHmiScreens | OK | 40 | final state check | OK |
| 24 | SaveProject | OK | 732 | final save | OK |
| 25 | Disconnect | OK | 49 |  | OK |
