#requires -Version 5.1
#requires -RunAsAdministrator
<#
Default: inspect settings without changing them.
Use -Apply to configure the current power plan and connected Razer Mouse Dock Pro.
Use -Apply -WhatIf to preview. This script exits; it installs no background task.
#>
[CmdletBinding(SupportsShouldProcess = $true)]
param([switch]$Apply)

$ErrorActionPreference = 'Stop'
$dockPattern = '^HID\\VID_1532&PID_00A4&'
$sleepGuid = '29f6c1db-86da-48c5-9fdb-f2b67b1f44da'
$hibernateGuid = '9d7815a6-7ee4-497e-8888-515a05f02364'

function Invoke-PowerCfg([string[]]$Arguments) {
    $output = @(& "$env:SystemRoot\System32\powercfg.exe" @Arguments 2>&1)
    if ($LASTEXITCODE -ne 0) {
        throw "powercfg $($Arguments -join ' ') failed: $($output -join ' ')"
    }
    $output
}

function Get-ActiveScheme {
    $description = (Invoke-PowerCfg @('/getactivescheme')) -join ' '
    $match = [regex]::Match($description, '[0-9a-fA-F]{8}(?:-[0-9a-fA-F]{4}){3}-[0-9a-fA-F]{12}')
    if (-not $match.Success) { throw "Cannot identify active power plan: $description" }
    $match.Value
}

function Get-ACValue([string]$Scheme, [string]$Setting) {
    # Numeric CIM values avoid parsing localized powercfg labels.
    $instance = 'Microsoft:PowerSettingDataIndex\{' + $Scheme + '}\AC\{' + $Setting + '}'
    $rows = @(Get-CimInstance -Namespace root\cimv2\power -ClassName Win32_PowerSettingDataIndex |
        Where-Object { $_.InstanceID -eq $instance })
    if ($rows.Count -ne 1) { throw "Cannot read AC setting $Setting in plan $Scheme" }
    [uint32]$rows[0].SettingIndexValue
}

function Get-DockWake {
    Get-CimInstance -Namespace root\wmi -ClassName MSPower_DeviceWakeEnable |
        Where-Object { $_.InstanceName -match $dockPattern }
}

$scheme = Get-ActiveScheme
$dockPresent = @(Get-PnpDevice -PresentOnly | Where-Object {
    $_.InstanceId -match '^USB\\VID_1532&PID_00A4\\' -and $_.Status -eq 'OK'
}).Count -gt 0
$dockWake = @(Get-DockWake)
if (-not $dockPresent) { throw 'Connect the paired Razer Mouse Dock Pro to this PC first (VID_1532, PID_00A4).' }
foreach ($interface in @('MI_00\\', 'MI_01&Col01\\', 'MI_01&Col02\\', 'MI_02\\')) {
    if (@($dockWake | Where-Object { $_.InstanceName -match ($dockPattern + $interface) }).Count -eq 0) {
        throw "Expected dock wake interface missing: $interface. Inspect drivers before applying."
    }
}

if ($Apply -and $PSCmdlet.ShouldProcess('Current power plan and Razer Mouse Dock Pro',
    'Enable full hibernation, set AC idle hibernate to 15 minutes, disable AC idle S3 and all dock wake permissions')) {
    $activeTest = Join-Path $env:USERPROFILE 'hang-diag\active-s4-trace.json'
    if (Test-Path -LiteralPath $activeTest) { throw 'Finish the active diagnostic test before applying permanent settings.' }

    $backupDirectory = Join-Path $PSScriptRoot 'backups'
    New-Item -ItemType Directory -Path $backupDirectory -Force | Out-Null
    $backupPath = Join-Path $backupDirectory ((Get-Date -Format 'yyyyMMdd-HHmmss-fff') + '.json')
    [ordered]@{
        Time = (Get-Date).ToString('o')
        PowerScheme = $scheme
        SleepACSeconds = Get-ACValue $scheme $sleepGuid
        HibernateACSeconds = Get-ACValue $scheme $hibernateGuid
        HibernateRegistry = Get-ItemProperty -LiteralPath 'HKLM:\SYSTEM\CurrentControlSet\Control\Power' |
            Select-Object HibernateEnabled, HiberFileType
        DockWake = @($dockWake | Select-Object InstanceName, Enable)
        DiagnosticTasks = @(foreach ($taskName in @('HangDiagStopAutoHibernateTest', 'HangDiagIdleBlockerSnapshots')) {
            Get-ScheduledTask -TaskName $taskName -ErrorAction SilentlyContinue | Select-Object TaskName, State
        })
    } | ConvertTo-Json -Depth 5 | Set-Content -LiteralPath $backupPath -Encoding UTF8
    Write-Host "Previous settings saved to $backupPath"

    # Retire the old one-shot test guard if present on this installation.
    foreach ($taskName in @('HangDiagStopAutoHibernateTest', 'HangDiagIdleBlockerSnapshots')) {
        $task = Get-ScheduledTask -TaskName $taskName -ErrorAction SilentlyContinue
        if ($task) { $task | Disable-ScheduledTask | Out-Null }
    }
    foreach ($device in $dockWake) {
        if ($device.Enable) { Set-CimInstance -InputObject $device -Property @{ Enable = $false } | Out-Null }
    }
    if (@(Get-DockWake | Where-Object Enable).Count -gt 0) { throw 'Some dock wake permissions remain enabled.' }

    $existingPower = Get-ItemProperty -LiteralPath 'HKLM:\SYSTEM\CurrentControlSet\Control\Power'
    if ($existingPower.HibernateEnabled -ne 1) {
        Invoke-PowerCfg @('/hibernate', 'on') | Out-Host
    }
    if ($existingPower.HibernateEnabled -ne 1 -or $existingPower.HiberFileType -ne 2) {
        Invoke-PowerCfg @('/hibernate', '/type', 'full') | Out-Host
    }
    Invoke-PowerCfg @('/setacvalueindex', $scheme, 'SUB_SLEEP', 'STANDBYIDLE', '0') | Out-Host
    Invoke-PowerCfg @('/setacvalueindex', $scheme, 'SUB_SLEEP', 'HIBERNATEIDLE', '900') | Out-Host
    Invoke-PowerCfg @('/setactive', $scheme) | Out-Host
}

$power = Get-ItemProperty -LiteralPath 'HKLM:\SYSTEM\CurrentControlSet\Control\Power'
$sleepSeconds = Get-ACValue $scheme $sleepGuid
$hibernateSeconds = Get-ACValue $scheme $hibernateGuid
$enabledDockWake = @(Get-DockWake | Where-Object Enable).Count
$guard = Get-ScheduledTask -TaskName 'HangDiagStopAutoHibernateTest' -ErrorAction SilentlyContinue
$guardDisabled = -not $guard -or $guard.State -eq 'Disabled'
$matches = $sleepSeconds -eq 0 -and $hibernateSeconds -eq 900 -and
    $enabledDockWake -eq 0 -and $power.HibernateEnabled -eq 1 -and
    $power.HiberFileType -eq 2 -and $guardDisabled

[pscustomobject]@{
    ActivePowerScheme = Get-ActiveScheme
    HibernateEnabled = $power.HibernateEnabled -eq 1
    FullHibernateFile = $power.HiberFileType -eq 2
    SleepACSeconds = $sleepSeconds
    HibernateACSeconds = $hibernateSeconds
    DockWakeInterfacesEnabled = $enabledDockWake
    OneShotCleanupDisabledOrAbsent = $guardDisabled
    MatchesDocumentedSettings = [bool]$matches
} | Format-List
Write-Host 'Devices still permitted to wake the PC:'
Invoke-PowerCfg @('/devicequery', 'wake_armed') | Out-Host
if (-not $matches -and -not $WhatIfPreference) { throw 'Settings differ from the documented configuration. Use -Apply to set them.' }
