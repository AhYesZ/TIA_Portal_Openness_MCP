# Monitoring, Global Library, and HMI Capability Roadmap

This document records the verified state for the monitoring/global-library/HMI workstream.
It is written so another AI or developer can continue without chat history.

## Safety Red Lines

- Online monitoring may read current variable status/value only.
- Online mode must not create, delete, import, export, or modify watch-table objects.
- Force-table and force-related operations must not be exposed as MCP tools.
- Generic reflection must block force-related services and write-like operations on online/watch/monitor surfaces.
- HMI bindings are not considered verified unless both HMI tag and PLC-side tag/DB member existence are checked.
- The delivery package `TIA_MCP_DELIVERY_FOR_OTHER_AI` is not modified in this workstream until the user explicitly allows it.

## Verified Commands

Build:

```powershell
dotnet build "C:\Users\XL626\Desktop\PID博途块\tools\tiaportal-mcp\src\TiaMcpServer\TiaMcpServer.csproj" -c Release
```

Verified result on 2026-05-06:

- Build: 0 errors.
- Existing nullable warnings remain in older code paths.

Online monitoring safety self-test:

```powershell
& "C:\Users\XL626\Desktop\PID博途块\tools\tiaportal-mcp\src\TiaMcpServer\bin\Release\net48\TiaMcpServer.exe" --run-online-monitoring-safety-self-test
```

Verified result on 2026-05-06:

- Safety self-test: `Ok=true`.
- MCP tool count: 117.
- Force-related MCP tool names: none.
- Reflection guard blocks `ForceValue`, watch-table create, and monitor write; normal read remains allowed.

Read-only monitoring report against the opened reference project:

```powershell
& "C:\Users\XL626\Desktop\PID博途块\tools\tiaportal-mcp\src\TiaMcpServer\bin\Release\net48\TiaMcpServer.exe" `
  --generate-monitoring-readonly-report `
  --plc-software-path "Zone1_PLC1516TF" `
  --monitoring-report-directory "C:\Users\XL626\Desktop\PID博途块\reports\monitoring_readonly"
```

Verified result on 2026-05-06:

- Connected to open project `XM_Mxxxx_PL007N_MP301_002_V21`.
- Real PLC software path from project tree: `Zone1_PLC1516TF`.
- Initial report before the V21 WatchAndForceTableGroup fix: `C:\Users\XL626\Desktop\PID博途块\reports\monitoring_readonly\monitoring_readonly_20260506_120206.json`
- Fixed report after resolving `PlcWatchAndForceTableGroup.WatchTables`: `C:\Users\XL626\Desktop\PID博途块\reports\monitoring_readonly\monitoring_readonly_20260506_121027.json`
- Safety self-test embedded in the report: pass.
- Watch tables listed/exported read-only: `监控表_1` and `程序里没有的点位`, 2 exported, 0 export failures.
- Exported XML summaries:
  - `监控表_1`: 38 entries, 3 symbolic entries, 35 absolute-address entries.
  - `程序里没有的点位`: 38 entries, 13 symbolic entries, 17 absolute-address entries.
- Online capability probe: `Ok=true`; no online/offline transition, no value write, no force operation.
- Live current-value read: not verified and intentionally marked `false`.

Negative-path verification:

```powershell
& "C:\Users\XL626\Desktop\PID博途块\tools\tiaportal-mcp\src\TiaMcpServer\bin\Release\net48\TiaMcpServer.exe" `
  --generate-monitoring-readonly-report `
  --plc-software-path "PLC_1" `
  --monitoring-report-directory "C:\Users\XL626\Desktop\PID博途块\reports\monitoring_readonly"
```

Verified result:

- The guessed PLC path `PLC_1` connected successfully to the same open project but failed closed with `PLC software not found`, `ok=false`.
- This proves the report does not invent monitor/watch-table data for an invalid PLC path.

Global library offline analysis:

```powershell
& "C:\Users\XL626\Desktop\PID博途块\tools\tiaportal-mcp\src\TiaMcpServer\bin\Release\net48\TiaMcpServer.exe" `
  --analyze-global-library-package `
  --global-library-package-path "C:\Users\XL626\Desktop\PID博途块\reference\HMI_Template_Suite_WinCC_Unified_V18\HMI Template Suite (WinCC Unified)_V18_V21" `
  --global-library-report-directory "C:\Users\XL626\Desktop\PID博途块\reports\global_library_analysis"
```

Verified result on 2026-05-06:

- `ok=true`
- `.al21` file found with SHA256 `932aa5539e0b4c39af88ad286f0c8d3c2e7dd85c04acfbf80511890b62d927d5`
- `System\PEData.plf` exists, 208699790 bytes.
- `System\PEData.idx` exists, 4482131 bytes.
- `XRef\XRef.db` exists, 69632 bytes.
- `XRef.db` header is `SQLite format 3`.
- Latest report: `C:\Users\XL626\Desktop\PID博途块\reports\global_library_analysis\global_library_package_20260506_115834.md`
- Latest JSON: `C:\Users\XL626\Desktop\PID博途块\reports\global_library_analysis\global_library_package_20260506_115834.json`

HMI template/reference offline analysis:

```powershell
& "C:\Users\XL626\Desktop\PID博途块\tools\tiaportal-mcp\src\TiaMcpServer\bin\Release\net48\TiaMcpServer.exe" `
  --analyze-hmi-template-reference `
  --hmi-template-directory "C:\Users\XL626\Desktop\PID博途块\docs\hmi_templates" `
  --reference-project-path "C:\Users\XL626\Desktop\PID博途块\reference\XM_Mxxxx_PL007N_MP301_002_V21" `
  --reference-global-library-path "C:\Users\XL626\Desktop\PID博途块\reference\HMI_Template_Suite_WinCC_Unified_V18\HMI Template Suite (WinCC Unified)_V18_V21" `
  --hmi-template-reference-report-directory "C:\Users\XL626\Desktop\PID博途块\reports\hmi_template_reference"
```

Verified result on 2026-05-06:

- Report: `C:\Users\XL626\Desktop\PID博途块\reports\hmi_template_reference\hmi_template_reference_20260506_115834.md`
- JSON: `C:\Users\XL626\Desktop\PID博途块\reports\hmi_template_reference\hmi_template_reference_20260506_115834.json`
- Templates analyzed: `drive-axis-control`, `equipment-overview`, `pid-faceplate`.
- Each template has 9 required tags.
- Action script tag references are all declared in `RequiredTags`.
- Reference project HMI runtime detected: 253 screen RDF files and 94 faceplate RDF files.
- Reference global library detected: 1 `.al*` file.

## MCP Tools Added Or Hardened

- `GetPlcWatchTables`: read-only list of watch/monitor tables.
- `ExportPlcWatchTable`: offline export of one existing watch table.
- `ExportPlcWatchTablesToDirectory`: offline export of existing watch tables.
- `ProbePlcMonitorOnlineCapabilities`: read-only API surface probe; no online transition or writes.
- `RunOnlineMonitoringSafetySelfTest`: static safety self-test for tool exposure and reflection guard semantics.
- `ProbeGlobalLibrary`: requires TIA connection; opens global library read-only/best-effort and lists visible metadata.
- `AnalyzeGlobalLibraryPackage`: offline file-system analysis; does not connect to TIA or open/import the library.
- `AnalyzeHmiTemplateReference`: offline HMI template/reference/global-library hint analysis; does not connect to TIA or write projects.

## CLI Reports Added

- `--generate-monitoring-readonly-report`: connects to TIA, embeds safety self-test, lists/exports existing watch tables, and probes online/monitor API surfaces without going online or writing values.
- `--analyze-hmi-template-reference`: parses local Unified HMI JSON templates, checks RequiredTags/Dynamizations/Actions consistency, and compares against reference runtime/global-library hints offline.

## Capability Status

### Online/Offline Monitoring

Status: guarded exploration only.

Verified:

- Safety self-test blocks force-related tool exposure.
- Reflection guard denies force-related methods and write-like methods on online/watch/monitor surfaces.
- Watch table discovery/export tools are present.
- Read-only report was validated against the opened reference project with real PLC software path `Zone1_PLC1516TF`.
- TIA V21 watch table discovery must read `PlcWatchAndForceTableGroup.WatchTables` and recurse child `Groups`; do not read or expose `ForceTables`.
- The reference project contains at least two watch tables: `监控表_1` and `程序里没有的点位`.
- Guessed PLC path `PLC_1` fails closed with `PLC software not found`.

Not yet verified:

- Reading live current values from a PLC online session.

Required before adding current-value reading:

- Use a sacrificial project/device.
- Prove read-only API behavior.
- Read Bool, Int, Real, and DB member variables.
- Save JSON/Markdown evidence with exact variable list and no-write proof.

### Watch/Monitor Tables

Status: paused by user request.

The user corrected the earlier discovery result and confirmed watch tables exist, then explicitly asked to skip this feature and continue with other work. Do not spend more implementation time on watch-table entry validation unless the user reopens it.

Allowed:

- List existing watch tables.
- Export existing watch tables for offline inspection.
- Generate a read-only report containing safety self-test, current project state, table names, exported files, XML entry summaries, and online API-surface hints.

Forbidden:

- Online modification.
- Create/delete/import watch table objects while online.
- Any value write through monitor/watch surfaces.

### Force Tables

Status: forbidden.

- Do not add force-table tools.
- Do not invoke force-related APIs through reflection.
- Do not expose force-related service suffixes.

### Global Library

Status: offline package analysis verified; TIA connected object probe exists but is not verified on the current reference setup.

Verified:

- HMI Template Suite folder structure and core files exist.
- XRef DB is SQLite format.
- Offline reports are generated without opening TIA.

Connected-probe verification on 2026-05-06:

- Initial command timed out because the TIA Openness confirmation dialog had not been acknowledged.
- After confirmation, `--generate-global-library-probe-report` completed successfully.
- Report: `C:\Users\XL626\Desktop\PID博途块\reports\global_library_probe\global_library_probe_20260506_123755.md`
- JSON: `C:\Users\XL626\Desktop\PID博途块\reports\global_library_probe\global_library_probe_20260506_123755.json`
- Library type: `Siemens.Engineering.Library.UserGlobalLibrary`
- Master copy paths listed: 601
- Library types listed: 25
- Folders list: 0 through the current listing heuristic, but folder-like hierarchy is visible in master copy paths.
- No import or project write was performed.

Next safe step:

- Keep the process-level timeout wrapper as a robustness improvement, because Openness dialogs can still block unattended runs.
- Mine the 601 master-copy paths into reusable HMI template categories.
- Only after readback succeeds, design import workflows in a temporary project.

### HMI Screens, Bindings, And Events

Status: continue with verified minimal instances.

Rules:

- HMI controls must bind to PLC-backed tags, not invented M addresses unless corresponding PLC tags exist.
- Different controls may require different events; event scripts must be read back after binding.
- Screen beautification should be template-driven JSON, not direct copying of runtime RDF files.
- Every HMI template must be validated by applying to a temporary HMI project, reading back screen/items/tags/events, and generating a report.

Verified offline:

- Existing JSON templates expose `RequiredTags`, `Dynamizations`, and `Actions` in a machine-checkable contract.
- Button scripts in the current templates reference tags that are declared in `RequiredTags`.
- Reference project has enough HMI runtime material to guide template taxonomy, especially screens and faceplates.
- `--generate-hmi-template-sync-precheck` now defaults to offline template contract checking and does not connect to TIA unless a bounded PLC tag-table regex and max count are supplied.
- Default offline sync precheck verified on 2026-05-06:
  - Report: `C:\Users\XL626\Desktop\PID博途块\reports\hmi_template_sync_precheck\hmi_template_sync_precheck_20260506_123222.md`
  - JSON: `C:\Users\XL626\Desktop\PID博途块\reports\hmi_template_sync_precheck\hmi_template_sync_precheck_20260506_123222.json`
  - Result: `ok=true`
  - PLC read mode: skipped by default for large-project safety.
  - Templates checked: `drive-axis-control`, `equipment-overview`, `pid-faceplate`.
- Bounded PLC-read sync precheck verified on 2026-05-06:
  - Command used `--plc-tag-table-regex ".*"` and `--max-plc-tag-tables-to-export 2`.
  - Report: `C:\Users\XL626\Desktop\PID博途块\reports\hmi_template_sync_precheck\hmi_template_sync_precheck_20260506_123951.md`
  - JSON: `C:\Users\XL626\Desktop\PID博途块\reports\hmi_template_sync_precheck\hmi_template_sync_precheck_20260506_123951.json`
  - Result: `ok=true`
  - PLC tag table list returned 0 tables, so no PLC symbols were exported.
  - This means PLC/HMI sync verification still needs a stronger PLC variable source, such as V21 tag-table API discovery, DB exports, or block/interface exports.

Important behavior:

- Without PLC tag-table exports, required PLC root symbols are reported as missing instead of guessed.
- DB/member references are marked as needing DB or block-interface readback before template application can be considered verified.

HMI component/event catalog and template beautification on 2026-05-06:

- Added offline CLI `--analyze-hmi-component-catalog`.
- Input is the connected read-only global-library probe JSON plus local `docs/hmi_templates/*.json`.
- Report: `C:\Users\XL626\Desktop\PID博途块\reports\hmi_component_catalog\hmi_component_catalog_20260506_125920.md`
- JSON: `C:\Users\XL626\Desktop\PID博途块\reports\hmi_component_catalog\hmi_component_catalog_20260506_125920.json`
- Result: all 10 learned component categories are covered by current templates:
  - layout/header/navigation
  - dashboard/value overview
  - popup/option panel
  - notification/alarm
  - function/command panel
  - wizard/progress
  - value stepper
  - chart/trend placeholder
  - status graphics
  - machine module
- The analyzer is offline only: no TIA connection, no project write, no library import, no delivery-package sync.

Beautified and strengthened templates:

- `C:\Users\XL626\Desktop\PID博途块\docs\hmi_templates\unified_equipment_overview.json`
- `C:\Users\XL626\Desktop\PID博途块\docs\hmi_templates\unified_drive_axis_control.json`
- `C:\Users\XL626\Desktop\PID博途块\docs\hmi_templates\unified_pid_faceplate.json`

Template contract improvements:

- Clean UTF-8 Chinese display text and Chinese comments were added.
- `DesignSystem` records palette, layout, and reference-library influence.
- `BindingPolicy` records the no-invented-M-point rule and required prechecks.
- `Components` records reusable HMI building blocks and global-library source hints.
- `Events` records `ActionKind`, `TargetTag`, `TargetTags`, `TargetScreen`, or `TargetPopup`.
- Button item `Actions` still keep executable script hints for current template tooling.
- Parameter/popup events are represented as contract entries, but are not treated as safe to write PLC until PLC variable and range checks are verified.

Latest verification:

- JSON parse check: all 3 templates parsed successfully.
- Build: `dotnet build ... -c Release` completed with 0 errors.
- HMI template reference report:
  - `drive-axis-control`: 12 tags, 19 items, 6 dynamizations, 8 actions/events.
  - `equipment-overview`: 11 tags, 19 items, 7 dynamizations, 5 actions/events.
  - `pid-faceplate`: 9 tags, 18 items, 7 dynamizations, 3 actions/events.
- HMI sync precheck:
  - Report: `C:\Users\XL626\Desktop\PID博途块\reports\hmi_template_sync_precheck\hmi_template_sync_precheck_20260506_125902.md`
  - JSON: `C:\Users\XL626\Desktop\PID博途块\reports\hmi_template_sync_precheck\hmi_template_sync_precheck_20260506_125902.json`
  - Result: report generated successfully.
  - PLC read mode was offline by default, so PLC root symbols are correctly reported as missing instead of guessed.
  - This is the intended safety behavior until PLC tag/DB/block-interface readback is improved.

PLC/HMI symbol synchronization improvement on 2026-05-06:

- Added `--plc-export-directory` to `--generate-hmi-template-sync-precheck`.
- The precheck can now scan exported PLC XML files offline and read:
  - Global DB names
  - FB/FC/OB names
  - Nested `Member` paths
  - Full DB/member symbols such as `HMI_Data.大车向前`
- Force-table folders are skipped during the offline symbol scan.
- DB/member bindings are now verified by full symbol match first, not by root DB name alone.
- This prevents false positives where `HMI_Data` exists but `HMI_Data.SomeMissingMember` does not.

Verified offline with existing `TMP_EXPORT`:

- Command included:
  - `--plc-export-directory C:\Users\XL626\Desktop\PID博途块\TMP_EXPORT\Source\5T车\Blocks`
- Latest report:
  - `C:\Users\XL626\Desktop\PID博途块\reports\hmi_template_sync_precheck\hmi_template_sync_precheck_20260506_130949.md`
  - `C:\Users\XL626\Desktop\PID博途块\reports\hmi_template_sync_precheck\hmi_template_sync_precheck_20260506_130949.json`
- PLC export catalog:
  - XML files scanned: 98
  - Blocks found: 89
  - Symbols extracted: 2988
- Added minimal sync proof template:
  - `C:\Users\XL626\Desktop\PID博途块\docs\hmi_templates\unified_hmi_data_export_probe.json`
  - Tags verified by full DB/member match:
    - `HMI_Data.总运行使能`
    - `HMI_Data.大车向前`
    - `HMI_Data.大车频率给定`
  - Result: `hmi-data-export-probe` status is `plc-symbols-present`, missing=0, dbRefs=0.
- The existing generic commercial templates still report missing PLC symbols when their placeholder PLC names are not present in the scanned project export. This is correct and prevents fake binding.

HMI temporary-project validation improvement on 2026-05-06:

- `--validate-unified-hmi-templates` now treats `ApplyUnifiedHmiScreenDesignJson` meta failures as real failures. A screen readback alone is not enough to pass.
- `--validate-unified-hmi-template-bindings` now also fails closed when the screen apply step reports failed writes, before attempting tag bindings/events.
- The template-to-execution conversion keeps the full design intent in `docs/hmi_templates/*.json`, but only writes currently verified Unified Openness style paths during temporary-project application.
- Chinese code comment added near the execution JSON conversion to record this boundary.

Verified minimal HMI apply validation:

- Command used a temporary directory containing only:
  - `C:\Users\XL626\Desktop\PID博途块\docs\hmi_templates\unified_hmi_data_export_probe.json`
- Report:
  - `C:\Users\XL626\Documents\Automation\MCP_HMI_Template_Apply_Probe_20260506_132057_reports\unified_hmi_template_validation.md`
  - `C:\Users\XL626\Documents\Automation\MCP_HMI_Template_Apply_Probe_20260506_132057_reports\unified_hmi_template_validation.json`
- Result: `PASS`
- Screen readback: true.
- Items created: 4.
- Apply failures: 0.

Verified minimal HMI tag/binding/event validation:

- Report:
  - `C:\Users\XL626\Documents\Automation\MCP_HMI_Template_Binding_Probe_20260506_132142_reports\unified_hmi_template_binding_validation.md`
  - `C:\Users\XL626\Documents\Automation\MCP_HMI_Template_Binding_Probe_20260506_132142_reports\unified_hmi_template_binding_validation.json`
- Result: `PASS`
- HMI tags created: 3.
- Dynamic bindings: 2/2.
- Button events: 1/1.
- Event readbacks: 1.
- This verifies the HMI-side binding/event machinery on a minimal template. It does not prove that every generic commercial template placeholder maps to the reference PLC.

Verified all-template HMI apply validation:

- Report:
  - `C:\Users\XL626\Documents\Automation\MCP_HMI_Templates_All_Apply_20260506_132321_reports\unified_hmi_template_validation.md`
  - `C:\Users\XL626\Documents\Automation\MCP_HMI_Templates_All_Apply_20260506_132321_reports\unified_hmi_template_validation.json`
- Result: `PASS`
- `unified_drive_axis_control.json`: 19 items created, apply failures=0.
- `unified_equipment_overview.json`: 19 items created, apply failures=0.
- `unified_hmi_data_export_probe.json`: 4 items created, apply failures=0.
- `unified_pid_faceplate.json`: 18 items created, apply failures=0.

Latest verification rerun on 2026-05-06:

- Build: `dotnet build ... -c Release` completed with 0 errors and 25 existing nullable warnings.
- Online monitoring safety self-test: `PASS`, 117 tools checked, no force-related MCP tool exposed.
- HMI reference analysis:
  - `C:\Users\XL626\Desktop\PID博途块\reports\hmi_template_reference\hmi_template_reference_20260506_132431.md`
  - `C:\Users\XL626\Desktop\PID博途块\reports\hmi_template_reference\hmi_template_reference_20260506_132431.json`
- HMI sync precheck:
  - `C:\Users\XL626\Desktop\PID博途块\reports\hmi_template_sync_precheck\hmi_template_sync_precheck_20260506_132431.md`
  - `C:\Users\XL626\Desktop\PID博途块\reports\hmi_template_sync_precheck\hmi_template_sync_precheck_20260506_132431.json`
- Current sync result remains intentionally strict:
  - `hmi-data-export-probe` has all 3 PLC DB/member symbols present.
  - Generic templates still report missing PLC symbols until their placeholder `RequiredTags.PlcTag` values are mapped to real project variables.

PLC mapping suggestion analysis on 2026-05-06:

- Added offline CLI:
  - `--analyze-hmi-template-plc-mapping`
  - `--hmi-template-plc-mapping-report-directory`
- Safety boundary:
  - no TIA connection,
  - no project write,
  - no HMI tag/screen/event creation,
  - no PLC block/template/delivery-package modification.
- The analyzer scans the offline PLC export catalog and ranks candidate PLC symbols for each `RequiredTags` entry.
- Only `verified-exact` means the requested full PLC symbol already exists.
- `review-required` candidates are suggestions only; they must not be applied automatically.
- High-confidence candidates are only prioritized for human or deterministic-rule review, not auto-binding.
- Latest verified report:
  - `C:\Users\XL626\Desktop\PID博途块\reports\hmi_template_plc_mapping\hmi_template_plc_mapping_20260506_133308.md`
  - `C:\Users\XL626\Desktop\PID博途块\reports\hmi_template_plc_mapping\hmi_template_plc_mapping_20260506_133308.json`
- Verified result:
  - PLC symbols analyzed: 2899.
  - `hmi-data-export-probe`: `mapping-ready`, verifiedExact=3, reviewRequired=0.
  - `drive-axis-control`: `mapping-needs-review`, verifiedExact=0, highConfidence=1, reviewRequired=11.
  - `equipment-overview`: `mapping-needs-review`, verifiedExact=0, reviewRequired=11.
  - `pid-faceplate`: `mapping-needs-review`, verifiedExact=0, reviewRequired=9.
- This proves the commercial templates are not yet safe to bind directly to the reference PLC without a mapping file/rule layer.
- The analyzer was intentionally adjusted to avoid treating root block names as bindable HMI variables.
- The final validation sequence was run in order: build first, then analyzer report. Do not run build-dependent report generation in parallel.

Explicit HMI template mapping file on 2026-05-06:

- Added offline CLI:
  - `--generate-hmi-template-mapping-skeleton`
  - `--hmi-template-mapping-path`
- Mapping file format:
  - `Format = tia-hmi-template-plc-mapping-v1`
  - `Templates[].Mappings[].HmiTag`
  - `Templates[].Mappings[].OriginalPlcTag`
  - `Templates[].Mappings[].MappedPlcTag`
  - `Templates[].Mappings[].Candidates`
- Safety rule:
  - only non-empty `MappedPlcTag` entries are applied to sync precheck,
  - `Candidates` are never applied automatically,
  - `needs-review` entries remain unbound until confirmed by a human or deterministic project rule.
- Generated skeleton:
  - `C:\Users\XL626\Desktop\PID博途块\reports\hmi_template_plc_mapping\hmi_template_mapping.skeleton.json`
- Verified skeleton contents:
  - `hmi-data-export-probe`: 3 mappings filled from exact PLC symbols.
  - `drive-axis-control`: 12 mappings present, 0 filled, all require review.
  - `equipment-overview`: 11 mappings present, 0 filled, all require review.
  - `pid-faceplate`: 9 mappings present, 0 filled, all require review.
- `--generate-hmi-template-sync-precheck` now supports `--hmi-template-mapping-path`.
- Verified mapped sync precheck:
  - `C:\Users\XL626\Desktop\PID博途块\reports\hmi_template_sync_precheck\hmi_template_sync_precheck_20260506_134208.md`
  - `C:\Users\XL626\Desktop\PID博途块\reports\hmi_template_sync_precheck\hmi_template_sync_precheck_20260506_134208.json`
- Mapped sync precheck result:
  - mapping file exists=true,
  - loaded=true,
  - effective mappings=3,
  - `hmi-data-export-probe`: `plc-symbols-present`,
  - generic commercial templates still fail strict PLC-symbol precheck until their mappings are filled.
- This completes the first commercialization gate: templates cannot bind to guessed PLC variables; they must pass through an explicit mapping file.

Mapped-template binding gate on 2026-05-06:

- Added CLI:
  - `--validate-mapped-hmi-template-bindings`
  - `--mapped-hmi-template-offline-only`
- Offline gate behavior:
  - loads `tia-hmi-template-plc-mapping-v1`,
  - applies only non-empty explicit `MappedPlcTag` entries,
  - scans the offline PLC export catalog,
  - requires full PLC symbol presence before creating mapped template files,
  - never uses `Candidates` as bindings,
  - does not modify the delivery package.
- Verified offline gate:
  - Report: `C:\Users\XL626\Documents\Automation\MCP_Mapped_HMI_Template_Offline_Gate_20260506_reports\mapped_hmi_template_binding_validation.md`
  - JSON: `C:\Users\XL626\Documents\Automation\MCP_Mapped_HMI_Template_Offline_Gate_20260506_reports\mapped_hmi_template_binding_validation.json`
  - Mapped template: `C:\Users\XL626\Documents\Automation\MCP_Mapped_HMI_Template_Offline_Gate_20260506_reports\mapped_templates\unified_hmi_data_export_probe.mapped.json`
  - Result: `PASS`.
  - `hmi-data-export-probe`: `offline-gate-pass`; 3 explicit mappings and PLC full-symbol checks passed.
  - `drive-axis-control`, `equipment-overview`, and `pid-faceplate`: skipped because their RequiredTags are not fully mapped by the explicit mapping file.
- Full TIA temporary-project mode was attempted twice:
  - `MCP_Mapped_HMI_Template_Binding_20260506_Continue`
  - `MCP_Mapped_HMI_Template_Binding_20260506_Retry`
  - The second run wrote the pre-TIA report, then blocked at `Mapped HMI template binding validation: Connect start`.
  - The hanging `TiaMcpServer` processes were stopped manually.
  - This failure motivated adding per-step TIA timeout/report guards.
- Added `--tia-step-timeout-seconds` for mapped-template TIA validation:
  - each high-risk TIA step is wrapped with a timeout,
  - timeout/failure rows are written into the same Markdown/JSON report,
  - this prevents a hung `Connect`, `CreateProject`, or device insertion from leaving no evidence.
- Verified full mapped HMI binding after timeout guard:
  - Command used `--tia-step-timeout-seconds 15`.
  - Report: `C:\Users\XL626\Documents\Automation\MCP_Mapped_HMI_Template_TimeoutGuard_20260506_reports\mapped_hmi_template_binding_validation.md`
  - JSON: `C:\Users\XL626\Documents\Automation\MCP_Mapped_HMI_Template_TimeoutGuard_20260506_reports\mapped_hmi_template_binding_validation.json`
  - Result: `PASS`.
  - Temporary project created: `MCP_Mapped_HMI_Template_TimeoutGuard_20260506`.
  - Verified sequence: TIA `Connect`, `CreateProject`, add PLC, add Unified HMI, ensure HMI connection/tag table, apply screen, create HMI tags, bind dynamizations, attach event script, read back event.
  - `hmi-data-export-probe`: validated, screen=`Map_hmi_data_export_probe`, HMI tags=3, bindings=2/2, events=1/1, eventReadback=1.
  - Generic commercial templates still remain skipped until explicit mappings are filled.
- Build and safety verification after this change:
  - `dotnet build ... -c Release`: 0 errors, 25 existing nullable warnings.
  - `--run-online-monitoring-safety-self-test`: `PASS`, 117 MCP tools checked, no force-related MCP tools exposed.

PLC Builder fixture readiness gate on 2026-05-07:

- Added offline CLI:
  - `--generate-plc-builder-fixture-readiness`
  - `--plc-builder-fixture-report-directory`
- Scope:
  - read-only scan of PLC XML golden fixtures,
  - no TIA connection,
  - no project import,
  - no delivery-package modification.
- Checked fixture families:
  - UDT / PLC data type,
  - PLC tag table,
  - SCL FC,
  - LAD / FlgNet,
  - Global DB.
- Important finding:
  - `TMP_EXPORT/_verify/Limit_Protect_roundtrip.xml/Limit_Protect.xml` is an FC/SCL sample and does not contain `FlgNet`.
  - LAD/FlgNet readiness therefore uses the existing real export:
    `C:\Users\XL626\Desktop\PID博途块\TMP_EXPORT\Source\5T车\Blocks\01_手动控制\FC控制\05-故障保护.xml`
- Verified reports:
  - First run caught the incorrect LAD assumption:
    `C:\Users\XL626\Desktop\PID博途块\reports\plc_builder_fixture_readiness\plc_builder_fixture_readiness_20260507_095352.md`
  - Corrected PASS run:
    `C:\Users\XL626\Desktop\PID博途块\reports\plc_builder_fixture_readiness\plc_builder_fixture_readiness_20260507_095555.md`
    `C:\Users\XL626\Desktop\PID博途块\reports\plc_builder_fixture_readiness\plc_builder_fixture_readiness_20260507_095555.json`
- Verification:
  - `dotnet build ... -c Release`: 0 errors, 25 existing nullable warnings.
  - `--generate-plc-builder-fixture-readiness`: `OK: true`, required=5, pass=5, fail=0.
  - `--run-online-monitoring-safety-self-test`: `PASS`, 117 MCP tools checked, force-related MCP tools not exposed.

PLC Tag Table Builder probe on 2026-05-07:

- Added structured builder:
  - `PlcTagTableXmlBuilder.BuildDocument(tableName, tags)`
  - `PlcTagTableXmlBuilder.BuildXml(tableName, tags)`
  - validates non-empty table name, non-empty tags, duplicate tag names, data type, and TIA absolute address prefix `%`.
- Added offline CLI:
  - `--run-plc-tag-table-builder-probe`
  - `--plc-builder-probe-report-directory`
- Scope:
  - generates a PLC tag table XML from structured definitions,
  - parses both generated XML and golden XML,
  - compares semantic table name plus tag name/type/address,
  - does not connect TIA or import PLC objects,
  - does not modify TMP_EXPORT or the delivery package.
- Golden fixture:
  - `C:\Users\XL626\Desktop\PID博途块\TMP_EXPORT\_verify\TagTable_StartStop.xml`
- Verified report:
  - `C:\Users\XL626\Desktop\PID博途块\reports\plc_builder_probes\plc_tag_table_builder_probe_20260507_095948.md`
  - `C:\Users\XL626\Desktop\PID博途块\reports\plc_builder_probes\plc_tag_table_builder_probe_20260507_095948.json`
  - Generated XML:
    `C:\Users\XL626\Desktop\PID博途块\reports\plc_builder_probes\TagTable_StartStop.generated_20260507_095948.xml`
- Verification:
  - `--run-plc-tag-table-builder-probe`: `OK: true`, `semanticEqual: true`.
  - `--generate-plc-builder-fixture-readiness`: `OK: true`, required=5, pass=5, fail=0.
  - `dotnet build ... -c Release`: 0 errors, existing nullable warnings only.

PLC UDT Builder probe on 2026-05-07:

- Added structured builder:
  - `PlcUdtXmlBuilder.BuildDocument(members)`
  - `PlcUdtXmlBuilder.BuildXml(members)`
  - validates non-empty members, duplicate member names, member name, and datatype.
- Supported semantics in this first slice:
  - flat UDT / `SW.Types.PlcStruct` members,
  - member datatype,
  - `ExternalWritable`,
  - `zh-CN` member comment.
- Added offline CLI:
  - `--run-plc-udt-builder-probe`
- Scope:
  - reads the first four members from the golden UDT,
  - generates a minimal UDT XML,
  - parses golden and generated XML,
  - compares member name/type/ExternalWritable/Chinese comment,
  - does not connect TIA or import PLC data types,
  - does not modify TMP_EXPORT or the delivery package.
- Golden fixture:
  - `C:\Users\XL626\Desktop\PID博途块\TMP_EXPORT\_verify\UDT_Fault.xml`
- Verified report:
  - `C:\Users\XL626\Desktop\PID博途块\reports\plc_builder_probes\plc_udt_builder_probe_20260507_100730.md`
  - `C:\Users\XL626\Desktop\PID博途块\reports\plc_builder_probes\plc_udt_builder_probe_20260507_100730.json`
  - Generated XML:
    `C:\Users\XL626\Desktop\PID博途块\reports\plc_builder_probes\UDT_Fault.minimal.generated_20260507_100730.xml`
- Verification:
  - `--run-plc-udt-builder-probe`: `OK: true`, `semanticEqual: true`.
  - `--run-plc-tag-table-builder-probe`: `OK: true` after the UDT builder change.
  - Generated XML contains the Chinese comment `行车接收不到控制主机心跳信息`.

PLC Builder offline suite on 2026-05-07:

- Added suite runner:
  - `PlcBuilderOfflineValidationSuite.Run(fixtureDirectory, reportDirectory)`
- Added offline CLI:
  - `--run-plc-builder-offline-suite`
  - `--plc-builder-suite-report-directory`
- Rule:
  - every future PLC Builder capability must be added to this suite with at least one positive probe before it is treated as usable.
  - a Builder change is not considered complete when only code compiles; it must pass this suite or a narrower documented probe plus relevant regression checks.
- Current suite items:
  - PLC Builder fixture readiness,
  - PLC tag table Builder,
  - PLC UDT Builder.
- Verified suite report:
  - `C:\Users\XL626\Desktop\PID博途块\reports\plc_builder_suite\plc_builder_offline_suite_20260507_101632.md`
  - `C:\Users\XL626\Desktop\PID博途块\reports\plc_builder_suite\plc_builder_offline_suite_20260507_101632.json`
- Verification:
  - `--run-plc-builder-offline-suite`: `OK: true`.
  - Suite report lists all three items as `PASS`.
  - `--run-online-monitoring-safety-self-test`: `PASS`, 117 MCP tools checked, force-related MCP tools not exposed.
  - `dotnet build ... -c Release`: 0 errors, existing nullable warnings only.

SCL StructuredText Builder probe on 2026-05-07:

- Added structured builder:
  - `StructuredTextXmlBuilder`
  - supports token, blank, newline, local variable access, literal constant, assignment, IF header, ELSE, and END_IF.
- Added offline CLI:
  - `--run-structured-text-builder-probe`
- Scope:
  - generates a `StructuredText/v4` XML fragment for the `FC_StartStop` IF/ELSE logic,
  - parses the golden and generated XML,
  - compares token sequence, variable sequence, literal constants, IF count, END_IF count, and assignment count,
  - does not connect TIA or import PLC blocks,
  - does not modify TMP_EXPORT or the delivery package.
- Golden fixture:
  - `C:\Users\XL626\Desktop\PID博途块\TMP_EXPORT\_verify\FC_StartStop.xml`
- Verified report:
  - `C:\Users\XL626\Desktop\PID博途块\reports\plc_builder_probes\structured_text_builder_probe_20260507_102320.md`
  - `C:\Users\XL626\Desktop\PID博途块\reports\plc_builder_probes\structured_text_builder_probe_20260507_102320.json`
  - Generated XML:
    `C:\Users\XL626\Desktop\PID博途块\reports\plc_builder_probes\StructuredText_StartStop.generated_20260507_102320.xml`
- Verification:
  - `--run-structured-text-builder-probe`: `OK: true`, `semanticEqual: true`.
  - `--run-plc-builder-offline-suite`: `OK: true`; suite now lists four items as `PASS`.

PLC FC Block Composer probe on 2026-05-07:

- Added structured composer:
  - `PlcFcBlockXmlComposer.Compose(...)`
  - `PlcFcBlockXmlComposer.ComposeXml(...)`
  - reuses `StructuredTextXmlBuilder` output instead of duplicating SCL XML generation.
- Added offline CLI:
  - `--run-plc-fc-block-composer-probe`
- Scope:
  - generates a complete `SW.Blocks.FC` XML for `FC_StartStop`,
  - includes interface sections, block metadata, one SCL CompileUnit, and StructuredText network source,
  - parses golden and generated FC XML,
  - compares block name, number, language, memory layout, compile unit count, interface members, and SCL semantics,
  - does not connect TIA or import PLC blocks,
  - does not modify TMP_EXPORT or the delivery package.
- Golden fixture:
  - `C:\Users\XL626\Desktop\PID博途块\TMP_EXPORT\_verify\FC_StartStop.xml`
- Verified report:
  - `C:\Users\XL626\Desktop\PID博途块\reports\plc_builder_probes\plc_fc_block_composer_probe_20260507_102706.md`
  - `C:\Users\XL626\Desktop\PID博途块\reports\plc_builder_probes\plc_fc_block_composer_probe_20260507_102706.json`
  - Generated XML:
    `C:\Users\XL626\Desktop\PID博途块\reports\plc_builder_probes\FC_StartStop.composed_20260507_102706.xml`
- Verification:
  - `--run-plc-fc-block-composer-probe`: `OK: true`, `semanticEqual: true`.
  - `--run-plc-builder-offline-suite`: `OK: true`; suite now lists five items as `PASS`.

PLC Global DB Builder probe on 2026-05-07:

- Added structured builder:
  - `PlcGlobalDbXmlBuilder.BuildDocument(dbName, dbNumber, staticMembers)`
  - `PlcGlobalDbXmlBuilder.BuildXml(dbName, dbNumber, staticMembers)`
- Supported semantics in this first slice:
  - `SW.Blocks.GlobalDB`,
  - `Static` members,
  - member datatype,
  - `ExternalWritable`,
  - `zh-CN` member comment,
  - `StartValue`,
  - DB name/number/language/memory layout.
- Added offline CLI:
  - `--run-plc-global-db-builder-probe`
- Scope:
  - reads the first 25 members from the `Sim_Data` golden DB,
  - generates a minimal GlobalDB XML,
  - compares DB metadata and member name/type/ExternalWritable/comment/StartValue,
  - does not connect TIA or import PLC DBs,
  - does not modify TMP_EXPORT or the delivery package.
- Golden fixture:
  - `C:\Users\XL626\Desktop\PID博途块\TMP_EXPORT\_verify\Sim_Data_roundtrip.xml\Sim_Data.xml`
- Verified report:
  - `C:\Users\XL626\Desktop\PID博途块\reports\plc_builder_probes\plc_global_db_builder_probe_20260507_104053.md`
  - `C:\Users\XL626\Desktop\PID博途块\reports\plc_builder_probes\plc_global_db_builder_probe_20260507_104053.json`
  - Generated XML:
    `C:\Users\XL626\Desktop\PID博途块\reports\plc_builder_probes\Sim_Data.minimal.generated_20260507_104053.xml`
- Verification:
  - `--run-plc-global-db-builder-probe`: `OK: true`, `semanticEqual: true`.
  - Generated XML contains `X_Act`, `StartValue=0`, and Chinese comment `X轴当前实际使用值`.
  - `--run-plc-builder-offline-suite`: `OK: true`; suite now lists six items as `PASS`.

LAD FlgNet Call Builder probe on 2026-05-07:

- Added structured builder:
  - `FlgNetCallXmlBuilder.BuildDocument(callName, parameters)`
  - `FlgNetCallXmlBuilder.BuildXml(callName, parameters)`
- Supported semantics in this first slice:
  - LAD `FlgNet/v5` network source,
  - FC `CallInfo` parameter declaration,
  - global-symbol `Access`,
  - literal-constant `Access`,
  - powerrail to `en`,
  - input/output parameter wires with `IdentCon` and `NameCon`.
- Added offline CLI:
  - `--run-flgnet-call-builder-probe`
- Scope:
  - generates the first `Limit_Protect` LAD call network from the real exported reference block,
  - compares call name, block type, parameter list, global/literal accesses, wire count, `IdentCon` count, and `NameCon` count,
  - does not connect TIA or import PLC blocks,
  - does not modify TMP_EXPORT, the reference project, or the delivery package.
- Golden fixture:
  - `C:\Users\XL626\Desktop\PID博途块\TMP_EXPORT\Source\5T车\Blocks\01_手动控制\FC控制\05-故障保护.xml`
- Verified report:
  - `C:\Users\XL626\Desktop\PID博途块\reports\plc_builder_probes\flgnet_call_builder_probe_20260507_110124.md`
  - `C:\Users\XL626\Desktop\PID博途块\reports\plc_builder_probes\flgnet_call_builder_probe_20260507_110124.json`
  - Generated XML:
    `C:\Users\XL626\Desktop\PID博途块\reports\plc_builder_probes\FlgNet_LimitProtect.generated_20260507_110124.xml`
- Verification:
  - `--run-flgnet-call-builder-probe`: `OK: true`, `semanticEqual: true`.
  - Golden and generated network both target `Limit_Protect` FC.
  - Both sides contain 12 parameter accesses, 13 wires, 12 `IdentCon`, and 13 `NameCon`.
  - `--run-plc-builder-offline-suite`: `OK: true`; suite now lists seven items as `PASS`.
  - `--run-online-monitoring-safety-self-test`: `PASS`, 117 MCP tools checked, force-related MCP tools not exposed.

HMI template PLC symbol precheck UDT expansion on 2026-05-07:

- Enhanced offline PLC export catalog:
  - scans `SW.Types.PlcStruct` UDT exports before block/DB scan,
  - records `udtTypes` and `udtTypeCount`,
  - expands DB/block members typed as quoted UDTs into full member symbols,
  - marks expanded symbols with `source=udt-expanded` and `ownerType=<UDT name>`.
- Purpose:
  - HMI binding precheck can now verify real DB member symbols, not only PLC tag-table roots or direct DB members,
  - reduces the risk of binding HMI controls to PLC symbols that do not actually exist,
  - supports later mapping for nested structures such as fault bits, communication config, and telegram data.
- Verified commands:
  - `--analyze-hmi-template-plc-mapping --plc-export-directory C:\Users\XL626\Desktop\PID博途块\TMP_EXPORT\Source\5T车`
  - `--generate-hmi-template-sync-precheck --plc-export-directory C:\Users\XL626\Desktop\PID博途块\TMP_EXPORT\Source\5T车`
- Verified reports:
  - `C:\Users\XL626\Desktop\PID博途块\reports\hmi_template_plc_mapping\hmi_template_plc_mapping_20260507_110755.json`
  - `C:\Users\XL626\Desktop\PID博途块\reports\hmi_template_sync_precheck\hmi_template_sync_precheck_20260507_110755.json`
- Verification:
  - PLC export scan: `filesScanned=109`, `blockCount=89`, `udtTypeCount=4`, `symbolCount=4037`.
  - Confirmed expanded symbols include:
    - `Global_Data.AllFault.F8000`
    - `A0_DB_InitData.ConnectConfig.ControlPC.Send.ConnectionData`
    - `Record_Telegram_PC.Telegram_Rec.Data.CMD`
  - `--run-plc-builder-offline-suite`: `OK: true` after the HMI precheck change.
  - `--run-online-monitoring-safety-self-test`: `PASS`, force and online write guards unchanged.

HMI action recipe analysis and lint on 2026-05-07:

- Enhanced offline template analyzer:
  - classifies event actions into recipes such as `set-bit`, `reset-bit`, `open-popup`, `goto-screen`, `confirm-write`, and generic `script`,
  - marks each action with safety level: `navigation`, `command`, or `high`,
  - emits required verification steps for each action recipe,
  - detects duplicate item/event/action entries,
  - checks whether `TargetPopup` or `TargetScreen` exists in the same template object set.
- Purpose:
  - converts HMI event work from loose handwritten scripts into auditable action recipes,
  - makes command buttons and value writes reviewable before TIA application,
  - supports later generation of safe button scripts with readback and syntax-check evidence.
- Verified command:
  - `--analyze-hmi-template-reference`
- Verified report:
  - `C:\Users\XL626\Desktop\PID博途块\reports\hmi_template_reference\hmi_template_reference_20260507_112021.json`
  - `C:\Users\XL626\Desktop\PID博途块\reports\hmi_template_reference\hmi_template_reference_20260507_112021.md`
- Verification:
  - `drive-axis-control`: 16 actions, 16 ready, 8 duplicate action rows, 0 missing targets.
  - `equipment-overview`: 11 actions, 1 high-risk confirm-write, 5 duplicate action rows, 2 missing target rows for `Alarm_Overview`.
  - `hmi-data-export-probe`: 2 actions, 1 duplicate action row.
  - `pid-faceplate`: 7 actions, 1 high-risk confirm-write, 3 duplicate action rows.
  - `--run-plc-builder-offline-suite`: `OK: true` after analyzer change.
  - `--run-online-monitoring-safety-self-test`: `PASS`, no force tools exposed and online write guards unchanged.

HMI effective action recipe view on 2026-05-07:

- Enhanced action analyzer output:
  - keeps raw `actions` for traceability,
  - keeps `duplicateActions` as lint findings,
  - adds `effectiveRecipes` for downstream template execution,
  - adds `effectiveActionCount` so reports can distinguish declared actions from executable unique actions.
- Rule:
  - top-level `Events` and item-level `Items[].Actions` may both describe the same action,
  - the analyzer must report the duplicate,
  - later HMI event generation should consume `effectiveRecipes`, not raw `actions`.
- Verified report:
  - `C:\Users\XL626\Desktop\PID博途块\reports\hmi_template_reference\hmi_template_reference_20260507_112920.json`
  - `C:\Users\XL626\Desktop\PID博途块\reports\hmi_template_reference\hmi_template_reference_20260507_112920.md`
- Verification:
  - `drive-axis-control`: raw actions=16, effective actions=8, duplicates=8.
  - `equipment-overview`: raw actions=11, effective actions=6, duplicates=5, missing target rows=2.
  - `hmi-data-export-probe`: raw actions=2, effective actions=1, duplicates=1.
  - `pid-faceplate`: raw actions=7, effective actions=4, duplicates=3.
  - `dotnet build ... -c Release`: 0 warnings, 0 errors after the final sequential build.
  - `--run-plc-builder-offline-suite`: `OK: true`.
  - `--run-online-monitoring-safety-self-test`: `PASS`.

HMI action script recipe builder on 2026-05-07:

- Added offline builder:
  - `HmiActionScriptRecipeBuilder.Build(...)`
  - `HmiActionScriptRecipeBuilder.RunProbe(...)`
- Added offline CLI:
  - `--run-hmi-action-script-recipe-probe`
- Supported deterministic script recipes in this first slice:
  - `set-bit` -> `HMIRuntime.Tags.SysFct.SetBitInTag("<tag>", 0);`
  - `reset-bit` -> `HMIRuntime.Tags.SysFct.ResetBitInTag("<tag>", 0);`
  - `toggle-bit` -> `HMIRuntime.Tags.SysFct.ToggleBitInTag("<tag>", 0);`
- Conservative placeholders:
  - `open-popup` and `goto-screen` are emitted as TODO scripts until the exact project/version API is verified,
  - `confirm-write` is emitted as high-risk TODO requiring range validation, operator confirmation, TIA SyntaxCheck, and ScriptCode readback,
  - generic `script` actions are not generated deterministically from metadata.
- Scope:
  - reads HMI JSON templates and their `effectiveRecipes`,
  - generates auditable script payloads and warnings,
  - does not connect TIA,
  - does not apply ScriptCode,
  - does not modify HMI templates, reference projects, TMP_EXPORT, or delivery package.
- Verified report:
  - `C:\Users\XL626\Desktop\PID博途块\reports\hmi_action_script_recipe\hmi_action_script_recipe_probe_20260507_113901.md`
  - `C:\Users\XL626\Desktop\PID博途块\reports\hmi_action_script_recipe\hmi_action_script_recipe_probe_20260507_113901.json`
- Verification:
  - `templateCount=4`, `generatedActionCount=19`, `errors=0`.
  - Deterministic command scripts were generated for set/reset bit actions.
  - `todo=5`, covering popup/navigation and confirm-write placeholders.
  - `high=2`, covering `equipment-overview.Btn_ConfirmParameter` and `pid-faceplate.Btn_ConfirmTuning`.
  - `--run-plc-builder-offline-suite`: `OK: true`.
  - `--run-online-monitoring-safety-self-test`: `PASS`.

Unified HMI high-level button action MCP tools on 2026-05-07:

- Added MCP tools:
  - `BuildUnifiedHmiButtonActionScript`
  - `EnsureUnifiedHmiButtonAction`
- `BuildUnifiedHmiButtonActionScript`:
  - offline/script-only helper exposed through MCP,
  - builds the same audited recipe payload as `HmiActionScriptRecipeBuilder.Build(...)`,
  - does not connect TIA or write project content.
- `EnsureUnifiedHmiButtonAction`:
  - high-level apply tool for deterministic button command actions,
  - internally calls `EnsureUnifiedHmiButtonEventHandler`,
  - then calls `SetUnifiedHmiButtonEventScriptCode`,
  - only allows `set-bit`, `reset-bit`, and `toggle-bit`,
  - rejects high-risk recipes, empty scripts, unsupported actions, and any generated script containing TODO.
- Safety:
  - force/watch-table operations remain unrelated and forbidden,
  - online monitoring safety self-test now checks 119 MCP tools and still reports no force-related tools,
  - popup/navigation/value-write recipes are not auto-applied by this tool until their exact project/version API and validation flow are verified.
- Verification:
  - source declaration confirmed for both MCP tools in `ModelContextProtocol/McpServer.cs`.
  - `dotnet build ... -c Release`: 0 errors, existing nullable warnings only after adding the tools.
  - `--run-hmi-action-script-recipe-probe`: `OK: true`, `generatedActionCount=19`, `errors=0`, `high=2`, `todo=5`.
  - `--run-plc-builder-offline-suite`: `OK: true`.
  - `--run-online-monitoring-safety-self-test`: `PASS`, `checkedTools=119`.

HMI action API-discovery guard on 2026-05-07:

- Tightened `HmiActionScriptRecipeBuilder.Build(...)` output for popup/navigation recipes:
  - adds machine-readable `requiresApiDiscovery`,
  - adds `applyBlockedReason`,
  - adds `discoveryRequired` steps for temporary-project/reference-project verification,
  - keeps popup/navigation scripts as TODO placeholders until exact WinCC Unified V21 API is proven by SyntaxCheck and ScriptCode readback.
- Current evidence:
  - local HMI export only proves `HMIRuntime.Tags.SysFct.SetBitInTag(...)` and `ResetBitInTag(...)`,
  - no verified local export/reference evidence yet proves popup-open or screen-navigation JavaScript API,
  - therefore popup/navigation remain blocked from deterministic application.
- Verification:
  - `dotnet build ... -c Release`: 0 errors, 25 existing nullable warnings.
  - `--run-hmi-action-script-recipe-probe`: `OK: true`.
  - Report: `C:\Users\XL626\Desktop\PID博途块\reports\hmi_action_script_recipe\hmi_action_script_recipe_probe_20260507_115535.json`
  - `templateCount=4`, `generatedActionCount=19`, `apiDiscoveryRequiredCount=3`.
  - API-discovery blocked actions:
    - `drive-axis-control.BtnOpenAxisParameter.Tapped`: `open-popup`.
    - `equipment-overview.Btn_OpenParameter.Tapped`: `open-popup`.
    - `pid-faceplate.Btn_OpenTuning.Tapped`: `open-popup`.
  - `high=2`, still covering high-risk confirm-write placeholders.
  - `todo=5`, covering the 3 popup API-discovery placeholders and 2 confirm-write placeholders.
  - `--run-plc-builder-offline-suite`: `OK: true`.
  - `--run-online-monitoring-safety-self-test`: `PASS`, `checkedTools=119`.

HMI template PLC/HMI usage sync precheck on 2026-05-07:

- Enhanced `BuildHmiTemplateSyncPrecheck(...)` so synchronization is no longer limited to `RequiredTags.PlcTag`:
  - checks every dynamization HMI tag usage against `RequiredTags`,
  - checks every effective action target tag against `RequiredTags`,
  - emits `hmiUsageChecks`, `commandTagChecks`, and `missingHmiTagDefinitions`,
  - keeps PLC-side full-symbol/root-symbol checks for each required tag,
  - reports `missing-plc-or-hmi-symbols` when either PLC symbols or HMI tag declarations are incomplete.
- Purpose:
  - prevents a button event or dynamic property from referencing an undeclared HMI tag,
  - keeps HMI controls/events synchronized with real PLC tags/DB members instead of guessed M addresses,
  - gives later TIA application a single precheck gate before creating tags, bindings, or event scripts.
- Verified command:
  - `--generate-hmi-template-sync-precheck --plc-export-directory C:\Users\XL626\Desktop\PID博途块\TMP_EXPORT\Source\5T车`
- Verified report:
  - `C:\Users\XL626\Desktop\PID博途块\reports\hmi_template_sync_precheck\hmi_template_sync_precheck_20260507_115950.json`
  - `C:\Users\XL626\Desktop\PID博途块\reports\hmi_template_sync_precheck\hmi_template_sync_precheck_20260507_115950.md`
- Verification:
  - `drive-axis-control`: usages=13, commandTags=7, missingHmiTags=0, missingPlc=12, dbRefs=7.
  - `equipment-overview`: usages=12, commandTags=5, missingHmiTags=0, missingPlc=11, dbRefs=0.
  - `hmi-data-export-probe`: usages=3, commandTags=1, missingHmiTags=0, missingPlc=0, status=`plc-symbols-present`.
  - `pid-faceplate`: usages=12, commandTags=5, missingHmiTags=0, missingPlc=9, dbRefs=7.
  - `dotnet build ... -c Release`: 0 errors, 25 existing nullable warnings.
  - `--run-hmi-action-script-recipe-probe`: `OK: true`.
  - `--run-plc-builder-offline-suite`: `OK: true`.
  - `--run-online-monitoring-safety-self-test`: `PASS`, `checkedTools=119`.

HMI template PLC mapping gate clarity on 2026-05-07:

- Enhanced `BuildHmiTemplatePlcMapping(...)` report rows:
  - adds row-level `gateStatus`,
  - adds row-level `gateReason`,
  - adds row-level `recommendedNextAction`,
  - distinguishes `verified-exact`, `high-confidence-review`, `review-required`, and `no-candidate`.
- Enhanced template-level mapping gate:
  - `mapping-ready` now requires every RequiredTag to be an exact PLC export symbol,
  - high-confidence candidates remain blocked until written to an explicit mapping file,
  - template-level `gateStatus` and `gateReason` tell later agents whether to run sync precheck or continue mapping review.
- Purpose:
  - prevents candidate scores from silently becoming bindings,
  - makes mapping reports actionable for agents without prior conversation context,
  - supports the commercial workflow: analyze candidates -> explicit mapping file -> sync precheck -> temporary-project validation.
- Verified command:
  - `--analyze-hmi-template-plc-mapping --plc-export-directory C:\Users\XL626\Desktop\PID博途块\TMP_EXPORT\Source\5T车`
- Verified report:
  - `C:\Users\XL626\Desktop\PID博途块\reports\hmi_template_plc_mapping\hmi_template_plc_mapping_20260507_120552.json`
  - `C:\Users\XL626\Desktop\PID博途块\reports\hmi_template_plc_mapping\hmi_template_plc_mapping_20260507_120552.md`
- Verification:
  - `hmi-data-export-probe`: `mapping-ready`, `ready-for-sync-precheck`, verifiedExact=3.
  - `drive-axis-control`: blocked, verifiedExact=0, highConfidenceCandidates=1, reviewRequired=11.
  - `equipment-overview`: blocked, verifiedExact=0, reviewRequired=11.
  - `pid-faceplate`: blocked, verifiedExact=0, reviewRequired=9.
  - `dotnet build ... -c Release`: 0 errors, 25 existing nullable warnings.
  - `--generate-hmi-template-sync-precheck`: report generated successfully.
  - `--run-plc-builder-offline-suite`: `OK: true`.
  - `--run-online-monitoring-safety-self-test`: `PASS`, `checkedTools=119`.

HMI template PLC data-type sync gate on 2026-05-07:

- Enhanced `BuildHmiTemplateSyncPrecheck(...)` with PLC data type verification:
  - builds a PLC symbol catalog from the offline export catalog,
  - records `hmiDataType`, `plcDataType`, `dataTypeVerified`, and `dataTypeCompatible` per binding,
  - emits `dataTypeMismatches`,
  - keeps a template blocked if symbols exist but HMI/PLC data types are incompatible.
- Purpose:
  - prevents HMI controls/events from binding to real but wrong-typed PLC symbols,
  - makes the precheck gate cover HMI tag declaration, PLC symbol existence, and PLC data type compatibility,
  - keeps DB/member readback and final TIA readback as required later gates.
- Verified command:
  - `--generate-hmi-template-sync-precheck --plc-export-directory C:\Users\XL626\Desktop\PID博途块\TMP_EXPORT\Source\5T车`
- Verified report:
  - `C:\Users\XL626\Desktop\PID博途块\reports\hmi_template_sync_precheck\hmi_template_sync_precheck_20260507_123556.json`
  - `C:\Users\XL626\Desktop\PID博途块\reports\hmi_template_sync_precheck\hmi_template_sync_precheck_20260507_123556.md`
- Verification:
  - `hmi-data-export-probe`: `plc-symbols-present`, missingPlc=0, typeMismatch=0, missingHmiTags=0.
  - `HMI_RunEnable`: HMI `Bool` -> PLC `Bool`, compatible.
  - `HMI_GantryForward`: HMI `Bool` -> PLC `Bool`, compatible.
  - `HMI_GantrySpeedSet`: HMI `DInt` -> PLC `DInt`, compatible.
  - `drive-axis-control`, `equipment-overview`, and `pid-faceplate` remain blocked by missing PLC symbols, not by type mismatch.
  - `dotnet build ... -c Release`: 0 errors, 25 existing nullable warnings.
  - `--analyze-hmi-template-plc-mapping`: report generated successfully.
  - `--run-plc-builder-offline-suite`: `OK: true`.
  - `--run-online-monitoring-safety-self-test`: `PASS`, `checkedTools=119`.

HMI deterministic PLC mapping rules v1 on 2026-05-07:

- Added conservative deterministic mapping support to `BuildHmiTemplateMappingSkeletonJson(...)`:
  - candidates are still not auto-bound by score,
  - only built-in alias rules may write `MappedPlcTag`,
  - every rule target must exist as a full PLC export symbol,
  - every rule target must be data-type compatible,
  - rule target must currently be a `GlobalDB` member,
  - generated rows record `MappingSource`, `DeterministicRule`, and `RuleEvidence`.
- Implemented v1 alias rule set:
  - `drive-axis-control.Cmd_Axis_Reset` -> `HMI_Data.大车复位`.
  - `drive-axis-control.Cmd_Axis_JogFwd` -> `HMI_Data.大车向前`.
  - `drive-axis-control.Cmd_Axis_JogRev` -> `HMI_Data.大车向后`.
  - `equipment-overview.Sys_Fault` -> `A5_DB2_Faults_DB.Sys_Fault_Flag`.
  - `equipment-overview.Sys_Auto` -> `Global_Data.CMS.Auto`.
  - `equipment-overview.Cmd_Stop` -> `21_DB_interface.Auto.Stop`.
  - `equipment-overview.Cmd_Reset` -> `21_DB_interface.Auto.Reset`.
  - existing exact mappings for `hmi-data-export-probe` remain `verified-exact`.
- Purpose:
  - starts the deterministic project-rule layer requested by the full-coverage plan,
  - avoids unsafe semantic guesses for ambiguous `Axis.*` and `PID.*` status/parameter tags,
  - gives commercial package users a traceable mapping source instead of opaque candidate scoring.
- Verified commands:
  - `dotnet build ... -c Release`.
  - `--generate-hmi-template-mapping-skeleton --plc-export-directory C:\Users\XL626\Desktop\PID博途块\TMP_EXPORT\Source\5T车 --hmi-template-mapping-path C:\Users\XL626\Desktop\PID博途块\reports\hmi_template_plc_mapping\hmi_template_mapping.deterministic_20260507.json`
  - `--generate-hmi-template-sync-precheck --plc-export-directory C:\Users\XL626\Desktop\PID博途块\TMP_EXPORT\Source\5T车 --hmi-template-mapping-path C:\Users\XL626\Desktop\PID博途块\reports\hmi_template_plc_mapping\hmi_template_mapping.deterministic_20260507.json`
  - `--validate-mapped-hmi-template-bindings --mapped-hmi-template-offline-only --plc-export-directory C:\Users\XL626\Desktop\PID博途块\TMP_EXPORT\Source\5T车 --hmi-template-mapping-path C:\Users\XL626\Desktop\PID博途块\reports\hmi_template_plc_mapping\hmi_template_mapping.deterministic_20260507.json --project-name MCP_Mapped_HMI_Offline_Deterministic_20260507`
- Verified reports:
  - `C:\Users\XL626\Desktop\PID博途块\reports\hmi_template_plc_mapping\hmi_template_mapping.deterministic_20260507.json`
  - `C:\Users\XL626\Desktop\PID博途块\reports\hmi_template_sync_precheck\hmi_template_sync_precheck_20260507_130705.json`
  - `C:\Users\XL626\Documents\Automation\MCP_Mapped_HMI_Offline_Deterministic_20260507_reports\mapped_hmi_template_binding_validation.json`
- Verification:
  - deterministic rule mappings=7.
  - total explicit mappings=10 including 3 exact `hmi-data-export-probe` mappings.
  - sync precheck: `typeMismatch=0`, `missingHmiTags=0`.
  - offline mapped-template gate: `hmi-data-export-probe` passed, `drive-axis-control`, `equipment-overview`, and `pid-faceplate` remained skipped because RequiredTags are not fully mapped.
  - `--run-hmi-action-script-recipe-probe`: `OK: true`.
  - `--run-plc-builder-offline-suite`: `OK: true`.
  - `--run-online-monitoring-safety-self-test`: `PASS`, `checkedTools=119`.

HMI mapping provenance trace on 2026-05-07:

- Extended mapping provenance from the mapping skeleton into later pipeline stages:
  - `LoadHmiTemplateMappingFile(...)` now preserves `mappingSource`, `deterministicRule`, and `ruleEvidence`,
  - `ApplyHmiTemplateMapping(...)` copies mapping provenance into effective template `RequiredTags`,
  - `WriteMappedTemplateFile(...)` preserves provenance fields in generated `.mapped.json` files.
- Purpose:
  - makes the mapping chain auditable from skeleton -> sync precheck -> mapped template,
  - lets later agents distinguish `verified-exact`, deterministic project rules, and manually filled mappings,
  - supports commercial delivery evidence without relying on prior chat context.
- Verified reports:
  - `C:\Users\XL626\Desktop\PID博途块\reports\hmi_template_plc_mapping\hmi_template_mapping.deterministic_20260507_trace.json`
  - `C:\Users\XL626\Desktop\PID博途块\reports\hmi_template_sync_precheck\hmi_template_sync_precheck_20260507_131039.json`
  - `C:\Users\XL626\Documents\Automation\MCP_Mapped_HMI_Offline_Deterministic_Trace_20260507_reports\mapped_hmi_template_binding_validation.json`
  - `C:\Users\XL626\Documents\Automation\MCP_Mapped_HMI_Offline_Deterministic_Trace_20260507_reports\mapped_templates\unified_hmi_data_export_probe.mapped.json`
- Verification:
  - sync precheck effective mappings=10.
  - `deterministic-project-rule` mappings=7.
  - `verified-exact` mappings=3.
  - mapped template file preserves `MappingSource` and `MappingStatus` for exact mappings.
  - offline mapped-template gate still passes only `hmi-data-export-probe`; partial templates remain skipped.
  - `dotnet build ... -c Release`: 0 errors, 25 existing nullable warnings.
  - `--run-hmi-action-script-recipe-probe`: `OK: true`.
  - `--run-plc-builder-offline-suite`: `OK: true`.
  - `--run-online-monitoring-safety-self-test`: `PASS`, `checkedTools=119`.

Unified HMI template layout probe on 2026-05-07:

- Added an offline-only CLI quality gate:
  - `--run-hmi-template-layout-probe`
  - optional `--hmi-template-layout-report-directory`
- The probe reads `docs/hmi_templates/unified_*.json` and validates:
  - screen size,
  - duplicate item names,
  - item bounds and non-positive dimensions,
  - design-system palette/layout metadata,
  - generated execution JSON item-count consistency through `BuildUnifiedHmiApplyDesignJson(...)`,
  - heuristic warnings for overlap, screen density, small controls, and possible text overflow.
- Safety:
  - no TIA connection,
  - no project writes,
  - no delivery-package changes,
  - blocking errors are limited to structural issues; visual heuristics remain warnings.
- Verified report:
  - `C:\Users\XL626\Desktop\PID博途块\reports\hmi_template_layout\hmi_template_layout_probe_20260507_131639.json`
  - `C:\Users\XL626\Desktop\PID博途块\reports\hmi_template_layout\hmi_template_layout_probe_20260507_131639.md`
- Verification:
  - `templateCount=4`,
  - `failed=0`,
  - `warnings=2`,
  - execution JSON generation checked for all templates,
  - `unified_drive_axis_control.json`: 19 items, 1280x720, no warnings,
  - `unified_equipment_overview.json`: 19 items, 1280x720, no warnings,
  - `unified_hmi_data_export_probe.json`: warning for missing `DesignSystem`,
  - `unified_pid_faceplate.json`: warning for missing `DesignSystem.Layout.Grid`.
- Regression:
  - `dotnet build ... -c Release`: 0 errors, existing nullable warnings.
  - `--run-hmi-action-script-recipe-probe`: `OK: true`.
  - `--run-plc-builder-offline-suite`: `OK: true`.
  - `--run-online-monitoring-safety-self-test`: `PASS`, `checkedTools=119`.

Unified HMI template layout QA cleanup and MCP exposure on 2026-05-07:

- Fixed the two non-blocking layout probe warnings:
  - added `DesignSystem` metadata to `docs/hmi_templates/unified_hmi_data_export_probe.json`,
  - added `DesignSystem.Layout.Grid` metadata to `docs/hmi_templates/unified_pid_faceplate.json`.
- Added MCP tool:
  - `AnalyzeUnifiedHmiTemplateLayout`
  - offline-only JSON response,
  - checks theme metadata, screen bounds, duplicate item names, size issues, layout warnings, density, and execution-shape readiness,
  - does not connect to TIA Portal and does not modify projects.
- Verification:
  - `--run-hmi-template-layout-probe`: `OK: true`, `templateCount=4`, `failed=0`, `warnings=0`.
  - MCP static reflection call `AnalyzeUnifiedHmiTemplateLayout("...\docs\hmi_templates")`: `Ok=True`, `templateCount=4`, `failed=0`, `warnings=0`.
  - `dotnet build ... -c Release`: 0 errors.
  - `--run-hmi-action-script-recipe-probe`: `OK: true`.
  - `--run-plc-builder-offline-suite`: `OK: true`.
  - `--run-online-monitoring-safety-self-test`: `PASS`, `checkedTools=120`, no Force tools exposed.

Unified HMI template layout analyzer de-duplication on 2026-05-07:

- Refactored layout/theme QA into shared analyzer:
  - `src/TiaMcpServer/ModelContextProtocol/HmiTemplateLayoutAnalyzer.cs`
- `--run-hmi-template-layout-probe` and MCP `AnalyzeUnifiedHmiTemplateLayout` now use the same rule set.
- Purpose:
  - avoid CLI/MCP drift,
  - make future theme/layout thresholds maintainable in one place,
  - improve external-agent reuse without remembering CLI-only behavior.
- Verification:
  - `dotnet build ... -c Release`: 0 errors.
  - CLI `--run-hmi-template-layout-probe`: `OK: true`, `templateCount=4`, `failed=0`, `warnings=0`.
  - MCP static reflection call `AnalyzeUnifiedHmiTemplateLayout("...\docs\hmi_templates")`: `Ok=True`, `templateCount=4`, `failed=0`, `warnings=0`.
  - `--run-hmi-action-script-recipe-probe`: `OK: true`.
  - `--run-plc-builder-offline-suite`: `OK: true`.
  - `--run-online-monitoring-safety-self-test`: `PASS`, `checkedTools=120`, no Force tools exposed.

Unified HMI template execution JSON builder on 2026-05-07:

- Refactored template-to-apply-design conversion into:
  - `src/TiaMcpServer/ModelContextProtocol/HmiTemplateDesignJsonBuilder.cs`
- Existing TIA validation flows now reuse this builder instead of a private `Program.cs` helper.
- Added MCP tool:
  - `BuildUnifiedHmiTemplateApplyDesignJson`
  - offline-only,
  - converts one Unified HMI template JSON file into the execution JSON accepted by `ApplyUnifiedHmiScreenDesignJson`,
  - attaches `layoutQa` from `HmiTemplateLayoutAnalyzer`,
  - returns item count and the exact `applyDesign` payload before any TIA write.
- Purpose:
  - lets external agents preview the exact HMI write payload,
  - makes "QA -> apply design" a reproducible two-step workflow,
  - keeps screen/template changes reviewable before project mutation.
- Verification:
  - `dotnet build ... -c Release`: 0 errors.
  - MCP static reflection call `BuildUnifiedHmiTemplateApplyDesignJson(unified_drive_axis_control.json, 800, 480)`: `Ok=True`, `itemCount=19`, `layoutStatus=pass`, `width=1280`, `height=720`.
  - CLI `--run-hmi-template-layout-probe`: `OK: true`, `templateCount=4`, `failed=0`, `warnings=0`.
  - `--run-hmi-action-script-recipe-probe`: `OK: true`.
  - `--run-plc-builder-offline-suite`: `OK: true`.
  - `--run-online-monitoring-safety-self-test`: `PASS`, `checkedTools=121`, no Force tools exposed.

Unified HMI template apply-design manifest on 2026-05-07:

- Added MCP tool:
  - `BuildUnifiedHmiTemplateApplyDesignManifest`
  - offline-only,
  - scans a template directory,
  - summarizes each `unified_*.json` template with layout QA, final screen size, final item count, error/warning counts, and recommended next action,
  - intentionally does not return full `applyDesign` payloads to keep the directory-level response compact.
- Intended workflow for external agents:
  - run `BuildUnifiedHmiTemplateApplyDesignManifest(...)`,
  - pick a passing template,
  - inspect its full payload with `BuildUnifiedHmiTemplateApplyDesignJson(...)`,
  - apply only in a temporary TIA project before touching a real project.
- Verification:
  - `dotnet build ... -c Release`: 0 errors.
  - MCP static reflection call `BuildUnifiedHmiTemplateApplyDesignManifest("...\docs\hmi_templates", 800, 480)`:
    - `Ok=True`,
    - `templateCount=4`,
    - `failed=0`,
    - `totalItems=60`,
    - per-template status all `pass`,
    - per-template warnings all `0`.
  - CLI `--run-hmi-template-layout-probe`: `OK: true`.
  - `--run-hmi-action-script-recipe-probe`: `OK: true`.
  - `--run-plc-builder-offline-suite`: `OK: true`.
  - `--run-online-monitoring-safety-self-test`: `PASS`, `checkedTools=122`, no Force tools exposed.

Unified HMI template apply-design manifest binding/event readiness extension on 2026-05-07:

- Extended MCP tool:
  - `BuildUnifiedHmiTemplateApplyDesignManifest`
  - still offline-only,
  - now joins layout/apply-design readiness with `HmiTemplateReferenceAnalyzer` binding and event metadata,
  - each template row now includes compact readiness counts:
    - `requiredTagCount`,
    - `dynamizationCount`,
    - `actionCount`,
    - `eventReadiness.status`,
    - `effectiveActionCount`,
    - `safeDeterministicActionCount`,
    - `apiDiscoveryRequiredCount`,
    - `highRiskActionCount`,
    - `todoActionCount`,
    - `missingRequiredTagCount`,
    - `missingTargetCount`,
    - `duplicateActionCount`,
    - command/navigation split,
    - `eventRecommendedNextAction`.
- Purpose:
  - let an external AI see, from one compact directory manifest, whether a HMI template is only visually ready or also event/binding ready,
  - keep unverified popup/navigation APIs and high-risk write actions blocked,
  - expose duplicate/missing-target problems before any TIA project write.
- Verification:
  - `dotnet build ... -c Release`: 0 errors, existing nullable warnings only.
  - MCP static reflection call `BuildUnifiedHmiTemplateApplyDesignManifest("...\docs\hmi_templates", 800, 480)`:
    - `Ok=True`,
    - `templateCount=4`,
    - `failed=0`,
    - `totalItems=60`,
    - `drive-axis-control`: tags=12, dynamizations=6, actions=16, safe deterministic actions=7, api discovery required=1, high risk=0, duplicate actions=8,
    - `equipment-overview`: tags=11, dynamizations=7, actions=11, safe deterministic actions=3, api discovery required=1, high risk=1, missing targets=2, duplicate actions=5,
    - `hmi-data-export-probe`: tags=3, dynamizations=2, actions=2, safe deterministic actions=1, api discovery required=0, high risk=0, duplicate actions=1,
    - `pid-faceplate`: tags=9, dynamizations=7, actions=7, safe deterministic actions=2, api discovery required=1, high risk=1, duplicate actions=3.
  - CLI `--run-hmi-template-layout-probe`: `OK: true`.
  - CLI `--run-hmi-action-script-recipe-probe`: `OK: true`.
  - CLI `--run-plc-builder-offline-suite`: `OK: true`.
  - CLI `--run-online-monitoring-safety-self-test`: `PASS`, `checkedTools=122`, no Force tools exposed.

Unified HMI template event de-duplication cleanup on 2026-05-07:

- Cleaned template event declarations in:
  - `docs/hmi_templates/unified_drive_axis_control.json`,
  - `docs/hmi_templates/unified_equipment_overview.json`,
  - `docs/hmi_templates/unified_hmi_data_export_probe.json`,
  - `docs/hmi_templates/unified_pid_faceplate.json`.
- Rule:
  - item-local `Actions` are the execution source for button actions,
  - top-level `Events` are kept only for actions not represented by an item-local action,
  - high-risk `ConfirmWrite` entries remain top-level and blocked until a confirmation/range/readback policy is implemented and verified.
- Added explicit `Alarm_Overview` screen reference component to `equipment-overview` so navigation target analysis no longer treats it as an accidental missing object.
- Verification:
  - JSON parse for all `unified_*.json` templates succeeded.
  - `HmiTemplateReferenceAnalyzer.Analyze("...\docs\hmi_templates", "", "")`:
    - `drive-axis-control`: actions=8, effective=8, duplicates=0, missingTargets=0, highRisk=0,
    - `equipment-overview`: actions=6, effective=6, duplicates=0, missingTargets=0, highRisk=1,
    - `hmi-data-export-probe`: actions=1, effective=1, duplicates=0, missingTargets=0, highRisk=0,
    - `pid-faceplate`: actions=4, effective=4, duplicates=0, missingTargets=0, highRisk=1.
  - MCP static reflection call `BuildUnifiedHmiTemplateApplyDesignManifest("...\docs\hmi_templates", 800, 480)`:
    - `Ok=True`,
    - `templateCount=4`,
    - `failed=0`,
    - `totalItems=60`,
    - `drive-axis-control`: status=`needs-api-discovery`, safe=7, apiDiscovery=1, highRisk=0, duplicates=0,
    - `equipment-overview`: status=`blocked-by-high-risk-actions`, safe=3, apiDiscovery=1, highRisk=1, duplicates=0,
    - `hmi-data-export-probe`: status=`ready-for-temp-project-validation`, safe=1, apiDiscovery=0, highRisk=0, duplicates=0,
    - `pid-faceplate`: status=`blocked-by-high-risk-actions`, safe=2, apiDiscovery=1, highRisk=1, duplicates=0.
  - CLI `--run-hmi-template-layout-probe`: `OK: true`.
  - CLI `--run-hmi-action-script-recipe-probe`: `OK: true`.
  - CLI `--run-plc-builder-offline-suite`: `OK: true`.
  - CLI `--run-online-monitoring-safety-self-test`: `PASS`, `checkedTools=122`, no Force tools exposed.

Unified HMI high-risk action blocking contract on 2026-05-07:

- Hardened `HmiActionScriptRecipeBuilder` for high-risk HMI writes:
  - `confirm-write` now returns `requiresSafetyPolicy=true`,
  - `applyBlocked=true`,
  - a clear `applyBlockedReason`,
  - `preApplySafetyGates` with tag verification, PLC-symbol verification, range/type validation, operator confirmation, permission check, before/after readback, TIA SyntaxCheck, and ScriptCode readback requirements.
- Extended `BuildUnifiedHmiTemplateApplyDesignManifest` event readiness:
  - added `blockedActionCount`,
  - blocked actions now include unverified popup/navigation APIs and `ConfirmWrite` actions,
  - safe deterministic set/reset/toggle bit actions remain counted separately.
- Local reference/export scan result:
  - verified local Unified export contains `SetBitInTag`/`ResetBitInTag` script examples,
  - no trustworthy WinCC Unified V21 popup/navigation script example was found in the scanned `TMP_EXPORT`/`reference` text exports,
  - therefore popup/navigation remains API-discovery blocked instead of being guessed.
- Verification:
  - `dotnet build ... -c Release`: 0 errors, existing nullable warnings only.
  - CLI `--run-hmi-action-script-recipe-probe`: `OK: true`.
  - Latest action recipe report shows blocked actions:
    - `drive-axis-control.BtnOpenAxisParameter`: `open-popup`, `applyBlocked=true`,
    - `equipment-overview.Btn_OpenParameter`: `open-popup`, `applyBlocked=true`,
    - `equipment-overview.Btn_ConfirmParameter`: `confirm-write`, `requiresSafetyPolicy=true`, `applyBlocked=true`,
    - `pid-faceplate.Btn_OpenTuning`: `open-popup`, `applyBlocked=true`,
    - `pid-faceplate.Btn_ConfirmTuning`: `confirm-write`, `requiresSafetyPolicy=true`, `applyBlocked=true`.
  - MCP static reflection call `BuildUnifiedHmiTemplateApplyDesignManifest("...\docs\hmi_templates", 800, 480)`:
    - `drive-axis-control`: status=`needs-api-discovery`, safe=7, blocked=1, apiDiscovery=1, highRisk=0,
    - `equipment-overview`: status=`blocked-by-high-risk-actions`, safe=3, blocked=2, apiDiscovery=1, highRisk=1,
    - `hmi-data-export-probe`: status=`ready-for-temp-project-validation`, safe=1, blocked=0, apiDiscovery=0, highRisk=0,
    - `pid-faceplate`: status=`blocked-by-high-risk-actions`, safe=2, blocked=2, apiDiscovery=1, highRisk=1.
  - CLI `--run-hmi-template-layout-probe`: `OK: true`.
  - CLI `--run-plc-builder-offline-suite`: `OK: true`.
  - CLI `--run-online-monitoring-safety-self-test`: `PASS`, `checkedTools=122`, no Force tools exposed.

Classic/Basic HMI structured screen XML builder on 2026-05-07:

- Added offline builder:
  - `src/TiaMcpServer/ModelContextProtocol/ClassicHmiScreenXmlBuilder.cs`
  - builds a Classic/Basic WinCC `Hmi.Screen.Screen` XML document from structured JSON,
  - supports the first practical control set:
    - `Text`,
    - `Button`,
    - `IOField`,
    - `Lamp`/`Rectangle`,
  - validates screen size, item bounds, positive dimensions, and duplicate item names,
  - analyzes generated or exported Classic HMI XML for screen name, size, item count, duplicate names, warnings, and parse errors.
- Added MCP tool:
  - `BuildClassicHmiScreenXml`
  - offline-only,
  - does not connect to TIA Portal,
  - does not import a screen,
  - returns the XML plus validation analysis and safety policy.
- Current status:
  - this is a structured generation layer for Classic/Basic HMI screens,
  - import into real TIA remains gated: first validate in a temporary Classic/Basic HMI project, then read back screen/items and compile/diagnose.
- Verification:
  - `dotnet build ... -c Release`: 0 errors, existing nullable warnings only.
  - MCP static reflection call `BuildClassicHmiScreenXml(...)` with a minimal 640x480 screen:
    - `Ok=True`,
    - screen=`Classic_Minimal_Probe`,
    - size=`640x480`,
    - itemCount=`4`,
    - generated XML length=`8355`,
    - errors=`0`,
    - warnings=`0`.
  - Bad input probe with duplicate item name `Dup`:
    - rejected with `Duplicate Classic HMI item name: Dup`.
  - `ClassicHmiScreenXmlBuilder.AnalyzeFile("...\TMP_EXPORT\optimized_hmi\Screens\主画面_优化.xml")`:
    - `ok=True`,
    - screen=`主画面`,
    - size=`640x480`,
    - itemCount=`17`,
    - errors=`0`,
    - warnings=`0`.
  - CLI `--run-hmi-template-layout-probe`: `OK: true`.
  - CLI `--run-hmi-action-script-recipe-probe`: `OK: true`.
  - CLI `--run-plc-builder-offline-suite`: `OK: true`.
  - CLI `--run-online-monitoring-safety-self-test`: `PASS`, `checkedTools=123`, no Force tools exposed.

Classic/Basic HMI structured tag-table XML builder on 2026-05-07:

- Added offline builder:
  - `src/TiaMcpServer/ModelContextProtocol/ClassicHmiTagTableXmlBuilder.cs`
  - builds `Hmi.Tag.TagTable` XML from structured JSON,
  - supports plain HMI tags,
  - supports symbolic PLC binding through `Connection` + `ControllerTag`/`PlcTag`,
  - validates non-empty tag tables, duplicate tag names, and incomplete symbolic bindings.
- Added MCP tool:
  - `BuildClassicHmiTagTableXml`
  - offline-only,
  - does not connect to TIA Portal,
  - does not import tag tables,
  - returns generated XML plus table/tag/symbolic-binding analysis and safety policy.
- Current status:
  - this closes the offline structured generation gap for Classic/Basic HMI tags,
  - PLC-side symbols are still not considered verified until a temporary TIA project import/readback confirms `Connection` and `ControllerTag`.
- Verification:
  - `dotnet build ... -c Release`: 0 errors, existing nullable warnings only.
  - MCP static reflection call `BuildClassicHmiTagTableXml(...)` with plain tags:
    - `Ok=True`,
    - table=`Classic_Minimal_Tags`,
    - tagCount=`2`,
    - symbolicBindingCount=`0`,
    - errors=`0`.
  - MCP static reflection call `BuildClassicHmiTagTableXml(...)` with symbolic tags:
    - `Ok=True`,
    - table=`Classic_Symbolic_Tags`,
    - tagCount=`2`,
    - symbolicBindingCount=`2`,
    - errors=`0`.
  - Bad input probe with duplicate tag name `Dup`:
    - rejected with `Duplicate Classic HMI tag name: Dup`.
  - Reference XML structure check with PowerShell XML parser:
    - `ClassicHmiTagTable_Symbolic.xml`: table=`Motor_HMI_Tags`, tags=`5`, symbolic=`5`,
    - `ClassicHmiTagTable_Minimal.xml`: table=`Motor_HMI_Tags`, tags=`5`, symbolic=`0`.
  - CLI `--run-hmi-template-layout-probe`: `OK: true`.
  - CLI `--run-hmi-action-script-recipe-probe`: `OK: true`.
  - CLI `--run-plc-builder-offline-suite`: `OK: true`.
  - CLI `--run-online-monitoring-safety-self-test`: `PASS`, `checkedTools=124`, no Force tools exposed.

Classic/Basic HMI minimal package builder on 2026-05-07:

- Added offline package builder:
  - `src/TiaMcpServer/ModelContextProtocol/ClassicHmiMinimalPackageBuilder.cs`
  - composes Classic screen XML and Classic tag-table XML from one structured package JSON,
  - returns import order and a readiness gate,
  - checks whether screen items referencing `Tag` / `HmiTag` / `ProcessValueTag` are declared in the tag table.
- Added MCP tool:
  - `BuildClassicHmiMinimalPackage`
  - offline-only,
  - does not connect to TIA Portal,
  - does not import files,
  - does not modify projects or delivery files.
- Intended workflow:
  - build package JSON,
  - inspect `readiness` and generated XML,
  - import tag table first and screen second into a temporary Classic/Basic HMI project,
  - read back HMI tags, screen items, connections, controller tags,
  - compile/diagnose,
  - use real projects only after temporary-project validation succeeds.
- Verification:
  - `dotnet build ... -c Release`: 0 errors, existing nullable warnings only.
  - MCP static reflection call `BuildClassicHmiMinimalPackage(...)` with motor minimal package:
    - `Ok=True`,
    - package=`Classic_Motor_Minimal`,
    - screenItems=`4`,
    - tags=`3`,
    - symbolicBindingCount=`3`,
    - referencedTagCount=`3`,
    - missingTagCount=`0`,
    - unusedTagCount=`0`,
    - screenXml length=`8333`,
    - tagXml length=`3278`.
  - Bad package probe with screen item referencing undeclared `Missing_Tag`:
    - `Ok=False`,
    - readinessOk=`false`,
    - missingTagCount=`1`,
    - missingTags=`Missing_Tag`.
  - CLI `--run-hmi-template-layout-probe`: `OK: true`.
  - CLI `--run-hmi-action-script-recipe-probe`: `OK: true`.
  - CLI `--run-plc-builder-offline-suite`: `OK: true`.
  - CLI `--run-online-monitoring-safety-self-test`: `PASS`, `checkedTools=125`, no Force tools exposed.

Classic/Basic HMI control binding and button event XML generation on 2026-05-07:

- Extended `ClassicHmiScreenXmlBuilder`:
  - writes `ProcessValue` bindings with `Hmi.Dynamic.TagConnectionDynamic` for items that specify `Tag`, `HmiTag`, or `ProcessValueTag`,
  - writes button event system functions for item-local `Actions`:
    - `SetBit` / `SetBitInTag` / `set-bit` -> Classic `SetBit`,
    - `ResetBit` / `ResetBitInTag` / `reset-bit` -> Classic `ResetBit`,
    - `Press` / `Release` / `Click` event names are normalized from common action names.
  - screen XML analysis now reports:
    - `dynamicBindingCount`,
    - `eventActionCount`.
- Extended `ClassicHmiMinimalPackageBuilder` readiness:
  - action `TargetTag` references are now included in the declared-tag gate,
  - button events that reference undeclared HMI tags block the package before any temporary-project import.
- Grounding:
  - local Classic export `TMP_EXPORT\optimized_hmi\Screens\主画面_优化.xml` contains the verified shapes for:
    - `ProcessValue` + `Hmi.Dynamic.TagConnectionDynamic`,
    - `Hmi.Event.Event` + `SetBit` / `ResetBit` system functions.
- Verification:
  - `dotnet build ... -c Release`: 0 errors, existing nullable warnings only.
  - MCP static reflection call `BuildClassicHmiMinimalPackage(...)` with bindings/actions:
    - `Ok=True`,
    - readinessOk=`true`,
    - referencedTagCount=`3`,
    - missingTagCount=`0`,
    - dynamicBindingCount=`2`,
    - eventActionCount=`2`,
    - generated screen XML contains `SetBit`, `ResetBit`, and `ProcessValue`.
  - Bad package probe with button action target `Missing_Action_Tag`:
    - `Ok=False`,
    - readinessOk=`false`,
    - referencedTagCount=`1`,
    - missingTagCount=`1`,
    - missingTags=`Missing_Action_Tag`,
    - generated screen analysis still reports `eventActionCount=1`, proving the readiness gate catches event tags, not only visual bindings.
  - CLI `--run-hmi-template-layout-probe`: `OK: true`.
  - CLI `--run-hmi-action-script-recipe-probe`: `OK: true`.
  - CLI `--run-plc-builder-offline-suite`: `OK: true`.
  - CLI `--run-online-monitoring-safety-self-test`: `PASS`, `checkedTools=125`, no Force tools exposed.

Classic/Basic HMI minimal package file writer on 2026-05-07:

- Added file output support:
  - `ClassicHmiMinimalPackageBuilder.WriteFiles(...)`
  - writes a Classic HMI tag-table XML file,
  - writes a Classic HMI screen XML file,
  - writes a compact `manifest.json` with import order, readiness, analyses, file paths, and next validation steps.
- Added MCP tool:
  - `WriteClassicHmiMinimalPackageFiles`
  - offline-only,
  - writes only to the caller-provided `outputDirectory`,
  - does not connect to TIA Portal,
  - does not import files,
  - does not modify projects or delivery files.
- Purpose:
  - move Classic/Basic HMI from "XML string in response" to a reusable file bundle that can be imported into a temporary TIA project in the required order.
- Verification:
  - `dotnet build ... -c Release`: 0 errors, existing nullable warnings only.
  - MCP static reflection call `WriteClassicHmiMinimalPackageFiles(...)` to `reports\classic_hmi_minimal_package\verify_20260507_155050`:
    - `Ok=True`,
    - `fileCount=3`,
    - tag table XML exists,
    - screen XML exists,
    - manifest JSON exists,
    - tag table XML bytes=`3281`,
    - screen XML bytes=`12768`,
    - manifest bytes=`2107`,
    - XML parser readback: tag table=`Motor_HMI_Tags`, screen=`Motor_Main`, screenItems=`4`.
  - CLI `--run-hmi-template-layout-probe`: `OK: true`.
  - CLI `--run-hmi-action-script-recipe-probe`: `OK: true`.
  - CLI `--run-plc-builder-offline-suite`: `OK: true`.
  - CLI `--run-online-monitoring-safety-self-test`: `PASS`, `checkedTools=126`, no Force tools exposed.

Classic/Basic HMI minimal package file validator on 2026-05-07:

- Added offline package validation:
  - `ClassicHmiMinimalPackageBuilder.ValidateFiles(...)`
  - accepts either a package output directory or a `*_manifest.json` path,
  - reads manifest, tag-table XML, and screen XML,
  - checks required files exist,
  - reuses Classic tag-table/screen XML analyzers,
  - extracts declared HMI tags from the tag-table XML,
  - extracts screen dynamic binding tags and button event target tags from the screen XML,
  - blocks the package if any screen binding/event references an undeclared HMI tag.
- Added MCP tool:
  - `ValidateClassicHmiMinimalPackageFiles`
  - offline-only,
  - does not connect to TIA Portal,
  - does not import files,
  - does not modify projects, reference projects, or delivery files.
- Purpose:
  - make generated Classic/Basic HMI bundles self-checkable before any temporary-project import,
  - reduce the risk that an HMI control/event is visually created but bound to a missing tag.
- Verification:
  - `dotnet build ... -c Release`: 0 errors, existing nullable warnings only.
  - Focused MSTest `Test_ClassicHmiMinimalPackageFiles_ValidateGoodAndBadPackage`:
    - good package:
      - writes tag-table XML, screen XML, and manifest,
      - validates `ok=true`,
      - `declaredTagCount=3`,
      - `referencedTagCount=3`,
      - `missingTagCount=0`,
      - `dynamicBindingCount=2`,
      - `eventActionCount=2`,
    - bad package:
      - tag table renames `Speed_Set` while screen still references `Speed_Set`,
      - validates `ok=false`,
      - `missingTagCount=1`,
      - `missingTags` contains `Speed_Set`.
  - CLI `--run-hmi-template-layout-probe`: `OK: true`.
  - CLI `--run-hmi-action-script-recipe-probe`: `OK: true`.
  - CLI `--run-plc-builder-offline-suite`: `OK: true`.
  - CLI `--run-online-monitoring-safety-self-test`: `PASS`, `checkedTools=127`, no Force tools exposed.

Classic/Basic HMI minimal package CLI regression probe on 2026-05-07:

- Added CLI switch:
  - `--run-classic-hmi-minimal-package-probe`
  - optional report directory:
    - `--classic-hmi-package-report-directory <dir>`
- Probe behavior:
  - builds the verified motor minimal Classic/Basic HMI package,
  - writes tag-table XML, screen XML, and manifest under `reports/classic_hmi_minimal_package_probe`,
  - validates the good package with `ValidateFiles(...)`,
  - creates a bad package by renaming declared `Speed_Set` to `Speed_Set_Deleted`,
  - validates that the bad package is blocked because the screen still references `Speed_Set`.
- Purpose:
  - make the Classic/Basic HMI package generation and file-level validation reproducible by a single command,
  - give future delivery users a quick offline smoke test before any TIA import/readback.
- Verification:
  - `dotnet build ... -c Release`: 0 errors, existing nullable warnings only.
  - CLI `--run-classic-hmi-minimal-package-probe`:
    - report:
      - `C:\Users\XL626\Desktop\PID博途块\reports\classic_hmi_minimal_package_probe\classic_hmi_minimal_package_probe_20260507_160014.md`
      - `C:\Users\XL626\Desktop\PID博途块\reports\classic_hmi_minimal_package_probe\classic_hmi_minimal_package_probe_20260507_160014.json`
    - `OK: true`,
    - good package `missingTagCount=0`,
    - good package `dynamicBindingCount=2`,
    - good package `eventActionCount=2`,
    - bad package `missingTags=["Speed_Set"]`.
  - Focused MSTest `Test_ClassicHmiMinimalPackageFiles_ValidateGoodAndBadPackage`: passed.
  - CLI `--run-hmi-template-layout-probe`: `OK: true`.
  - CLI `--run-hmi-action-script-recipe-probe`: `OK: true`.
  - CLI `--run-plc-builder-offline-suite`: `OK: true`.
  - CLI `--run-online-monitoring-safety-self-test`: `PASS`, `checkedTools=127`, no Force tools exposed.

Classic/Basic HMI PLC-symbol synchronization gate on 2026-05-07:

- Added offline sync validation:
  - `ClassicHmiMinimalPackageBuilder.ValidateFilesWithPlcSymbols(...)`
  - reads the HMI package via `ValidateFiles(...)`,
  - extracts Classic HMI tag table `ControllerTag` bindings,
  - compares every `ControllerTag` against a caller-provided exact PLC symbol list,
  - blocks if a bound PLC symbol is missing,
  - reports unused PLC symbols as warnings.
- Added MCP tool:
  - `ValidateClassicHmiMinimalPackagePlcSync`
  - offline-only,
  - does not connect to TIA Portal,
  - does not import HMI files,
  - does not modify projects, reference projects, or delivery files.
- Extended CLI probe:
  - `--run-classic-hmi-minimal-package-probe` now validates:
    - HMI screen/control/event references to HMI tags,
    - HMI tag-table `ControllerTag` references to PLC symbols.
- Purpose:
  - enforce the rule that HMI bindings must point to real declared PLC symbols, not guessed M bits or invented DB paths,
  - provide an offline precheck before temporary-project import/readback.
- Verification:
  - `dotnet build ... -c Release`: 0 errors, existing nullable warnings only.
  - Focused MSTest `Test_ClassicHmiMinimalPackageFiles_ValidateGoodAndBadPackage`: passed.
    - good PLC symbol list:
      - `controllerTagCount=3`,
      - `missingPlcSymbolCount=0`.
    - bad PLC symbol list missing `DB1_MotorData.SpeedSet`:
      - `ok=false`,
      - `missingPlcSymbolCount=1`,
      - `missingPlcSymbols` contains `DB1_MotorData.SpeedSet`.
  - CLI `--run-classic-hmi-minimal-package-probe`:
    - report:
      - `C:\Users\XL626\Desktop\PID博途块\reports\classic_hmi_minimal_package_probe\classic_hmi_minimal_package_probe_20260507_160704.md`
      - `C:\Users\XL626\Desktop\PID博途块\reports\classic_hmi_minimal_package_probe\classic_hmi_minimal_package_probe_20260507_160704.json`
    - `OK: true`,
    - good package `missingTagCount=0`,
    - good package `dynamicBindingCount=2`,
    - good package `eventActionCount=2`,
    - good PLC sync `missingPlcSymbolCount=0`,
    - bad PLC sync `missingPlcSymbols=["DB1_MotorData.SpeedSet"]`,
    - bad HMI package `missingTags=["Speed_Set"]`.
  - CLI `--run-hmi-template-layout-probe`: `OK: true`.
  - CLI `--run-hmi-action-script-recipe-probe`: `OK: true`.
  - CLI `--run-plc-builder-offline-suite`: `OK: true`.
  - CLI `--run-online-monitoring-safety-self-test`: `PASS`, `checkedTools=128`, no Force tools exposed.

PLC symbol manifest offline extractor on 2026-05-07:

- Added offline extractor:
  - `src/TiaMcpServer/ModelContextProtocol/PlcSymbolManifestBuilder.cs`
  - reads one XML file or a directory of XML files,
  - extracts PLC tag table symbols from `SW.Tags.PlcTag`,
  - extracts GlobalDB member symbols as `DBName.Member` and nested `DBName.Member.Child`,
  - returns `symbolNames` directly consumable by `ValidateClassicHmiMinimalPackagePlcSync`.
- Added MCP tool:
  - `BuildPlcSymbolManifestFromXmlPath`
  - offline-only,
  - does not connect to TIA Portal,
  - does not import PLC/HMI objects,
  - does not modify projects, reference projects, or delivery files.
- Added CLI switch:
  - `--run-plc-symbol-manifest-probe`
  - optional report directory:
    - `--plc-symbol-manifest-report-directory <dir>`
- Extended Classic HMI CLI probe:
  - `--run-classic-hmi-minimal-package-probe` now builds a PLC symbol manifest from generated PLC XML fixtures,
  - then feeds the extracted `symbolNames` into the PLC-HMI sync gate,
  - proving the normal path no longer depends on a hand-written PLC symbol JSON list.
- Verification:
  - `dotnet build ... -c Release`: 0 errors, existing nullable warnings only.
  - Focused MSTest:
    - `Test_ClassicHmiMinimalPackageFiles_ValidateGoodAndBadPackage`: passed,
    - `Test_PlcSymbolManifestBuilder_ExtractsTagTableAndGlobalDbSymbols`: passed.
  - CLI `--run-plc-symbol-manifest-probe`:
    - report:
      - `C:\Users\XL626\Desktop\PID博途块\reports\plc_symbol_manifest\plc_symbol_manifest_probe_20260507_161057.md`
      - `C:\Users\XL626\Desktop\PID博途块\reports\plc_symbol_manifest\plc_symbol_manifest_probe_20260507_161057.json`
    - `OK: true`,
    - `symbolCount=9`,
    - extracted includes:
      - `Motor_Start`,
      - `Motor_Run`,
      - `Counter`,
      - `DB1_MotorData.Motor`,
      - `DB1_MotorData.Motor.Start`,
      - `DB1_MotorData.Motor.Run`,
      - `DB1_MotorData.SpeedSet`.
  - CLI `--run-classic-hmi-minimal-package-probe`:
    - report:
      - `C:\Users\XL626\Desktop\PID博途块\reports\classic_hmi_minimal_package_probe\classic_hmi_minimal_package_probe_20260507_161057.md`
      - `C:\Users\XL626\Desktop\PID博途块\reports\classic_hmi_minimal_package_probe\classic_hmi_minimal_package_probe_20260507_161057.json`
    - `OK: true`,
    - uses extracted PLC symbol manifest for the good sync path,
    - good PLC sync `missingPlcSymbolCount=0`,
    - bad PLC sync `missingPlcSymbols=["DB1_MotorData.SpeedSet"]`.
  - CLI `--run-hmi-template-layout-probe`: `OK: true`.
  - CLI `--run-hmi-action-script-recipe-probe`: `OK: true`.
  - CLI `--run-plc-builder-offline-suite`: `OK: true`.
  - CLI `--run-online-monitoring-safety-self-test`: `PASS`, `checkedTools=129`, no Force tools exposed.

Classic/Basic HMI offline validation suite on 2026-05-07:

- Added suite:
  - `src/TiaMcpServer/ModelContextProtocol/ClassicHmiOfflineValidationSuite.cs`
  - runs a complete offline Classic/Basic HMI acceptance chain:
    - PLC XML fixture generation,
    - PLC symbol manifest extraction,
    - Classic HMI package generation,
    - HMI tag reference validation,
    - PLC-HMI symbol sync positive case,
    - PLC-HMI symbol sync negative case,
    - HMI tag reference negative case.
- Added MCP tool:
  - `RunClassicHmiOfflineValidationSuite`
  - offline-only,
  - writes reports only to caller-provided report directory,
  - does not connect to TIA Portal,
  - does not import PLC/HMI objects,
  - does not modify projects, reference projects, or delivery files.
- Added CLI switch:
  - `--run-classic-hmi-offline-suite`
  - optional report directory:
    - `--classic-hmi-offline-suite-report-directory <dir>`
- Purpose:
  - make the Classic/Basic HMI offline chain reproducible as one command for future delivery/commercial smoke testing,
  - prevent single-feature probes from drifting apart,
  - prove both success paths and expected-blocking failure paths before any temporary TIA project import.
- Verification:
  - `dotnet build ... -c Release`: 0 errors, existing nullable warnings only.
  - Focused MSTest:
    - `Test_ClassicHmiMinimalPackageFiles_ValidateGoodAndBadPackage`: passed,
    - `Test_PlcSymbolManifestBuilder_ExtractsTagTableAndGlobalDbSymbols`: passed,
    - `Test_ClassicHmiOfflineValidationSuite_RunsPositiveAndNegativeGates`: passed.
  - CLI `--run-classic-hmi-offline-suite`:
    - report:
      - `C:\Users\XL626\Desktop\PID博途块\reports\classic_hmi_offline_suite\classic_hmi_offline_validation_suite_20260507_161543.md`
      - `C:\Users\XL626\Desktop\PID博途块\reports\classic_hmi_offline_suite\classic_hmi_offline_validation_suite_20260507_161543.json`
    - `OK: true`,
    - suite items:
      - PLC symbol manifest extraction: PASS, `symbolCount=6`,
      - Classic HMI package write: PASS, `fileCount=3`,
      - Classic HMI tag reference validation: PASS, `missingTagCount=0`,
      - PLC-HMI sync positive case: PASS, `missingPlcSymbolCount=0`,
      - PLC-HMI sync negative case: PASS, `missingPlcSymbolCount=1`,
      - HMI tag reference negative case: PASS, `missingTagCount=1`.
  - CLI `--run-classic-hmi-minimal-package-probe`: `OK: true`.
  - CLI `--run-plc-symbol-manifest-probe`: `OK: true`.
  - CLI `--run-hmi-template-layout-probe`: `OK: true`.
  - CLI `--run-hmi-action-script-recipe-probe`: `OK: true`.
  - CLI `--run-plc-builder-offline-suite`: `OK: true`.
  - CLI `--run-online-monitoring-safety-self-test`: `PASS`, `checkedTools=130`, no Force tools exposed.

Offline release validation suite on 2026-05-07:

- Added release smoke suite:
  - `src/TiaMcpServer/ModelContextProtocol/OfflineReleaseValidationSuite.cs`
  - combines currently verified offline/safety gates:
    - PLC Builder offline suite,
    - Classic/Basic HMI offline validation suite,
    - PLC symbol manifest probe,
    - Unified HMI template layout QA,
    - HMI action script recipe probe,
    - online-monitoring safety self-test.
- Added MCP tool:
  - `RunOfflineReleaseValidationSuite`
  - offline-only,
  - does not connect to TIA Portal,
  - does not open or modify projects,
  - does not import PLC/HMI objects,
  - writes reports only to the requested report directory.
- Added CLI switch:
  - `--run-offline-release-suite`
  - optional report directory:
    - `--offline-release-suite-report-directory <dir>`
- Purpose:
  - provide one reproducible smoke-test command for future delivery/commercial packaging,
  - prevent individual probes from drifting apart,
  - make "what has been verified" explicit in one Markdown/JSON report.
- Verification:
  - `dotnet build ... -c Release`: 0 errors, existing nullable warnings only.
  - CLI `--run-offline-release-suite`:
    - report:
      - `C:\Users\XL626\Desktop\PID博途块\reports\offline_release_suite\offline_release_validation_suite_20260507_162044.md`
      - `C:\Users\XL626\Desktop\PID博途块\reports\offline_release_suite\offline_release_validation_suite_20260507_162044.json`
    - `OK: true`,
    - suite items:
      - PLC Builder offline suite: PASS, `items=7`,
      - Classic HMI offline suite: PASS, `items=6`,
      - PLC symbol manifest probe: PASS, `symbolCount=9`,
      - Unified HMI template layout QA: PASS, `templateCount=4`, `failed=0`,
      - HMI action script recipe probe: PASS, `templateCount=4`, `failed=0`,
      - online-monitoring safety self-test: PASS, `items=6`.
  - Focused MSTest:
    - `Test_ClassicHmiMinimalPackageFiles_ValidateGoodAndBadPackage`: passed,
    - `Test_PlcSymbolManifestBuilder_ExtractsTagTableAndGlobalDbSymbols`: passed,
    - `Test_ClassicHmiOfflineValidationSuite_RunsPositiveAndNegativeGates`: passed.
  - CLI `--run-classic-hmi-offline-suite`: `OK: true`.
  - CLI `--run-hmi-template-layout-probe`: `OK: true`.
  - CLI `--run-hmi-action-script-recipe-probe`: `OK: true`.
  - CLI `--run-plc-builder-offline-suite`: `OK: true`.
  - CLI `--run-online-monitoring-safety-self-test`: `PASS`, `checkedTools=131`, no Force tools exposed.

## Next Implementation Targets

- Add a PLC symbol mapping layer for generic templates:
  - add deterministic mapping rules to fill the explicit mapping file,
  - support deterministic project rules for `Axis.*`, `PID.*`, and system tags,
  - require exact full-symbol sync precheck after mapping, before any HMI binding.
- Extend Unified HMI layout/theme QA:
  - keep `--run-hmi-template-layout-probe` in the release regression set,
  - fix remaining template warnings by adding `DesignSystem` to minimal probe templates and `Layout.Grid` to faceplate templates,
  - later promote validated layout metadata into `ApplyUnifiedHmiScreenDesignJson`/theme application once exact Openness properties are read back.
- Extend temporary-project HMI validation from minimal binding to mapped-template binding:
  - create/check HMI tags only after PLC symbol precheck passes,
  - apply screen items with apply failures=0,
  - bind dynamizations,
  - attach events,
  - read back screen/items/tags/events,
  - compile HMI where available.
- Add explicit event implementation for safe popup/navigation/value-stepper patterns, instead of leaving them as empty script placeholders.
- Extend the template sync precheck so it can read PLC DB members and block interfaces, not only PLC tag tables.
- Add focused nullable-warning cleanup only around newly added code paths, after functional verification remains green.

## 2026-05-07 HMI Template PLC Sync Gate

- Added suite:
  - `src/TiaMcpServer/ModelContextProtocol/HmiTemplatePlcSyncPrecheckSuite.cs`
  - offline-only Unified HMI template `RequiredTags` vs PLC XML symbol sync precheck,
  - validates exact PLC tag/GlobalDB-member existence before any HMI binding,
  - validates data type compatibility,
  - supports optional explicit mapping file,
  - includes embedded positive/negative self-test so missing PLC symbols are proven to block.
- Added MCP tool:
  - `RunHmiTemplatePlcSyncPrecheckSuite`
  - no TIA connection,
  - no project/reference/delivery-package writes,
  - report-only output.
- Added CLI switch:
  - `--run-hmi-template-plc-sync-precheck-suite`
  - optional:
    - `--hmi-template-directory <dir>`
    - `--plc-export-directory <xml-or-dir>`
    - `--hmi-template-plc-sync-precheck-report-directory <dir>`
    - `--hmi-template-mapping-path <json>`
- Integrated into release smoke suite:
  - `OfflineReleaseValidationSuite` now includes `hmi-template-plc-sync-precheck`.
- Safety effect:
  - templates can still be analyzed for layout/visual design when blocked,
  - but HMI tag creation, dynamization binding, and event writes must not proceed unless the precheck is ready and later temporary-project validation passes.
- Verification:
  - `dotnet build ... -c Release`: passed, 0 errors, existing nullable warnings only.
  - Focused MSTest:
    - `Test_HmiTemplatePlcSyncPrecheckSuite_BlocksMissingPlcSymbols`: passed.
    - Existing Classic HMI/PLC symbol tests plus new sync test: 4 passed.
  - CLI `--run-hmi-template-plc-sync-precheck-suite`:
    - report:
      - `C:\Users\XL626\Desktop\PID博途块\reports\hmi_template_plc_sync_precheck\hmi_template_plc_sync_precheck_20260507_164447.md`
      - `C:\Users\XL626\Desktop\PID博途块\reports\hmi_template_plc_sync_precheck\hmi_template_plc_sync_precheck_20260507_164447.json`
    - `OK: true`.
  - CLI `--run-offline-release-suite`:
    - report:
      - `C:\Users\XL626\Desktop\PID博途块\reports\offline_release_suite\offline_release_validation_suite_20260507_164500.md`
      - `C:\Users\XL626\Desktop\PID博途块\reports\offline_release_suite\offline_release_validation_suite_20260507_164500.json`
    - `OK: true`.

## 2026-05-07 HMI Action Recipe Safety Gate

- Enhanced action recipe builder:
  - `src/TiaMcpServer/ModelContextProtocol/HmiActionScriptRecipeBuilder.cs`
  - deterministic direct-apply candidates remain limited to:
    - `set-bit`,
    - `reset-bit`,
    - `toggle-bit`.
  - high-risk write recipes are generated only as blocked recipes:
    - `set-value`,
    - `confirm-write`.
  - navigation/popup recipes remain blocked until exact WinCC Unified V21 API shape is discovered and read back:
    - `goto-screen`,
    - `open-popup`.
- Added safety self-test:
  - proves safe bit operations generate usable scripts,
  - proves missing target tags are not safe apply candidates,
  - proves high-risk writes are blocked,
  - proves navigation/popup actions are API-discovery-blocked.
- Added MCP tool:
  - `RunHmiActionScriptRecipeSafetySelfTest`
  - offline-only, no TIA connection, no project/template/delivery-package writes.
- Added CLI switch:
  - `--run-hmi-action-script-recipe-safety-self-test`
- Probe report now includes:
  - `applyBlockedCount`,
  - `safeDeterministicApplyCandidateCount`,
  - embedded `safetySelfTest`.
- Verification:
  - `dotnet build ... -c Release`: passed, 0 errors, existing nullable warnings only.
  - Focused MSTest:
    - `Test_HmiActionScriptRecipeBuilder_SafetySelfTestBlocksRiskyActions`: passed.
  - Focused regression MSTest set:
    - Classic HMI package validation,
    - PLC symbol manifest,
    - Classic HMI offline suite,
    - HMI template PLC sync gate,
    - HMI action recipe safety gate,
    - result: 5 passed.
  - CLI `--run-hmi-action-script-recipe-safety-self-test`:
    - `OK: true`,
    - cases=8,
    - `set-bit/reset-bit/toggle-bit` safe apply true,
    - `confirm-write/set-value/goto-screen/open-popup` safe apply false.
  - CLI `--run-hmi-action-script-recipe-probe`:
    - report:
      - `C:\Users\XL626\Desktop\PID博途块\reports\hmi_action_script_recipe\hmi_action_script_recipe_probe_20260507_165113.md`
      - `C:\Users\XL626\Desktop\PID博途块\reports\hmi_action_script_recipe\hmi_action_script_recipe_probe_20260507_165113.json`
    - `OK: true`.
  - CLI `--run-offline-release-suite`:
    - report:
      - `C:\Users\XL626\Desktop\PID博途块\reports\offline_release_suite\offline_release_validation_suite_20260507_165122.md`
      - `C:\Users\XL626\Desktop\PID博途块\reports\offline_release_suite\offline_release_validation_suite_20260507_165122.json`
    - `OK: true`.

## 2026-05-07 Release Diagnostics And Error Report

- Added release diagnostic builder:
  - `src/TiaMcpServer/ModelContextProtocol/ReleaseDiagnosticReportBuilder.cs`
  - converts an offline release suite result into a commercial/debug-friendly diagnostic report.
- Diagnostic report contains:
  - suite summary,
  - pass/fail item counts,
  - report index for every child suite,
  - failed item list,
  - collected error/warning/missing/blocked/mismatch signals,
  - safety redlines,
  - recommended next actions.
- Integrated diagnostics into:
  - `OfflineReleaseValidationSuite`
  - every `--run-offline-release-suite` run now emits:
    - `offline_release_validation_suite_*.md/json`,
    - `offline_release_diagnostics_*.md/json`.
- Added MCP tool:
  - `BuildReleaseDiagnosticReport`
  - builds diagnostics from an existing offline release suite JSON report,
  - offline-only, no TIA connection and no project write.
- Verification:
  - `dotnet build ... -c Release`: passed, 0 errors, existing nullable warnings only.
  - Focused MSTest:
    - `Test_ReleaseDiagnosticReportBuilder_SummarizesFailuresAndSignals`: passed.
  - Focused regression MSTest set:
    - Classic HMI package validation,
    - PLC symbol manifest,
    - Classic HMI offline suite,
    - HMI template PLC sync gate,
    - HMI action recipe safety gate,
    - release diagnostics,
    - result: 6 passed.
  - CLI `--run-offline-release-suite`:
    - main report:
      - `C:\Users\XL626\Desktop\PID博途块\reports\offline_release_suite\offline_release_validation_suite_20260507_165435.md`
      - `C:\Users\XL626\Desktop\PID博途块\reports\offline_release_suite\offline_release_validation_suite_20260507_165435.json`
    - diagnostic report:
      - `C:\Users\XL626\Desktop\PID博途块\reports\offline_release_suite\offline_release_diagnostics_20260507_165435.md`
      - `C:\Users\XL626\Desktop\PID博途块\reports\offline_release_suite\offline_release_diagnostics_20260507_165435.json`
    - `OK: true`,
    - diagnostics summary:
      - items=8,
      - passed=8,
      - failed=0,
      - blocking signals retained for expected next-stage work:
        - HMI template PLC mapping still needs explicit real-symbol mapping,
        - Unified navigation/popup API still requires temporary-project discovery/readback.

## 2026-05-07 Release Runbook For First-Time Handoff

- Added release runbook builder:
  - `src/TiaMcpServer/ModelContextProtocol/ReleaseRunbookBuilder.cs`
  - creates a first-user/first-agent runbook from the release suite and diagnostics.
- Runbook includes:
  - purpose and starting point,
  - main report and diagnostic report links,
  - quick PowerShell commands,
  - handoff checklist,
  - safety redlines,
  - current known blocks,
  - next actions.
- Integrated into:
  - `OfflineReleaseValidationSuite`
  - every `--run-offline-release-suite` run now emits:
    - `offline_release_validation_suite_*.md/json`,
    - `offline_release_diagnostics_*.md/json`,
    - `offline_release_runbook_*.md/json`.
- Added MCP tool:
  - `BuildReleaseRunbook`
  - builds a runbook from an existing offline release suite JSON report,
  - offline-only, no TIA connection and no project write.
- Verification:
  - `dotnet build ... -c Release`: passed.
  - Focused MSTest:
    - `Test_ReleaseRunbookBuilder_ContainsQuickStartAndSafetyRedlines`: passed.
  - Focused regression MSTest set:
    - Classic HMI package validation,
    - PLC symbol manifest,
    - Classic HMI offline suite,
    - HMI template PLC sync gate,
    - HMI action recipe safety gate,
    - release diagnostics,
    - release runbook,
    - result: 7 passed.
  - CLI `--run-offline-release-suite`:
    - main report:
      - `C:\Users\XL626\Desktop\PID博途块\reports\offline_release_suite\offline_release_validation_suite_20260507_172730.md`
      - `C:\Users\XL626\Desktop\PID博途块\reports\offline_release_suite\offline_release_validation_suite_20260507_172730.json`
    - diagnostic report:
      - `C:\Users\XL626\Desktop\PID博途块\reports\offline_release_suite\offline_release_diagnostics_20260507_172730.md`
      - `C:\Users\XL626\Desktop\PID博途块\reports\offline_release_suite\offline_release_diagnostics_20260507_172730.json`
    - runbook:
      - `C:\Users\XL626\Desktop\PID博途块\reports\offline_release_suite\offline_release_runbook_20260507_172730.md`
      - `C:\Users\XL626\Desktop\PID博途块\reports\offline_release_suite\offline_release_runbook_20260507_172730.json`
    - `OK: true`.

## 2026-05-07 Commercial Release Manifest

- Added release manifest builder:
  - `src/TiaMcpServer/ModelContextProtocol/ReleaseManifestBuilder.cs`
  - creates a machine-readable and human-readable release manifest from release suite, diagnostics, and runbook.
- Manifest includes:
  - suite status,
  - commercial readiness flag and reason,
  - links to main/diagnostic/runbook reports,
  - verified capability list,
  - known blocks,
  - safety redlines,
  - required gates before delivery package sync,
  - quick start commands.
- Integrated into:
  - `OfflineReleaseValidationSuite`
  - every `--run-offline-release-suite` run now emits:
    - `offline_release_validation_suite_*.md/json`,
    - `offline_release_diagnostics_*.md/json`,
    - `offline_release_runbook_*.md/json`,
    - `offline_release_manifest_*.md/json`.
- Added MCP tool:
  - `BuildReleaseManifest`
  - builds a manifest from an existing offline release suite JSON report,
  - offline-only, no TIA connection and no project write.
- Verification:
  - `dotnet build ... -c Release`: passed, 0 errors, existing nullable warnings only.
  - Focused MSTest:
    - `Test_ReleaseManifestBuilder_MarksKnownBlocksNotCommercialReady`: passed.
  - Focused regression MSTest set:
    - Classic HMI package validation,
    - PLC symbol manifest,
    - Classic HMI offline suite,
    - HMI template PLC sync gate,
    - HMI action recipe safety gate,
    - release diagnostics,
    - release runbook,
    - release manifest,
    - result: 8 passed.
  - CLI `--run-offline-release-suite`:
    - main report:
      - `C:\Users\XL626\Desktop\PID博途块\reports\offline_release_suite\offline_release_validation_suite_20260507_180115.md`
      - `C:\Users\XL626\Desktop\PID博途块\reports\offline_release_suite\offline_release_validation_suite_20260507_180115.json`
    - diagnostic report:
      - `C:\Users\XL626\Desktop\PID博途块\reports\offline_release_suite\offline_release_diagnostics_20260507_180115.md`
      - `C:\Users\XL626\Desktop\PID博途块\reports\offline_release_suite\offline_release_diagnostics_20260507_180115.json`
    - runbook:
      - `C:\Users\XL626\Desktop\PID博途块\reports\offline_release_suite\offline_release_runbook_20260507_180115.md`
      - `C:\Users\XL626\Desktop\PID博途块\reports\offline_release_suite\offline_release_runbook_20260507_180115.json`
    - manifest:
      - `C:\Users\XL626\Desktop\PID博途块\reports\offline_release_suite\offline_release_manifest_20260507_180115.md`
      - `C:\Users\XL626\Desktop\PID博途块\reports\offline_release_suite\offline_release_manifest_20260507_180115.json`
    - `OK: true`,
    - `commercialReady=false` by design because expected blocking signals remain:
      - HMI template PLC mapping needs explicit real-symbol mapping,
      - Unified navigation/popup API requires temporary-project discovery/readback.
