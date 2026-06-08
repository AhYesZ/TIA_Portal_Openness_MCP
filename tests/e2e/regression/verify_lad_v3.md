# LAD v3 Verification (FC Lt + FB TON Static / PBox / Not / Lt on 安全PLC)

Run: 2026-05-11 14:06:48
PASS: 9 / 9  FAIL: 0

| Layer | Tool | Time(ms) | Status & Detail |
|---|---|---:|---|
| L1-Portal | `Connect` | 982 | PASS: {"message":"Connected to TIA-Portal","meta":{"timestamp":"2026-05-11T14:06:32.7170265+08:00","success":true}} |
| L1-Project | `GetProject` | 160 | PASS: {"items":[{"name":"\u6C5F\u590F\u6D4B\u8BD5\u9879\u76EEV21-260511","attributes":[{"name":"Author","value":"XL626","accessMode":"Read"},{"name":"Copyright","value":"","accessMode":"Read"},{"name":"CreationTime","value":"2 |
| L1-Project | `AttachToOpenProject` | 55 | PASS: {"message":"Attached to open project \u0027\u6C5F\u590F\u6D4B\u8BD5\u9879\u76EEV21-260511\u0027","meta":{"timestamp":"2026-05-11T14:06:33.0612716+08:00","success":true}} |
| L2-PLC | `ImportBlock(MCPVerify_FC_LAD_v3.xml)` | 2812 | PASS: {"message":"Block imported from \u0027C:\\Users\\XL626\\AppData\\Local\\Temp\\tiaportal-mcp-verify\\MCPVerify_FC_LAD_v3.xml\u0027 to \u0027\u0027","meta":{"timestamp":"2026-05-11T14:06:35.8766452+08:00","success":true}} |
| L2-PLC | `ImportBlock(MCPVerify_FB_LAD_v3.xml)` | 2109 | PASS: {"message":"Block imported from \u0027C:\\Users\\XL626\\AppData\\Local\\Temp\\tiaportal-mcp-verify\\MCPVerify_FB_LAD_v3.xml\u0027 to \u0027\u0027","meta":{"timestamp":"2026-05-11T14:06:37.9869352+08:00","success":true}} |
| L2-PLC | `GetBlocks(post-import)` | 929 | PASS: {"items":[{"typeName":"OB","name":"Main","namespace":"","programmingLanguage":"LAD","memoryLayout":"Optimized","isConsistent":true,"headerName":"","modifiedDate":"2026-04-07T06:27:36.0345306Z","isKnowHowProtected":false, |
| L2-PLC | `CompileSoftware(安全PLC)` | 6885 | PASS: {"state":"Warning","errorCount":0,"warningCount":13,"messages":["State=Warning; Path=\u5B89\u5168PLC","State=Warning; Description=Compiling finished (errors: 0; warnings: 13)"],"message":"Software \u0027\u5B89\u5168PLC\u |
| L1-Project | `SaveProject` | 477 | PASS: {"message":"Local project saved","meta":{"timestamp":"2026-05-11T14:06:46.2945371+08:00","success":true}} |
| L1-Portal | `Disconnect` | 213 | PASS: {"message":"Disconnected from TIA-Portal","meta":{"timestamp":"2026-05-11T14:06:46.5093501+08:00","success":true}} |
