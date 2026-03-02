# Kanata Keyboard Remapping Dotfiles

## Project Overview

[kanata](https://github.com/jtroo/kanata) 키보드 리매핑 도구의 설치 및 설정을 자동화하는 dotfiles 프로젝트입니다.
크로스 플랫폼(Windows, macOS, Linux)에서 일관된 키보드 레이아웃을 유지하는 것이 목표입니다.

## Repository Structure

```
.
├── CLAUDE.md                    # 이 파일
├── README.md
├── config/
│   ├── kanata.kbd               # 메인 kanata 설정 (공통)
│   └── layers/                  # 레이어별 설정 분할 (선택)
├── install/
│   ├── install.sh               # Linux/macOS 통합 설치 스크립트
│   ├── install.ps1              # Windows 설치 스크립트 (PowerShell)
│   └── uninstall.sh             # 제거 스크립트
└── autostart/
    ├── linux/
    │   └── kanata.service       # systemd 서비스 유닛
    ├── macos/
    │   └── com.kanata.plist     # launchd plist
    └── windows/
        └── kanata-startup.ps1   # 시작프로그램 등록 스크립트
```

## Key Commands

### 설치

```bash
# Linux / macOS
bash install/install.sh

# Windows (PowerShell, 관리자 권한)
.\install\install.ps1
```

### kanata 수동 실행

```bash
# Linux / macOS
kanata --cfg config/kanata.kbd

# Windows
kanata.exe --cfg config\kanata.kbd
```

### 설정 검증

```bash
kanata --cfg config/kanata.kbd --check
```

### 자동 시작 등록 / 해제

```bash
# Linux (systemd)
systemctl --user enable kanata
systemctl --user start kanata

# macOS (launchd)
launchctl load ~/Library/LaunchAgents/com.kanata.plist

# Windows (PowerShell)
.\autostart\windows\kanata-startup.ps1
```

## Platform Notes

### Linux

- **권한**: `/dev/input/*` 접근을 위해 `input` 그룹 추가 필요
  ```bash
  sudo usermod -aG input $USER
  ```
- **udev rule**: `99-kanata.rules` 를 `/etc/udev/rules.d/` 에 복사
- **자동 시작**: systemd user service (`--user`) 사용

### macOS

- **권한**: 시스템 환경설정 → 보안 및 개인 정보 → 손쉬운 사용에서 kanata 허용 필요
- **자동 시작**: `~/Library/LaunchAgents/` 에 plist 배치 후 `launchctl load`
- **Apple Silicon**: arm64 빌드 사용 확인

### Windows

- **권한**: 관리자 권한으로 실행 필요
- **드라이버**: `kanata_winIOv2.exe` 사용 권장 (WinIO 드라이버 필요)
- **자동 시작**: 작업 스케줄러 또는 시작 폴더(`shell:startup`) 등록

## Config File Guidelines

- `config/kanata.kbd` 는 플랫폼 공통 설정
- 플랫폼별 분기가 필요한 경우 `defvar` 또는 별도 `.kbd` 파일로 분리
- 레이어 구조:
  - `base` — 기본 레이어
  - `fn` — Fn 키 조합 레이어
  - `nav` — 화살표/편집 레이어 (선택)

## Development Guidelines

- 설치 스크립트 수정 시 **반드시 3개 플랫폼 모두** 동일하게 반영
- kanata 버전은 `install/install.sh` 상단 `KANATA_VERSION` 변수에서 중앙 관리
- `.kbd` 설정 변경 후 `--check` 플래그로 구문 검증 후 커밋
- 자동 시작 스크립트의 kanata 실행 경로는 설치 경로와 일치해야 함

## Common Issues

| 증상 | 원인 | 해결 |
|------|------|------|
| `permission denied /dev/input` | input 그룹 미등록 | `sudo usermod -aG input $USER` 후 재로그인 |
| macOS 키 입력 무반응 | 손쉬운 사용 권한 미허용 | 시스템 설정에서 kanata 허용 |
| Windows 실행 즉시 종료 | 관리자 권한 없음 | 관리자로 실행 또는 작업 스케줄러 등록 |
| 설정 변경 후 미적용 | 서비스 재시작 필요 | `systemctl --user restart kanata` |

## References

- [kanata GitHub](https://github.com/jtroo/kanata)
- [kanata 설정 문서](https://github.com/jtroo/kanata/blob/main/docs/config.adoc)
- [kanata Releases](https://github.com/jtroo/kanata/releases)
