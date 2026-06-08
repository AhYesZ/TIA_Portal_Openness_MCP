# SCL external source v2 (CASE FOR WHILE)

Run: 2026-05-11 14:14:52
PASS: 10 / 10  FAIL: 0

| Layer | Tool | Time(ms) | Status & Detail |
|---|---|---:|---|
| L1-Portal | `Connect` | 2159 | PASS: {"message":"Connected to TIA-Portal","meta":{"timestamp":"2026-05-11T14:14:10.1419818+08:00","success":true}} |
| L1-Project | `GetProject` | 101 | PASS: {"items":[{"name":"\u6C5F\u590F\u6D4B\u8BD5\u9879\u76EEV21-260511","attributes":[{"name":"Author","value":"XL626","accessMode":"Read"},{"name":"Copyright","value":"","accessMode":"Read"},{"name":"CreationTime","value":"2 |
| L1-Project | `AttachToOpenProject` | 41 | PASS: {"message":"Attached to open project \u0027\u6C5F\u590F\u6D4B\u8BD5\u9879\u76EEV21-260511\u0027","meta":{"timestamp":"2026-05-11T14:14:10.4664169+08:00","success":true}} |
| L2-PLC | `DeletePlcExternalSource(MCPVerify_FC_SCL_v2.scl)` | 815 | PASS: {"message":"PLC external source \u0027MCPVerify_FC_SCL_v2.scl\u0027 deleted or was not present","meta":{"timestamp":"2026-05-11T14:14:11.2850574+08:00","success":true}} |
| L2-PLC | `ImportPlcExternalSource(MCPVerify_FC_SCL_v2.scl)` | 330 | PASS: {"message":"PLC external source imported","meta":{"timestamp":"2026-05-11T14:14:11.6193214+08:00","success":true}} |
| L2-PLC | `GetPlcExternalSources(安全PLC)` | 260 | PASS: {"items":["HPTimer.scl","Ramp.scl","S_Curve.scl","TrapezoidalCurve.scl","LinearCtrl_SCurve_PID.scl","FB310_Drive_ MoveAbsolute_S.scl","FC320_RC_Filter.scl","SpeedTest.scl","test.scl","FB_PosSpd_Smooth_mm.scl","FB_ReadInc |
| L2-PLC | `GenerateBlocksFromExternalSource(MCPVerify_FC_SCL_v2.scl)` | 20422 | PASS: {"message":"Blocks generated from external source \u0027MCPVerify_FC_SCL_v2.scl\u0027","meta":{"timestamp":"2026-05-11T14:14:32.3061887+08:00","success":true}} |
| L2-PLC | `CompileSoftware(安全PLC)` | 18597 | PASS: {"state":"Warning","errorCount":0,"warningCount":12,"messages":["State=Warning; Path=\u5B89\u5168PLC","State=Warning; Description=Compiling finished (errors: 0; warnings: 12)"],"message":"Software \u0027\u5B89\u5168PLC\u |
| L1-Project | `SaveProject` | 240 | PASS: {"message":"Local project saved","meta":{"timestamp":"2026-05-11T14:14:51.1553402+08:00","success":true}} |
| L1-Portal | `Disconnect` | 79 | PASS: {"message":"Disconnected from TIA-Portal","meta":{"timestamp":"2026-05-11T14:14:51.2370464+08:00","success":true}} |
