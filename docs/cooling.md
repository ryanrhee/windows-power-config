# Cooling recovery is separate from power configuration

The hibernation script does not install or configure cooling software. Preserve this
setup too if rebuilding Windows.

## Existing working setup

- Python 3.13, liquidctl, NZXT Kraken Z-series USB connection.
- `KrakenCooling` scheduled task runs at this user's logon and on System
  Power-Troubleshooter Event 1 (resume).
- It waits for USB enumeration, initializes the cooler, applies the curves below,
  reads status, logs the result, and exits. It does not request a system wake.
- Motherboard-connected fans use BIOS control. The liquidctl script controls the
  Kraken pump and radiator fan channel; it does not replace GPU fan control.

| Liquid temperature C | Pump duty % |
| --- | --- |
| 20 | 60 |
| 30 | 60 |
| 34 | 75 |
| 38 | 90 |
| 42 | 100 |

| Liquid temperature C | Radiator fan duty % |
| --- | --- |
| 20 | 25 |
| 30 | 30 |
| 34 | 45 |
| 38 | 65 |
| 42 | 85 |
| 45 | 100 |

## Script snapshots

`reference/cooling/` contains exact copies of the three scripts used on 2026-09-20:

- `apply-cooling.ps1`
- `launch-hidden.vbs`
- `register-cooling-task.ps1`

**These are archival copies, not fully portable installers.** In particular,
`apply-cooling.ps1` has a hard-coded Python path for the old Windows user. After
installing Python and liquidctl on a new installation, update `$py` to that Python
executable. Keep the UTF-8 options and command exit-code checks.

Place the adapted scripts in a permanent directory. Verify liquidctl can see the
Kraken and read its status before applying the curves. Run the apply script manually,
check `cooling.log` for success and sensible temperature/pump/fan readings, then run
the task-registration script from that directory. Confirm the task references the
new directory and user, has both logon/resume triggers, and has WakeToRun disabled.
Validate again after one hibernation/resume.

The original installation used `C:\Users\rhee\cooling`. Moving that directory after
task registration requires registering the task again.

The earlier USB descriptor failure prevented software access to the cooler; it did
not establish that the pump was dead. A full power drain recovered USB access. Do not
treat reinstalling software as proof that the cooler is operating: read its status.

See the [liquidctl Kraken guide](https://github.com/liquidctl/liquidctl/blob/main/docs/kraken-x3-z3-guide.md)
for current installation and device-specific instructions.
