# Online Monitoring Safety Policy

Document id: `online-monitoring-safety`

This MCP server treats online PLC monitoring as a read-only diagnostic workflow.

## Hard Rules

- Online monitoring may read the current state/value of known PLC variables only.
- Online monitoring must not create, delete, import, export, or modify watch-table objects while the PLC/project is online.
- Force-table and force-related operations are not exposed as MCP tools.
- Force-related services and methods are blocked through the generic reflection bridge.
- Any future online-current-value tool must prove read-only behavior in a sacrificial project before being documented as supported.

## Current Implementation State

- `GetPlcWatchTables` lists watch/monitor tables by read-only inspection.
- `ExportPlcWatchTable` and `ExportPlcWatchTablesToDirectory` export existing watch tables for offline analysis.
- `ProbePlcMonitorOnlineCapabilities` only probes read-only API surfaces. It does not go online/offline, modify watch tables, write PLC values, or touch force-table APIs.
- `PlanOnlineReadOnlyMonitoring` validates a future current-value monitoring request without connecting to TIA Portal. It accepts only symbolic PLC paths such as `DB_HMI.MotorRun`, rejects guessed absolute `M/I/Q` addresses, and rejects write/force/watch-table edit intent.
- `RunOnlineMonitoringSafetySelfTest` is a static safety self-test. It does not connect to TIA Portal or open projects. It checks exposed MCP tool names, required read-only monitoring tools, and reflection hard-deny behavior.
- `GenerateAcceptanceReport` includes the online-monitoring safety self-test so deployment reports show both environment readiness and safety guard status.
- `InvokeObject` and `InvokeService` reject force-related calls and reject mutating methods on online/watch/monitor surfaces.
- Dedicated force-table MCP tools are intentionally absent.

## Verification Checklist

Run these checks after any change touching monitoring, online APIs, reflection, or PLC table APIs:

```powershell
$Workspace = "<workspace-root>"
dotnet build "$Workspace\tools\tiaportal-mcp\src\TiaMcpServer\TiaMcpServer.csproj" -c Release

& "$Workspace\tools\tiaportal-mcp\src\TiaMcpServer\bin\Release\net48\TiaMcpServer.exe" `
  --run-online-monitoring-safety-self-test

$path = "$Workspace\tools\tiaportal-mcp\src\TiaMcpServer\ModelContextProtocol\McpServer.cs"
$matches = Select-String -LiteralPath $path -Pattern 'McpServerTool\(Name = "([^"]+)"' -AllMatches
$names = foreach ($m in $matches) { foreach ($x in $m.Matches) { $x.Groups[1].Value } }
$names | Where-Object { $_ -match 'Force' }

dotnet test "$Workspace\tools\tiaportal-mcp\tests\TiaMcpServer.Test\TiaMcpServer.Test.csproj" `
  --filter "FullyQualifiedName~TestOnlineMonitoringSafety"
```

Expected:

- Build exits with 0 errors.
- Safety self-test returns `Ok=true`.
- The tool-name scan returns no names.
- Reflection bridge blocks force-related services/methods and mutating online/watch/monitor methods.
- The online monitoring safety tests pass, including `PlanOnlineReadOnlyMonitoring` rejecting `M0.0`, force intent, and write intent.

## Future Online Current-Value Tool Requirements

Before adding a current-value monitor tool:

- Resolve PLC variable/tag paths from project readback, never from guessed names.
- Use a read-only Openness/online API only.
- Reject every write-like method name: `Set`, `Write`, `Create`, `Delete`, `Remove`, `Import`, `Add`, `Insert`, `Update`, `Modify`, `GoOnline`, `GoOffline`, `Download`, `Activate`, `Start`, `Stop`.
- Verify on a sacrificial project with at least Bool, Int, Real, and DB member variables.
- Save Markdown/JSON evidence with the exact project name, PLC path, variable list, read method, and no-write proof.
