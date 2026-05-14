# Minimal SICAR-Style HMI Template

This package contains a second WinCC Unified screen set for projects that need a cleaner industrial HMI than the compact basic templates.

## Files

| File | Purpose |
|---|---|
| `templates/hmi/theme_minimal_sicar_tokens.json` | Color, spacing, and layout tokens. |
| `templates/hmi/unified_minimal_sicar_page_set.json` | Six-screen page set: `Overview`, `Operation`, `Parameters`, `Trend`, `Diagnostics`, `Events`. |
| `templates/hmi/hmi_minimal_sicar_bindings.json` | Matching HMI tags, button actions, and dynamization bindings. |

## Style

The template follows the structure of a standard industrial HMI:

- Fixed dark header with runtime and connection status.
- Stable left navigation rail.
- Status and operation-mode cards.
- Faceplate-like value, command, counter, and limit panels.
- Operation rows with command and feedback columns.
- Alarm/event band visible from overview and event pages.

The template uses only the supported basic JSON item types: `Rectangle`, `Text`, `Button`, and `IOField`.

## Use

1. Create and compile PLC objects first, including `DB_HMI_Interface` with standard access and DB number `200`.
2. Create HMI connection and tag table.
3. Create tags from `hmi_minimal_sicar_bindings.json`.
4. Create each screen from `unified_minimal_sicar_page_set.json`.
5. Apply the screen JSON with `ApplyUnifiedHmiScreenDesignJson`.
6. Apply button actions and dynamization from `hmi_minimal_sicar_bindings.json`.
7. Read back the HMI connection, tag addresses, screen items, and action syntax checks.

## Notes

- The template is intentionally not a raw project export. It is a reusable JSON layout based on the SICAR-style organization: panel status, operation lines, alarms, diagnostics, and reusable faceplate areas.
- Navigation buttons are visual placeholders unless project-specific navigation actions are added.
- Status lamps should be bound through `BackColor`; numeric fields should be bound through `ProcessValue`.
