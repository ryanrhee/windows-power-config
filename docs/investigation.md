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
