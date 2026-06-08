# Quick Start — TIA Portal MCP Server

Get from zero to "AI controls your TIA project" in about 5 minutes.

---

## 1. Prerequisites (one-time setup)

- **Windows** with .NET Framework **4.8** installed
- **Siemens TIA Portal** installed (V21 by default; V18/V19/V20 also supported)
- Your Windows user must be a member of the **`Siemens TIA Openness`** local group
  - Check: `whoami /groups | findstr Openness`
  - If missing: open `lusrmgr.msc` → Groups → Siemens TIA Openness → Add → your user → log off / log on
- Set the user environment variable `TiaPortalLocation` to your TIA install root, for example:
  - `D:\app\TIA21\Portal V21`
  - `C:\Program Files\Siemens\Automation\Portal V20`

---

## 2. Build the server

```powershell
cd <repo-root>
dotnet build src\TiaMcpServer\TiaMcpServer.csproj --configuration Release
```

This produces `src\TiaMcpServer\bin\Release\net48\TiaMcpServer.exe`. Note this absolute path — you'll plug it into your AI client config below.

---

## 3. Wire it into your AI client

Pick one of the two transports.

### A. Claude Desktop / VS Code MCP (stdio, recommended for personal use)

Edit `%APPDATA%\Claude\claude_desktop_config.json` (Claude Desktop) or your VS Code MCP config:

```json
{
  "mcpServers": {
    "tia-portal": {
      "command": "C:\\path\\to\\src\\TiaMcpServer\\bin\\Release\\net48\\TiaMcpServer.exe",
      "args": [],
      "env": {}
    }
  }
}
```

Restart the AI client. Logs go to stderr by default — visible in the client's MCP log pane.

### B. HTTP transport (any client that speaks JSON-RPC over HTTP)

```powershell
TiaMcpServer.exe --transport http --http-prefix http://127.0.0.1:8765/ --http-api-key mysecret
```

Then have your client POST to `http://127.0.0.1:8765/mcp` with header `X-API-Key: mysecret`. Body is one JSON-RPC message per request.

---

## 4. First sanity check

In your AI client, ask the model:

> "Run `RunCapabilitySelfTest` and report the result."

You should get back a structured response confirming:
- Openness group membership: OK
- TIA Portal processes detected
- Read-only checks pass

If anything fails, the response message points at the missing prerequisite.

---

## 5. First real workflow

With TIA Portal already open and a project loaded:

> "Connect to TIA Portal, attach to the open project, get the project tree, and tell me how many PLCs are in it."

The AI will run, in order: `Connect` → `AttachToOpenProject` → `GetProjectTree` → parse the result. You'll get a Markdown summary of the device hierarchy.

---

## What can it do?

180 tools across these categories. See [`tool-capability-matrix.md`](tool-capability-matrix.md) for the full list with online/offline requirements.

| Category | Examples |
|---|---|
| **Portal & Project** | Connect, OpenProject, SaveProject, GetProjectTree |
| **Hardware** | GetDevices, AddDevice, ConnectDeviceNodesToProfinetSubnet |
| **PLC Software** | GetBlocks, ExportBlock, ImportBlock, CompileSoftware |
| **PLC Builders (offline)** | BuildPlcUdtXml, BuildPlcTagTableXml, ComposePlcFcBlockXml |
| **HMI Unified** | EnsureUnifiedHmiScreen, ApplyUnifiedHmiTheme |
| **HMI Classic** | BuildClassicHmiScreenXml, BuildClassicHmiMinimalPackage |
| **Online ops** | GoOnline, DownloadToPlc, CompareSoftwareToOnline |
| **Diagnostics** | RunCapabilitySelfTest, GenerateAcceptanceReport |

For natural-language workflow recipes see [`TIA_NL_INTENT_RECIPES.md`](TIA_NL_INTENT_RECIPES.md).

---

## What it cannot do (by design)

These are unsupported by the TIA Openness PublicAPI; using OPC UA is the supported path:

- Read CPU operating mode (RUN/STOP/STARTUP)
- Change CPU operating mode (Run/Stop commands)
- Read fault buffer / diagnostic history
- Clear all forces / unforce single variables

See [`openness-limitations.md`](openness-limitations.md) for the full boundary list.

---

## Troubleshooting

| Symptom | Likely cause | Fix |
|---|---|---|
| `Connect` returns `LastConnectError = "TIA Portal not running"` | TIA Portal not started | Open TIA Portal manually first |
| Connect attaches but `GetProjectTree` is empty | Attached to a TIA instance with no open project | Use `ListPortalProcessProjects` to see all running instances and `AttachToOpenProject` to pick the right one |
| `GetOnlineState` says `Offline` but TIA UI shows online | OnlineProvider service resolution issue (fixed in v0.0.27) | Make sure you're on v0.0.27+ |
| Download fails with `Protected` | CPU has access password configured | Pass `password` parameter to `DownloadToPlc` |
| Tool fails with `not in Openness group` | User not in Windows Siemens TIA Openness group | Re-check step 1, log off / on after adding |
| Server starts but no logs | `--logging 0` or earlier version with silent default | Don't pass `--logging` (default is 1=stderr) or pass `--logging 1` explicitly |
| Chinese comments / block names import as `乱码` (mojibake) | Block/type XML written as UTF-8 **without BOM** | Fixed in current builds (`Portal.cs::PrepareXmlForImport` re-emits with BOM on import). On older builds, save the XML/`.s7dcl`/`.s7res` as **UTF-8 with BOM** |
| Import fails: `The engineering version 'V21' ... is not supported` | Running the V21 build (or V21-hardcoded XML) against a **V20** portal | Use the **V20 exe** (`bin-v20/Release/...`) and pass `--tia-major-version 20`; current builds also auto-rewrite the version on import |
| Ladder (LAD) import errors / `UId 属性无效` | Hand-written FlgNet XML for contacts/coils (no tool builds those) | Author ladder as **S7DCL** (`.s7dcl` + `.s7res`) and import with `ImportBlocksFromScl` — see SKILL §9a. If a LAD `.s7res` fails, add `en-US:` tags beside `zh-CN:` |
| Wrong exe / version mismatch on a machine with both TIA versions | V20 and V21 are **separate binaries** (IL-bound to different Siemens assemblies) | Point your MCP client at `bin/Release/...` for V21, `bin-v20/Release/...` for V20 — they cannot be swapped |

For deeper issues: see [`error-model.md`](error-model.md) and [`project-status.md`](project-status.md).
