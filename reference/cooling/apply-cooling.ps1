# Sends pump/fan curves to the NZXT Kraken Z3. The cooler runs these curves itself
# (liquid temperature based) with no software running, but forgets them when it
# loses power entirely (PSU switch, unplugged), so this re-applies them at logon
# and after every wake. Runs once and exits. Log: cooling.log next to this file.
param([int]$SettleSeconds = 20)

[Console]::OutputEncoding = New-Object System.Text.UTF8Encoding($false)
$py  = 'C:\Users\rhee\AppData\Local\Programs\Python\Python313\python.exe'
$log = Join-Path $PSScriptRoot 'cooling.log'
function Log([string]$m) { Add-Content -Path $log -Encoding UTF8 -Value ('{0:yyyy-MM-dd HH:mm:ss}  {1}' -f (Get-Date), $m) }
function Invoke-Liquidctl([string]$Label, [string[]]$Arguments) {
    $output = @(& $py -X utf8 -m liquidctl --match kraken @Arguments 2>&1)
    $result = $LASTEXITCODE
    foreach ($line in $output) { Log ('{0}: {1}' -f $Label, $line) }
    if ($result -ne 0) { throw "$Label failed with exit code $result" }
}

# Pump: liquid C -> duty %. Firmware minimum is 20%; it forces 100% at >= 60C liquid.
$pump = '20 60 30 60 34 75 38 90 42 100'
# Radiator fans: liquid C -> duty %.
$fan  = '20 25 30 30 34 45 38 65 42 85 45 100'
Start-Sleep -Seconds $SettleSeconds

$found = $false
for ($i = 0; $i -lt 6 -and -not $found; $i++) {
    $list = (& $py -X utf8 -m liquidctl list 2>&1 | Out-String)
    if ($LASTEXITCODE -eq 0 -and $list -match 'Kraken') { $found = $true } else { Start-Sleep -Seconds 10 }
}
if (-not $found) {
    Log 'KRAKEN NOT FOUND on USB - curves NOT applied; pump/fan state could not be read'
    exit 1
}

try {
    Invoke-Liquidctl -Label 'init' -Arguments @('initialize')
    Invoke-Liquidctl -Label 'pump' -Arguments (@('set', 'pump', 'speed') + $pump.Split(' '))
    Invoke-Liquidctl -Label 'fan' -Arguments (@('set', 'fan', 'speed') + $fan.Split(' '))
    Invoke-Liquidctl -Label 'status' -Arguments @('status')
    Log 'curve commands succeeded and status read successfully'
    exit 0
} catch {
    Log ('ERROR: ' + $_.Exception.Message)
    exit 1
}
