# Windows 11 업그레이드 차단 우회

"이 PC는 현재 Windows 11 시스템 요구 사항을 충족하지 않습니다" 메시지로 업그레이드가
막힐 때, 원인을 진단하고 하드웨어 요구 사항 검사를 우회하는 스크립트 모음입니다.

> **먼저 읽어 주세요**
> - 요구 사항 미충족 PC 에 Windows 11 을 설치하면 제조사와 Microsoft 의 **지원 대상에서
>   제외**되며, 업데이트 제공이 보장되지 않습니다. 설치 화면에도 같은 경고가 뜹니다.
> - 실제로는 업데이트가 계속 오는 경우가 대부분이지만, 보장된 동작은 아닙니다.
> - 시작 전 **중요한 데이터를 반드시 백업**하세요.
> - 이 방법은 하드웨어 호환성 검사만 건너뜁니다. 정품 인증(라이선스)과는 무관하며,
>   Windows 10 정품 라이선스가 있어야 정상적으로 인증됩니다.

## 파일 구성

| 파일 | 용도 |
| --- | --- |
| `win11check.ps1` | 어떤 항목 때문에 막히는지 진단 (시스템 변경 없음) |
| `win11enable.ps1` | 검사 우회 레지스트리 적용 / `-Revert` 로 원복 |
| `win11setup.ps1` | ISO 마운트 후 우회 방식으로 설치 관리자 실행 |
| `win11bypass.reg` | PowerShell 없이 더블클릭으로 적용하는 레지스트리 파일 |
| `win11revert.reg` | 위 레지스트리 값 제거 |

## 사용 순서

### 0단계 — 스크립트를 PC 로 옮기기

이 폴더 전체를 대상 Windows PC 의 아무 폴더(예: `C:\win11`)에 복사합니다.

> 파일명에 하이픈을 쓰지 않은 이유: 일부 다운로드 경로가 파일명의 `-` 를 제거해
> `win11-check.ps1` 이 `win11check.ps1` 로 저장되면서 경로를 못 찾는 일이 있었습니다.
> 복사 후 `dir` 로 파일명이 아래 표와 같은지 먼저 확인하세요.

### 1단계 — 원인 진단

먼저 무엇이 막고 있는지 확인합니다. **PowerShell 을 관리자 권한으로** 열고:

```powershell
cd C:\win11
powershell -ExecutionPolicy Bypass -File .\win11check.ps1
```

CPU / 메모리 / 디스크 / UEFI / GPT / 보안 부팅 / TPM 항목을 표로 보여 주고,
"실패" 로 나온 항목이 바로 차단 원인입니다. 같은 내용이 `win11-report.txt` 로도
저장되므로 그 파일을 그대로 복사해 전달할 수 있습니다.

검사 항목 하나가 오류를 내도 나머지 결과는 그대로 출력되며, 오류 메시지는 `비고`
열에 표시됩니다. 표가 아예 안 나온다면 PowerShell 이 스크립트 파일을 못 찾은
경우이니 `dir` 로 파일명을 확인하세요.

### 2단계 — 우회하기 전에, UEFI 설정부터 확인

`TPM` 이나 `보안 부팅` 이 **"사용 안 함"** 으로 나왔다면 하드웨어는 멀쩡한데 꺼져 있을
뿐인 경우가 많습니다. 이때는 우회보다 **펌웨어에서 켜는 쪽이 안전하고 정식 지원도
유지**됩니다.

- **Surface 기기**: 전원이 꺼진 상태에서 `볼륨 ↑` 을 누른 채 `전원` 버튼을 눌러 UEFI 진입
  → **Security** → `Secure Boot`, `TPM` 을 켬
- **일반 PC**: 부팅 시 `Del` / `F2` → Security 또는 Advanced 탭
  → `TPM` (인텔은 `PTT`, AMD 는 `fTPM`), `Secure Boot` 를 `Enabled` 로

> 리눅스 듀얼 부팅 때문에 보안 부팅을 꺼 둔 상태라면, 켤 경우 리눅스가 부팅되지 않을 수
> 있습니다. 그 경우 켜지 말고 아래 3단계 우회를 사용하세요.

`파티션 방식` 이 `MBR` 로 나왔다면 변환이 필요합니다 (데이터 유지):

```powershell
mbr2gpt.exe /validate /allowFullOS
mbr2gpt.exe /convert /allowFullOS
```

변환 후 UEFI 설정에서 부팅 모드를 `Legacy/CSM` 에서 `UEFI` 로 바꿔야 부팅됩니다.

### 3단계 — 검사 우회 적용

관리자 PowerShell 에서:

```powershell
powershell -ExecutionPolicy Bypass -File .\win11enable.ps1
```

적용되는 값은 두 가지입니다.

1. `HKLM\SYSTEM\Setup\MoSetup\AllowUpgradesWithUnsupportedTPMOrCPU = 1`
   Microsoft 가 **공식 문서에서 직접 안내하는 값**입니다. TPM 1.2 이상이고 보안 부팅이
   켜진 상태에서 "지원되지 않는 CPU" 때문에 막힐 때 씁니다.
2. `HKLM\SYSTEM\Setup\LabConfig\Bypass*Check = 1`
   설치 관리자가 참조하는 개별 검사(TPM / 보안 부팅 / CPU / RAM / 디스크) 우회 값입니다.
   TPM 이 아예 없거나 보안 부팅을 켤 수 없을 때 필요합니다.

공식 키만 적용하려면 `-OfficialOnly`, 되돌리려면 `-Revert` 를 붙이면 됩니다.
변경 전 상태는 `%USERPROFILE%\Win11BypassBackup\` 에 `.reg` 로 자동 백업됩니다.

PowerShell 대신 `win11bypass.reg` 를 더블클릭해 병합해도 결과는 같습니다.

#### 스크립트가 아무 출력 없이 끝날 때

`powershell -ExecutionPolicy Bypass -File .\win11enable.ps1` 이 아무것도 출력하지 않고
끝나는 환경이 확인됐습니다 (Surface Book 2 / Windows 10 22H2). 원인은 아직 특정하지
못했지만, 아래 명령을 관리자 PowerShell 에 그대로 붙여넣으면 스크립트와 동일한 결과를
얻을 수 있습니다. 실제 장비에서 동작을 확인한 방법입니다.

```powershell
$admin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
"Administrator : $admin"
if (-not $admin) { "관리자 권한으로 다시 실행하세요"; return }

New-Item -Path 'HKLM:\SYSTEM\Setup\MoSetup' -Force | Out-Null
New-ItemProperty -Path 'HKLM:\SYSTEM\Setup\MoSetup' -Name 'AllowUpgradesWithUnsupportedTPMOrCPU' -Value 1 -PropertyType DWord -Force | Out-Null

New-Item -Path 'HKLM:\SYSTEM\Setup\LabConfig' -Force | Out-Null
foreach ($n in 'BypassTPMCheck','BypassSecureBootCheck','BypassCPUCheck','BypassRAMCheck','BypassStorageCheck') {
    New-ItemProperty -Path 'HKLM:\SYSTEM\Setup\LabConfig' -Name $n -Value 1 -PropertyType DWord -Force | Out-Null
}

"--- 적용 결과 ---"
Get-ItemProperty 'HKLM:\SYSTEM\Setup\MoSetup'   | Select-Object AllowUpgradesWithUnsupportedTPMOrCPU | Format-List
Get-ItemProperty 'HKLM:\SYSTEM\Setup\LabConfig' | Select-Object Bypass* | Format-List
```

같은 이유로 4단계의 `win11setup.ps1` 도 건너뛸 수 있습니다. ISO 를 탐색기에서
더블클릭해 마운트한 뒤 그 드라이브의 `setup.exe` 를 직접 실행하면 됩니다.

### 4단계 — ISO 로 업그레이드

**중요**: Windows Update 나 "Windows 11 설치 도우미" 는 위 레지스트리를 무시합니다.
반드시 **ISO 안의 `setup.exe`** 로 실행해야 우회가 적용됩니다.

1. [Microsoft 공식 다운로드 페이지](https://www.microsoft.com/software-download/windows11)
   에서 "Windows 11 디스크 이미지(ISO) 다운로드" 를 받습니다.
2. 관리자 PowerShell 에서:

```powershell
powershell -ExecutionPolicy Bypass -File .\win11setup.ps1
```

ISO 를 자동으로 찾아 마운트하고 설치 관리자를 실행합니다.
경로를 직접 지정하려면 `-IsoPath D:\Win11.iso` 를 붙이세요.

3. 설치 화면에서 **"설정, 개인 파일 및 앱 유지"** 를 선택하면 지금 환경 그대로
   Windows 11 로 올라갑니다.
4. 요구 사항 미충족 경고가 뜨면 동의 후 계속 진행합니다.

### 그래도 막힐 때 — 더 강한 우회

3단계 레지스트리로도 설치 관리자가 거부하면 다른 방식을 씁니다.

```powershell
# 방법 A: 설치 관리자를 서버 설치 경로로 실행해 호환성 검사를 건너뜀
powershell -ExecutionPolicy Bypass -File .\win11setup.ps1 -Method ProductServer

# 방법 B: 호환성 검사 모듈(appraiserres.dll)을 빈 파일로 교체 — 가장 확실, 여유 공간 10GB 필요
powershell -ExecutionPolicy Bypass -File .\win11setup.ps1 -Method AppraiserRes
```

방법 B 는 ISO 내용을 `C:\Win11Setup` 에 복사한 뒤 `sources\appraiserres.dll` 을 0바이트
파일로 바꿔 실행합니다. 검사 모듈이 로드되지 않으므로 검사 자체가 수행되지 않습니다.
업그레이드가 끝나면 해당 폴더를 삭제해 공간을 회수하세요.

### 참고 — 새로 설치(클린 설치)하는 경우

USB 로 부팅해 새로 설치할 때 "이 PC 는 Windows 11 을 실행할 수 없습니다" 가 뜨면:

1. 그 화면에서 `Shift` + `F10` 을 눌러 명령 프롬프트를 엽니다.
2. `regedit` 실행 → `HKEY_LOCAL_MACHINE\SYSTEM\Setup` 에 `LabConfig` 키를 만들고
   `BypassTPMCheck`, `BypassSecureBootCheck`, `BypassCPUCheck` 를 `DWORD 1` 로 추가합니다.
3. regedit 를 닫고 뒤로 가기 화살표를 눌러 설치를 다시 진행합니다.

USB 를 만들 때 [Rufus](https://rufus.ie) 를 쓰면 "확장된 Windows 11 설치" 옵션으로
이 검사들이 제거된 USB 를 바로 만들 수 있어 더 간단합니다.

## 되돌리기

```powershell
powershell -ExecutionPolicy Bypass -File .\win11enable.ps1 -Revert
```

또는 `win11revert.reg` 더블클릭. 이미 업그레이드를 마쳤다면 레지스트리를 되돌려도
Windows 11 은 그대로 유지되며, 설치 후 10일 이내라면
`설정 → 시스템 → 복구 → 돌아가기` 로 Windows 10 으로 롤백할 수 있습니다.
