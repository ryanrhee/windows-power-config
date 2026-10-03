# Windows desktop power configuration

Recovery instructions for the Razer Mouse Dock Pro + Windows power setup on this desktop.
Updated 2026-10-03. This is specific to this desktop, not a general Windows tuning guide.

## Recommended setup

Since 2026-10-03 this PC is an always-on browser host: automatic S3 sleep and automatic
S4 hibernation are both disabled on AC power. Hibernation itself stays enabled with a
full file, so it remains available manually and for the `-IdleHibernate` profile.
Connect the Mouse Dock Pro to the PC for charging and mouse connectivity, leave the
standalone receiver unplugged, and disable all four dock wake permissions. Those
permissions control waking the PC; charging and normal mouse use still work.
Leave the separate keyboard's wake permission enabled. Retain the
[cooling task](docs/cooling.md): it re-pushes the cooler curves at logon and after any
resume, and the cooler runs them from firmware in between.

Disabling idle hibernation does not re-arm S3. Automatic sleep stays Never, so the
unresolved S3 hard lockup is not back in play. The earlier tested setup, S4 after
15 minutes idle, remains available through `-IdleHibernate` if the PC stops being a
host. Diagnostic sleep tests are finished and none is armed.

## Intended behavior

| Setting | Value |
| --- | --- |
| Hibernate after, on AC power | Never (0 seconds); 15 minutes (900) with `-IdleHibernate` |
| Ordinary sleep after, on AC power | Never (0 seconds) |
| Hibernation support | Enabled, full hibernation file |
| Mouse Dock Pro wake permissions | Disabled on all its HID interfaces |
| Separate keyboard wake permission | Left enabled on the tested installation |
| Resume, if hibernated manually | Use the power button; mouse movement should not wake the PC |

The tested plan is Windows Balanced. The script modifies the **currently active plan**.
Battery settings, wake timers, hybrid sleep, button actions, display and disk timeouts,
and other devices' wake permissions are left unchanged. The display still turns off
when idle; that does not suspend the browser. Choosing Sleep manually can still enter S3.
Under `-IdleHibernate`, applications can delay idle hibernation through power requests;
15 minutes is not a forced deadline.

## After reinstalling Windows

1. Restore this repository from a copy stored off the Windows disk.
2. Install the motherboard/chipset and peripheral drivers, and select the intended power plan
   (Balanced was tested).
3. Connect the Mouse Dock Pro to the PC and pair the Naga V2 Pro to it in Razer Synapse.
   If the mouse still uses its standalone receiver, keep that receiver available while pairing,
   or use a USB cable for mouse control. Remove the standalone receiver once dock pairing works.
4. Open **Windows PowerShell as Administrator**, change to this repository, and run:

   ```powershell
   # Preview: no settings are changed.
   .\Set-Hibernation.ps1 -Apply -WhatIf

   # Apply and verify.
   .\Set-Hibernation.ps1 -Apply

   # Later: check only, without changing settings.
   .\Set-Hibernation.ps1

   # Earlier tested profile: S4 after 15 minutes idle instead of never.
   .\Set-Hibernation.ps1 -Apply -IdleHibernate
   ```

   Check mode compares against the selected profile, so check the 15-minute
   profile with `.\Set-Hibernation.ps1 -IdleHibernate`.

   If execution policy blocks the local script, use a process-only invocation:

   ```powershell
   powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\Set-Hibernation.ps1 -Apply
   ```

5. Confirm `MatchesDocumentedSettings : True`. Check the listed wake devices and
   verify the separate keyboard has the desired permission in Device Manager.
6. Restore cooling separately using [the cooling notes](docs/cooling.md).
7. Validate that the PC stays up. Leave it idle overnight, then confirm with
   `powercfg /lastwake` and the Power-Troubleshooter query below that no sleep or
   hibernation was recorded, and check the cooler status in `cooling.log`. If using
   `-IdleHibernate` instead, validate one idle hibernation with work saved: keep the
   monitor KVM on the desktop and the laptop disconnected so the keyboard stays attached,
   leave it 45-60 minutes, wake with the power button, then check mouse, keyboard and
   cooling, and follow with an overnight trial. A new Windows/driver installation needs
   fresh validation.

The script finds dock interfaces by **VID_1532 / PID_00A4**, including its two mouse
and two keyboard functions. Display names and device-instance suffixes can change
after a reinstall or USB port move, so they are discovered each run. The standalone
receiver is PID_00A8 and is not targeted by this script.

The script runs once and exits. It creates no task or background process. These are
Windows settings that remain after resume/restart. Recheck after driver reinstalls,
USB port changes, or changing power plans; new device instances can have new defaults.
It disables the old diagnostic cleanup task if found, because that task would undo
the configuration on resume. It saves previous values in the ignored `backups/` folder.
An error can leave earlier steps applied; inspect its status and backup before retrying.

## Diagnose an unexpected result

```powershell
powercfg /requests
powercfg /waketimers
powercfg /devicequery wake_armed
powercfg /lastwake
Get-WinEvent -FilterHashtable @{
    LogName = 'System'
    ProviderName = 'Microsoft-Windows-Power-Troubleshooter'
    Id = 1
} -MaxEvents 1 | ForEach-Object { $_.ToXml() }
```

In the last command, `SleepTime` and `WakeTime` are UTC. `TargetState=5` and
`EffectiveState=5` identify S4 in the recorded tests. On this PC, wake source often
reports Unknown, even after a reported power-button wake. Kernel-Power 107 timestamps
have been misleading; use the Power-Troubleshooter timestamps to measure the interval.

To switch idle hibernation without changing device permissions, set `HIBERNATEIDLE`
to `0` (never, the browser-host default) or `900` (the `-IdleHibernate` profile):

```powershell
powercfg /setacvalueindex SCHEME_CURRENT SUB_SLEEP HIBERNATEIDLE 0
powercfg /setactive SCHEME_CURRENT
```

For individual wake permissions, use Device Manager's Power Management tab, or match
hardware IDs in `MSPower_DeviceWakeEnable` as the setup script does. Do not restore old
full instance paths onto a new installation. Avoid enabling S3 as an incidental rollback;
the original S3 hard lockup remains unresolved.

## What belongs in Git

- This README, setup script, investigation conclusions and cooling script snapshots.
- A short dated note whenever a setting changes, with the test result that supports it.
- No large ETW recordings, runtime logs, local backups or full registry exports.

A `powercfg /export` file can supplement these notes, but covers a power plan rather
than the separate device wake settings and cooling tasks. The readable recipe is the
main recovery record. See [Microsoft's powercfg reference](https://learn.microsoft.com/en-us/windows-hardware/design/device-experiences/powercfg-command-line-options).

Keep a private remote or another backup **outside this Windows installation**.
A local Git repository alone will not survive wiping the disk. Nothing in this repo
requires publishing it publicly.

## Evidence and limits

See [investigation notes](docs/investigation.md) for the full record. S4 with the dock
and its wake permissions disabled has passed repeated daytime and overnight trials.

The September 23-26 S3 comparison kept the mouse charging on the dock and the KVM
on desktop throughout, confirmed by the user for each test:

| Dock wake permissions | S3 result |
| --- | --- |
| Disabled | ~12h46m, ended with power-button wake |
| Enabled | Spontaneous USB wake after ~19 seconds |
| Disabled | ~20h15m, ended with power-button wake |
| Enabled | Spontaneous USB wake after ~42 seconds |

Both spontaneous wakes named the same AMD USB controller serving the dock. This
is strong evidence that dock wake permissions contribute to unwanted wakes in
this setup. The tests do not identify the individual dock function responsible,
and the original hard lockup has not recurred or been explained. Successful S3
controls therefore do not establish that its original hang is fixed.
