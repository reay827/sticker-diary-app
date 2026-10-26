param([string]$SourceFolder = '', [switch]$Quiet)
$ErrorActionPreference = 'Stop'
$project = Split-Path $PSScriptRoot -Parent
$workspace = Split-Path $project -Parent
$adb = Join-Path $workspace '.devtools\android-sdk\platform-tools\adb.exe'
$env:ANDROID_USER_HOME = Join-Path ([Environment]::GetFolderPath('UserProfile')) '.android'
$serial = 'emulator-5580'
if ([string]::IsNullOrWhiteSpace($SourceFolder)) {
    $SourceFolder = Join-Path ([Environment]::GetFolderPath('Desktop')) '입력 이미지'
}
function Invoke-Device {
    param([string[]]$DeviceArgs)
    $old = $ErrorActionPreference
    $ErrorActionPreference = 'Continue'
    $output = (& $adb @DeviceArgs 2>&1 | Out-String).Trim()
    $code = $LASTEXITCODE
    $ErrorActionPreference = $old
    return [PSCustomObject]@{ Code=$code; Text=$output }
}
try {
    if (!(Test-Path -LiteralPath $adb -PathType Leaf)) { throw '가상폰 연결 도구가 없어요. 이 채팅에 알려 주세요.' }
    if (!(Test-Path -LiteralPath $SourceFolder -PathType Container)) { throw '바탕화면에 입력 이미지 폴더를 만들고 사진을 넣어 주세요.' }
    $state = Invoke-Device -DeviceArgs @('-s', $serial, 'get-state')
    if ($state.Code -ne 0 -or $state.Text -ne 'device') { throw '먼저 PC테스트-시작.cmd로 가상폰을 켜 주세요. 연결 승인 창이 있으면 Allow를 눌러 주세요.' }
    $name = Invoke-Device -DeviceArgs @('-s', $serial, 'emu', 'avd', 'name')
    if ($name.Code -ne 0 -or $name.Text -notmatch '(?m)^haru_pc\r?$') { throw '하루 조각 전용 가상폰이 아니어서 사진을 보내지 않았어요.' }
    $mkdir = Invoke-Device -DeviceArgs @('-s', $serial, 'shell', 'mkdir', '-p', '/sdcard/Pictures/HaruTest')
    if ($mkdir.Code -ne 0) { throw '가상폰 사진함을 열지 못했어요.' }
    $existing = Invoke-Device -DeviceArgs @('-s', $serial, 'shell', 'sha256sum', '/sdcard/Pictures/HaruTest/*')
    $known = [Collections.Generic.HashSet[string]]::new([StringComparer]::OrdinalIgnoreCase)
    foreach ($match in [regex]::Matches($existing.Text, '(?m)^([0-9a-fA-F]{64})\s+')) { [void]$known.Add($match.Groups[1].Value) }
    $files = @(Get-ChildItem -LiteralPath $SourceFolder -File | Where-Object { $_.Extension.ToLowerInvariant() -in @('.jpg','.jpeg','.jfif','.png','.webp') })
    $added = 0; $skipped = 0
    foreach ($file in $files) {
        $hash = (Get-FileHash -LiteralPath $file.FullName -Algorithm SHA256).Hash.ToLowerInvariant()
        if ($known.Contains($hash)) { $skipped++; continue }
        $extension = $file.Extension.ToLowerInvariant()
        if ($extension -eq '.jfif') { $extension = '.jpg' }
        $remote = '/sdcard/Pictures/HaruTest/pc-' + $hash + $extension
        $copy = Invoke-Device -DeviceArgs @('-s', $serial, 'push', $file.FullName, $remote)
        if ($copy.Code -ne 0) { throw '사진 복사를 완료하지 못했어요. 다시 실행하면 이미 넣은 사진은 건너뛰어요.' }
        $verify = Invoke-Device -DeviceArgs @('-s', $serial, 'shell', 'sha256sum', $remote)
        if ($verify.Code -ne 0 -or !$verify.Text.StartsWith($hash)) { throw '복사된 사진 확인에 실패했어요. 다시 실행해 주세요.' }
        $scan = Invoke-Device -DeviceArgs @('-s', $serial, 'shell', 'am', 'broadcast', '-a', 'android.intent.action.MEDIA_SCANNER_SCAN_FILE', '-d', ('file://'+$remote))
        if ($scan.Code -ne 0) { throw '사진은 복사됐지만 사진함 등록을 완료하지 못했어요. 이 채팅에 알려 주세요.' }
        [void]$known.Add($hash)
        $added++
    }
    if ($Quiet) { [PSCustomObject]@{ Added=$added; AlreadyPresent=$skipped; PhotosInFolder=$files.Count } | ConvertTo-Json }
    else {
        Add-Type -AssemblyName System.Windows.Forms
        [System.Windows.Forms.MessageBox]::Show("새 사진 $added 장을 가상폰에 넣었어요.`n이미 있던 사진 $skipped 장은 건너뛰었어요.`n`n앱에서 사진 선택을 다시 열면 보여요.`nPC 원본과 기존 가상폰 사진은 삭제하지 않아요.", '하루 조각 · 사진 가져오기', 'OK', 'Information') | Out-Null
    }
} catch {
    if ($Quiet) { throw }
    Add-Type -AssemblyName System.Windows.Forms
    [System.Windows.Forms.MessageBox]::Show($_.Exception.Message, '하루 조각 · 사진 가져오기', 'OK', 'Information') | Out-Null
}
