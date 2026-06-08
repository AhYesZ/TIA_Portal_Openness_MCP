# TIA-Portal MCP-Server

A MCP server which connects to Siemens TIA Portal.

## Features

- Connect to a TIA Portal instance and manage projects (create, open, save, close)
- Full hardware configuration: add PLCs/HMI panels, configure PROFINET subnets
- PLC software: create/import/export FB/FC/GlobalDB/UDT/tag tables, compile and diagnose
- WinCC Unified HMI: screens, tags, connections, controls, dynamization, button scripts
- Classic/Basic WinCC HMI: screens, tag tables, import/export
- Online operations: connect/disconnect, download to CPU, compare offline-vs-online, read-only watch-table monitoring; password-protected CPUs supported via the `password` parameter on `GoOnline` / `DownloadToPlc`
- Offline builders: generate PLC XML and HMI JSON without a TIA Portal connection
- 180 MCP tools — use natural language to describe what you want

## Stable Project Generation Mode

For public GitHub users, prefer this stable path instead of composing many low-level tools by hand:

1. Build PLC declarations and simple FC/FB logic with `PlcBuildAndImport(dryRun=true)`.
2. Check `CapabilityDecision`, `CapabilityWarnings`, and `RecommendedNextActions`. If the response says `external-scl-recommended`, generate native SCL/SIMATIC document source instead of forcing the narrow XML DSL.
3. Import only after dry-run review, then require `CompileAndDiagnosePlc` with `Errors=0`.
4. Build Unified HMI screens with `ApplyUnifiedHmiScreenDesignJson(strict=true)`. Unsupported properties now fail closed instead of returning a false success.
5. HMI tags must read back as `SymbolicVerified` or `AbsoluteVerified`. Internal-only or unverified HMI tags are rejected by the stable path. Keep `EnsureUnifiedHmiTag(requireVerifiedBinding=true)` for generated user projects; set it to `false` only for intentional internal HMI-only validation/probe tags.

This mode intentionally favors a smaller verified feature set over best-effort output. It is designed to avoid the common user-facing failures: PLC blocks that import but fail compile, ugly HMI screens caused by unsupported style properties, wrong HMI tag bindings, and driver/link settings that cannot be read back.

## Natural-Language Automation

See [`docs/TIA_NL_INTENT_RECIPES.md`](docs/TIA_NL_INTENT_RECIPES.md) for 12 ready-to-use recipes mapping natural-language requests to exact tool sequences.

## Tools Reference

- [`docs/tool-capability-matrix.md`](docs/tool-capability-matrix.md) — per-tool online/offline, TIA version, and idempotency reference
- [`docs/error-model.md`](docs/error-model.md) — error codes and handling patterns
- [`docs/natural-language-automation.md`](docs/natural-language-automation.md) — readiness rules for NL workflows
- [`docs/openness-limitations.md`](docs/openness-limitations.md) — what TIA Openness PublicAPI cannot do (CPU RUN/STOP, fault buffer, ClearForces, …) and which capabilities require OPC UA
- [`docs/quickstart.md`](docs/quickstart.md) — **5-minute setup**: prerequisites → build → wire into Claude Desktop / VS Code MCP / HTTP → first sanity check

## Requirements

- __.net Framework 4.8__ installed
- __Siemens TIA Portal__ installed and running on your machine (V21 by default; V18/V19/V20 supported via `--tia-major-version`)
- The user environment variable `TiaPortalLocation` must point at your install root (e.g. `D:\app\TIA21\Portal V21` or `C:\Program Files\Siemens\Automation\Portal V20`)
- User must be in Windows User Group `Siemens TIA Openness`

## TIA-Portal Versions

- __V21__ is the default version.
- Previous versions (V18/V19/V20) are also supported, but must use the `--tia-major-version` argument to specify the version.
- Export as documents (.s7dcl/.s7res) via `ExportAsDocuments`/`ExportBlocksAsDocuments` requires TIA Portal V20 or newer.
- Import from documents (.s7dcl/.s7res) via `ImportFromDocuments`/`ImportBlocksFromDocuments` also requires TIA Portal V20 or newer.

### Which build do I run? (V20 vs V21 — read this first)

TIA **V21 split `Siemens.Engineering.dll` into multiple assemblies** (`.Base`/`.Step7`/`.WinCC`/…),
while V20 is monolithic. A single exe **cannot** target both — the IL is hard-bound to a
specific assembly identity. So there are **two separate binaries**:

| Your TIA Portal | Run this exe | Extra arg |
|---|---|---|
| V21 | `src/TiaMcpServer/bin/Release/net48/TiaMcpServer.exe` | _(none — V21 is default)_ |
| V20 | `src/TiaMcpServer/bin-v20/Release/net48/TiaMcpServer.exe` | `--tia-major-version 20` |
| V18 / V19 | V21-line exe is best-effort | `--tia-major-version 18` (or 19) |

Pointing the V21 exe at a V20 portal (or vice-versa) fails to attach, or imports error with
`The engineering version 'V21' ... is not supported`. Build the V20 exe with
`dotnet build src/TiaMcpServer/TiaMcpServer.V20.csproj -c Release`. If you switch between the
two csproj in the same checkout, delete `obj/` and `obj-v20/` first to avoid duplicate-attribute
build errors.

## Known Limitations

- As of 2025-09-02: Importing Ladder (LAD) blocks from SIMATIC SD documents requires the companion `.s7res` file to contain en-US tags for all items; otherwise import may fail. This is a known limitation/bug in TIA Portal Openness.
 - `ExportBlock` requires a fully qualified `blockPath` like `Group/Subgroup/Name`. If only a name is provided, the MCP server returns `InvalidParams` and may include suggestions for likely full paths.

## Testing

- See `tests/TiaMcpServer.Test/README.md` for environment prerequisites and test asset setup.
- Standard command: `dotnet test` (run from the repo root).
- Test execution policy: offer to run tests, but only execute after explicit user confirmation. Details in `AGENTS.md`.

## Contributing

- See `agents.md` for guidance on working with agentic assistants and the test execution policy (offer to run tests only with explicit user confirmation).

## Error Handling (ExportBlock)

- The Portal layer throws `PortalException` with a short message and `PortalErrorCode` (e.g., NotFound, ExportFailed), and attaches `softwarePath`, `blockPath`, `exportPath` in `Exception.Data` while preserving `InnerException` on export failures.
- The MCP layer maps these to `McpException` codes. For `ExportFailed`, it includes a concise reason from the underlying error; for `NotFound`, it returns `InvalidParams` and may suggest likely full block paths if a bare name was provided.
- Consistency required: TIA Portal never exports inconsistent blocks/types. Single export returns `InvalidParams` with a message to compile first. Bulk export skips inconsistent items and returns them in an `Inconsistent` list alongside `Items`.
- Standardization: Exception context metadata is attached in a single catch per portal method right before rethrow, not at inline throw sites. See `docs/error-model.md`.
- This standardized pattern currently applies to `ExportBlock` and will expand incrementally.

## CLI Options

| Flag | Type | Default | Description |
|---|---|---|---|
| `--tia-major-version <int>` | int | 21 | TIA Portal major version (e.g. 18, 19, 20, 21) |
| `--logging <0\|1\|2\|3>` | int | `1` (stderr) | 0 = silent, 1 = stderr, 2 = Debug output, 3 = Windows Event Log |
| `--transport <stdio\|http>` | string | `stdio` | MCP transport mode |
| `--http-prefix <url>` | string | `http://127.0.0.1:8765/` | HTTP listener URL (only with `--transport http`) |
| `--http-api-key <secret>` | string | _(none)_ | Optional `X-API-Key` header guard for HTTP transport |

## Build and Run

```bash
# Build
dotnet build src/TiaMcpServer/TiaMcpServer.csproj --configuration Release

# Run (stdio transport, default)
dotnet run --project src/TiaMcpServer/TiaMcpServer.csproj

# Run (HTTP transport)
dotnet run --project src/TiaMcpServer/TiaMcpServer.csproj -- --transport http --http-prefix http://127.0.0.1:8765/ --http-api-key mysecret

# Or run the compiled exe directly
.\src\TiaMcpServer\bin\Release\net48\TiaMcpServer.exe --transport http --http-prefix http://127.0.0.1:8765/
```

## Transports

### stdio (default)
The server reads JSON-RPC from stdin and writes responses to stdout.
Logs **must** go to stderr (`--logging 1`) to avoid corrupting the JSON-RPC stream.

```json
{
  "command": "TiaMcpServer.exe",
  "args": []
}
```

### HTTP
Listens on an `HttpListener` endpoint. Each `POST /mcp` carries one JSON-RPC message and receives one JSON-RPC response; notifications (no `id`) return HTTP 202. A new `Mcp-Session-Id` is issued on the first request and echoed back on subsequent ones; uses `WithStreamServerTransport` internally so session state (open project, connected portal) persists across requests. `GET /mcp/health` is an unauthenticated liveness probe; `DELETE /mcp` terminates a session. If the MCP host fails to produce a response within 30s, the call returns **504** instead of hanging.

> Fixed in v0.0.31: the request body and the internal HTTP↔MCP pipe are now read/written synchronously. The previous async path hung on the .NET Framework `HttpListener` input stream, so every `POST /mcp` blocked indefinitely.

```bash
# Start HTTP server
TiaMcpServer.exe --transport http --http-prefix http://127.0.0.1:8765/ --http-api-key mysecret

# Example request (curl)
curl -s -X POST http://127.0.0.1:8765/mcp \
  -H "Content-Type: application/json" \
  -H "X-API-Key: mysecret" \
  -d '{"jsonrpc":"2.0","id":1,"method":"tools/list","params":{}}'
```

Security note: bind to `127.0.0.1` for local-only access. If exposing on a network interface, always set `--http-api-key`.

Implemented: single-shot SSE responses (`Accept: text/event-stream`), `Mcp-Session-Id` issuance/correlation, `MCP-Protocol-Version` capture. Remaining follow-up: full MCP Streamable HTTP spec alignment (server-initiated `GET /mcp` SSE stream, `Origin` validation, protocol-version enforcement).

## Copilot Chat

- Example mcp.json, when using VS Code extension [TIA-Portal MCP-Server](https://marketplace.visualstudio.com/items?itemName=JHeilingbrunner.vscode-tiaportal-mcp) and TIA-Portal V18
  ```json
  {
      "servers": {
          "vscode-tiaportal-mcp": {
          "command": "c:\\Users\\<user>\\.vscode\\extensions\\jheilingbrunner.vscode-tiaportal-mcp-<version>\\srv\\net48\\TiaMcpServer.exe",
          "args": [
              "--tia-major-version",
              "18"
          ],
          "env": {}
          }
      }
  }
  ```

## Claude Desktop

- Create/Edit to add/remove server to `C:\Users\<user>\AppData\Roaming\Claude\claude_desktop_config.json`:

  ```json
  {
    "mcpServers": {
      "vscode-tiaportal-mcp": {
        "command": "<path-to>\\TiaMcpServer.exe",
        "args": [],
        "env": {}
      }
    }
  }
  ```
