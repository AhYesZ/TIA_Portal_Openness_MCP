# SCL external source v3 (REPEAT UNTIL + IF ELSIF ELSE)

Run: 2026-05-11 14:13:49
PASS: 10 / 10  FAIL: 0

| Layer | Tool | Time(ms) | Status & Detail |
|---|---|---:|---|
| L1-Portal | `Connect` | 18399 | PASS: {"message":"Connected to TIA-Portal","meta":{"timestamp":"2026-05-11T14:13:21.8183705+08:00","success":true}} |
| L1-Project | `GetProject` | 476 | PASS: {"items":[{"name":"\u6C5F\u590F\u6D4B\u8BD5\u9879\u76EEV21-260511","attributes":[{"name":"Author","value":"XL626","accessMode":"Read"},{"name":"Copyright","value":"","accessMode":"Read"},{"name":"CreationTime","value":"2 |
| L1-Project | `AttachToOpenProject` | 40 | PASS: {"message":"Attached to open project \u0027\u6C5F\u590F\u6D4B\u8BD5\u9879\u76EEV21-260511\u0027","meta":{"timestamp":"2026-05-11T14:13:22.5430013+08:00","success":true}} |
| L2-PLC | `DeletePlcExternalSource(MCPVerify_FC_SCL_v3.scl)` | 1166 | PASS: {"message":"PLC external source \u0027MCPVerify_FC_SCL_v3.scl\u0027 deleted or was not present","meta":{"timestamp":"2026-05-11T14:13:23.7109242+08:00","success":true}} |
| L2-PLC | `ImportPlcExternalSource(MCPVerify_FC_SCL_v3.scl)` | 712 | PASS: {"message":"PLC external source imported","meta":{"timestamp":"2026-05-11T14:13:24.4253229+08:00","success":true}} |
| L2-PLC | `GetPlcExternalSources(安全PLC)` | 331 | PASS: {"items":["HPTimer.scl","Ramp.scl","S_Curve.scl","TrapezoidalCurve.scl","LinearCtrl_SCurve_PID.scl","FB310_Drive_ MoveAbsolute_S.scl","FC320_RC_Filter.scl","SpeedTest.scl","test.scl","FB_PosSpd_Smooth_mm.scl","FB_ReadInc |
| L2-PLC | `GenerateBlocksFromExternalSource(MCPVerify_FC_SCL_v3.scl)` | 17884 | PASS: {"message":"Blocks generated from external source \u0027MCPVerify_FC_SCL_v3.scl\u0027","meta":{"timestamp":"2026-05-11T14:13:42.646355+08:00","success":true}} |
| L2-PLC | `CompileSoftware(安全PLC)` | 4816 | PASS: {"state":"Warning","errorCount":0,"warningCount":12,"messages":["State=Warning; Path=\u5B89\u5168PLC","State=Warning; Description=Compiling finished (errors: 0; warnings: 12)"],"message":"Software \u0027\u5B89\u5168PLC\u |
| L1-Project | `SaveProject` | 248 | PASS: {"message":"Local project saved","meta":{"timestamp":"2026-05-11T14:13:47.7187071+08:00","success":true}} |
| L1-Portal | `Disconnect` | 51 | PASS: {"message":"Disconnected from TIA-Portal","meta":{"timestamp":"2026-05-11T14:13:47.7726641+08:00","success":true}} |
