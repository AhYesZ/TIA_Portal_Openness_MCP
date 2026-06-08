# MCP Validation Summary
Generated: 2026-05-10T10:41:28.5892243+08:00

## By status
- LOGICAL_FAIL: 1
- OK: 37
- SKIP: 3

## Detailed results
| Category | Tool | Status | ms | Message |
|---|---|---|---|---|
| Portal | GetState | OK | 45 | OK |
| Diagnostics | RunCapabilitySelfTest | OK | 13 | OK |
| Portal | ListPortalProcessProjects | OK | 37707 | OK |
| Portal | Connect | OK | 348 | OK |
| Portal | GetState | OK | 46 | OK |
| Project | CreateProject | OK | 10196 | OK |
| Project | GetProjectTree | OK | 160 | OK |
| Hardware | SearchHardwareCatalog | OK | 1707 | OK |
| Hardware | SearchHardwareCatalog | OK | 1631 | OK |
| Hardware | SearchInstalledGsdDevices | OK | 1465 | OK |
| Hardware | AddDeviceWithFallback | OK | 4831 | OK |
| Hardware | AddHardwareCatalogDeviceWithProbe | OK | 9642 | OK |
| Hardware | GetDevices | OK | 73 | OK |
| Hardware | GetProjectTree | OK | 337 | OK |
| Hardware | GetDeviceItemTree | OK | 145 | OK |
| Hardware | ConnectDeviceNodesToProfinetSubnet | OK | 1607 | OK |
| Hardware | EnsureSubnet | OK | 654 | OK |
| PLC-Software | GetSoftwareInfo | OK | 14 | OK |
| PLC-Software | GetSoftwareTree | OK | 45 | OK |
| PLC-Software | GetBlocks | OK | 98 | OK |
| PLC-Software | GetTypes | OK | 23 | OK |
| PLC-Software | GetPlcTagTables | OK | 20 | OK |
| PLC-Software | GetPlcWatchTables | OK | 36 | OK |
| PLC-Import | ImportType | OK | 2695 | OK |
| PLC-Import | ImportBlock | OK | 3638 | OK |
| PLC-Software | CompileSoftware | LOGICAL_FAIL | 2428 | success=false in payload |
| PLC-Export | ExportBlocks | OK | 188 | OK |
| PLC-Builders | BuildPlcUdtXml | OK | 12 | OK |
| PLC-Builders | BuildPlcTagTableXml | OK | 4 | OK |
| PLC-Builders | BuildPlcGlobalDbXml | OK | 8 | OK |
| PLC-Builders | BuildStructuredTextXml | OK | 24 | OK |
| PLC-Builders | ComposePlcFcBlockXml | OK | 6 | OK |
| HMI | GetHmiProgramInfo | OK | 46 | OK |
| HMI-Builders | BuildClassicHmiScreenXml | OK | 15 | OK |
| HMI-Builders | BuildClassicHmiTagTableXml | OK | 10 | OK |
| Project | SaveProject | OK | 13159 | OK |
| Portal | GetState | OK | 70 | OK |
| Online | GoOnline | SKIP | 0 | avoid auth dialog |
| Online | DownloadToPlc | SKIP | 0 | avoid auth dialog |
| Online | GetOnlineState | SKIP | 0 | requires GoOnline first |
| Portal | Disconnect | OK | 23 | OK |
