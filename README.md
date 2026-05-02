# kanata-settings

`kanata` 키보드 리매핑 설정을 Linux, macOS, Windows에서 공통 관리하기 위한 설치 프로젝트입니다.

## 프로젝트 구조

배포 기준 소스는 `src/` 아래에 정리됩니다.

```text
.
├── README.md
├── dist/
├── .github/
│   └── workflows/
├── install.sh
├── install.ps1
├── src/
│   ├── bin/
│   ├── commands/
│   ├── config/
│   ├── autostart/
│   ├── scripts/
│   └── lib/
└── .codex/
```

`src/commands` 아래 명령은 command 단위로 분리되어 유지보수할 수 있게 구성합니다.

기본 keymap source는 플랫폼별로 분리합니다.

```text
src/config/linux/kanata.kbd
src/config/macos/kanata.kbd
src/config/windows/kanata.kbd
```

`setup` 단계에서 현재 OS에 맞는 source config를 선택해 base/runtime config로 설치합니다.

## 설치

### Linux / macOS

GitHub Release에서 `install.sh`와 `kanata-tool-x.y.z.tar.gz`를 내려받은 뒤 설치합니다.

```bash
tar -xzf kanata-tool-x.y.z.tar.gz
bash install.sh --from-dir kanata-tool-x.y.z
source ~/.zshrc   # 또는 ~/.bashrc, ~/.profile
```

설치 스크립트는 다음을 수행합니다.

- `~/.local/share/kanata-tool`에 관리 CLI와 자산 설치
- `~/.local/bin/kanata-tool` wrapper 생성
- setup 단계에서 `kanata` 바이너리를 네트워크로 다운로드
- setup 단계에서 현재 OS에 맞는 `config/<platform>/kanata.kbd`를 base/runtime config로 설치
- shell profile에 PATH 초기화 라인 추가
- `kanata-tool setup` 자동 실행

### Windows

GitHub Release에서 `install.ps1`과 `kanata-tool-x.y.z.zip`를 내려받은 뒤 설치합니다.

```powershell
Expand-Archive kanata-tool-x.y.z.zip
.\install.ps1 -FromDir .\kanata-tool-x.y.z
```

Windows 설치 스크립트는 다음을 수행합니다.

- `%LOCALAPPDATA%\kanata-tool`에 관리 CLI와 자산 설치
- `%LOCALAPPDATA%\kanata-tool\bin`을 사용자 PATH에 추가
- setup 단계에서 `kanata.exe`를 네트워크로 다운로드
- setup 단계에서 `config/windows/kanata.kbd`를 base/runtime config로 설치
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
kanata-tool update --check
kanata-tool update
kanata-tool update --version v1.2.3
kanata-tool version
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
- 기본 제공 설정 파일은 `src/config/<platform>/kanata.kbd`이며, setup 시 OS에 맞는 파일이 `kanata.base.kbd`로 복사됩니다.
- 배포 아카이브 안에서는 `src/` 디렉토리를 제거하고 `config/<platform>/kanata.kbd`처럼 패키지 루트에 펼쳐진 경로를 사용합니다.
- 실제 수정 대상은 runtime 설정 파일 `~/.config/kanata/kanata.kbd`입니다.
- `--init`은 runtime 설정을 설치된 base config로 되돌립니다.
- 변경 후 현재 kanata가 동작 중이면 reload/restart를 수행합니다.
- 동작 중이 아니면 설정 파일만 갱신합니다.
- `--print`는 현재 runtime keymap 내용을 stdout으로 출력합니다.

`device` 명령:

```bash
kanata-tool device --list
kanata-tool device --config
kanata-tool device --add /dev/input/event20
kanata-tool device --remove /dev/input/event20
```

동작 방식:

- 장치 목록은 `kanata --list` 결과를 기준으로 조회합니다.
- 목록 출력 형식은 한 줄 요약형이며 `num. [v| ] "name"  vid:xxx  pid:xxx  id:/path` 형태입니다.
- `[v]`는 현재 적용된 기기, `[ ]`는 아직 적용되지 않은 기기를 의미합니다.
- `--add/--remove`는 목록에 출력된 `id` 값을 입력으로 받습니다.
- `--config` 대화형 모드는 작업 선택 화면부터 시작합니다.
- 대화형 메뉴는 `1.view devices / 2.add device / 3.delete device / 4.quit` 순서입니다.
- `--config`에서 add/delete를 선택하면 목록의 `num` 값을 사용합니다.
- `4.quit`을 선택할 때까지 대화형 메뉴를 반복합니다.
- 등록 대상은 runtime keymap의 `defcfg`에 반영합니다.
- 마지막 장치를 제거하면 device 관련 `defcfg` 항목은 완전히 삭제합니다.
- Windows에서는 아직 지원하지 않습니다.

`status` 명령은 아래 상태를 확인합니다.

- 실행 파일 설치 여부
- base/runtime config 존재 여부
- 현재 실행 중 여부
- 자동시작 등록 여부

## 업데이트

업데이트 확인:

```bash
kanata-tool update --check
```

최신 안정 릴리스로 업데이트:

```bash
kanata-tool update
```

특정 버전으로 업데이트:

```bash
kanata-tool update --version v1.2.3
```

`update --check`는 GitHub Release 기준으로 설치된 `kanata-tool`보다 새 버전이 있는지 확인합니다. 이 명령은 읽기 전용이며 설치 파일을 변경하지 않습니다.

`update`는 GitHub Release asset과 `SHA256SUMS`를 내려받아 checksum을 검증한 뒤 관리 CLI를 갱신합니다.

- Linux / macOS: `kanata-tool-<version>.tar.gz`
- Windows: `kanata-tool-<version>.zip`
- 공통 checksum: `SHA256SUMS`

업데이트 중 기존 runtime keymap은 보존됩니다.

- POSIX runtime config: `~/.config/kanata/kanata.kbd`
- Windows runtime config: `%APPDATA%\kanata\kanata.kbd`

새 패키지의 기본 keymap은 `kanata.base.kbd`에 반영될 수 있습니다. 사용자가 실제로 수정하는 runtime keymap은 덮어쓰지 않습니다.

업데이트 요구사항:

- POSIX: `curl`, `jq`, `tar`, `sha256sum`
- Windows: PowerShell web cmdlet, `Expand-Archive`, `Get-FileHash`

## 설치 위치

### Linux / macOS

- 관리 CLI 및 자산: `~/.local/share/kanata-tool`
- 실행 wrapper: `~/.local/bin/kanata-tool`
- kanata 실행 파일: `~/.local/bin/kanata`
- base config: `~/.config/kanata/kanata.base.kbd`
- runtime config: `~/.config/kanata/kanata.kbd`

### Windows

- 관리 CLI 및 자산: `%LOCALAPPDATA%\kanata-tool`
- kanata 실행 파일: `%LOCALAPPDATA%\kanata\bin\kanata.exe`
- base config: `%APPDATA%\kanata\kanata.base.kbd`
- runtime config: `%APPDATA%\kanata\kanata.kbd`

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
bash src/scripts/fetch-kanata-binaries.sh --version v1.8.1 --platform linux --arch x64 --destination /tmp/kanata
```

배포 패키지 생성:

```bash
bash src/scripts/package.sh 1.2.3
```

개발 중 로컬 source를 바로 설치할 수 있습니다.

```bash
bash install.sh --from-dir src
```

패키징 시 repository 내부의 `src/` 디렉토리는 배포 아카이브에 그대로 넣지 않습니다. 대신 `src` 아래의 실행 자산을 패키지 루트로 복사해 payload archive를 만듭니다. installer는 archive에 포함하지 않고 GitHub Release에 별도 asset으로 배포합니다.

```text
kanata-tool-1.2.3/
├── VERSION
├── bin/
├── commands/
├── config/
├── autostart/
├── scripts/
├── lib/
└── README.md
```

생성 결과:

- `dist/kanata-tool-1.2.3.tar.gz`
- `dist/kanata-tool-1.2.3.zip`
- `dist/SHA256SUMS`

Release asset:

- `install.sh`
- `install.ps1`
- `dist/kanata-tool-1.2.3.tar.gz`
- `dist/kanata-tool-1.2.3.zip`
- `dist/SHA256SUMS`

## GitHub Actions / Release

- `verify`: shell / PowerShell 문법 검사
- `package-check`: main/PR에서 release archive layout 검증
- `release`: `vX.Y.Z` 또는 `X.Y.Z` 태그에서 release archive 생성
- 생성된 `dist` 산출물을 GitHub Release asset으로 등록

공식 다운로드 URL은 GitHub Release asset link를 기준으로 합니다.
설치 시 `kanata` 실행 파일 다운로드를 위해 네트워크가 필요합니다.

## 플랫폼 메모

### Linux

- 설치 시 `/dev/input/event*`, `/dev/uinput` 접근을 위한 udev rule과 `input`/`uinput` 그룹 권한을 자동 설정합니다.
- 사용자가 새 그룹에 추가된 경우 현재 로그인 세션에는 즉시 반영되지 않을 수 있습니다. 이때는 로그아웃 후 다시 로그인하거나 재부팅한 뒤 `kanata-tool start`를 실행하세요.

```bash
kanata-tool status
kanata-tool start
```

생성되는 시스템 권한 파일:

- `/etc/udev/rules.d/99-kanata-tool.rules`
- `/etc/modules-load.d/uinput.conf`

`kanata-tool uninstall`은 위 파일을 제거하지만, 기존 `input`/`uinput` 그룹과 사용자 그룹 멤버십은 다른 프로그램에서 사용할 수 있으므로 제거하지 않습니다.

### macOS

- 시스템 설정에서 접근성 권한 허용이 필요합니다.

### Windows

- 관리자 권한으로 실행하면 더 안정적일 수 있습니다.
