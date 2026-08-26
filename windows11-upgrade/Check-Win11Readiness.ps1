<#
.SYNOPSIS
    Windows 11 업그레이드 차단 원인을 진단합니다.

.DESCRIPTION
    "이 PC는 현재 Windows 11 시스템 요구 사항을 충족하지 않습니다" 메시지가 나올 때
    정확히 어떤 항목이 걸리는지 하나씩 검사해서 표로 보여 줍니다.
    읽기만 하며 시스템을 변경하지 않습니다. 관리자 권한으로 실행하면 더 정확합니다.

.EXAMPLE
    powershell -ExecutionPolicy Bypass -File .\Check-Win11Readiness.ps1
#>

[CmdletBinding()]
param()

$ErrorActionPreference = 'SilentlyContinue'
$results = New-Object System.Collections.Generic.List[object]

function Add-Result {
    param(
        [string]$Item,
        [string]$Required,
        [string]$Current,
        [ValidateSet('통과', '실패', '확인불가')][string]$Status,
        [string]$Note = ''
    )
    $results.Add([pscustomobject]@{
        항목    = $Item
        요구사항 = $Required
        현재값  = $Current
        판정    = $Status
        비고    = $Note
    })
}

Write-Host ''
Write-Host '=== Windows 11 업그레이드 요구 사항 진단 ===' -ForegroundColor Cyan
Write-Host ''

$isAdmin = ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()
           ).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
if (-not $isAdmin) {
    Write-Host '[!] 관리자 권한이 아닙니다. TPM/보안 부팅 항목이 "확인불가"로 나올 수 있습니다.' -ForegroundColor Yellow
    Write-Host ''
}

# --- 현재 OS -----------------------------------------------------------------
$os = Get-CimInstance Win32_OperatingSystem
$cs = Get-CimInstance Win32_ComputerSystem
Write-Host ("장치        : {0} {1}" -f $cs.Manufacturer, $cs.Model)
Write-Host ("현재 OS     : {0} (빌드 {1})" -f $os.Caption, $os.BuildNumber)
Write-Host ''

# 업그레이드는 Windows 10 2004(19041) 이상에서만 인플레이스로 진행됩니다.
$build = [int]$os.BuildNumber
if ($build -ge 22000) {
    Add-Result '현재 OS' 'Windows 10 19041+' "빌드 $build" '통과' '이미 Windows 11 입니다'
} elseif ($build -ge 19041) {
    Add-Result '현재 OS' 'Windows 10 19041+' "빌드 $build" '통과'
} else {
    Add-Result '현재 OS' 'Windows 10 19041+' "빌드 $build" '실패' '먼저 Windows 10 22H2로 업데이트하세요'
}

# --- CPU ---------------------------------------------------------------------
$cpu = Get-CimInstance Win32_Processor | Select-Object -First 1
$cores = $cpu.NumberOfCores
$speed = $cpu.MaxClockSpeed
$arch  = switch ($cpu.Architecture) { 0 {'x86'} 9 {'x64'} 12 {'ARM64'} default {"코드 $($cpu.Architecture)"} }

$cpuOk = ($cores -ge 2) -and ($speed -ge 1000) -and ($arch -in @('x64', 'ARM64'))
Add-Result 'CPU 코어/클럭' '2코어 이상 / 1GHz 이상 / 64비트' `
           ("{0}코어, {1}MHz, {2}" -f $cores, $speed, $arch) `
           $(if ($cpuOk) { '통과' } else { '실패' })

# 공식 지원 CPU 목록(세대) 여부는 모델명으로 대략 추정합니다.
# Intel: 8세대(Coffee Lake) 이상, AMD: Ryzen 2000 시리즈 이상이 공식 지원선입니다.
$cpuName   = $cpu.Name
$genNote   = '공식 지원 목록은 Microsoft 문서를 확인하세요'
$genStatus = '확인불가'

if ($cpuName -match 'Core.*Ultra') {
    # Core Ultra 시리즈는 전 모델이 공식 지원 대상입니다.
    $genStatus = '통과'
    $genNote   = 'Core Ultra 시리즈 (공식 지원)'
}
elseif ($cpuName -match 'Intel.*i[3579][- ](\d{3,5})') {
    $model = $Matches[1]
    # 5자리(12700K)는 앞 두 자리, 4자리 중 1로 시작(1065G7/1135G7/1240P)은 10~14세대라
    # 앞 두 자리, 그 밖의 4자리(8250U)는 앞 한 자리, 3자리(920)는 1세대입니다.
    $gen = switch ($model.Length) {
        5       { [int]$model.Substring(0, 2) }
        4       { if ($model.StartsWith('1')) { [int]$model.Substring(0, 2) } else { [int]$model.Substring(0, 1) } }
        default { 1 }
    }
    $genStatus = if ($gen -ge 8) { '통과' } else { '실패' }
    $genNote   = "Intel 추정 {0}세대 (8세대 이상이 공식 지원)" -f $gen
}
elseif ($cpuName -match 'Ryzen\s+AI') {
    # Ryzen AI 300 시리즈 등 최신 라인은 전 모델이 공식 지원 대상입니다.
    $genStatus = '통과'
    $genNote   = 'Ryzen AI 시리즈 (공식 지원)'
}
elseif ($cpuName -match 'Ryzen\s+\d+\s+(\d{4})') {
    # "Ryzen 5 2500U", "Ryzen 7 5800X" 처럼 등급 뒤 4자리 모델 번호의 첫 자리가 세대입니다.
    $series    = [int]$Matches[1].Substring(0, 1)
    $genStatus = if ($series -ge 2) { '통과' } else { '실패' }
    $genNote   = "Ryzen 추정 {0}000 시리즈 (2000 이상이 공식 지원)" -f $series
}
elseif ($cpuName -match 'Snapdragon|Microsoft SQ') {
    $genStatus = '통과'
    $genNote   = 'ARM64 (Snapdragon/SQ, 공식 지원)'
}

Add-Result 'CPU 공식 지원 목록' '지원 CPU 목록에 포함' $cpuName $genStatus $genNote

# --- 메모리 ------------------------------------------------------------------
$ramGB = [math]::Round($cs.TotalPhysicalMemory / 1GB, 1)
Add-Result '메모리' '4GB 이상' "${ramGB}GB" $(if ($ramGB -ge 3.5) { '통과' } else { '실패' })

# --- 시스템 디스크 -----------------------------------------------------------
$sysDrive = $env:SystemDrive.TrimEnd(':')
$vol = Get-Volume -DriveLetter $sysDrive
if ($vol) {
    $sizeGB = [math]::Round($vol.Size / 1GB, 1)
    $freeGB = [math]::Round($vol.SizeRemaining / 1GB, 1)
    Add-Result '시스템 디스크 용량' '64GB 이상' "${sizeGB}GB" $(if ($sizeGB -ge 64) { '통과' } else { '실패' })
    # 인플레이스 업그레이드에는 실사용상 20GB 이상의 여유가 필요합니다.
    Add-Result '디스크 여유 공간' '20GB 이상 권장' "${freeGB}GB" $(if ($freeGB -ge 20) { '통과' } else { '실패' }) '업그레이드 작업 공간'
}

# --- 펌웨어 / 파티션 ---------------------------------------------------------
$firmware = $env:firmware_type
if (-not $firmware) {
    # UEFI 시스템에만 존재하는 레지스트리 키로 대체 판정합니다.
    $firmware = if (Test-Path 'HKLM:\System\CurrentControlSet\Control\SecureBoot\State') { 'UEFI' } else { 'Unknown' }
}
$isUefi = ($firmware -eq 'UEFI')
Add-Result '펌웨어 모드' 'UEFI' $firmware $(if ($isUefi) { '통과' } elseif ($firmware -eq 'Unknown') { '확인불가' } else { '실패' }) `
           'Legacy BIOS면 MBR2GPT 변환 필요'

$sysDisk = Get-Partition -DriveLetter $sysDrive | Get-Disk
if ($sysDisk) {
    Add-Result '파티션 방식' 'GPT' $sysDisk.PartitionStyle `
               $(if ($sysDisk.PartitionStyle -eq 'GPT') { '통과' } else { '실패' }) `
               'MBR이면 mbr2gpt.exe 로 변환'
}

# --- 보안 부팅 ---------------------------------------------------------------
$sbStatus = '확인불가'; $sbCurrent = '알 수 없음'
try {
    $sb = Confirm-SecureBootUEFI -ErrorAction Stop
    $sbCurrent = if ($sb) { '사용' } else { '사용 안 함' }
    $sbStatus  = if ($sb) { '통과' } else { '실패' }
} catch {
    $sbCurrent = 'UEFI 아님 또는 조회 실패'
}
Add-Result '보안 부팅(Secure Boot)' '사용' $sbCurrent $sbStatus 'UEFI 설정에서 켤 수 있음'

# --- TPM ---------------------------------------------------------------------
$tpm = Get-CimInstance -Namespace 'root\cimv2\security\microsofttpm' -ClassName Win32_Tpm
if ($tpm) {
    $ver = ($tpm.SpecVersion -split ',')[0].Trim()
    $ready = $tpm.IsEnabled_InitialValue -and $tpm.IsActivated_InitialValue
    $cur = "버전 $ver, 사용 " + $(if ($tpm.IsEnabled_InitialValue) { '함' } else { '안 함' })
    $status = if ($ready -and [double]$ver -ge 2.0) { '통과' } else { '실패' }
    Add-Result 'TPM' '2.0 이상, 사용 상태' $cur $status $(if (-not $ready) { 'UEFI 설정에서 활성화 필요' } else { '' })
} else {
    Add-Result 'TPM' '2.0 이상, 사용 상태' '감지되지 않음' '실패' 'UEFI 설정에서 활성화하거나 우회 필요'
}

# --- 그래픽 ------------------------------------------------------------------
$gpu = Get-CimInstance Win32_VideoController | Select-Object -First 1
Add-Result '그래픽' 'DirectX 12 / WDDM 2.0' $gpu.Name '확인불가' '최근 10년 내 GPU면 대부분 통과'

# --- 출력 --------------------------------------------------------------------
$results | Format-Table -AutoSize -Wrap

$failed = $results | Where-Object { $_.판정 -eq '실패' }
Write-Host ''
if ($failed) {
    Write-Host '차단 원인으로 보이는 항목:' -ForegroundColor Yellow
    $failed | ForEach-Object { Write-Host ("  - {0} (현재: {1})" -f $_.항목, $_.현재값) -ForegroundColor Yellow }
    Write-Host ''
    Write-Host '다음 단계:' -ForegroundColor Cyan
    Write-Host '  1) TPM / 보안 부팅이 "사용 안 함"이면 먼저 UEFI 설정에서 켜 보세요 (우회보다 안전).'
    Write-Host '  2) 그래도 막히면 Enable-Win11Upgrade.ps1 을 관리자 권한으로 실행해 검사 우회를 적용하세요.'
} else {
    Write-Host '요구 사항을 모두 충족합니다. 업그레이드가 막힌다면 Windows Update 단계 배포 대기 중일 수 있습니다.' -ForegroundColor Green
    Write-Host 'Windows 11 설치 도우미 또는 ISO 로 바로 업그레이드할 수 있습니다.'
}
Write-Host ''
