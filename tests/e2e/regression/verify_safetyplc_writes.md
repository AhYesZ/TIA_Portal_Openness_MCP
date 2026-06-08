# Safety-PLC Real-Write Verification

Run: 2026-05-11 11:02:00
Project: `江夏测试项目V21-260511`
Pass: 18 / 18

## PASS

| Layer | Tool | Time(ms) | Sample |
|---|---|---:|---|
| L1-Portal | `Connect` | 980 | {"message":"Connected to TIA-Portal","meta":{"timestamp":"2026-05-11T11:01:12.585505+08:00","success":true}} |
| L1-Project | `GetProject` | 93 | {"items":[{"name":"\u6C5F\u590F\u6D4B\u8BD5\u9879\u76EEV21-260511","attributes":[{"name":"Author","value":"XL626","accessMode":"Read"},{"nam |
| L1-Project | `AttachToOpenProject` | 64 | {"message":"Attached to open project \u0027\u6C5F\u590F\u6D4B\u8BD5\u9879\u76EEV21-260511\u0027","meta":{"timestamp":"2026-05-11T11:01:12.83 |
| L1-Project | `GetProjectTree` | 1335 | {"tree":"\u0060\u0060\u0060\n\u6C5F\u590F\u6D4B\u8BD5\u9879\u76EEV21-260511\r\n\u251C\u2500\u2500 Devices [Collection]\r\n\u2502 \u251C\u250 |
| L1-Hardware | `GetDevices` | 77 | {"items":[{"name":"S7-1500/ET200MP station_1","description":"Siemens.Engineering.HW.DeviceImpl","attributes":[{"name":"Author","value":"XL62 |
| L1-PLC | `GetSoftwareInfo` | 304 | {"name":"\u5B89\u5168PLC","description":"Siemens.Engineering.SW.PlcSoftware","attributes":[{"name":"Name","value":"\u5B89\u5168PLC","accessM |
| L1-PLC | `GetSoftwareTree` | 326 | {"tree":"\u0060\u0060\u0060\n\u5B89\u5168PLC [PLC Software]\r\n\u251C\u2500\u2500 Program blocks\r\n\u2502 \u251C\u2500\u2500 Main [OB1, LAD |
| L1-PLC | `GetBlocks` | 505 | {"items":[{"typeName":"OB","name":"Main","namespace":"","programmingLanguage":"LAD","memoryLayout":"Optimized","isConsistent":false,"headerN |
| L1-PLC-Build | `PlcBuildAndImport(tagtable real)` | 10450 | {"dryRun":false,"buildKind":"tagtable","generatedDirectory":"C:\\Users\\XL626\\AppData\\Local\\Temp\\tia_mcp_plc_build_import_20260511_11011 |
| L1-PLC-Build | `PlcBuildAndImport(globaldb real)` | 5184 | {"dryRun":false,"buildKind":"globaldb","generatedDirectory":"C:\\Users\\XL626\\AppData\\Local\\Temp\\tia_mcp_plc_build_import_20260511_11012 |
| L1-PLC-Build | `PlcBuildAndImport(fc real)` | 5185 | {"dryRun":false,"buildKind":"fc","generatedDirectory":"C:\\Users\\XL626\\AppData\\Local\\Temp\\tia_mcp_plc_build_import_20260511_110131_091" |
| L1-PLC | `GetBlocks(after-write)` | 1260 | {"items":[{"typeName":"OB","name":"Main","namespace":"","programmingLanguage":"LAD","memoryLayout":"Optimized","isConsistent":false,"headerN |
| L1-PLC | `CompileSoftware(real)` | 18868 | {"state":"Warning","errorCount":0,"warningCount":12,"messages":["State=Warning; Path=\u5B89\u5168PLC","State=Warning; Description=Compiling  |
| L2-Online | `CheckDownloadReadiness` | 700 | {"ready":true,"hasDownloadProvider":true,"hasConfiguration":true,"isConsistent":true,"message":"PLC \u0027\u5B89\u5168PLC\u0027 is ready for |
| L2-Online | `GetOnlineState` | 602 | {"state":"Offline","isOnline":false,"isReachable":false,"message":"\u0027\u5B89\u5168PLC\u0027 is offline. Call GoOnline first."} |
| L1-Project | `SaveProject` | 628 | {"message":"Local project saved","meta":{"timestamp":"2026-05-11T11:01:58.317767+08:00","success":true}} |
| L0 | `GetState` | 133 | {"isConnected":true,"project":"\u6C5F\u590F\u6D4B\u8BD5\u9879\u76EEV21-260511","session":"-","message":"TIA-Portal MCP server state retrieve |
| L1-Portal | `Disconnect` | 56 | {"message":"Disconnected from TIA-Portal","meta":{"timestamp":"2026-05-11T11:01:58.5128227+08:00","success":true}} |
