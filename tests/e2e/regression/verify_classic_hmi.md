# Classic HMI End-to-end Verification

Run: 2026-05-11 11:45:56
PASS: 8 / 11  FAIL: 3

| Layer | Tool | Time(ms) | Status & Detail |
|---|---|---:|---|
| L1-Portal | `Connect` | 1010 | PASS: {"message":"Connected to TIA-Portal","meta":{"timestamp":"2026-05-11T11:45:54.1588214+08:00","success":true}} |
| L1-Project | `GetProject` | 86 | PASS: {"items":[{"name":"\u6C5F\u590F\u6D4B\u8BD5\u9879\u76EEV21-260511","attributes":[{"name":"Author","value":"XL626","accessMode":"Read"},{"name":"Copyright","value":"","accessMode":"Read"},{"name":"CreationTime","value":"2 |
| L1-Project | `AttachToOpenProject` | 33 | PASS: {"message":"Attached to open project \u0027\u6C5F\u590F\u6D4B\u8BD5\u9879\u76EEV21-260511\u0027","meta":{"timestamp":"2026-05-11T11:45:54.4142138+08:00","success":true}} |
| L2-HMI | `GetHmiProgramInfo` | 297 | PASS: {"name":"HMI_RT_1","programType":"Unified","screens":["\u753B\u9762_1"],"message":"HMI program info retrieved from \u0027HMI_RT_1\u0027","meta":{"timestamp":"2026-05-11T11:45:54.7142195+08:00","success":true}} |
| L2-HMI | `WriteClassicHmiMinimalPackageFiles` | 93 | PASS: {"ok":true,"data":{"format":"tia-classic-hmi-minimal-package-files-v1","timestamp":"2026-05-11T11:45:54.7964261\u002B08:00","offlineOnly":true,"packageName":"MCPVerify_HmiPackage","ok":true,"outputDirectory":"C:\\Users\\ |
| L2-HMI | `ImportHmiTagTable(MCPVerify_HmiTags)` | 58 | FAIL: tool-error: An error occurred invoking 'ImportHmiTagTable': Failed importing HMI tag table from 'C:\Users\XL626\Desktop\testtia\hmi_classic_verify\MCPVerify_HmiPackage_TagTable.xml'. LastError: No Import method found on  |
| L2-HMI | `ImportHmiScreen(MCPVerify_MainScreen)` | 59 | FAIL: tool-error: An error occurred invoking 'ImportHmiScreen': Failed importing HMI screen from 'C:\Users\XL626\Desktop\testtia\hmi_classic_verify\MCPVerify_HmiPackage_Screen.xml'. LastError: No Import method found on collect |
| L2-HMI | `GetHmiScreens(post-import)` | 69 | PASS: {"items":["\u753B\u9762_1"],"message":"HMI screens listed for \u0027HMI_RT_1\u0027","meta":{"timestamp":"2026-05-11T11:45:55.0623438+08:00","success":true}} |
| L2-HMI | `CompileSoftware(HMI_RT_1)` | 51 | FAIL: tool-error: An error occurred invoking 'CompileSoftware': Failed compiling software 'HMI_RT_1': Software at 'HMI_RT_1' is not PlcSoftware. Type=Siemens.Engineering.HmiUnified.HmiSoftware |
| L1-Project | `SaveProject` | 21 | PASS: {"message":"Local project saved","meta":{"timestamp":"2026-05-11T11:45:55.1446376+08:00","success":true}} |
| L1-Portal | `Disconnect` | 37 | PASS: {"message":"Disconnected from TIA-Portal","meta":{"timestamp":"2026-05-11T11:45:55.1837857+08:00","success":true}} |
