# Real-sample regression import
Generated: 2026-05-10T17:01:33.4579337+08:00
Project: MCP_Real_Samples_20260510_170054

## By status
- FAIL: 3
- LOGIC_FAIL: 1
- OK: 21

## Detail
| # | Cat | Tool | Status | ms | Note | Msg |
|---|---|---|---|---|---|---|
| 1 | Portal | Connect | OK | 1068 |  | OK |
| 2 | Project | CreateProject | OK | 4751 |  | OK |
| 3 | HW | AddDeviceWithFallback | OK | 5336 | CPU | OK |
| 4 | UDT | ImportType | OK | 1136 | UDT_Connect_Config.xml | OK |
| 5 | UDT | ImportType | OK | 1312 | UDT_Fault.xml | OK |
| 6 | UDT | ImportType | OK | 1082 | UDT_Record_Telegram.xml | OK |
| 7 | UDT | ImportType | OK | 788 | UDT_Service_Parameters.xml | OK |
| 8 | TagTable | ImportPlcTagTable | OK | 1078 | 01-手动点位.xml | OK |
| 9 | TagTable | ImportPlcTagTable | OK | 973 | 02-操作模式.xml | OK |
| 10 | TagTable | ImportPlcTagTable | OK | 997 | 03-遥控点位.xml | OK |
| 11 | TagTable | ImportPlcTagTable | OK | 1651 | IO表.xml | OK |
| 12 | TagTable | ImportPlcTagTable | OK | 3472 | 默认变量表.xml | OK |
| 13 | Block | ImportBlock | OK | 1211 | Cyclic interrupt.xml | OK |
| 14 | Block | ImportBlock | OK | 971 | Diagnostic error interrupt.xml | OK |
| 15 | Block | ImportBlock | OK | 878 | Time error interrupt.xml | OK |
| 16 | Block | ImportBlock | OK | 806 | Control_FC.xml | OK |
| 17 | Block | ImportBlock | OK | 1239 | 21_数据转换.xml | OK |
| 18 | Block | ImportBlock | OK | 835 | Global_Data.xml | OK |
| 19 | Block | ImportBlock | FAIL | 972 | FB_DualLoopPID.xml | Import failed |
| 20 | Block | ImportBlock | FAIL | 882 | FB_AntiSway_SpeedCtl.xml | Import failed |
| 21 | Block | ImportBlock | FAIL | 870 | FB_Crane_AntiSway.xml | Import failed |
| 22 | Block | ImportBlock | OK | 777 | Main.xml | OK |
| 23 | Compile | CompileSoftware | LOGIC_FAIL | 1558 | final | success=false |
| 24 | Project | SaveProject | OK | 95 |  | OK |
| 25 | Portal | Disconnect | OK | 44 |  | OK |
