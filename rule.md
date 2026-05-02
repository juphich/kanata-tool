# Kanata Project Rules

## 현재 구조

실행 및 배포 기준 소스는 `src/` 아래에 둔다.

```text
.
├── README.md
├── dist/
├── src/
│   ├── install.sh
│   ├── install.ps1
│   ├── bin/
│   ├── commands/
│   ├── config/
│   ├── autostart/
│   ├── scripts/
│   └── lib/
├── .gitlab-ci.yml
└── .codex/
```

## 설치 규칙

- POSIX 설치 경로는 `~/.local/bin`, `~/.local/share/kanata-tool`, `~/.config/kanata`를 사용한다.
- Windows 설치 경로는 `%LOCALAPPDATA%\kanata-tool`, `%LOCALAPPDATA%\kanata\bin`, `%APPDATA%\kanata`를 사용한다.
- PATH 설정은 shell/profile 또는 사용자 PATH에 자동 등록한다.
- `kanata-tool uninstall`은 clean uninstall을 수행해야 한다.

## 명령어 구조

- 관리 CLI 엔트리포인트는 `src/bin/kanata-tool`, `src/bin/kanata-tool.ps1`, `src/bin/kanata-tool.cmd`다.
- 실제 동작은 `src/commands/<platform>/` 아래 command별 파일로 분리한다.
- 공통 경로 상수는 `src/lib/paths.sh`, `src/lib/paths.ps1`에서 관리한다.

## 배포 규칙

- 배포 패키지는 `src/scripts/package.sh`로 생성한다.
- 산출물은 `dist/kanata-tool-<version>.tar.gz`, `dist/kanata-tool-<version>.zip`, `dist/SHA256SUMS`다.
- 공식 다운로드 채널은 GitLab Release asset link다.
- release 파이프라인은 `x.y.z` 형식 태그 push에서만 동작한다.
- 설치 시 `kanata` 실행 파일은 네트워크로 다운로드한다.

## 유지보수 규칙

- 설치 경로 변경 시 POSIX/Windows installer와 uninstall 로직을 함께 수정한다.
- 새 명령을 추가할 때는 platform별 `src/commands`에 파일을 추가하고 dispatcher에서 연결한다.
- 설정 변경 후 가능한 범위에서 `kanata --check` 또는 스크립트 문법 검사를 수행한다.
- 루트에는 배포 기준 소스 대신 문서와 CI 설정만 둔다.

## 플랫폼 메모

### Linux

- 설치 시 `/dev/input/event*`, `/dev/uinput` 접근을 위한 udev rule과 `input`/`uinput` 그룹 권한을 자동 설정한다.
- 새 그룹 멤버십이 생긴 경우 현재 로그인 세션에는 즉시 반영되지 않을 수 있으므로 서비스 시작을 다음 로그인 이후로 미룰 수 있다.
- uninstall은 kanata-tool이 생성한 udev rule과 modules-load 파일을 제거한다. 그룹과 사용자 그룹 멤버십은 다른 프로그램에 영향을 줄 수 있으므로 제거하지 않는다.
- `systemctl --user`가 usable하지 않으면 autostart는 건너뛸 수 있다.

### macOS

- 접근성 권한 허용이 필요하다.
- autostart는 `launchd` 기반이다.

### Windows

- 관리자 권한 실행이 더 안정적일 수 있다.
- autostart는 `HKCU\Software\Microsoft\Windows\CurrentVersion\Run`을 사용한다.
