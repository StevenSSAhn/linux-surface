<#
.SYNOPSIS
    Windows 11 설치 관리자의 하드웨어 요구 사항 검사를 우회하도록 레지스트리를 설정합니다.

.DESCRIPTION
    아래 두 가지 키를 설정합니다.

    1) HKLM\SYSTEM\Setup\MoSetup\AllowUpgradesWithUnsupportedTPMOrCPU = 1
       Microsoft 가 공식 문서에서 안내하는 값입니다. TPM 1.2 이상 + 보안 부팅이 켜져 있는
       상태에서 "지원되지 않는 CPU" 때문에 막힐 때 인플레이스 업그레이드를 허용합니다.

    2) HKLM\SYSTEM\Setup\LabConfig\Bypass*Check = 1
       설치 관리자(setup.exe)가 참조하는 검사 우회 값입니다. TPM 자체가 없거나
       보안 부팅을 켤 수 없는 환경에서 사용합니다.

    변경 전 값을 자동으로 백업하며, -Revert 로 원상 복구할 수 있습니다.

.PARAMETER Revert
    이 스크립트가 추가한 값을 제거하고 원래 상태로 되돌립니다.

.PARAMETER OfficialOnly
    Microsoft 공식 키(MoSetup)만 적용하고 LabConfig 우회는 건너뜁니다.

.EXAMPLE
    # 관리자 PowerShell 에서
    powershell -ExecutionPolicy Bypass -File .\win11enable.ps1

.EXAMPLE
    powershell -ExecutionPolicy Bypass -File .\win11enable.ps1 -Revert

.NOTES
    요구 사항을 충족하지 않는 PC 에 Windows 11 을 설치하면 제조사/Microsoft 의 지원 대상에서
    제외되며, 업데이트 제공이 보장되지 않습니다. 진행 전 반드시 중요한 데이터를 백업하세요.
#>

[CmdletBinding(SupportsShouldProcess = $true)]
param(
    [switch]$Revert,
    [switch]$OfficialOnly
)

$ErrorActionPreference = 'Stop'

# --- 관리자 권한 확인 --------------------------------------------------------
$isAdmin = ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()
           ).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
if (-not $isAdmin) {
    Write-Host '[X] 관리자 권한이 필요합니다.' -ForegroundColor Red
    Write-Host '    시작 메뉴에서 PowerShell 을 마우스 우클릭 → "관리자 권한으로 실행" 후 다시 시도하세요.' -ForegroundColor Red
    exit 1
}

$moSetupPath   = 'HKLM:\SYSTEM\Setup\MoSetup'
$labConfigPath = 'HKLM:\SYSTEM\Setup\LabConfig'

$officialValues = @{
    Path   = $moSetupPath
    Values = @{ 'AllowUpgradesWithUnsupportedTPMOrCPU' = 1 }
}

$labConfigValues = @{
    Path   = $labConfigPath
    Values = @{
        'BypassTPMCheck'        = 1   # TPM 없음/1.2
        'BypassSecureBootCheck' = 1   # 보안 부팅 꺼짐
        'BypassCPUCheck'        = 1   # 지원 목록에 없는 CPU
        'BypassRAMCheck'        = 1   # 메모리 4GB 미만
        'BypassStorageCheck'    = 1   # 디스크 64GB 미만
    }
}

$targets = if ($OfficialOnly) { @($officialValues) } else { @($officialValues, $labConfigValues) }

$backupDir  = Join-Path $env:USERPROFILE 'Win11BypassBackup'
$backupFile = Join-Path $backupDir ('registry-backup-{0}.reg' -f (Get-Date -Format 'yyyyMMdd-HHmmss'))

function Backup-Keys {
    if (-not (Test-Path $backupDir)) {
        New-Item -Path $backupDir -ItemType Directory -Force | Out-Null
    }
    # reg.exe export 는 키가 없으면 실패하므로 존재하는 키만 내보냅니다.
    $exported = $false
    foreach ($t in $targets) {
        if (Test-Path $t.Path) {
            $native = $t.Path -replace '^HKLM:', 'HKLM'
            $tmp = Join-Path ([System.IO.Path]::GetTempPath()) ([System.IO.Path]::GetRandomFileName() + '.reg')
            & reg.exe export $native $tmp /y | Out-Null
            if ($LASTEXITCODE -eq 0) {
                Get-Content $tmp | Add-Content -Path $backupFile
                $exported = $true
            }
            Remove-Item $tmp -ErrorAction SilentlyContinue
        }
    }
    if ($exported) {
        Write-Host ("[i] 변경 전 상태를 백업했습니다: {0}" -f $backupFile) -ForegroundColor DarkGray
    } else {
        Write-Host '[i] 백업할 기존 키가 없습니다 (새로 생성됨).' -ForegroundColor DarkGray
    }
}

# --- 되돌리기 ----------------------------------------------------------------
if ($Revert) {
    Write-Host ''
    Write-Host '=== 우회 설정 제거 ===' -ForegroundColor Cyan
    foreach ($t in $targets) {
        if (-not (Test-Path $t.Path)) { continue }
        foreach ($name in $t.Values.Keys) {
            $existing = Get-ItemProperty -Path $t.Path -Name $name -ErrorAction SilentlyContinue
            if ($null -ne $existing) {
                if ($PSCmdlet.ShouldProcess("$($t.Path)\$name", '삭제')) {
                    Remove-ItemProperty -Path $t.Path -Name $name -Force
                    Write-Host ("  제거됨: {0}\{1}" -f $t.Path, $name) -ForegroundColor Green
                }
            }
        }
    }
    # LabConfig 는 이 우회 용도로만 쓰이므로, 비어 있으면 키까지 정리합니다.
    if (-not $OfficialOnly -and (Test-Path $labConfigPath)) {
        $remaining = (Get-Item $labConfigPath).Property
        if (-not $remaining -and $PSCmdlet.ShouldProcess($labConfigPath, '빈 키 삭제')) {
            Remove-Item $labConfigPath -Force
            Write-Host ("  제거됨: {0} (빈 키)" -f $labConfigPath) -ForegroundColor Green
        }
    }
    Write-Host ''
    Write-Host '원래 상태로 되돌렸습니다.' -ForegroundColor Green
    exit 0
}

# --- 적용 --------------------------------------------------------------------
Write-Host ''
Write-Host '=== Windows 11 업그레이드 검사 우회 적용 ===' -ForegroundColor Cyan
Write-Host ''
Write-Host '주의: 요구 사항 미충족 PC 에 Windows 11 을 설치하면 제조사/Microsoft 지원 대상에서' -ForegroundColor Yellow
Write-Host '      제외되고 업데이트 제공이 보장되지 않습니다. 중요한 데이터는 먼저 백업하세요.' -ForegroundColor Yellow
Write-Host ''

Backup-Keys

foreach ($t in $targets) {
    if (-not (Test-Path $t.Path)) {
        if ($PSCmdlet.ShouldProcess($t.Path, '키 생성')) {
            New-Item -Path $t.Path -Force | Out-Null
        }
    }
    foreach ($name in $t.Values.Keys) {
        if ($PSCmdlet.ShouldProcess("$($t.Path)\$name", "DWORD $($t.Values[$name]) 설정")) {
            New-ItemProperty -Path $t.Path -Name $name -Value $t.Values[$name] `
                             -PropertyType DWord -Force | Out-Null
            Write-Host ("  설정됨: {0}\{1} = {2}" -f $t.Path, $name, $t.Values[$name]) -ForegroundColor Green
        }
    }
}

Write-Host ''
Write-Host '적용이 끝났습니다. 이제 다음 순서로 업그레이드하세요.' -ForegroundColor Cyan
Write-Host ''
Write-Host '  1. Microsoft 공식 페이지에서 Windows 11 디스크 이미지(ISO) 를 내려받습니다.'
Write-Host '     https://www.microsoft.com/software-download/windows11'
Write-Host '  2. 내려받은 ISO 파일을 더블클릭해 가상 드라이브로 마운트합니다.'
Write-Host '  3. 마운트된 드라이브의 setup.exe 를 실행합니다.'
Write-Host '     (Windows Update 나 "설치 도우미"가 아니라 ISO 의 setup.exe 여야 우회가 적용됩니다.)'
Write-Host '  4. "설정, 개인 파일 및 앱 유지"를 선택하면 기존 환경 그대로 업그레이드됩니다.'
Write-Host ''
Write-Host '  같은 폴더의 win11setup.ps1 을 쓰면 2~3 단계를 자동으로 처리합니다.' -ForegroundColor DarkGray
Write-Host ''
