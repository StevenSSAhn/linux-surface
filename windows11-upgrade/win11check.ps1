<#
.SYNOPSIS
    Windows 11 업그레이드 차단 원인을 진단합니다.

.DESCRIPTION
    "이 PC는 현재 Windows 11 시스템 요구 사항을 충족하지 않습니다" 메시지가 나올 때
    정확히 어떤 항목이 걸리는지 하나씩 검사합니다. 읽기만 하며 시스템을 변경하지 않습니다.

    각 검사는 개별적으로 오류를 처리하므로, 한 항목이 실패해도 나머지 결과는 그대로
    출력됩니다. 결과는 화면과 win11-report.txt 파일에 동시에 기록됩니다.

.EXAMPLE
    powershell -ExecutionPolicy Bypass -File .\win11check.ps1
#>

[CmdletBinding()]
param(
    [string]$ReportPath = (Join-Path $PSScriptRoot 'win11-report.txt')
)

# 개별 검사마다 try/catch 로 처리하므로 전역 침묵 설정은 두지 않습니다.
$ErrorActionPreference = 'Continue'

$script:lines = New-Object System.Collections.Generic.List[string]

function Out-Line {
    param([string]$Text = '', [string]$Color = 'Gray')
    $script:lines.Add($Text)
    if ($Color -eq 'Gray') { Write-Host $Text } else { Write-Host $Text -ForegroundColor $Color }
}

$script:results = New-Object System.Collections.Generic.List[object]

function Add-Result {
    param(
        [string]$Item,
        [string]$Required,
        [string]$Current,
        [string]$Status,
        [string]$Note = ''
    )
    # 예외 메시지는 여러 줄일 수 있어 표가 깨지므로 한 줄로 접고 길이를 제한합니다.
    $clean = ($Note -replace '\s*\r?\n\s*', ' ').Trim()
    if ($clean.Length -gt 46) { $clean = $clean.Substring(0, 45) + '~' }
    $script:results.Add([pscustomobject]@{
        Item = $Item; Required = $Required; Current = $Current; Status = $Status; Note = $clean
    })
}

# 검사 하나를 안전하게 실행합니다. 예외가 나면 '확인불가' 로 기록하고 계속 진행합니다.
function Invoke-Check {
    param([string]$Name, [scriptblock]$Body)
    try {
        & $Body
    } catch {
        Add-Result $Name '-' '검사 중 오류' '확인불가' $_.Exception.Message
        Write-Host ("  [!] '{0}' 검사 실패: {1}" -f $Name, $_.Exception.Message) -ForegroundColor DarkYellow
    }
}

Out-Line ''
Out-Line '=== Windows 11 업그레이드 요구 사항 진단 ===' 'Cyan'
Out-Line ("실행 시각: {0}" -f (Get-Date -Format 'yyyy-MM-dd HH:mm:ss'))
Out-Line ("PowerShell: {0}" -f $PSVersionTable.PSVersion)
Out-Line ''

$isAdmin = $false
try {
    $id = [Security.Principal.WindowsIdentity]::GetCurrent()
    $isAdmin = (New-Object Security.Principal.WindowsPrincipal($id)).IsInRole(
                   [Security.Principal.WindowsBuiltInRole]::Administrator)
} catch { }

if (-not $isAdmin) {
    Out-Line '[!] 관리자 권한이 아닙니다. TPM/보안 부팅이 "확인불가"로 나올 수 있습니다.' 'Yellow'
    Out-Line ''
}

# --- 장치 / OS ---------------------------------------------------------------
$os = $null; $cs = $null
Invoke-Check '장치 정보' {
    $script:os = Get-CimInstance Win32_OperatingSystem -ErrorAction Stop
    $script:cs = Get-CimInstance Win32_ComputerSystem -ErrorAction Stop
    Out-Line ("장치    : {0} {1}" -f $script:cs.Manufacturer, $script:cs.Model)
    Out-Line ("현재 OS : {0} (빌드 {1})" -f $script:os.Caption, $script:os.BuildNumber)
    Out-Line ''
}

Invoke-Check '현재 OS' {
    if (-not $script:os) {
        Add-Result '현재 OS' 'Windows 10 빌드 19041 이상' '조회 실패' '확인불가' '위의 장치 정보 오류 참고'
        return
    }
    $build = [int]$script:os.BuildNumber
    if ($build -ge 22000) {
        Add-Result '현재 OS' 'Windows 10 빌드 19041 이상' "빌드 $build" '통과' '이미 Windows 11 입니다'
    } elseif ($build -ge 19041) {
        Add-Result '현재 OS' 'Windows 10 빌드 19041 이상' "빌드 $build" '통과'
    } else {
        Add-Result '현재 OS' 'Windows 10 빌드 19041 이상' "빌드 $build" '실패' '먼저 Windows 10 22H2로 업데이트'
    }
}

# --- CPU ---------------------------------------------------------------------
Invoke-Check 'CPU' {
    $cpu = Get-CimInstance Win32_Processor -ErrorAction Stop | Select-Object -First 1
    $cores = $cpu.NumberOfCores
    $speed = $cpu.MaxClockSpeed
    $arch  = switch ($cpu.Architecture) { 0 {'x86'} 9 {'x64'} 12 {'ARM64'} default {"코드 $($cpu.Architecture)"} }

    $cpuOk = ($cores -ge 2) -and ($speed -ge 1000) -and ($arch -in @('x64', 'ARM64'))
    Add-Result 'CPU 코어/클럭' '2코어 / 1GHz / 64비트' ("{0}코어, {1}MHz, {2}" -f $cores, $speed, $arch) `
               $(if ($cpuOk) { '통과' } else { '실패' })

    # 공식 지원 CPU 목록 여부는 모델명으로 대략 추정합니다.
    # Intel: 8세대 이상, AMD: Ryzen 2000 시리즈 이상이 공식 지원선입니다.
    $cpuName   = $cpu.Name
    $genNote   = '공식 지원 목록은 Microsoft 문서 확인'
    $genStatus = '확인불가'

    if ($cpuName -match 'Core.*Ultra') {
        $genStatus = '통과'; $genNote = 'Core Ultra 시리즈 (공식 지원)'
    }
    elseif ($cpuName -match 'Intel.*i[3579][- ](\d{3,5})') {
        $model = $Matches[1]
        # 5자리(12700K)는 앞 두 자리, 4자리 중 1로 시작(1065G7/1240P)은 10~14세대라 앞 두 자리,
        # 그 밖의 4자리(8250U)는 앞 한 자리, 3자리(920)는 1세대입니다.
        $gen = switch ($model.Length) {
            5       { [int]$model.Substring(0, 2) }
            4       { if ($model.StartsWith('1')) { [int]$model.Substring(0, 2) } else { [int]$model.Substring(0, 1) } }
            default { 1 }
        }
        $genStatus = if ($gen -ge 8) { '통과' } else { '실패' }
        $genNote   = "Intel 추정 {0}세대 (8세대 이상 지원)" -f $gen
    }
    elseif ($cpuName -match 'Ryzen\s+AI') {
        $genStatus = '통과'; $genNote = 'Ryzen AI 시리즈 (공식 지원)'
    }
    elseif ($cpuName -match 'Ryzen\s+\d+\s+(\d{4})') {
        $series    = [int]$Matches[1].Substring(0, 1)
        $genStatus = if ($series -ge 2) { '통과' } else { '실패' }
        $genNote   = "Ryzen 추정 {0}000 시리즈 (2000 이상 지원)" -f $series
    }
    elseif ($cpuName -match 'Snapdragon|Microsoft SQ') {
        $genStatus = '통과'; $genNote = 'ARM64 (공식 지원)'
    }

    Add-Result 'CPU 지원 목록' '지원 CPU 목록에 포함' $cpuName $genStatus $genNote
}

# --- 메모리 ------------------------------------------------------------------
Invoke-Check '메모리' {
    if (-not $script:cs) {
        Add-Result '메모리' '4GB 이상' '조회 실패' '확인불가' '위의 장치 정보 오류 참고'
        return
    }
    $ramGB = [math]::Round($script:cs.TotalPhysicalMemory / 1GB, 1)
    Add-Result '메모리' '4GB 이상' "${ramGB}GB" $(if ($ramGB -ge 3.5) { '통과' } else { '실패' })
}

# --- 디스크 ------------------------------------------------------------------
Invoke-Check '디스크' {
    $sysLetter = $env:SystemDrive.TrimEnd(':')
    $vol = Get-Volume -DriveLetter $sysLetter -ErrorAction Stop
    $sizeGB = [math]::Round($vol.Size / 1GB, 1)
    $freeGB = [math]::Round($vol.SizeRemaining / 1GB, 1)
    Add-Result '시스템 디스크' '64GB 이상' "${sizeGB}GB" $(if ($sizeGB -ge 64) { '통과' } else { '실패' })
    # 인플레이스 업그레이드에는 실사용상 20GB 이상의 여유가 필요합니다.
    Add-Result '디스크 여유 공간' '20GB 이상 권장' "${freeGB}GB" $(if ($freeGB -ge 20) { '통과' } else { '실패' }) '업그레이드 작업 공간'
}

# --- 펌웨어 / 파티션 ---------------------------------------------------------
Invoke-Check '펌웨어 모드' {
    $firmware = $env:firmware_type
    if (-not $firmware) {
        # UEFI 시스템에만 존재하는 레지스트리 키로 대체 판정합니다.
        $firmware = if (Test-Path 'HKLM:\System\CurrentControlSet\Control\SecureBoot\State') { 'UEFI' } else { '알 수 없음' }
    }
    $status = if ($firmware -eq 'UEFI') { '통과' } elseif ($firmware -eq '알 수 없음') { '확인불가' } else { '실패' }
    Add-Result '펌웨어 모드' 'UEFI' $firmware $status 'Legacy BIOS면 MBR2GPT 변환 필요'
}

Invoke-Check '파티션 방식' {
    $sysLetter = $env:SystemDrive.TrimEnd(':')
    $disk = Get-Partition -DriveLetter $sysLetter -ErrorAction Stop | Get-Disk -ErrorAction Stop
    Add-Result '파티션 방식' 'GPT' $disk.PartitionStyle `
               $(if ($disk.PartitionStyle -eq 'GPT') { '통과' } else { '실패' }) `
               'MBR이면 mbr2gpt.exe 로 변환'
}

# --- 보안 부팅 ---------------------------------------------------------------
Invoke-Check '보안 부팅' {
    try {
        $sb = Confirm-SecureBootUEFI -ErrorAction Stop
        Add-Result '보안 부팅' '사용' $(if ($sb) { '사용' } else { '사용 안 함' }) `
                   $(if ($sb) { '통과' } else { '실패' }) 'UEFI 설정에서 켤 수 있음'
    } catch {
        # Legacy BIOS 부팅이거나 cmdlet 을 쓸 수 없는 경우입니다.
        Add-Result '보안 부팅' '사용' '조회 불가' '확인불가' 'UEFI 부팅이 아닐 수 있음'
    }
}

# --- TPM ---------------------------------------------------------------------
Invoke-Check 'TPM' {
    $tpm = Get-CimInstance -Namespace 'root\cimv2\security\microsofttpm' -ClassName Win32_Tpm -ErrorAction Stop
    if ($tpm) {
        $ver = ($tpm.SpecVersion -split ',')[0].Trim()
        $verNum = 0.0; [double]::TryParse($ver, [ref]$verNum) | Out-Null
        $ready = $tpm.IsEnabled_InitialValue -and $tpm.IsActivated_InitialValue
        $cur = "버전 $ver, 사용 " + $(if ($tpm.IsEnabled_InitialValue) { '함' } else { '안 함' })
        $status = if ($ready -and $verNum -ge 2.0) { '통과' } else { '실패' }
        Add-Result 'TPM' '2.0, 사용 상태' $cur $status $(if (-not $ready) { 'UEFI 설정에서 활성화 필요' } else { '' })
    } else {
        Add-Result 'TPM' '2.0, 사용 상태' '감지되지 않음' '실패' 'UEFI 설정에서 활성화하거나 우회'
    }
}

# --- 결과 출력 ---------------------------------------------------------------
# Format-Table 에 의존하지 않고 직접 정렬해 출력합니다.
Out-Line ''
Out-Line ('-' * 78)
Out-Line ("{0,-18} {1,-24} {2,-8} {3}" -f '항목', '현재값', '판정', '비고')
Out-Line ('-' * 78)

foreach ($r in $script:results) {
    $color = switch ($r.Status) { '통과' { 'Green' } '실패' { 'Red' } default { 'DarkYellow' } }
    $cur = if ($r.Current.Length -gt 23) { $r.Current.Substring(0, 22) + '~' } else { $r.Current }
    Out-Line ("{0,-18} {1,-24} {2,-8} {3}" -f $r.Item, $cur, $r.Status, $r.Note) $color
}
Out-Line ('-' * 78)

if ($script:results.Count -eq 0) {
    Out-Line ''
    Out-Line '[X] 검사 결과가 하나도 수집되지 않았습니다. 위의 오류 메시지를 확인하세요.' 'Red'
}

$failed  = @($script:results | Where-Object { $_.Status -eq '실패' })
$unknown = @($script:results | Where-Object { $_.Status -eq '확인불가' })
Out-Line ''
if ($failed.Count -gt 0) {
    Out-Line '차단 원인으로 보이는 항목:' 'Yellow'
    foreach ($f in $failed) { Out-Line ("  - {0} (현재: {1})" -f $f.Item, $f.Current) 'Yellow' }
    Out-Line ''
    Out-Line '다음 단계:' 'Cyan'
    Out-Line '  1) TPM / 보안 부팅이 "사용 안 함"이면 먼저 UEFI 설정에서 켜 보세요 (우회보다 안전).'
    Out-Line '  2) 그래도 막히면 win11enable.ps1 을 관리자 권한으로 실행해 검사 우회를 적용하세요.'
} elseif ($unknown.Count -gt 0) {
    # '실패' 는 없지만 확인하지 못한 항목이 있으면 통과로 단정할 수 없습니다.
    Out-Line '확인하지 못한 항목이 있습니다:' 'DarkYellow'
    foreach ($u in $unknown) { Out-Line ("  - {0}: {1}" -f $u.Item, $u.Note) 'DarkYellow' }
    Out-Line ''
    Out-Line '관리자 권한 PowerShell 에서 다시 실행해 보세요. 그래도 같다면 위 비고의' 'DarkYellow'
    Out-Line '오류 메시지를 그대로 전달해 주세요.' 'DarkYellow'
} elseif ($script:results.Count -gt 0) {
    Out-Line '요구 사항을 모두 충족합니다. 업그레이드가 막힌다면 단계 배포 대기 중일 수 있으니' 'Green'
    Out-Line 'ISO 로 직접 업그레이드해 보세요.' 'Green'
}

# --- 파일 저장 ---------------------------------------------------------------
try {
    $script:lines | Out-File -FilePath $ReportPath -Encoding UTF8 -Force
    Out-Line ''
    Out-Line ("결과를 파일로도 저장했습니다: {0}" -f $ReportPath) 'DarkGray'
    Out-Line '이 파일 내용을 복사해서 전달하시면 됩니다.' 'DarkGray'
} catch {
    Write-Host ("[!] 보고서 저장 실패: {0}" -f $_.Exception.Message) -ForegroundColor DarkYellow
}
Out-Line ''
