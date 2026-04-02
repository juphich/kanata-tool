# kanata-settings

`kanata` 키보드 리매핑 설정을 Linux, macOS, Windows에서 공통 관리하기 위한 설치 프로젝트입니다.

## 프로젝트 구조

배포 기준 소스는 `src/` 아래에 정리됩니다.

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
│   ├── bundled-bin/
│   ├── scripts/
│   └── lib/
├── .gitlab-ci.yml
└── .codex/
```

`src/commands` 아래 명령은 command 단위로 분리되어 유지보수할 수 있게 구성합니다.

## 설치

### Linux / macOS

GitLab Release에서 `kanata-tool-x.y.z.tar.gz`를 내려받은 뒤 설치합니다.

```bash
tar -xzf kanata-tool-x.y.z.tar.gz
cd kanata-tool-x.y.z
./install.sh
source ~/.zshrc   # 또는 ~/.bashrc, ~/.profile
```

설치 스크립트는 다음을 수행합니다.

- `~/.local/share/kanata-tool`에 관리 CLI와 자산 설치
- `~/.local/bin/kanata-tool` wrapper 생성
- shell profile에 PATH 초기화 라인 추가
- `kanata-tool setup` 자동 실행

### Windows

GitLab Release에서 `kanata-tool-x.y.z.zip`를 내려받은 뒤 설치합니다.

```powershell
Expand-Archive kanata-tool-x.y.z.zip
cd kanata-tool-x.y.z
.\install.ps1
```

Windows 설치 스크립트는 다음을 수행합니다.

- `%LOCALAPPDATA%\kanata-tool`에 관리 CLI와 자산 설치
- `%LOCALAPPDATA%\kanata-tool\bin`을 사용자 PATH에 추가
- `kanata-tool setup` 자동 실행

## 명령어

```bash
kanata-tool setup
kanata-tool uninstall
kanata-tool device
kanata-tool keymap
kanata-tool status
kanata-tool start
kanata-tool stop
```

`kanata-tool uninstall`은 clean uninstall을 수행합니다.

`keymap` 사용 예시:

```bash
kanata-tool keymap
kanata-tool keymap --init
kanata-tool keymap --file ~/my-layout.kbd
kanata-tool keymap --print
```

동작 방식:

- 기본 제공 설정 파일은 수정하지 않습니다.
- 실제 수정 대상은 runtime 설정 파일 `~/.config/kanata/kanata.kbd`입니다.
- 변경 후 현재 kanata가 동작 중이면 reload/restart를 수행합니다.
- 동작 중이 아니면 설정 파일만 갱신합니다.
- `--print`는 현재 runtime keymap 내용을 stdout으로 출력합니다.

`status` 명령은 아래 상태를 확인합니다.

- 실행 파일 설치 여부
- base/runtime config 존재 여부
- 현재 실행 중 여부
- 자동시작 등록 여부

## 설치 위치

### Linux / macOS

- 관리 CLI 및 자산: `~/.local/share/kanata-tool`
- 실행 wrapper: `~/.local/bin/kanata-tool`
- kanata 실행 파일: `~/.local/bin/kanata`
- 설정 파일: `~/.config/kanata`

### Windows

- 관리 CLI 및 자산: `%LOCALAPPDATA%\kanata-tool`
- kanata 실행 파일: `%LOCALAPPDATA%\kanata\bin\kanata.exe`
- 설정 파일: `%APPDATA%\kanata`

## 제거

POSIX:

```bash
kanata-tool uninstall
```

Windows:

```powershell
kanata-tool uninstall
```

clean uninstall 범위:

- 관리 CLI
- `kanata` 바이너리
- 설정 파일
- 자동시작 설정
- PATH/profile 등록

## 개발 및 패키징

번들 바이너리 fetch:

```bash
bash src/scripts/fetch-kanata-binaries.sh --version v1.8.1 --output-dir src
```

배포 패키지 생성:

```bash
bash src/scripts/package.sh 1.2.3
```

생성 결과:

- `dist/kanata-tool-1.2.3.tar.gz`
- `dist/kanata-tool-1.2.3.zip`
- `dist/SHA256SUMS`

## GitLab CI / Release

- `verify`: shell / PowerShell 문법 검사
- `package`: `x.y.z` 태그에서 release archive 생성
- `release`: `dist` 산출물을 GitLab Release asset link로 등록

공식 다운로드 URL은 GitLab Release asset link를 기준으로 합니다.

## 플랫폼 메모

### Linux

- `/dev/input/*` 접근을 위해 `input` 그룹이 필요할 수 있습니다.

```bash
sudo usermod -aG input "$USER"
```

### macOS

- 시스템 설정에서 접근성 권한 허용이 필요합니다.

### Windows

- 관리자 권한으로 실행하면 더 안정적일 수 있습니다.
