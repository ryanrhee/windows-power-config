# Cooling recovery is separate from power configuration

The hibernation script does not install or configure cooling software. Preserve this
setup too if rebuilding Windows.

## Existing working setup

- Python 3.13, liquidctl, NZXT Kraken Z-series USB connection.
- `KrakenCooling` scheduled task runs at this user's logon and on System
  Power-Troubleshooter Event 1 (resume).
- It waits for USB enumeration, initializes the cooler, applies the curves below,
  reads status, logs the result, and exits. It does not request a system wake.
- **No software runs the cooler.** The Kraken stores these curves in its own firmware
  and executes them with nothing resident: no service, no daemon, no tray app. The task
  is a one-shot push lasting roughly 25 seconds, after which the cooler is autonomous.
  It only forgets the curves on total power loss (PSU switch, unplugged), which is why
  the task re-pushes them at logon and after resume rather than on a timer.
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

## Do not install NZXT CAM

Use liquidctl, not NZXT CAM. Both drive the Kraken over the same USB HID interface, and
CAM takes ownership of the cooler while it runs: it applies its own profiles and will
override the curves above. CAM also installs a service and a tray app that start at
logon, so the conflict would recur on every boot rather than once.

Verified absent on 2026-10-03: no NZXT process or service was running, no NZXT entry
existed in the per-machine, WOW6432Node or per-user uninstall keys, no NZXT scheduled
task was registered, and nothing NZXT-related appeared in either `Run` key. The live
cooler read matched the documented curves exactly, interpolated at integer degrees
(32 C liquid gives pump 67.5 -> 68%, fan 37.5 -> 38%), confirming the firmware alone
was driving it.

`C:\Program Files\NZXT CAM` survived as an empty directory, created 2021-12-05 and last
modified 2024-09-01, holding zero files including hidden ones. It was an orphan from an
old uninstall rather than an installation, and it was deleted on 2026-10-03 after being
re-checked as empty. Should such a folder reappear, do not read it as evidence that CAM
is installed; check for a running process instead, which is what `apply-cooling.ps1`
now does.

After reinstalling Windows, install only Python and liquidctl. If CAM is ever needed
for a firmware update or to configure the LCD, close it afterwards and re-run
`apply-cooling.ps1` to restore these curves, then confirm the status read matches.

## Script snapshots

`reference/cooling/` contains exact copies of the three scripts in use. `launch-hidden.vbs`
and `register-cooling-task.ps1` are unchanged from 2026-09-20; `apply-cooling.ps1` gained
the CAM warning above on 2026-10-03. Each copy is byte-identical to its counterpart in
`C:\Users\rhee\cooling`; keep them in sync when either side changes.

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
