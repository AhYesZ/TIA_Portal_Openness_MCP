# LAD Native Instruction Verification

Run: 2026-05-11 11:29:41
PASS: 8 / 8
FAIL: 0

| Layer | Tool | Time(ms) | Detail |
|---|---|---:|---|
| L1-Portal | `Connect` | 936 | PASS: {"message":"Connected to TIA-Portal","meta":{"timestamp":"2026-05-11T11:29:34.9241983+08:00","success":true}} |
| L1-Project | `GetProject` | 100 | PASS: {"items":[{"name":"\u6C5F\u590F\u6D4B\u8BD5\u9879\u76EEV21-260511","attributes":[{"name":"Author","value":"XL626","accessMode":"Read"},{"name":"Copyright","value":"","accessMode":"Read"},{"name":"CreationTime","value":"2 |
| L1-Project | `AttachToOpenProject` | 66 | PASS: {"message":"Attached to open project \u0027\u6C5F\u590F\u6D4B\u8BD5\u9879\u76EEV21-260511\u0027","meta":{"timestamp":"2026-05-11T11:29:35.2164219+08:00","success":true}} |
| L1-PLC | `ImportBlock(MCPVerify_FC_LAD.xml LAD native)` | 2320 | PASS: {"message":"Block imported from \u0027C:\\Users\\XL626\\Desktop\\testtia\\lad_native_verify\\MCPVerify_FC_LAD.xml\u0027 to \u0027\u0027","meta":{"timestamp":"2026-05-11T11:29:37.5376393+08:00","success":true}} |
| L1-PLC | `GetBlocks(post-import)` | 609 | PASS: {"items":[{"typeName":"OB","name":"Main","namespace":"","programmingLanguage":"LAD","memoryLayout":"Optimized","isConsistent":true,"headerName":"","modifiedDate":"2026-04-07T06:27:36.0345306Z","isKnowHowProtected":false, |
| L1-PLC | `CompileSoftware(after LAD import)` | 1134 | PASS: {"state":"Warning","errorCount":0,"warningCount":12,"messages":["State=Warning; Path=\u5B89\u5168PLC","State=Warning; Description=Compiling finished (errors: 0; warnings: 12)"],"message":"Software \u0027\u5B89\u5168PLC\u |
| L1-Project | `SaveProject` | 185 | PASS: {"message":"Local project saved","meta":{"timestamp":"2026-05-11T11:29:39.4813444+08:00","success":true}} |
| L1-Portal | `Disconnect` | 43 | PASS: {"message":"Disconnected from TIA-Portal","meta":{"timestamp":"2026-05-11T11:29:39.5270812+08:00","success":true}} |
