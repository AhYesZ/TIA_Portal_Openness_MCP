# MCP E2E Verification Result

Run: 2026-05-11 10:31:49  |  Attached project: `MCP_TankCtrl_20260510_230937`
Pass: 22 / 22  |  Fail: 0

## Verified (PASS)

| Layer | Tool | Time(ms) | Sample output |
|---|---|---:|---|
| L0 | `Bootstrap` | 101 | {"ready":true,"environment":{"tiaVersionInUse":21,"tiaVersionDetected":21,"opennessGroupOk":true,"tiaInstallPath":"D:\\a |
| L0 | `GetState` | 3 | {"isConnected":false,"project":"-","session":"-","message":"TIA-Portal MCP server state retrieved","meta":{"timestamp":" |
| L0 | `RunCapabilitySelfTest` | 14 | {"ok":true,"includeProjectTree":false,"items":[{"id":"openness.user-group","name":"Siemens TIA Openness user group","sta |
| L2-Builder | `BuildPlcTagTableXml` | 16 | {"xml":"\u003C?xml version=\u00221.0\u0022 encoding=\u0022utf-8\u0022?\u003E\r\n\u003CDocument\u003E\r\n \u003CEngineeri |
| L2-Builder | `ComposePlcFcBlockXml` | 20 | {"xml":"\u003C?xml version=\u00221.0\u0022 encoding=\u0022utf-8\u0022?\u003E\r\n\u003CDocument\u003E\r\n \u003CEngineeri |
| L2-Builder | `BuildClassicHmiScreenXml` | 26 | {"xml":"\u003C?xml version=\u00221.0\u0022 encoding=\u0022utf-8\u0022?\u003E\r\n\u003CDocument\u003E\r\n \u003CEngineeri |
| L1-Portal | `Connect` | 748 | {"message":"Connected to TIA-Portal","meta":{"timestamp":"2026-05-11T10:31:46.0849178+08:00","success":true}} |
| L1-Project | `AttachToOpenProject` | 38 | {"message":"Attached to open project \u0027MCP_TankCtrl_20260510_230937\u0027","meta":{"timestamp":"2026-05-11T10:31:46. |
| L1-Project | `GetProject` | 64 | {"items":[{"name":"MCP_TankCtrl_20260510_230937","attributes":[{"name":"Author","value":"","accessMode":"Read"},{"name": |
| L1-Project | `GetProjectTree` | 335 | {"tree":"\u0060\u0060\u0060\nMCP_TankCtrl_20260510_230937\r\n\u251C\u2500\u2500 Devices [Collection]\r\n\u2502 \u251C\u2 |
| L1-Hardware | `GetDevices` | 25 | {"items":[{"name":"PLC_1","description":"Siemens.Engineering.HW.DeviceImpl","attributes":[{"name":"Author","value":"XL62 |
| L1-Hardware | `SearchHardwareCatalog` | 509 | {"keyword":"1211C","count":40,"items":[{"source":"HardwareCatalog","keyword":"1211C","articleNumber":"6ES7 211-1AD30-0XB |
| L1-PLC | `GetSoftwareInfo` | 19 | {"name":"PLC_1","description":"Siemens.Engineering.SW.PlcSoftware","attributes":[{"name":"Name","value":"PLC_1","accessM |
| L1-PLC | `GetSoftwareTree` | 67 | {"tree":"\u0060\u0060\u0060\nPLC_1 [PLC Software]\r\n\u251C\u2500\u2500 Program blocks\r\n\u2502 \u251C\u2500\u2500 Main |
| L1-PLC | `GetBlocks` | 285 | {"items":[{"typeName":"OB","name":"Main","namespace":"","programmingLanguage":"LAD","memoryLayout":"Optimized","isConsis |
| L1-PLC-Build | `PlcBuildAndImport` | 12 | {"dryRun":true,"buildKind":"tagtable","generatedDirectory":"C:\\Users\\XL626\\AppData\\Local\\Temp\\tia_mcp_plc_build_im |
| L1-PLC-Build | `PlcBuildAndImport` | 10 | {"dryRun":true,"buildKind":"globaldb","generatedDirectory":"C:\\Users\\XL626\\AppData\\Local\\Temp\\tia_mcp_plc_build_im |
| L1-PLC-Build | `PlcBuildAndImport` | 5 | {"dryRun":true,"buildKind":"fc","generatedDirectory":"C:\\Users\\XL626\\AppData\\Local\\Temp\\tia_mcp_plc_build_import_2 |
| L2-Online | `GetOnlineState` | 51 | {"state":"Offline","isOnline":false,"isReachable":false,"message":"\u0027PLC_1\u0027 is offline. Call GoOnline first."} |
| L2-Online | `CheckDownloadReadiness` | 51 | {"ready":true,"hasDownloadProvider":true,"hasConfiguration":true,"isConsistent":true,"message":"PLC \u0027PLC_1\u0027 is |
| L0 | `GetState` | 50 | {"isConnected":true,"project":"MCP_TankCtrl_20260510_230937","session":"-","message":"TIA-Portal MCP server state retrie |
| L1-Portal | `Disconnect` | 31 | {"message":"Disconnected from TIA-Portal","meta":{"timestamp":"2026-05-11T10:31:47.7097494+08:00","success":true}} |
