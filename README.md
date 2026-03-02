# Kanata Install Project

`kanata` 키보드 리매핑 설정을 Windows, macOS, Linux에서 공통으로 관리하고 설치/자동시작을 구성하는 프로젝트입니다.

## Directory Structure

```text
.
├── README.md
├── rule.md
├── config/
│   └── kanata.kbd
├── install/
│   ├── install.sh
│   ├── install.ps1
│   ├── select-device.sh
│   └── uninstall.sh
├── autostart/
│   ├── linux/
│   │   └── kanata.service
│   ├── macos/
│   │   └── com.kanata.plist
│   └── windows/
│       └── kanata-startup.ps1
└── bin/
    ├── kanata_linux_x64
    └── kanata_linux_cmd_allowed_x64
```

## Install

### Linux / macOS

```bash
bash install/install.sh
```

동작 내용:
- `config/kanata.kbd`를 `~/.config/kanata/kanata.base.kbd`로 복사
- Linux에서는 설치 중 키보드 디바이스 선택 프롬프트 제공
  - 자동 감지
  - 디바이스 이름 기준 선택
  - `/dev/input/eventX` 경로 기준 선택
- 선택 결과로 런타임 설정 `~/.config/kanata/kanata.kbd` 생성
- `kanata` 바이너리를 `~/.local/bin/kanata`에 배치
- 자동시작 등록
  - Linux: `systemd --user` 서비스 등록/시작
  - macOS: `launchd` 에이전트 등록/로드
- 마지막에 `--check`로 설정 유효성 검사

Linux에서 설치 후 디바이스를 다시 선택:

```bash
bash install/select-device.sh
```

### Windows (PowerShell, 관리자 권한 권장)

```powershell
.\install\install.ps1
```

`kanata.exe`가 PATH에 없으면 경로를 직접 전달:

```powershell
.\install\install.ps1 -KanataExePath "C:\path\to\kanata.exe"
```

동작 내용:
- `kanata.exe`를 `%LOCALAPPDATA%\kanata\bin\kanata.exe`에 복사
- `config/kanata.kbd`를 `%APPDATA%\kanata\kanata.kbd`로 복사
- `--check`로 설정 유효성 검사

## Run Manually

### Linux / macOS

```bash
~/.local/bin/kanata --cfg ~/.config/kanata/kanata.kbd
```

### Windows

```powershell
"$env:LOCALAPPDATA\kanata\bin\kanata.exe" --cfg "$env:APPDATA\kanata\kanata.kbd"
```

## Autostart

### Linux (systemd --user)

```bash
systemctl --user status kanata
systemctl --user restart kanata
```

### macOS (launchd)

```bash
launchctl unload ~/Library/LaunchAgents/com.kanata.plist
launchctl load ~/Library/LaunchAgents/com.kanata.plist
```

### Windows (Run 레지스트리 등록)

```powershell
.\autostart\windows\kanata-startup.ps1
```

## Uninstall (Linux / macOS)

```bash
bash install/uninstall.sh
```

제거 내용:
- 자동시작 항목 제거 (`systemd` 또는 `launchd`)
- `~/.local/bin/kanata` 삭제
- `~/.config/kanata` 삭제

## Validation

```bash
~/.local/bin/kanata --cfg ~/.config/kanata/kanata.kbd --check
```

Windows:

```powershell
"$env:LOCALAPPDATA\kanata\bin\kanata.exe" --cfg "$env:APPDATA\kanata\kanata.kbd" --check
```

## Platform Notes

### Linux

- `/dev/input/*` 접근 권한을 위해 `input` 그룹 추가가 필요할 수 있습니다.

```bash
sudo usermod -aG input $USER
```

- 그룹 변경 후 재로그인 필요

### macOS

- 시스템 설정에서 접근성(손쉬운 사용) 권한 허용 필요

### Windows

- 관리자 권한으로 실행 시 안정적인 동작

## References

- https://github.com/jtroo/kanata
- https://github.com/jtroo/kanata/blob/main/docs/config.adoc
- https://github.com/jtroo/kanata/releases
