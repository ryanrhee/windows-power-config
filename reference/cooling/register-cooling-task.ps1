# Registers task KrakenCooling: runs apply-cooling.ps1 at logon and after every wake.
$dir = $PSScriptRoot
$action = New-ScheduledTaskAction -Execute 'wscript.exe' -Argument ('"{0}\launch-hidden.vbs" "{0}\apply-cooling.ps1"' -f $dir)
$logon = New-ScheduledTaskTrigger -AtLogOn -User $env:USERNAME
$cls = Get-CimClass -ClassName MSFT_TaskEventTrigger -Namespace Root/Microsoft/Windows/TaskScheduler
$wake = New-CimInstance -CimClass $cls -ClientOnly
$wake.Enabled = $true
$wake.Subscription = '<QueryList><Query Id="0" Path="System"><Select Path="System">*[System[Provider[@Name=''Microsoft-Windows-Power-Troubleshooter''] and EventID=1]]</Select></Query></QueryList>'
$principal = New-ScheduledTaskPrincipal -UserId $env:USERNAME -LogonType Interactive -RunLevel Limited
$settings = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries -MultipleInstances IgnoreNew -ExecutionTimeLimit (New-TimeSpan -Minutes 5)
Register-ScheduledTask -TaskName 'KrakenCooling' -Action $action -Trigger @($logon, $wake) -Principal $principal -Settings $settings -Force | Out-Null
$t = Get-ScheduledTask -TaskName 'KrakenCooling'
"task: $($t.TaskName)  state: $($t.State)  triggers: $($t.Triggers.Count)"
