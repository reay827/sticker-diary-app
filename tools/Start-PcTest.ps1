param([switch]$CheckOnly, [switch]$ImportPhoto)
$ErrorActionPreference = 'Stop'
$project = Split-Path $PSScriptRoot -Parent
$workspace = Split-Path $project -Parent
$devtools = Join-Path $workspace '.devtools'
$sdk = Join-Path $devtools 'android-sdk'
$emulator = Join-Path $sdk 'emulator\emulator.exe'
$script:adb = Join-Path $sdk 'platform-tools\adb.exe'
$apk = Join-Path $project 'build\pc\haru-jogak-pc.apk'
$env:ANDROID_HOME = $sdk
$env:ANDROID_AVD_HOME = Join-Path $devtools 'avd'
$serial = 'emulator-5580'
$avd = 'haru_pc'
$logs = Join-Path $devtools 'logs'
New-Item -ItemType Directory -Force $logs | Out-Null
Add-Type -AssemblyName System.Windows.Forms

function Invoke-Adb {
    param([string[]]$AdbArgs)
    $oldPreference = $ErrorActionPreference
    $ErrorActionPreference = 'Continue'
    $text = (& $script:adb @AdbArgs 2>&1 | Out-String).Trim()
    $code = $LASTEXITCODE
    $ErrorActionPreference = $oldPreference
    return [PSCustomObject]@{ Code=$code; Text=$text }
}

try {
    foreach ($path in @($emulator, $script:adb, $apk, (Join-Path $env:ANDROID_AVD_HOME 'haru_pc.ini'))) {
        if (!(Test-Path -LiteralPath $path)) { throw '가상폰 준비 파일이 아직 없어요. 이 채팅에서 준비를 마무리해 주세요.' }
    }
    $accel = (& $emulator -accel-check 2>&1 | Out-String)
    $ready = $LASTEXITCODE -eq 0
    if ($CheckOnly) {
        [PSCustomObject]@{ FilesReady=$true; AccelerationReady=$ready; Device=$avd; Apk=$apk } | ConvertTo-Json
        exit 0
    }
    if (!$ready) {
        $message = "가상폰 실행에 필요한 Windows 기능이 아직 꺼져 있어요.`n`n1. 기능 목록에서 'Windows 하이퍼바이저 플랫폼'을 체크하세요.`n2. 확인을 누르고 PC를 다시 시작하세요.`n3. 'PC테스트-시작.cmd'를 다시 여세요.`n`nWindows 기능 목록을 열까요? (자동으로 설정을 바꾸거나 재부팅하지 않아요.)"
        $answer = [System.Windows.Forms.MessageBox]::Show($message, '하루 조각 · 가상폰 준비', 'YesNo', 'Information')
        if ($answer -eq 'Yes') { Start-Process -FilePath 'optionalfeatures.exe' }
        exit 0
    }
    $status = New-Object System.Windows.Forms.Form
    $status.Text = '하루 조각 · PC 테스트'
    $status.Width = 390; $status.Height = 140
    $status.StartPosition = 'CenterScreen'
    $status.FormBorderStyle = 'FixedDialog'
    $status.MaximizeBox = $false; $status.MinimizeBox = $false
    $label = New-Object System.Windows.Forms.Label
    $label.AutoSize=$true; $label.Left=22; $label.Top=28
    $label.Text = '가상폰을 준비하고 있어요. 잠시 기다려 주세요.'
    $status.Controls.Add($label); $status.Show()
    [System.Windows.Forms.Application]::DoEvents()

    $startServer = Invoke-Adb -AdbArgs @('start-server')
    if ($startServer.Code -ne 0) { throw '가상폰 연결 도구를 시작하지 못했어요.' }
    $state = Invoke-Adb -AdbArgs @('-s', $serial, 'get-state')
    if ($state.Code -eq 0) {
        $name = Invoke-Adb -AdbArgs @('-s', $serial, 'emu', 'avd', 'name')
        if ($name.Text -notmatch '(?m)^haru_pc\r?$') { throw '다른 가상폰이 테스트 연결을 사용하고 있어요. 실행 중인 가상폰을 닫고 다시 시도해 주세요.' }
    } else {
        Start-Process -FilePath $emulator -ArgumentList @('-avd', $avd, '-port', '5580', '-no-boot-anim', '-gpu', 'auto', '-no-snapshot', '-netdelay', 'none', '-netspeed', 'full') -WindowStyle Normal -RedirectStandardOutput (Join-Path $logs 'emulator-output.log') -RedirectStandardError (Join-Path $logs 'emulator-error.log') | Out-Null
    }
    $deadline = (Get-Date).AddMinutes(5)
    $booted = $false
    while ((Get-Date) -lt $deadline) {
        $boot = Invoke-Adb -AdbArgs @('-s', $serial, 'shell', 'getprop', 'sys.boot_completed')
        if ($boot.Code -eq 0 -and $boot.Text.Trim() -eq '1') { $booted=$true; break }
        [System.Windows.Forms.Application]::DoEvents()
        Start-Sleep -Seconds 2
    }
    if (!$booted) { throw '가상폰 시작이 오래 걸리고 있어요. 가상폰 창의 안내를 확인한 뒤 다시 실행해 주세요.' }
    $label.Text = '앱을 설치하고 있어요. 기록은 그대로 유지돼요.'
    [System.Windows.Forms.Application]::DoEvents()
    $install = Invoke-Adb -AdbArgs @('-s', $serial, 'install', '-r', '-t', $apk)
    if ($install.Code -ne 0) { throw '앱을 설치하지 못했어요. 기존 앱은 지우지 말고 이 채팅에 알려주세요.' }
    if ($ImportPhoto) {
        $status.Hide()
        $dialog = New-Object System.Windows.Forms.OpenFileDialog
        $dialog.Title='가상폰에 넣을 테스트 사진 고르기'
        $dialog.Filter='사진|*.jpg;*.jpeg;*.png;*.webp'
        $dialog.Multiselect=$true
        if ($dialog.ShowDialog() -eq 'OK') {
            $folder = Invoke-Adb -AdbArgs @('-s', $serial, 'shell', 'mkdir', '-p', '/sdcard/Pictures/HaruTest')
            foreach ($file in $dialog.FileNames) {
                $extension=[IO.Path]::GetExtension($file).ToLowerInvariant()
                $remote='/sdcard/Pictures/HaruTest/'+[Guid]::NewGuid().ToString('N')+$extension
                $copy = Invoke-Adb -AdbArgs @('-s', $serial, 'push', $file, $remote)
                if ($copy.Code -ne 0) { throw '사진을 가상폰으로 복사하지 못했어요.' }
                $scan = Invoke-Adb -AdbArgs @('-s', $serial, 'shell', 'am', 'broadcast', '-a', 'android.intent.action.MEDIA_SCANNER_SCAN_FILE', '-d', ('file://'+$remote))
            }
        }
        $dialog.Dispose()
    }
    $launch=Invoke-Adb -AdbArgs @('-s', $serial, 'shell', 'am', 'start', '-n', 'com.reay827.sticker_diary/.MainActivity')
    if ($launch.Code -ne 0) { throw '앱을 열지 못했어요. 가상폰에서 하루 조각 아이콘을 눌러 주세요.' }
    $status.Close()
} catch {
    if ($status) { $status.Close() }
    if ($CheckOnly) { throw }
    [System.Windows.Forms.MessageBox]::Show($_.Exception.Message, '하루 조각 · PC 테스트', 'OK', 'Information') | Out-Null
}
