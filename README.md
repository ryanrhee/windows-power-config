# Windows desktop power configuration

Recovery instructions for the tested Razer Mouse Dock Pro + Windows S4 hibernation setup.
Recorded 2026-09-20. This is specific to this desktop, not a general Windows tuning guide.

## Intended behavior

| Setting | Value |
| --- | --- |
| Hibernate after, on AC power | 15 minutes idle (900 seconds) |
| Ordinary sleep after, on AC power | Never (0 seconds) |
| Hibernation support | Enabled, full hibernation file |
| Mouse Dock Pro wake permissions | Disabled on all its HID interfaces |
| Separate keyboard wake permission | Left enabled on the tested installation |
| Resume | Use the power button; mouse movement should not wake the PC |

The tested plan is Windows Balanced. The script modifies the **currently active plan**.
Battery settings, wake timers, hybrid sleep, button actions and other devices' wake
permissions are left unchanged. Choosing Sleep manually can still enter S3.
Applications can delay idle hibernation through power requests; 15 minutes is not a forced deadline.

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
   ```

   If execution policy blocks the local script, use a process-only invocation:

   ```powershell
   powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\Set-Hibernation.ps1 -Apply
   ```

5. Confirm `MatchesDocumentedSettings : True`. Check the listed wake devices and
   verify the separate keyboard has the desired permission in Device Manager.
6. Restore cooling separately using [the cooling notes](docs/cooling.md).
7. Validate one idle hibernation with work saved. Keep the monitor KVM on the desktop
   and the laptop disconnected, so the keyboard stays attached. Leave the desktop for
   45-60 minutes, wake with the power button, then check mouse, keyboard and cooling.
   Follow with an overnight trial. A new Windows/driver installation needs fresh validation.

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

To pause automatic hibernation without changing device permissions:

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

See [investigation notes](docs/investigation.md). S4 with the dock and its wake
permissions disabled passed one short test and one 9-hour overnight test. It is a
tested workaround; the original S3 hang's mechanism is still unknown.
