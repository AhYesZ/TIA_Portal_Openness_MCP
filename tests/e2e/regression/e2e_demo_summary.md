# MCP Demo Project — Validation
Generated: 2026-05-10T10:57:28.3534101+08:00
Project: MCP_Demo_20260510_105644
Path: C:\Users\XL626\Desktop\testtia\mcp-demo_20260510_105644

## By status
- OK: 16

## Step-by-step
| # | Tool | Status | ms | Note | Message |
|---|---|---|---|---|---|
| 1 | Connect | OK | 843 |  | OK |
| 2 | CreateProject | OK | 6736 |  | OK |
| 3 | AddDeviceWithFallback | OK | 5248 | CPU 1211C V4.7 | OK |
| 4 | AddHardwareCatalogDeviceWithProbe | OK | 8555 | KTP700 Basic PN | OK |
| 5 | ConnectDeviceNodesToProfinetSubnet | OK | 1838 | PLC<->HMI on PN_IE_1 | OK |
| 6 | PlcBuildAndImport | OK | 1337 | UDT_Motor | OK |
| 7 | PlcBuildAndImport | OK | 1284 | DefaultTagTable | OK |
| 8 | PlcBuildAndImport | OK | 1605 | DB_Motor | OK |
| 9 | PlcBuildAndImport | OK | 1221 | FB_StartStop SCL | OK |
| 10 | PlcBuildAndImport | OK | 1575 | FC_Lamp SCL | OK |
| 11 | CompileSoftware | OK | 1729 | final compile - expect 0 errors | OK |
| 12 | BuildClassicHmiScreenXml | OK | 23 |  | OK |
| 13 | BuildClassicHmiTagTableXml | OK | 8 |  | OK |
| 14 | SaveProject | OK | 8189 |  | OK |
| 15 | GetState | OK | 38 |  | OK |
| 16 | Disconnect | OK | 42 |  | OK |
