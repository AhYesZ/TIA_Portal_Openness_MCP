# Natural-Language Automation Readiness

This MCP server is intended to let an agent operate TIA Portal from natural-language requests. The server supplies tools; the skills decide routing and safety.

Primary project-level references:

- `docs/TIA_NL_INTENT_RECIPES.md` — natural-language → tool sequence recipes (12 scenarios)
- `docs/tool-capability-matrix.md` — per-tool online/offline/version/idempotency reference
- `docs/error-model.md` — error codes and handling patterns

## Readiness Rule

A natural-language workflow is product-ready only when it has:

1. A clear intent recipe.
2. A deterministic MCP sequence.
3. A readback step.
4. PLC compile or HMI/API validation.
5. Diagnostics for expected failure cases.
6. A note in the skill or acceptance matrix that says whether it is verified, observed, manual-derived, or probe-required.

## Existing CLI Probes

The server has several CLI probes that can support end-to-end validation:

```text
--run-flowlight-test
--fix-current-flow-binding
--probe-s7-1200-device
--add-1511c-current
--validate-plc-scl-syntax
--search-gsd <keyword>
```

Use with TIA V21:

```powershell
tools\tiaportal-mcp\dist\TiaMcpServer-net48\TiaMcpServer.exe --tia-major-version 21 --run-flowlight-test
```

These probes are not substitutes for skill rules. When a probe succeeds, copy the exact outcome into the skill/acceptance matrix.

## Probe Concurrency

Standalone CLI probes and a running Cursor MCP server both talk to TIA Portal. Avoid running them at the same time for write-capable operations.

Observed diagnostic pattern:

```text
TIA Openness API initialized
Siemens TIA Openness group membership: True
Search installed GSD/catalog devices: keyword=...
```

If the process then hangs at connection time, the likely problem is session contention or TIA connection state, not a failed GSD search. Stop only the probe process you launched, then use the active MCP server or restart MCP cleanly.

## Next Probe Candidates

- Full new project generation with PLC + Unified HMI + readback.
- Third-party GSD insertion for AFM60A, ATV320, and DL100.
- SCL instruction batches for timers, counters, math, word operations, and scaling.
- HMI JSON templates for equipment overview, PID faceplate, drive/axis control, alarm page, and parameter page.
