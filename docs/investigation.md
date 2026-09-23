# Investigation record

## Machine and original symptom

- Gigabyte B550 AORUS ELITE AX V2, Ryzen 9 5900X, RX 6800 XT.
- BIOS recorded as F21a during the later investigation.
- NZXT Kraken Z-series cooler, identified by liquidctl as Z53/Z63/Z73, firmware 5.11.0.
- Razer Naga V2 Pro; standalone receiver PID_00A8, Mouse Dock Pro PID_00A4.
- Separate keyboard VID_CB10 / PID_4256, routed through a monitor KVM.

Around ordinary S3 sleep, the PC sometimes locked up so severely that even a long
power-button hold did not recover it. Cutting PSU power was required. Removing the
dock and using the standalone receiver did not eliminate that symptom. Long periods
without S3 were stable. This does not establish a specific hardware or driver defect.

S4 hibernation is an alternate path: save memory to disk, power down, and restore
through the boot path. The original S3 failure has not been reproduced in the recent
S4 trials, but the root cause is unresolved. The immediate S4 wakes were a separate
obstacle; addressing them does not prove the S3 problem fixed.

## Tests that matter

Times below are local Asia/Singapore. Durations are entry-to-resume intervals.

| Configuration | Result |
| --- | --- |
| Receiver with either mouse function still wake-enabled | Several quick resumes, about 25-35 seconds |
| Receiver with both mouse wake permissions disabled | Two successes (~11 and ~19 minutes), then a quick-wake failure (~30 seconds) |
| All receiver wake permissions disabled; keyboard disappeared through KVM | Successes, but keyboard absence confounded attribution |
| All receiver wake permissions disabled; keyboard remained wake-enabled | Sep 19: ~6 minutes, then 17:53-19:56 (~2h03m), both successful |
| All dock wake permissions disabled; keyboard remained wake-enabled | Sep 19: 22:40-22:49 (~9 minutes), successful |
| Same dock configuration overnight | Sep 19 23:06 to Sep 20 08:25 (~9h19m), successful |
| Permanent dock S4 configuration | Sep 20-21: ~27h18m and ~3h01m, successful; current settings still verified afterward |
| S3, all dock wake disabled, KVM on desktop | Sep 22 00:56:45-11:12:58 (~10h16m), power-button resume; keyboard wake-listed before sleep |
| S3, all dock wake disabled, KVM on MacBook | Sep 22 17:04:51-22:12:13 (~5h07m), power-button resume; keyboard absent from pre-sleep wake list |
| S3 charging control A1: all dock wake disabled, KVM on desktop, mouse on dock throughout (user confirmed) | Sep 23 17:23:40 to Sep 24 06:09:35 (~12h46m), power-button resume, no intervening wake; keyboard wake-listed in all 18 pre-sleep samples |

Disabling just the two receiver mouse functions was **not sufficient**. Both the
receiver and dock expose keyboard functions too. All four originally enabled wake
interfaces were disabled in the successful final configurations. This is evidence
for a practical workaround, not proof of which individual interface or firmware
mechanism caused unwanted wakes.

The separate keyboard disappearing from `wake_armed` likely followed the monitor KVM
switching to the laptop. Later controlled tests kept the KVM on the desktop and
verified the keyboard stayed listed in every pre-hibernation sample.

## Permanent settings adopted 2026-09-20

AC idle S3=Never; AC idle S4=15 minutes; all Mouse Dock Pro HID wake permissions off.
The standalone receiver is unplugged and the mouse is paired to the dock. Separate
keyboard wake remains on. Existing timer permissions are unchanged.

The diagnostic one-shot scripts are not part of the permanent setup. Their cleanup
and snapshot tasks are disabled. Existing heartbeat and raw-input diagnostic tasks
were left enabled on this installation; they are not required after reinstalling.
The separate Kraken cooling task remains active.

Original evidence is under `C:\Users\rhee\hang-diag` on the old installation.
Large traces and logs are intentionally excluded from this repo. Older notes contain
stronger causal claims than the experiments justify; use the conclusions above.

## Historical audit, 2026-09-23

Do not repeat earlier trials without specifying what new comparison they provide.

- July 23-24: the logs show the dock's two **keyboard** wake interfaces disabled,
  but both **mouse** wake interfaces remained enabled. USB selective suspend was
  also off. Wakes and a lockup still occurred; this did not test full dock wake-off.
- July 25: disabling the monitor's control HIDs did not eliminate wakes or the lockup.
- August 14: disabling CPU C-states and using Typical Current Idle did not eliminate
  the lockup.
- August 15: a lockup occurred with the dock physically removed and the standalone
  receiver still wake-enabled. Dock removal was not sufficient on that configuration.
- In the original session, Claude explicitly said full dock wake disarming had not
  been tested. Its later claim that every wake-disabling option had been refuted was
  broader than the records support.
- The old `hang-diag/fix-wake.ps1` contains reversed logic: `$want = -not $Revert`
  produces Enable=true when invoked normally. No FIXWAKE execution record was found
  in the event log. Do not use that old script or treat its existence as a completed
  experiment. The current repository setup script writes Enable=false explicitly.

### Why old failures are not today's control

On August 16 the memory configuration changed to four DIMMs (2x8GB plus 2x16GB),
48GB total, at 3066 MT/s with a recorded manual VSOC setting of 1.10V. The modules
and configured speed were confirmed again on September 23. On August 21 CPU
C-state/idle settings were restored to Auto and SVM was re-enabled. Cooling software
also changed later. Current successful S3 tests therefore cannot be attributed
solely to disabling dock wake by comparing them with July/August lockups.

## Next proposed diagnostic comparison (not armed)

Question: on the **current** hardware/software configuration, does changing the
dock's four wake permissions change spontaneous S3 wake behavior or reproduce a hang?

Use matched S3 trials with KVM on desktop, keyboard connected, mouse charging on
the dock, same applications/idle timeout, and no added timer wakes. Record whether
the mouse is on the dock; earlier tests did not consistently record that variable.

1. **Completed September 24:** all-four-off control with specified mouse placement,
   confirmed by the user on return. S3 lasted ~12h46m until power-button wake;
   dock and cooler recovered normally and the production S4 settings restored.
2. Enable all four dock wake permissions for one otherwise identical attempt.
3. If spontaneous waking returns, disable all four again and repeat the control.
   Reproduce the on/off association before calling it causal evidence for wakes.

Each trial is one-shot and must restore the production S4 settings and original
dock wake flags on resume or boot. A normal planned observation window is at least
30 minutes **after actual S3 entry**, ending in a power-button wake if still asleep.
An early uncommanded wake is a result to inspect, not a reason to silently run more
cycles. Stop and inspect on any hang, USB/cooling failure, or unexpected topology
change. Do not use the old unattended cycler for this comparison.

If the enabled condition does not reproduce spontaneous wakes in a small bounded
series (at most three attempts per condition), record the trigger as not reproduced;
do not keep requesting identical nights or declare the rare lockup fixed. This
bound is a practical investigation limit, not a statistical reliability guarantee.
Repeated on/off association can identify a wake trigger. It still cannot establish
the precise driver/firmware mechanism of a hard lockup. A hang under all-four-off
would show that restriction insufficient; a captured hang warrants analysis of the
transition trace before choosing another intervention.
