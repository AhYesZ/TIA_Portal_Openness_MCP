# HMI Button Event Standard

Command buttons must have visible event scripts in the TIA Events tab. A button that only has text, color, layout, or `PressedStateTags` is not accepted as a complete command button.

## Required Behavior

| Button type | Required events | Action |
|---|---|---|
| Start / Enable | `Down` or `Press` + `Up` or `Release` | down/press = `set-bit`, up/release = `reset-bit` |
| Stop / Disable | `Down` or `Press` + `Up` or `Release` | down/press = `set-bit`, up/release = `reset-bit` |
| Reset / Apply | `Down` or `Press` + `Up` or `Release` | down/press = `set-bit`, up/release = `reset-bit` |

Use `EnsureUnifiedHmiButtonAction` for every command event. It creates the event handler, writes deterministic ScriptCode, and runs SyntaxCheck.

## Accepted Pattern

```text
EnsureUnifiedHmiButtonAction(
  hmiSoftwarePath="HMI_RT_1",
  screenName="Main",
  buttonName="Btn_Start",
  eventType="Down",
  actionKind="set-bit",
  targetTag="Motor_Start"
)

EnsureUnifiedHmiButtonAction(
  hmiSoftwarePath="HMI_RT_1",
  screenName="Main",
  buttonName="Btn_Start",
  eventType="Up",
  actionKind="reset-bit",
  targetTag="Motor_Start"
)
```

If a TIA installation exposes the events as `Press`/`Release` instead of `Down`/`Up`, use that pair consistently.

## Validation

- Each command button must show at least one event row in the TIA Events tab.
- Momentary command buttons must show both a set event and a reset event.
- `SetUnifiedHmiButtonEventScriptCode` must return successful SyntaxCheck/readback metadata.
- `BindUnifiedHmiButtonPressedTag` may be used as an auxiliary binding only; it does not replace Events-tab scripts.
