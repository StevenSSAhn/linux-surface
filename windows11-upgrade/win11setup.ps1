<#
.SYNOPSIS
    Windows 11 ISO 를 마운트하고 요구 사항 검사를 우회하는 방식으로 setup.exe 를 실행합니다.

.DESCRIPTION
    win11enable.ps1 로 레지스트리를 설정한 뒤에도 설치 관리자가 막을 때 사용합니다.
    세 가지 방식 중 하나를 고를 수 있습니다.

      Registry     레지스트리 우회만 믿고 setup.exe 를 그대로 실행 (기본값, 가장 깔끔)
      ProductServer setup.exe /product server 로 실행. 설치 관리자가 서버 설치 경로를 타면서
                    TPM/CPU 호환성 검사를 건너뜁니다. 최근 빌드에서는 막힐 수 있습니다.
      AppraiserRes ISO 내용을 임시 폴더로 복사한 뒤 호환성 검사 모듈
                   (sources\appraiserres.dll) 을 빈 파일로 교체해 실행합니다.
                   가장 확실하지만 여유 공간이 약 10GB 필요합니다.

.PARAMETER IsoPath
    Windows 11 ISO 파일 경로. 생략하면 다운로드 폴더에서 자동으로 찾습니다.

.PARAMETER Method
    Registry | ProductServer | AppraiserRes

.PARAMETER WorkDir
    AppraiserRes 방식에서 ISO 내용을 풀어 놓을 폴더. 기본값은 시스템 드라이브의 Win11Setup.

.EXAMPLE
    powershell -ExecutionPolicy Bypass -File .\win11setup.ps1

.EXAMPLE
    powershell -ExecutionPolicy Bypass -File .\win11setup.ps1 -IsoPath D:\Win11.iso -Method AppraiserRes
#>

[CmdletBinding()]
param(
    [string]$IsoPath,
    [ValidateSet('Registry', 'ProductServer', 'AppraiserRes')]
    [string]$Method = 'Registry',
    [string]$WorkDir = (Join-Path $env:SystemDrive 'Win11Setup')
)

$ErrorActionPreference = 'Stop'

$isAdmin = ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()
           ).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
if (-not $isAdmin) {
    Write-Host '[X] 관리자 권한이 필요합니다. PowerShell 을 관리자로 실행하세요.' -ForegroundColor Red
    exit 1
}

# --- ISO 찾기 ----------------------------------------------------------------
if (-not $IsoPath) {
    $searchDirs = @(
        (Join-Path $env:USERPROFILE 'Downloads'),
        (Join-Path $env:USERPROFILE 'Desktop'),
        $PSScriptRoot
    ) | Where-Object { $_ -and (Test-Path $_) }

    $candidate = Get-ChildItem -Path $searchDirs -Filter '*.iso' -File -ErrorAction SilentlyContinue |
                 Sort-Object LastWriteTime -Descending |
                 Select-Object -First 1
    if (-not $candidate) {
        Write-Host '[X] ISO 파일을 찾지 못했습니다.' -ForegroundColor Red
        Write-Host '    https://www.microsoft.com/software-download/windows11 에서 내려받은 뒤'
        Write-Host '    -IsoPath "C:\경로\Win11.iso" 로 경로를 직접 지정하세요.'
        exit 1
    }
    $IsoPath = $candidate.FullName
    Write-Host ("[i] ISO 자동 선택: {0}" -f $IsoPath) -ForegroundColor DarkGray
}

if (-not (Test-Path $IsoPath)) {
    Write-Host ("[X] 파일이 없습니다: {0}" -f $IsoPath) -ForegroundColor Red
    exit 1
}
$IsoPath = (Resolve-Path $IsoPath).Path

# --- 마운트 ------------------------------------------------------------------
Write-Host ''
Write-Host ("ISO 마운트 중: {0}" -f $IsoPath) -ForegroundColor Cyan
$image = Mount-DiskImage -ImagePath $IsoPath -PassThru
Start-Sleep -Seconds 2
$driveLetter = ($image | Get-Volume).DriveLetter
if (-not $driveLetter) {
    Write-Host '[X] 마운트된 드라이브 문자를 확인하지 못했습니다.' -ForegroundColor Red
    Dismount-DiskImage -ImagePath $IsoPath | Out-Null
    exit 1
}
$mountRoot = "${driveLetter}:\"
Write-Host ("  → {0}" -f $mountRoot) -ForegroundColor Green

$setupExe = Join-Path $mountRoot 'setup.exe'
if (-not (Test-Path $setupExe)) {
    Write-Host '[X] ISO 안에서 setup.exe 를 찾지 못했습니다. Windows 11 설치 ISO 가 맞는지 확인하세요.' -ForegroundColor Red
    Dismount-DiskImage -ImagePath $IsoPath | Out-Null
    exit 1
}

try {
    switch ($Method) {

        'Registry' {
            Write-Host ''
            Write-Host '방식: 레지스트리 우회 + 기본 setup.exe' -ForegroundColor Cyan
            Write-Host '설치 관리자를 실행합니다. "설정, 개인 파일 및 앱 유지"를 선택하세요.'
            Start-Process -FilePath $setupExe -Wait
        }

        'ProductServer' {
            Write-Host ''
            Write-Host '방식: setup.exe /product server' -ForegroundColor Cyan
            Write-Host '설치 관리자가 호환성 검사를 건너뜁니다. 설치 후에도 에디션은 그대로 유지됩니다.'
            Start-Process -FilePath $setupExe -ArgumentList '/product', 'server' -Wait
        }

        'AppraiserRes' {
            Write-Host ''
            Write-Host '방식: appraiserres.dll 교체' -ForegroundColor Cyan

            $freeGB = [math]::Round((Get-Volume -DriveLetter $WorkDir[0]).SizeRemaining / 1GB, 1)
            if ($freeGB -lt 10) {
                Write-Host ("[X] 여유 공간이 부족합니다 ({0}GB). 10GB 이상 필요합니다." -f $freeGB) -ForegroundColor Red
                return
            }

            if (Test-Path $WorkDir) {
                Write-Host ("[i] 기존 작업 폴더를 비웁니다: {0}" -f $WorkDir) -ForegroundColor DarkGray
                Remove-Item $WorkDir -Recurse -Force
            }
            New-Item -Path $WorkDir -ItemType Directory -Force | Out-Null

            Write-Host 'ISO 내용을 복사하는 중입니다. 몇 분 걸릴 수 있습니다...'
            Copy-Item -Path (Join-Path $mountRoot '*') -Destination $WorkDir -Recurse -Force

            # 호환성 검사 모듈을 0바이트 파일로 교체하면 검사 자체가 수행되지 않습니다.
            $appraiser = Join-Path $WorkDir 'sources\appraiserres.dll'
            if (Test-Path $appraiser) {
                [System.IO.File]::WriteAllBytes($appraiser, [byte[]]@())
                Write-Host '  appraiserres.dll 을 빈 파일로 교체했습니다.' -ForegroundColor Green
            } else {
                Write-Host '  [!] appraiserres.dll 이 없습니다. 레지스트리 우회에 의존합니다.' -ForegroundColor Yellow
            }

            $localSetup = Join-Path $WorkDir 'setup.exe'
            Write-Host '설치 관리자를 실행합니다. "설정, 개인 파일 및 앱 유지"를 선택하세요.'
            Start-Process -FilePath $localSetup -ArgumentList '/product', 'server' -Wait
        }
    }
}
finally {
    Write-Host ''
    Write-Host 'ISO 마운트를 해제합니다.' -ForegroundColor DarkGray
    Dismount-DiskImage -ImagePath $IsoPath | Out-Null
}

Write-Host ''
Write-Host '설치 관리자가 종료되었습니다.' -ForegroundColor Green
if ($Method -eq 'AppraiserRes') {
    Write-Host ("업그레이드가 끝나면 작업 폴더를 삭제해 공간을 회수하세요: {0}" -f $WorkDir) -ForegroundColor DarkGray
}
Write-Host ''
