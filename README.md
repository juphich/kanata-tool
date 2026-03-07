# Kanata Install Project

`kanata` 키보드 리매핑 설정을 Windows, macOS, Linux에서 공통으로 관리하고 설치/자동시작을 구성하는 프로젝트입니다.

## Directory Structure

```text
.
├── README.md
├── install.sh
├── rule.md
├── fetch-kanata-binaries.sh
├── commands/
│   ├── linux/
│   │   ├── setup.sh
│   │   ├── uninstall.sh
│   │   ├── device.sh
│   │   ├── start.sh
│   │   └── stop.sh
│   ├── macos/
│   │   ├── setup.sh
│   │   ├── uninstall.sh
│   │   ├── device.sh
│   │   ├── start.sh
│   │   └── stop.sh
│   └── windows/
│       ├── setup.ps1
│       ├── uninstall.ps1
│       ├── device.ps1
│       ├── start.ps1
│       └── stop.ps1
├── config/
│   └── kanata.kbd
├── autostart/
│   ├── linux/
│   │   └── kanata.service
│   └── macos/
│       └── com.kanata.plist
├── tool/
│   ├── kanata-tool
│   ├── kanata-tool.ps1
│   └── kanata-tool.cmd
└── bin/
    ├── linux/x64/kanata
    ├── macos/x64/kanata
    ├── macos/arm64/kanata
    ├── windows/x64/kanata.exe
    └── windows/arm64/kanata.exe
```

## Build / Release

kanata 바이너리는 `https://github.com/jtroo/kanata/releases`에서 플랫폼별 ZIP을 받아 패키징합니다.

로컬에서 바이너리 fetch:

```bash
bash fetch-kanata-binaries.sh --version v1.8.1 --output-dir .
```

GitLab CI 동작:
- `verify`: shellcheck + 문법 검사
- `package`(tag 전용): source archive(`tar.gz`, `zip`)와 `SHA256SUMS` 생성
- `release`(tag 전용): Release 생성 + assets 링크 등록

`KANATA_VERSION`을 지정하면 해당 버전을 사용하고, 지정하지 않으면 빌드 시점의 GitHub `releases/latest`를 자동 감지합니다.

## Install

### Install CLI Tool

```bash
curl -fsSL https://gitlab.com/jp-env/kanata-settings/-/raw/main/install.sh | sh
```

설치 후 명령 (Linux/macOS):

```bash
kanata-tool setup
```

하위 명령:

```bash
kanata-tool setup      # 설치 + 자동시작 등록 + 실행
kanata-tool uninstall  # 제거
kanata-tool device     # base config -> runtime config (Linux/Windows)
kanata-tool start      # 서비스/프로세스 시작
kanata-tool stop       # 서비스/프로세스 중지
```

### Windows

```powershell
.\tool\kanata-tool.cmd setup
```

또는 PowerShell 직접 실행:

```powershell
.\tool\kanata-tool.ps1 setup
.\tool\kanata-tool.ps1 uninstall
.\tool\kanata-tool.ps1 device
.\tool\kanata-tool.ps1 start
.\tool\kanata-tool.ps1 stop
```

Windows `setup` 동작:
- `kanata.exe` 설치: `bin/windows/<arch>/kanata.exe` -> PATH -> GitHub release 다운로드
- `%APPDATA%\kanata\kanata.base.kbd` / `kanata.kbd` 설치
- `--check` 검증
- `HKCU\Software\Microsoft\Windows\CurrentVersion\Run` 자동시작 등록
- kanata 프로세스 즉시 실행

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

### Windows
- `kanata-tool start` / `kanata-tool stop`으로 제어

## Uninstall

```bash
kanata-tool uninstall
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
