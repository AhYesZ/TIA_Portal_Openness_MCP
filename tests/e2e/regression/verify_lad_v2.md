# LAD Native v2 Verification (10 instructions)

Run: 2026-05-11 12:00:15
PASS: 8 / 8  FAIL: 0

| Layer | Tool | Time(ms) | Status & Detail |
|---|---|---:|---|
| L1-Portal | `Connect` | 995 | PASS: {"message":"Connected to TIA-Portal","meta":{"timestamp":"2026-05-11T11:59:53.5795071+08:00","success":true}} |
| L1-Project | `GetProject` | 96 | PASS: {"items":[{"name":"\u6C5F\u590F\u6D4B\u8BD5\u9879\u76EEV21-260511","attributes":[{"name":"Author","value":"XL626","accessMode":"Read"},{"name":"Copyright","value":"","accessMode":"Read"},{"name":"CreationTime","value":"2 |
| L1-Project | `AttachToOpenProject` | 55 | PASS: {"message":"Attached to open project \u0027\u6C5F\u590F\u6D4B\u8BD5\u9879\u76EEV21-260511\u0027","meta":{"timestamp":"2026-05-11T11:59:53.839746+08:00","success":true}} |
| L2-PLC | `ImportBlock(MCPVerify_FC_LAD_v2.xml)` | 2475 | PASS: {"message":"Block imported from \u0027C:\\Users\\XL626\\Desktop\\PID\u535A\u9014\u5757\\tools\\tiaportal-mcp\\skill\\lad-cookbook\\MCPVerify_FC_LAD_v2.xml\u0027 to \u0027\u0027","meta":{"timestamp":"2026-05-11T11:59:56.3 |
| L2-PLC | `GetBlocks(post-import)` | 12061 | PASS: {"items":[{"typeName":"OB","name":"Main","namespace":"","programmingLanguage":"LAD","memoryLayout":"Optimized","isConsistent":true,"headerName":"","modifiedDate":"2026-04-07T06:27:36.0345306Z","isKnowHowProtected":false, |
| L2-PLC | `CompileSoftware(安全PLC)` | 4644 | PASS: {"state":"Warning","errorCount":0,"warningCount":12,"messages":["State=Warning; Path=\u5B89\u5168PLC","State=Warning; Description=Compiling finished (errors: 0; warnings: 12)"],"message":"Software \u0027\u5B89\u5168PLC\u |
| L1-Project | `SaveProject` | 294 | PASS: {"message":"Local project saved","meta":{"timestamp":"2026-05-11T12:00:13.3262751+08:00","success":true}} |
| L1-Portal | `Disconnect` | 71 | PASS: {"message":"Disconnected from TIA-Portal","meta":{"timestamp":"2026-05-11T12:00:13.3963008+08:00","success":true}} |
