# TIA Portal MCP — Tool Capability Matrix

Quick reference: category, online requirement, TIA version, idempotency, and side-effects for every tool.

**Online**: whether the tool requires an active TIA Portal connection and open project.
**Idempotent**: safe to call multiple times without changing the result.
**Side-effects**: modifies project, writes files to disk, or starts processes.

---

## Portal & Connection

| Tool | Category | Online | TIA Version | Idempotent | Side-effects |
|------|----------|--------|-------------|-----------|--------------|
| `Connect` | Portal | No | V18+ | Yes | Attaches to TIA process |
| `Disconnect` | Portal | No | V18+ | Yes | Releases Openness handle |
| `EnsureOpennessUserGroup` | Portal | No | Any | Yes | May prompt Windows UI |
| `GetState` | Portal | No | Any | Yes | None |
| `ListPortalProcessProjects` | Portal | No | V18+ | Yes | Attaches to TIA processes (slow) |

---

## Project Management

| Tool | Category | Online | TIA Version | Idempotent | Side-effects |
|------|----------|--------|-------------|-----------|--------------|
| `GetProject` | Project | Required | V18+ | Yes | None |
| `OpenProject` | Project | Required | V18+ | No | Closes current project |
| `AttachToOpenProject` | Project | Required | V18+ | Yes | None |
| `CreateProject` | Project | Required | V18+ | No | Creates project on disk |
| `SaveProject` | Project | Required | V18+ | Yes | Writes project to disk |
| `SaveAsProject` | Project | Required | V18+ | No | Writes project to new path |
| `CloseProject` | Project | Required | V18+ | Yes | Closes project |
| `GetProjectTree` | Project | Required | V18+ | Yes | None |
| `ValidateAutomationContext` | Project | Required | V18+ | Yes | None |

---

## Capability & Diagnostics

| Tool | Category | Online | TIA Version | Idempotent | Side-effects |
|------|----------|--------|-------------|-----------|--------------|
| `RunCapabilitySelfTest` | Diagnostics | Optional | Any | Yes | None (read-only) |
| `RunOnlineMonitoringSafetySelfTest` | Diagnostics | **No** | Any | Yes | None (static analysis) |
| `GenerateAcceptanceReport` | Diagnostics | Optional | Any | Yes | Writes report files |
| `GenerateErrorReport` | Diagnostics | **No** | Any | Yes | Writes report files |

---

## Hardware & Devices

| Tool | Category | Online | TIA Version | Idempotent | Side-effects |
|------|----------|--------|-------------|-----------|--------------|
| `GetDevices` | Hardware | Required | V18+ | Yes | None |
| `GetDeviceInfo` | Hardware | Required | V18+ | Yes | None |
| `GetDeviceItemInfo` | Hardware | Required | V18+ | Yes | None |
| `GetDeviceItemTree` | Hardware | Required | V18+ | Yes | None |
| `GetDeviceItemNetworkInfo` | Hardware | Required | V18+ | Yes | None |
| `AddDevice` | Hardware | Required | V18+ | No | Adds device to project |
| `AddDeviceWithFallback` | Hardware | Required | V18+ | No | Adds device to project |
| `AddHardwareCatalogDeviceWithProbe` | Hardware | Required | V18+ | No | Adds device to project |
| `AddGsdDeviceWithProbe` | Hardware | Required | V18+ | No | Adds GSD device to project |
| `SearchHardwareCatalog` | Hardware | Required | V18+ | Yes | None |
| `SearchInstalledGsdDevices` | Hardware | Required | V18+ | Yes | None |
| `SetDeviceItemAttribute` | Hardware | Required | V18+ | Yes | Modifies device attribute |
| `ConnectDeviceNodesToProfinetSubnet` | Hardware/Network | Required | V18+ | Yes | Creates/reuses subnet |
| `EnsureSubnet` | Hardware/Network | Required | V18+ | Yes | Creates/reuses subnet |
| `AttachDeviceNodeToSubnet` | Hardware/Network | Required | V18+ | Yes | Connects node to subnet |
| `SetCpuCommonSettings` | Hardware/Network | Required | V18+ | Yes | Modifies CPU attributes |
| `PlanHardwareNetworkConfiguration` | Hardware/Network | **No** | Any | Yes | None (validation only) |
| `ProbeHardwareHmiConnectionOwnerCandidates` | Hardware | Required | V18+ | Yes | None (read-only probe) |
| `ProbeHardwareHmiConnectionWhitelistedServices` | Hardware | Required | V18+ | Yes | None (read-only probe) |

---

## PLC Software

| Tool | Category | Online | TIA Version | Idempotent | Side-effects |
|------|----------|--------|-------------|-----------|--------------|
| `GetSoftwareInfo` | PLC-Software | Required | V18+ | Yes | None |
| `GetSoftwareTree` | PLC-Software | Required | V18+ | Yes | None |
| `GetBlocks` | PLC-Software | Required | V18+ | Yes | None |
| `GetBlocksWithHierarchy` | PLC-Software | Required | V18+ | Yes | None |
| `GetBlockInfo` | PLC-Software | Required | V18+ | Yes | None |
| `ExportBlock` | PLC-Software | Required | V18+ | Yes | Writes XML to disk |
| `ExportBlockToTemp` | PLC-Software | Required | V18+ | Yes | Writes XML to temp dir |
| `ExportBlocks` | PLC-Software | Required | V18+ | Yes | Writes XMLs to disk |
| `ExportBlocksToTemp` | PLC-Software | Required | V18+ | Yes | Writes XMLs to temp dir |
| `ImportBlock` | PLC-Software | Required | V18+ | No | Imports/overwrites block |
| `ImportBlocksFromDirectory` | PLC-Software | Required | V18+ | No | Imports/overwrites blocks |
| `ExportAsDocuments` | PLC-Software | Required | **V20+** | Yes | Writes .s7dcl/.s7res to disk |
| `ExportBlocksAsDocuments` | PLC-Software | Required | **V20+** | Yes | Writes .s7dcl/.s7res to disk |
| `ImportFromDocuments` | PLC-Software | Required | **V20+** | No | Imports/overwrites block |
| `ImportBlocksFromDocuments` | PLC-Software | Required | **V20+** | No | Imports/overwrites blocks |
| `GetTypes` | PLC-Software | Required | V18+ | Yes | None |
| `GetTypeInfo` | PLC-Software | Required | V18+ | Yes | None |
| `ExportType` | PLC-Software | Required | V18+ | Yes | Writes XML to disk |
| `ExportTypeToTemp` | PLC-Software | Required | V18+ | Yes | Writes XML to temp dir |
| `ExportTypes` | PLC-Software | Required | V18+ | Yes | Writes XMLs to disk |
| `ExportTypesToTemp` | PLC-Software | Required | V18+ | Yes | Writes XMLs to temp dir |
| `ImportType` | PLC-Software | Required | V18+ | No | Imports/overwrites UDT |
| `GetPlcTagTables` | PLC-Tags | Required | V18+ | Yes | None |
| `ExportPlcTagTable` | PLC-Tags | Required | V18+ | Yes | Writes XML to disk |
| `ImportPlcTagTable` | PLC-Tags | Required | V18+ | No | Imports/overwrites tag table |
| `ImportPlcTagTablesFromDirectory` | PLC-Tags | Required | V18+ | No | Imports/overwrites tag tables |
| `CompileSoftware` | PLC-Compile | Required | V18+ | Yes | Modifies consistency state |
| `CompileAndDiagnosePlc` | PLC-Compile | Required | V18+ | Yes | Modifies consistency state |
| `RepairAndReimportBlock` | PLC-Software | Required | V18+ | No | Attempts import; suggests on failure |
| `GetPlcExternalSources` | PLC-Software | Required | V18+ | Yes | None |
| `ImportPlcExternalSource` | PLC-Software | Required | V18+ | No | Imports source file |
| `GenerateBlocksFromExternalSource` | PLC-Software | Required | V18+ | No | Generates blocks from source |
| `ImportPlcProgramFromDirectory` | PLC-Software | Required | V18+ | No | Imports all XMLs in order |
| `ImportTechnologyObject` | PLC-Software | Required | V18+ | No | Imports technology object |
| `ImportTechnologyObjectsFromDirectory` | PLC-Software | Required | V18+ | No | Imports technology objects |

---

## PLC Builders (Offline)

| Tool | Category | Online | TIA Version | Idempotent | Side-effects |
|------|----------|--------|-------------|-----------|--------------|
| `BuildPlcUdtXml` | PLC-Build | **No** | Any | Yes | None (returns XML) |
| `BuildPlcTagTableXml` | PLC-Build | **No** | Any | Yes | None (returns XML) |
| `BuildPlcGlobalDbXml` | PLC-Build | **No** | Any | Yes | None (returns XML) |
| `BuildStructuredTextXml` | PLC-Build | **No** | Any | Yes | None (returns XML) |
| `BuildFlgNetCallXml` | PLC-Build | **No** | Any | Yes | None (returns XML) |
| `ComposePlcFcBlockXml` | PLC-Build | **No** | Any | Yes | None (returns XML) |
| `ComposePlcFbBlockXml` | PLC-Build | **No** | Any | Yes | None (returns XML) |
| `PlcBuildAndImport` | PLC-Build+Import | Optional | V18+ | No | Writes temp XML; imports when dryRun=false |
| `BuildPlcSymbolManifestFromXmlPath` | PLC-Build | **No** | Any | Yes | None (returns manifest) |

---

## HMI — Classic / Basic

| Tool | Category | Online | TIA Version | Idempotent | Side-effects |
|------|----------|--------|-------------|-----------|--------------|
| `GetHmiProgramInfo` | HMI | Required | V18+ | Yes | None |
| `GetHmiScreens` | HMI | Required | V18+ | Yes | None |
| `GetHmiTagTables` | HMI | Required | V18+ | Yes | None |
| `GetHmiTags` | HMI | Required | V18+ | Yes | None |
| `GetHmiConnections` | HMI | Required | V18+ | Yes | None |
| `ExportHmiScreen` | HMI-Classic | Required | V18+ | Yes | Writes XML to disk |
| `ExportHmiTagTable` | HMI-Classic | Required | V18+ | Yes | Writes XML to disk |
| `ExportHmiConnection` | HMI-Classic | Required | V18+ | Yes | Writes XML to disk |
| `ExportHmiProgram` | HMI-Classic | Required | V18+ | Yes | Writes XMLs to disk |
| `ImportHmiScreen` | HMI-Classic | Required | V18+ | No | Imports/overwrites screen |
| `ImportHmiTagTable` | HMI-Classic | Required | V18+ | No | Imports/overwrites tag table |
| `ImportHmiConnection` | HMI-Classic | Required | V18+ | No | Imports/overwrites connection |
| `ImportHmiScreensFromDirectory` | HMI-Classic | Required | V18+ | No | Imports/overwrites screens |
| `ImportHmiTagTablesFromDirectory` | HMI-Classic | Required | V18+ | No | Imports/overwrites tag tables |
| `BuildClassicHmiScreenXml` | HMI-Classic | **No** | Any | Yes | None (returns XML) |
| `BuildClassicHmiTagTableXml` | HMI-Classic | **No** | Any | Yes | None (returns XML) |
| `BuildClassicHmiMinimalPackage` | HMI-Classic | **No** | Any | Yes | None (returns package) |
| `WriteClassicHmiMinimalPackageFiles` | HMI-Classic | **No** | Any | Yes | Writes XML files to disk |
| `ValidateClassicHmiMinimalPackageFiles` | HMI-Classic | **No** | Any | Yes | None (validation only) |
| `ValidateClassicHmiMinimalPackagePlcSync` | HMI-Classic | **No** | Any | Yes | None (validation only) |

---

## HMI — Unified (WinCC Unified)

| Tool | Category | Online | TIA Version | Idempotent | Side-effects |
|------|----------|--------|-------------|-----------|--------------|
| `EnsureUnifiedHmiScreen` | HMI-Unified | Required | V18+ | **Yes** | Creates screen if missing |
| `EnsureUnifiedHmiTagTable` | HMI-Unified | Required | V18+ | **Yes** | Creates tag table if missing |
| `EnsureUnifiedHmiTag` | HMI-Unified | Required | V18+ | **Yes** | Creates tag if missing |
| `EnsureUnifiedHmiConnection` | HMI-Unified | Required | V18+ | **Yes** | Creates connection if missing |
| `EnsureUnifiedHmiScreenItem` | HMI-Unified | Required | V18+ | **Yes** | Creates item if missing |
| `EnsureStartStopUnifiedHmi` | HMI-Unified | Required | V18+ | **Yes** | Creates 4 tags + UI items |
| `ApplyUnifiedHmiScreenDesignJson` | HMI-Unified | Required | V18+ | Yes | Creates/updates screen items |
| `BuildUnifiedHmiThemeDesignJson` | HMI-Unified | **No** | Any | Yes | None (returns JSON) |
| `BuildUnifiedHmiLayoutDesignJson` | HMI-Unified | **No** | Any | Yes | None (returns JSON) |
| `ApplyUnifiedHmiTheme` | HMI-Unified | Required | V18+ | Yes | Modifies screen item properties |
| `ApplyUnifiedHmiLayout` | HMI-Unified | Required | V18+ | Yes | Creates/modifies screen items |
| `EnsureUnifiedHmiDynamization` | HMI-Unified | Required | V18+ | Yes | Creates dynamization if missing |
| `BindUnifiedHmiTagDynamization` | HMI-Unified | Required | V18+ | Yes | Binds tag to dynamization |
| `BindUnifiedHmiButtonPressedTag` | HMI-Unified | Required | V18+ | Yes | Binds tag to button |
| `EnsureUnifiedHmiButtonEventHandler` | HMI-Unified | Required | V18+ | Yes | Creates event handler if missing |
| `SetUnifiedHmiButtonEventScriptCode` | HMI-Unified | Required | V18+ | Yes | Sets script code + syntax check |
| `BuildUnifiedHmiButtonActionScript` | HMI-Unified | **No** | Any | Yes | None (returns script) |
| `EnsureUnifiedHmiButtonAction` | HMI-Unified | Required | V18+ | Yes | Generates and applies action |

---

## Reflection / Discovery

| Tool | Category | Online | TIA Version | Idempotent | Side-effects |
|------|----------|--------|-------------|-----------|--------------|
| `DescribeHmiSoftware` | Reflection | Required | V18+ | Yes | None |
| `DescribeHmiScreen` | Reflection | Required | V18+ | Yes | None |
| `DescribeHmiTagTable` | Reflection | Required | V18+ | Yes | None |
| `DescribeHmiTag` | Reflection | Required | V18+ | Yes | None |
| `DescribeHmiScreenItem` | Reflection | Required | V18+ | Yes | None |
| `DescribeObject` | Reflection | Required | V18+ | Yes | None |
| `DescribeObjectProperty` | Reflection | Required | V18+ | Yes | None |
| `DescribeService` | Reflection | Required | V18+ | Yes | None |
| `GetObjectProperty` | Reflection | Required | V18+ | Yes | None |
| `ListObjectChildren` | Reflection | Required | V18+ | Yes | None |
| `InvokeObject` | Reflection | Required | V18+ | No | May have side-effects (guarded) |
| `InvokeService` | Reflection | Required | V18+ | No | May have side-effects (guarded) |
| `GetCrossReferences` | Reflection | Required | V18+ | Yes | None |
| `ListUnifiedHmiApiTypes` | Reflection | Required | V18+ | Yes | None |

---

## Online Operations (Write / Deploy)

| Tool | Category | Online | TIA Version | Idempotent | Side-effects |
|------|----------|--------|-------------|-----------|--------------|
| `GetOnlineState` | Online | Required | V18+ | Yes | None (read-only) |
| `GoOnline` | Online | Required | V18+ | Yes | Establishes CPU connection |
| `GoOffline` | Online | Required | V18+ | Yes | Drops CPU connection |
| `CheckDownloadReadiness` | Online | Required | V18+ | Yes | None (read-only preflight) |
| `DownloadToPlc` | Online | Required | **V18+** | **No** | **Stops/restarts CPU, modifies program** |
| `GetPlcForceTables` | Online | Required | V18+ | Yes | None |
| `SetWatchTableModifyValue` | Online | Required | V18+ | **No** | Modifies watch table config; CPU write on trigger |
| `SetForceTableEntry` | Online | Required | V18+ | **No** | Modifies force table config; forces variable while online |

---

## Online Monitoring (Read-only)

| Tool | Category | Online | TIA Version | Idempotent | Side-effects |
|------|----------|--------|-------------|-----------|--------------|
| `ProbePlcMonitorOnlineCapabilities` | Monitoring | Required | V18+ | Yes | None (read-only probe) |
| `ReadPlcWatchTableCurrentValuesReadOnly` | Monitoring | Required | V18+ | Yes | None (read-only) |
| `PlanOnlineReadOnlyMonitoring` | Monitoring | **No** | Any | Yes | None (offline preflight) |
| `PlanOnlineReadOnlyDataProvider` | Monitoring | **No** | Any | Yes | None (offline plan) |
| `GetPlcWatchTables` | Monitoring | Required | V18+ | Yes | None |
| `ExportPlcWatchTable` | Monitoring | Required | V18+ | Yes | Writes XML to disk |
| `ExportPlcWatchTablesToDirectory` | Monitoring | Required | V18+ | Yes | Writes XMLs to disk |

---

## Validation Suites (Offline)

| Tool | Category | Online | TIA Version | Idempotent | Side-effects |
|------|----------|--------|-------------|-----------|--------------|
| `RunClassicHmiOfflineValidationSuite` | Validation | **No** | Any | Yes | Writes report files |
| `RunOfflineReleaseValidationSuite` | Validation | **No** | Any | Yes | Writes report files |
| `RunV2PlanCompletionAudit` | Validation | **No** | Any | Yes | Writes report files |
| `RunClassicHmiTemporaryImportPreflight` | Validation | **No** | Any | Yes | None |
| `RunHmiTemplatePlcSyncPrecheckSuite` | Validation | **No** | Any | Yes | None |
| `RunHmiActionScriptRecipeSafetySelfTest` | Validation | **No** | Any | Yes | None |
| `RunCapabilitySelfTest` | Validation | Optional | Any | Yes | None |
| `RunOnlineMonitoringSafetySelfTest` | Validation | **No** | Any | Yes | None |

---

## Report Generation (Offline)

| Tool | Category | Online | TIA Version | Idempotent | Side-effects |
|------|----------|--------|-------------|-----------|--------------|
| `BuildReleaseDiagnosticReport` | Reports | **No** | Any | Yes | Writes report files |
| `BuildReleaseRunbook` | Reports | **No** | Any | Yes | Writes report files |
| `BuildReleaseManifest` | Reports | **No** | Any | Yes | Writes report files |
| `RebuildReleaseHandoffArtifacts` | Reports | **No** | Any | Yes | Writes report files |
| `GenerateAcceptanceReport` | Reports | Optional | Any | Yes | Writes report files |
| `GenerateErrorReport` | Reports | **No** | Any | Yes | Writes report files |

---

## HMI Template & Global Library

| Tool | Category | Online | TIA Version | Idempotent | Side-effects |
|------|----------|--------|-------------|-----------|--------------|
| `ProbeGlobalLibrary` | Library | Required | V18+ | Yes | Opens library read-only |
| `ImportMasterCopyFromGlobalLibrary` | Library | Required | V18+ | No | Imports master copy |
| `AnalyzeGlobalLibraryPackage` | Library | **No** | Any | Yes | None |
| `PlanGlobalLibraryTemplateReuse` | Library | **No** | Any | Yes | None |
| `AnalyzeHmiTemplateReference` | HMI-Template | **No** | Any | Yes | None |
| `AnalyzeUnifiedHmiTemplateLayout` | HMI-Template | **No** | Any | Yes | None |
| `BuildUnifiedHmiTemplateApplyDesignJson` | HMI-Template | **No** | Any | Yes | None (returns JSON) |
| `BuildUnifiedHmiTemplateApplyDesignManifest` | HMI-Template | **No** | Any | Yes | None (returns manifest) |
| `SeedProjectFromReference` | Library | Required | V18+ | No | Imports blocks/UDTs/HMI |
| `AnalyzeHmiComponentCatalog` | HMI-Template | **No** | Any | Yes | None |

---

## Alarm Text Management

| Tool | Category | Online | TIA Version | Idempotent | Side-effects |
|------|----------|--------|-------------|-----------|--------------|
| `ExportAlarmClasses` | Alarms | Required | V18+ | Yes | Writes file to disk |
| `ImportAlarmClasses` | Alarms | Required | V18+ | No | Overwrites alarm class definitions |
| `ExportAlarmTextLists` | Alarms | Required | V18+ | Yes | Writes XLSX to disk |
| `ImportAlarmTextLists` | Alarms | Required | V18+ | No | Overwrites text list content |
| `ExportAlarmInstanceTexts` | Alarms | Required | V18+ | Yes | Writes XLSX to disk |

---

## OPC UA Configuration

| Tool | Category | Online | TIA Version | Idempotent | Side-effects |
|------|----------|--------|-------------|-----------|--------------|
| `GetOpcUaConfig` | OPC-UA | Required | V18+ | Yes | None (read-only) |
| `SetOpcUaInterfaceEnabled` | OPC-UA | Required | V18+ | Yes | Modifies project; DownloadToPlc required |
| `ExportOpcUaInterface` | OPC-UA | Required | V18+ | Yes | Writes XML to disk |
| `ImportOpcUaInterface` | OPC-UA | Required | V18+ | No | Creates/updates interface definition |
