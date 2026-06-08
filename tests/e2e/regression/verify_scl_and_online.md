# SCL Multi-instruction + Real Download/Online Verification

Run: 2026-05-11 11:38:35
PASS: 9 / 10  FAIL: 

| Layer | Tool | Time(ms) | Status & Detail |
|---|---|---:|---|
| L1-Portal | `Connect` | 955 | PASS: {"message":"Connected to TIA-Portal","meta":{"timestamp":"2026-05-11T11:38:28.0876568+08:00","success":true}} |
| L1-Project | `GetProject` | 74 | PASS: {"items":[{"name":"\u6C5F\u590F\u6D4B\u8BD5\u9879\u76EEV21-260511","attributes":[{"name":"Author","value":"XL626","accessMode":"Read"},{"name":"Copyright","value":"","accessMode":"Read"},{"name":"CreationTime","value":"2 |
| L1-Project | `AttachToOpenProject` | 38 | PASS: {"message":"Attached to open project \u0027\u6C5F\u590F\u6D4B\u8BD5\u9879\u76EEV21-260511\u0027","meta":{"timestamp":"2026-05-11T11:38:28.3280052+08:00","success":true}} |
| L2-SCL | `PlcBuildAndImport(SCL multi-instruction)` | 2308 | PASS: {"dryRun":false,"buildKind":"fc","generatedDirectory":"C:\\Users\\XL626\\AppData\\Local\\Temp\\tia_mcp_plc_build_import_20260511_113828_370","writtenFiles":["C:\\Users\\XL626\\AppData\\Local\\Temp\\tia_mcp_plc_build_impo |
| L2-SCL | `CompileSoftware(after SCL import)` | 1057 | PASS: {"state":"Warning","errorCount":0,"warningCount":12,"messages":["State=Warning; Path=\u5B89\u5168PLC","State=Warning; Description=Compiling finished (errors: 0; warnings: 12)"],"message":"Software \u0027\u5B89\u5168PLC\u |
| L3-Online | `GetOnlineState(pre-download)` | 555 | PASS: {"state":"Offline","isOnline":false,"isReachable":false,"message":"\u0027\u5B89\u5168PLC\u0027 is offline. Call GoOnline first."} |
| L3-Online | `CheckDownloadReadiness(safetyPlc)` | 470 | PASS: {"ready":true,"hasDownloadProvider":true,"hasConfiguration":true,"isConsistent":true,"message":"PLC \u0027\u5B89\u5168PLC\u0027 is ready for download."} |
| L3-Download | `DownloadToPlc(safetyPlc)` | 503 | FAIL: tool-error: An error occurred invoking 'DownloadToPlc': Download to '安全PLC' failed: Download failed: 类型“Siemens.Engineering.Connection.ConnectionConfiguration”的对象无法转换为类型“Siemens.Engineering.Connection.IConfiguration”。 |
| L1-Project | `SaveProject` | 180 | PASS: {"message":"Local project saved","meta":{"timestamp":"2026-05-11T11:38:33.42529+08:00","success":true}} |
| L1-Portal | `Disconnect` | 38 | PASS: {"message":"Disconnected from TIA-Portal","meta":{"timestamp":"2026-05-11T11:38:33.4739442+08:00","success":true}} |
