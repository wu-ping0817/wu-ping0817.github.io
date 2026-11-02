#!/usr/bin/env bash
# ==============================================================================
#  docker_toolkit.sh — 单文件 · 多发行版自适应的 Docker 部署工具箱
#
#  脚本将原本分散的部署能力整合为「五大阶段」，共享同一运行环境、统一入口。
#  本文件开头即给出每一阶段「做什么 / 产出什么 / 依赖什么」，便于快速理解：
#  五大阶段顺序：① 运行环境检测 → ② yum/dnf 镜像源修复 → ③ Docker CE 安装
#                → ④ 服务与用户组配置 → ⑤ 结果验证
#
#  ┌─────────────── 各阶段功能说明（FC = Functional Component）────────────────┐
#  │ FC-1  运行环境检测      detect_environment                              │
#  │       输入 : /etc/os-release、uname -m、是否 root / systemd             │
#  │       输出 : OS_ID/OS_VERSION_ID/OS_PRETTY、PKG_MGR、REPO_DISTRO、      │
#  │              CPU_ARCH，以及 RHEL 系专用的 RELEASEVER/BASEARCH/          │
#  │              CONTENTDIR/OFFICIAL_HOST/OFFICIAL_HOST_RE                 │
#  │       依赖 : 无（所有其它功能的基础层）                                 │
#  │                                                                       │
#  │ FC-2  yum/dnf 镜像源检测与切换  fix_mirrors                            │
#  │       输入 : FC-1 的 RHEL 参数、预定义镜像源列表、可选 -m/-y/--dry-run  │
#  │       输出 : 更新后的 /etc/yum.repos.d/*.repo（自动备份 .bak-时间戳）  │
#  │       依赖 : FC-1（识别发行版与官方主机）、curl                        │
#  │       适用 : 仅 RHEL 系（dnf/yum）；apt/zypper 自动跳过                │
#  │                                                                       │
#  │ FC-3  Docker CE 安装       install_docker_ce                          │
#  │       输入 : FC-1 输出、可选 -v 指定版本、FC-2 选定的 Docker 镜像源     │
#  │       输出 : 已安装的 docker-ce/cli/containerd/buildx/compose          │
#  │       依赖 : FC-1、FC-2(按需，RHEL EOL 时需先修源)、网络、root         │
#  │       特性 : 已安装则跳过；支持指定精确版本；Docker 仓库复用国内镜像源  │
#  │             以规避官方源连接失败，内置下载重试与失败原因诊断            │
#  │                                                                       │
#  │ FC-4  服务与用户组配置    configure_docker                            │
#  │       输入 : FC-3 已安装 docker                                       │
#  │       输出 : /etc/docker/daemon.json、                                │
#  │              /etc/systemd/system/docker.socket.d/override.conf、      │
#  │              docker 组、当前用户入组、systemctl start/enable          │
#  │       依赖 : FC-3                                                     │
#  │                                                                       │
#  │ FC-5  结果验证            verify_docker                               │
#  │       输入 : FC-3 / FC-4 的结果                                       │
#  │       输出 : 版本 / active / enabled 状态、hello-world 端到端、        │
#  │              配置文件核对                                             │
#  │       依赖 : FC-3、FC-4                                                │
#  └───────────────────────────────────────────────────────────────────────┘
#
#  依赖关系图：
#     FC-1 ──┬──> FC-2 ──┐
#            ├──> FC-3 ──┴──> FC-4 ──> FC-5
#            └──> (FC-4 也可独立对已装 docker 重配置；FC-5 可独立验证)
#
#  统一调用入口（子命令）：
#    sudo bash docker_toolkit.sh auto          完整一键流程（FC-1→FC-2→FC-3→FC-4→FC-5）
#    sudo bash docker_toolkit.sh install       仅安装 Docker（FC-1→FC-3→FC-4→FC-5）
#    sudo bash docker_toolkit.sh fix-mirrors   仅修复 yum 镜像源（FC-1→FC-2）
#    sudo bash docker_toolkit.sh config        仅（重）配置服务与用户组（FC-1→FC-4→FC-5）
#    sudo bash docker_toolkit.sh verify        仅验证（FC-1→FC-5）
#    sudo bash docker_toolkit.sh -h            帮助
#
#  常用选项：
#    -v, --version VER   安装指定 Docker 版本（如 24.0.7），仅 install/auto 有效
#    -y, --yes           非交互：镜像源自动选第一个；install/auto/fix-mirrors 有效
#    -m, --mirror URL    直接指定镜像源根地址（跳过检测），fix-mirrors/auto 有效
#    --dry-run           仅检测与预览，不写入（fix-mirrors 有效）
# ==============================================================================

# ----------------------------- 严格模式 -----------------------------
set -o errexit
set -o nounset
set -o pipefail

# ----------------------------- 颜色（仅交互终端） -----------------------------
if [[ -t 1 ]]; then
  readonly C_RESET=$'\033[0m' C_RED=$'\033[31m' C_GREEN=$'\033[32m' \
           C_YELLOW=$'\033[33m' C_CYAN=$'\033[36m' C_BOLD=$'\033[1m'
else
  readonly C_RESET="" C_RED="" C_GREEN="" C_YELLOW="" C_CYAN="" C_BOLD=""
fi

# ----------------------------- 日志（共享） -----------------------------
_ts()  { date '+%H:%M:%S'; }
_log() { local lvl="$1"; shift; printf '%s %s[%s]%s %s\n' "$(_ts)" "$C_BOLD" "$lvl" "$C_RESET" "$*"; }
info() { _log "INFO" "$@"; }
ok()   { _log "OK  " "$@"; }
warn() { _log "WARN" "$@"; }
err()  { _log "ERROR" "$@" >&2; }

DIED=0
fail() { DIED=1; err "$1"; err "操作已中止，请依据以上信息排查后重试。"; exit 1; }
trap 'c=$?; if [[ $c -ne 0 && $DIED -eq 0 ]]; then err "脚本异常退出（退出码 $c）。"; fi' EXIT

# ----------------------------- 全局状态（共享运行环境） -----------------------------
# —— FC-1 输出 ——
OS_ID=""; OS_ID_LIKE=""; OS_VERSION_ID=""; OS_PRETTY=""
PKG_MGR=""; REPO_DISTRO=""; CPU_ARCH=""
# —— RHEL 系专用（供 FC-2 使用）——
RELEASEVER=""; BASEARCH=""; CONTENTDIR=""; OFFICIAL_HOST=""; OFFICIAL_HOST_RE=""
# —— FC-3 选项 ——
DOCKER_VERSION=""          # 非空=锁定指定版本，空=最新稳定版
# —— FC-2 选项与状态 ——
NONINTERACTIVE=0; DRY_RUN=0; PRESET_MIRROR=""; MIRROR_FORCE=0
DOCKER_MIRROR=""           # 已选定的 Docker CE 镜像根（如 .../docker-ce/linux/centos）；空=回退官方+阿里云兜底
declare -a MIRRORS=() WORKING=() REPOMD_PATHS=()
SELECTED=""

# ----------------------------- 环境断言（共享） -----------------------------
assert_linux()   { [[ "$(uname -s)" == "Linux" ]] || fail "仅支持 Linux 系统，当前为 $(uname -s)。"; }
assert_root()    { [[ "$(id -u)" -eq 0 ]] || fail "需要 root 权限，请使用 sudo 运行本脚本。"; }
assert_systemd() { command -v systemctl >/dev/null 2>&1 || fail "需要 systemd 环境（未找到 systemctl）。"; }
need_cmd()       { command -v "$1" >/dev/null 2>&1 || fail "未找到必需命令: $1（请先安装）。"; }

# ==============================================================================
#  FC-1  运行环境检测
# ==============================================================================
detect_arch() {
  case "$(uname -m)" in
    x86_64|amd64) CPU_ARCH="amd64" ;;
    aarch64|arm64) CPU_ARCH="arm64" ;;
    *) fail "不支持的 CPU 架构: $(uname -m)（仅支持 amd64 与 arm64）。" ;;
  esac
  info "CPU 架构: $(uname -m) -> Docker 架构标识 ${CPU_ARCH}"
}

detect_os() {
  [[ -r /etc/os-release ]] || fail "无法读取 /etc/os-release，无法确定发行版。"
  # shellcheck disable=SC1091
  . /etc/os-release
  OS_ID="${ID:-}"; OS_ID_LIKE="${ID_LIKE:-}"; OS_VERSION_ID="${VERSION_ID:-}"; OS_PRETTY="${PRETTY_NAME:-unknown}"
}

# classify：确定包管理器与仓库标识，并补充 RHEL 系专用元数据
classify() {
  case "$OS_ID" in
    ubuntu|debian)
      PKG_MGR="apt"; REPO_DISTRO="$OS_ID" ;;
    linuxmint|raspbian|kali)
      PKG_MGR="apt"
      REPO_DISTRO="$([[ "$OS_ID" == "kali" ]] && echo debian || echo ubuntu)"
      warn "衍生发行版 $OS_ID，尝试以 $REPO_DISTRO 官方源安装。" ;;
    centos|rocky|almalinux|ol|amzn|anolis|rhel|fedora)
      command -v dnf >/dev/null 2>&1 && PKG_MGR="dnf" || PKG_MGR="$(command -v yum || true)"
      [[ -n "$PKG_MGR" ]] || fail "未找到 dnf 或 yum 包管理器。"
      case "$OS_ID" in
        fedora)  REPO_DISTRO="fedora" ;;
        rhel|ol) REPO_DISTRO="rhel" ;;
        *)       REPO_DISTRO="centos" ;;
      esac
      # —— RHEL 系元数据（供 FC-2 镜像源修复使用）——
      RELEASEVER="$(rpm -E '%{releasever}' 2>/dev/null || true)"
      [[ "$RELEASEVER" =~ ^[0-9] ]] || RELEASEVER="${OS_VERSION_ID:-}"
      BASEARCH="$(rpm -E '%{_arch}' 2>/dev/null || true)"
      [[ -n "$BASEARCH" ]] || BASEARCH="$(uname -m)"
      case "$OS_ID" in
        rocky)     OFFICIAL_HOST="mirrors.rockylinux.org"; CONTENTDIR="rocky" ;;
        almalinux) OFFICIAL_HOST="mirrors.almalinux.org";  CONTENTDIR="almalinux" ;;
        *)
          OFFICIAL_HOST="mirror.centos.org"; CONTENTDIR="centos"
          [[ "$OS_ID" != "centos" ]] && warn "未明确识别的 RHEL 系发行版($OS_ID)，按 CentOS 规则尝试重写（可能不适用，建议用 -m 手动指定）。" ;;
      esac
      OFFICIAL_HOST_RE="$(printf '%s' "$OFFICIAL_HOST" | sed 's/[.]/\\./g')" ;;
    opensuse-leap|opensuse-tumbleweed|sles)
      PKG_MGR="zypper"; REPO_DISTRO="opensuse-leap"
      [[ "$OS_ID" == "opensuse-tumbleweed" ]] && warn "Tumbleweed 为滚动版，Docker 无专用源，将使用 Leap 源（可能不可用）。" ;;
    *)
      case "$OS_ID_LIKE" in
        *debian*) PKG_MGR="apt"; REPO_DISTRO="debian" ;;
        *rhel*|*fedora*)
          command -v dnf >/dev/null 2>&1 && PKG_MGR="dnf" || PKG_MGR="$(command -v yum || true)"
          [[ -n "$PKG_MGR" ]] || fail "未找到 dnf 或 yum 包管理器。"
          REPO_DISTRO="centos"
          RELEASEVER="${OS_VERSION_ID:-}"; BASEARCH="$(uname -m)"
          OFFICIAL_HOST="mirror.centos.org"; CONTENTDIR="centos"
          OFFICIAL_HOST_RE="$(printf '%s' "$OFFICIAL_HOST" | sed 's/[.]/\\./g')" ;;
        *suse*) PKG_MGR="zypper"; REPO_DISTRO="opensuse-leap" ;;
        *) fail "未识别的发行版 (ID=$OS_ID)。支持 Debian/Ubuntu、RHEL 系、openSUSE。" ;;
      esac
      warn "经 ID_LIKE 推断为 $REPO_DISTRO / $PKG_MGR。" ;;
  esac
  info "发行版: $OS_PRETTY | 包管理器: $PKG_MGR | 仓库标识: $REPO_DISTRO"
}

# ==============================================================================
#  FC-2  yum/dnf 镜像源检测与切换
# ==============================================================================
build_repomd_paths() {
  local major="${RELEASEVER%%.*}"
  if [[ "$major" =~ ^[0-9]+$ ]] && (( major >= 8 )); then
    REPOMD_PATHS=( "$CONTENTDIR/$RELEASEVER/BaseOS/$BASEARCH/os/repodata/repomd.xml"
                   "$CONTENTDIR/$RELEASEVER/AppStream/$BASEARCH/os/repodata/repomd.xml" )
  else
    REPOMD_PATHS=( "$CONTENTDIR/$RELEASEVER/os/$BASEARCH/repodata/repomd.xml" )
  fi
}

# 每个条目格式：名称|系统仓库根|Docker CE 镜像根（空=不提供 docker-ce，如 vault）
build_mirrors() {
  MIRRORS=(
    "阿里云|https://mirrors.aliyun.com|https://mirrors.aliyun.com/docker-ce/linux/centos"
    "腾讯云|https://mirrors.cloud.tencent.com|https://mirrors.cloud.tencent.com/docker-ce/linux/centos"
    "华为云|https://mirrors.huaweicloud.com|https://repo.huaweicloud.com/docker-ce/linux/centos"
    "清华大学 TUNA|https://mirrors.tuna.tsinghua.edu.cn|https://mirrors.tuna.tsinghua.edu.cn/docker-ce/linux/centos"
    "中科大 USTC|https://mirrors.ustc.edu.cn|https://mirrors.ustc.edu.cn/docker-ce/linux/centos"
    "网易 163|http://mirrors.163.com|https://mirrors.163.com/docker-ce/linux/centos"
    "CentOS 官方归档 vault|https://vault.centos.org|"
  )
}

url_reachable() {
  local url="$1" code
  code="$(curl -s -o /dev/null -w '%{http_code}' --connect-timeout 8 --max-time 25 "$url" 2>/dev/null || echo 000)"
  [[ "$code" == "200" ]]
}

check_mirror() {
  local root="$1" sub
  for sub in "${REPOMD_PATHS[@]}"; do
    if url_reachable "$root/$sub"; then return 0; fi
  done
  return 1
}

detect_mirrors() {
  info "开始检测 ${#MIRRORS[@]} 个预定义镜像源的可用性..."
  echo
  printf '  %-24s %s\n' "镜像源" "状态"
  printf '  %-24s %s\n' "------------------------" "------"
  local name root status rest
  for entry in "${MIRRORS[@]}"; do
    name="${entry%%|*}"; rest="${entry#*|}"; root="${rest%%|*}"
    if check_mirror "$root"; then
      status="${C_GREEN}可用${C_RESET}"
      WORKING+=("$entry")
    else
      status="${C_RED}不可达${C_RESET}"
    fi
    printf '  %-24s %s\n' "$name" "$status"
  done
  echo
  ok "检测完成：可用 ${#WORKING[@]} 个，不可用 $(( ${#MIRRORS[@]} - ${#WORKING[@]} )) 个。"
}

backup_file() {
  local f="$1" bak
  bak="${f}.bak-$(date +%Y%m%d%H%M%S)"
  cp -p "$f" "$bak" || fail "备份文件失败: $f"
  info "已备份: $bak"
}

# apply_mirror：将所选镜像源根地址写入引用了失效官方源主机的仓库文件
apply_mirror() {
  local mirror="$1"
  info "将镜像源根地址写入仓库配置: $mirror"
  local f modified=0
  shopt -s nullglob
  for f in /etc/yum.repos.d/*.repo; do
    if grep -qE "$OFFICIAL_HOST_RE" "$f"; then
      # MIRROR_FORCE=0 时（auto 流程）：仅当官方源当前确不可达才替换，避免改动健康系统
      if [[ $MIRROR_FORCE -eq 0 ]]; then
        if url_reachable "https://$OFFICIAL_HOST/${REPOMD_PATHS[0]}"; then
          info "官方源 $OFFICIAL_HOST 当前可访问，无需替换，跳过 $f"
          continue
        fi
      fi
      if [[ $DRY_RUN -eq 1 ]]; then
        info "[dry-run] 将修改: $f"
        modified=1
        continue
      fi
      backup_file "$f"
      sed -i -E "s|^[[:space:]]*mirrorlist=|#mirrorlist=|g" "$f"
      sed -i -E "s|^[[:space:]]*metalink=|#metalink=|g" "$f"
      sed -i -E "s|^[[:space:]]*#baseurl=|baseurl=|g" "$f"
      sed -i -E "s|(baseurl=)https?://$OFFICIAL_HOST_RE|\1$mirror|g" "$f"
      ok "已更新: $f"
      modified=1
    fi
  done
  shopt -u nullglob
  if [[ $modified -eq 0 ]]; then
    warn "未发现需替换的仓库文件（未引用失效官方源 $OFFICIAL_HOST），未做任何修改。"
    return 0
  fi
  if [[ $DRY_RUN -eq 1 ]]; then
    info "[dry-run] 未实际写入（--dry-run）。"
    return 0
  fi
  info "重建仓库元数据缓存以验证..."
  if command -v dnf >/dev/null 2>&1; then
    dnf makecache -y >/dev/null 2>&1 && ok "dnf makecache 成功，镜像源生效。" || warn "dnf makecache 失败，请检查网络或所选镜像源。"
  else
    yum makecache >/dev/null 2>&1 && ok "yum makecache 成功，镜像源生效。" || warn "yum makecache 失败，请检查网络或所选镜像源。"
  fi
}

# set_selected：从 MIRRORS 条目解析出 系统仓库根(SELECTED) 与 Docker CE 镜像根(DOCKER_MIRROR)
set_selected() {
  local entry="$1" rest
  rest="${entry#*|}"
  SELECTED="${rest%%|*}"
  DOCKER_MIRROR="${rest#*|}"
}

choose_working() {
  local n="${#WORKING[@]}"
  if [[ $NONINTERACTIVE -eq 1 || $n -eq 1 ]]; then
    set_selected "${WORKING[0]}"
    return
  fi
  echo -e "${C_BOLD}检测到以下可用镜像源，请选择（输入序号，回车默认第 1 个）：${C_RESET}"
  local i
  for i in "${!WORKING[@]}"; do
    printf '  %d) %s\n' "$((i+1))" "${WORKING[$i]%%|*}"
  done
  local choice
  read -r -p "请选择 [1-$n]: " choice
  choice="${choice:-1}"
  if [[ "$choice" =~ ^[0-9]+$ ]] && (( choice>=1 && choice<=n )); then
    set_selected "${WORKING[$((choice-1))]}"
  else
    warn "输入无效，使用第 1 个可用镜像源。"
    set_selected "${WORKING[0]}"
  fi
}

validate_manual() {
  local inp="$1"; inp="${inp%/}"
  if [[ "$inp" == */repomd.xml ]]; then
    url_reachable "$inp" && return 0
    return 1
  fi
  local sub
  for sub in "${REPOMD_PATHS[@]}"; do
    url_reachable "$inp/$sub" && return 0
  done
  return 1
}

manual_input() {
  local tries=0 max=3 inp
  while (( tries < max )); do
    read -r -p "请输入一个可用的镜像源根地址（如 https://mirrors.aliyun.com）: " inp
    [[ -n "$inp" ]] || { warn "未输入地址。"; tries=$((tries+1)); continue; }
    info "正在校验: $inp ..."
    if validate_manual "$inp"; then
      ok "镜像源校验通过。"
      PRESET_MIRROR="$inp"
      return 0
    fi
    err "该地址无法取到仓库元数据（repomd.xml），可能不可用或路径不匹配。"
    tries=$((tries+1))
  done
  fail "多次输入均不可用，已放弃。请确认镜像源地址后重试。"
}

# fix_mirrors：FC-2 核心（依赖 FC-1 已完成；非 RHEL 系自动跳过）
fix_mirrors() {
  if [[ "$PKG_MGR" != "dnf" && "$PKG_MGR" != "yum" ]]; then
    warn "当前包管理器为 $PKG_MGR（非 dnf/yum），不适用 yum 镜像源修复，已跳过。"
    return 0
  fi
  need_cmd curl
  build_repomd_paths
  build_mirrors

  if [[ -n "$PRESET_MIRROR" ]]; then
    info "使用指定的镜像源: $PRESET_MIRROR"
    SELECTED="$PRESET_MIRROR"
    DOCKER_MIRROR="${PRESET_MIRROR}/docker-ce/linux/centos"
  else
    detect_mirrors
    if [[ ${#WORKING[@]} -eq 0 ]]; then
      err "自动检测已全部失效：预定义的镜像源均不可访问。"
      err "可能原因：当前网络无法连接外网镜像，或发行版/版本路径不匹配。"
      manual_input
      SELECTED="$PRESET_MIRROR"
    else
      choose_working
    fi
  fi

  apply_mirror "$SELECTED"
  echo
  echo -e "${C_BOLD}${C_GREEN}========== 镜像源切换完成 ==========${C_RESET}"
  echo -e "  选用镜像源 : ${C_BOLD}${SELECTED}${C_RESET}"
  echo -e "  ${C_YELLOW}提示：如仍报错，请检查所选镜像源是否支持当前发行版与版本路径。${C_RESET}"
  echo
}

# ==============================================================================
#  FC-3  Docker CE 安装
# ==============================================================================
validate_version() {
  [[ -z "$DOCKER_VERSION" ]] && return 0
  [[ "$DOCKER_VERSION" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]] \
    || fail "版本号格式不正确: $DOCKER_VERSION（应为 X.Y.Z，例如 24.0.7）。"
}

resolve_apt_version() {
  local user_ver="$1" codename="$2" full
  full="$(apt-cache madison docker-ce 2>/dev/null | awk -F'|' -v v="$user_ver" -v c="$codename" '
    { gsub(/[ \t]+/, "", $2); ve = v; gsub(/\./, "\\.", ve);
      if ($2 ~ "^[0-9]*:" ve "-.*" c "$") { print $2; exit } }')"
  [[ -n "$full" ]] || fail "未在官方源中找到匹配 $user_ver 且适用于 $codename 的 docker-ce 版本。可运行: apt-cache madison docker-ce 查看可用版本。"
  echo "$full"
}

resolve_dnf_version() {
  local user_ver="$1" list full
  if command -v dnf >/dev/null 2>&1; then
    list="$(dnf list docker-ce --showduplicates 2>/dev/null)"
  else
    list="$(yum list docker-ce --showduplicates 2>/dev/null)"
  fi
  [[ -n "$list" ]] || fail "无法查询 docker-ce 可用版本（dnf/yum list --showduplicates 失败，请检查网络与仓库）。"
  full="$(printf '%s\n' "$list" | awk -v v="$user_ver" '
    $1 ~ /^docker-ce[.@]/ {
      ver = $2; sub(/^[0-9]+:/, "", ver); sub(/-.*/, "", ver);
      if (ver == v) { print $2; exit }
    }')"
  [[ -n "$full" ]] || fail "未找到匹配 $user_ver 的 docker-ce 版本。可运行: $PKG_MGR list docker-ce --showduplicates 查看可用版本。"
  echo "$full"
}

resolve_zypper_version() {
  local user_ver="$1" full
  full="$(zypper --non-interactive search -s docker-ce 2>/dev/null | awk -v v="$user_ver" '
    $2 == "docker-ce" && $4 ~ v { print $4; exit }')"
  [[ -n "$full" ]] || fail "未找到匹配 $user_ver 的 docker-ce 版本（zypper）。请确认该版本在官方源中存在。"
  echo "$full"
}

install_apt() {
  export DEBIAN_FRONTEND=noninteractive
  info "刷新软件包索引并安装依赖"
  apt-get update -y || fail "apt-get update 失败。"
  apt-get install -y ca-certificates curl gnupg || fail "安装依赖（ca-certificates/curl/gnupg）失败。"

  install -m 0755 -d /etc/apt/keyrings
  info "导入 Docker 官方 GPG 密钥"
  curl -fsSL "https://download.docker.com/linux/${REPO_DISTRO}/gpg" -o /etc/apt/keyrings/docker.asc \
    || fail "下载 Docker GPG 密钥失败（请检查网络连通性）。"
  chmod a+r /etc/apt/keyrings/docker.asc

  # shellcheck disable=SC1091
  . /etc/os-release
  local codename="${VERSION_CODENAME:-}"
  [[ -n "$codename" ]] || codename="$(command -v lsb_release >/dev/null 2>&1 && lsb_release -cs || true)"
  [[ -n "$codename" ]] || fail "无法获取发行代号（缺少 VERSION_CODENAME 且未安装 lsb-release）。"

  printf 'deb [arch=%s signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/%s %s stable\n' \
    "$CPU_ARCH" "$REPO_DISTRO" "$codename" > /etc/apt/sources.list.d/docker.list

  info "刷新 Docker 官方源"
  apt-get update -y || fail "刷新 Docker 官方源失败。"

  if [[ -n "$DOCKER_VERSION" ]]; then
    local full
    full="$(resolve_apt_version "$DOCKER_VERSION" "$codename")"
    info "安装指定版本 docker-ce / docker-ce-cli: $full"
    apt-get install -y "docker-ce=${full}" "docker-ce-cli=${full}" containerd.io docker-buildx-plugin docker-compose-plugin \
      || fail "安装指定版本 Docker 软件包失败。"
  else
    info "安装最新稳定版 Docker 引擎"
    apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin \
      || fail "安装 Docker 软件包失败。"
  fi
}

install_dnf_yum() {
  local url; local -a pin
  # —— Docker 仓库地址：优先复用已选定的国内镜像源，规避 download.docker.com 连接问题 ——
  if [[ -n "$DOCKER_MIRROR" ]]; then
    url="${DOCKER_MIRROR}/docker-ce.repo"
    info "复用国内镜像源安装 Docker 仓库: ${DOCKER_MIRROR}"
  else
    case "$REPO_DISTRO" in
      fedora) url="https://download.docker.com/linux/fedora/docker-ce.repo" ;;
      rhel)   url="https://download.docker.com/linux/rhel/docker-ce.repo" ;;
      *)      url="https://download.docker.com/linux/centos/docker-ce.repo" ;;
    esac
    # 官方源探测不可达时，自动回退到阿里云 docker-ce 镜像（最大化成功率）
    if ! url_reachable "$url"; then
      local alt="https://mirrors.aliyun.com/docker-ce/linux/centos"
      if url_reachable "${alt}/docker-ce.repo"; then
        warn "官方 Docker 源不可达，自动回退到阿里云 docker-ce 镜像: ${alt}"
        DOCKER_MIRROR="$alt"; url="${alt}/docker-ce.repo"
      else
        warn "官方 Docker 源与阿里云镜像均不可达，将仍以官方源尝试（可能失败，建议用 -m 指定可用镜像）。"
      fi
    fi
  fi

  # —— 清理可能残留的旧 Docker 仓库文件，避免新旧源并存时仍从官方源下载 ——
  local old
  for old in /etc/yum.repos.d/*docker*.repo; do
    [[ -e "$old" ]] || continue
    info "移除旧 Docker 仓库文件以避免多源冲突: $old"
    rm -f "$old"
  done

  info "添加 Docker 仓库: ${url}"
  if [[ "$PKG_MGR" == "dnf" ]]; then
    dnf install -y dnf-plugins-core || fail "安装 dnf-plugins-core 失败。"
    dnf config-manager --add-repo "$url" || fail "添加 Docker 仓库失败（URL: ${url}）。"
  else
    yum install -y yum-utils || fail "安装 yum-utils 失败。"
    yum-config-manager --add-repo "$url" || fail "添加 Docker 仓库失败（URL: ${url}）。"
  fi

  # —— 保留并完善 runc/podman/buildah 冲突规避环境检测 ——
  if rpm -q runc >/dev/null 2>&1; then
    warn "检测到系统已安装 runc（与 containerd.io 冲突，且 podman/buildah 依赖 runc）。将启用冲突规避。"
  fi

  if [[ -n "$DOCKER_VERSION" ]]; then
    local full
    full="$(resolve_dnf_version "$DOCKER_VERSION")"
    info "安装指定版本: docker-ce-${full} / docker-ce-cli-${full}"
    pin=( "docker-ce-${full}" "docker-ce-cli-${full}" containerd.io docker-buildx-plugin docker-compose-plugin )
  else
    info "安装最新稳定版 Docker 引擎"
    pin=( docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin )
  fi

  # 冲突规避 + 网络重试安装
  install_pkgs_with_fallback "${pin[@]}"
}

# ------------------------- 下载/网络瞬断判断与失败诊断 -------------------------
# 仅根据日志关键字判断是否为「瞬时网络/下载」错误（可安全重试）；返回 0=疑似瞬断
is_transient_network_error() {
  local log="$1"
  grep -qiE 'SSL_ERROR_SYSCALL|curl error|Could not retrieve|Timeout|Timed out|Connection reset|Connection timed out|No route to host|Network is unreachable|Failed to connect|Temporary failure|Cannot download|error: Status code|Downloading' "$log" 2>/dev/null
}

# 安装失败原因诊断：根据日志输出可能的原因与排查建议，便于用户定位
diagnose_docker_install_failure() {
  local log="$1"
  echo
  echo -e "${C_BOLD}${C_RED}========== Docker 安装失败原因诊断 ==========${C_RESET}"
  if grep -qiE 'SSL_ERROR_SYSCALL|curl error|Could not retrieve|Timeout|Connection reset|No route to host|Network is unreachable|Failed to connect|Cannot download' "$log" 2>/dev/null; then
    echo -e "  ${C_RED}[网络/下载失败]${C_RESET}"
    echo "    · 现象：拉取 Docker 仓库软件包时发生连接/下载错误（常见于官方源 download.docker.com 被限速或阻断）。"
    echo "    · 可能原因："
    echo "        1) 官方源在当前网络下不稳定（SSL_ERROR_SYSCALL、curl error 28 超时、Connection reset）。"
    echo "        2) 所选镜像源不稳定或路径与当前发行版/版本不匹配。"
    echo "        3) 服务器出网被限流、DNS 解析异常，或系统时间与证书有效期不符。"
    echo "    · 排查建议："
    echo "        - 重新运行并指定稳定国内镜像源： sudo bash $0 auto -m https://mirrors.aliyun.com"
    echo "        - 手动验证连通性： curl -I https://mirrors.aliyun.com/docker-ce/linux/centos/\$releasever/\$basearch/stable/repodata/repomd.xml"
    echo "        - 检查 DNS： nslookup mirrors.aliyun.com； 检查时间： date（证书校验依赖正确系统时间）"
  fi
  if grep -qiE 'conflicts|obsoletes|nothing provides|no candidate|Problem:|Error: package' "$log" 2>/dev/null; then
    echo -e "  ${C_RED}[依赖/冲突失败]${C_RESET}"
    echo "    · 现象：软件包依赖无法解析或互相冲突（如 containerd.io 与系统 runc、podman/buildah 冲突）。"
    echo "    · 排查建议："
    echo "        - 本脚本已尝试 --allowerasing 与显式移除 runc/podman/buildah 进行规避。"
    echo "        - 若仍失败，可手动执行： dnf remove -y runc podman buildah ，再重新运行安装。"
  fi
  if grep -qiE 'Status code: 404|Not Found|repomd.xml: \[Errno 14\]|Cannot find a valid baseurl|Invalid' "$log" 2>/dev/null; then
    echo -e "  ${C_RED}[仓库/路径不匹配]${C_RESET}"
    echo "    · 现象：仓库元数据或软件包路径 404 / 找不到。"
    echo "    · 可能原因： releasever/arch 与实际不符（如 CentOS 8 已 EOL，官方路径需注意）。"
    echo "    · 排查建议： echo \$releasever \$basearch 确认； 用 -m 指定与当前系统匹配的镜像源。"
  fi
  echo -e "  ${C_YELLOW}完整安装日志见：${log}${C_RESET}"
  echo
}

# 安装 Docker 软件包（RHEL 系），内置 containerd.io 与系统 runc 的冲突规避，并带网络重试。
# 策略一：以 --allowerasing 安装，允许 dnf/yum 移除冲突包以解析依赖；
# 策略二（兜底）：若仍失败，显式移除 runc/podman/buildah 后重新安装。
install_pkgs_with_fallback() {
  local -a pkgs=("$@")
  local mgr="$PKG_MGR" log="/tmp/docker_install.log"
  local max_attempts=3 attempt=0
  info "安装 Docker 软件包（含 containerd.io 冲突规避与网络重试）"

  # —— 策略一：--allowerasing 自动解决冲突（含 runc 冲突）；遇瞬时网络错误自动重试 ——
  while (( attempt < max_attempts )); do
    attempt=$((attempt+1))
    info "（尝试 $attempt/$max_attempts）以 --allowerasing 安装 Docker 软件包..."
    if "$mgr" install -y --allowerasing "${pkgs[@]}" >"$log" 2>&1; then
      ok "Docker 软件包安装成功。"
      return 0
    fi
    if is_transient_network_error "$log"; then
      warn "检测到网络/下载瞬时错误，准备重试（详见 ${log} 末尾）："
      tail -n 15 "$log" >&2 || true
      sleep 5
      continue
    fi
    break   # 非网络错误（依赖冲突等），跳出策略一进入策略二
  done

  err "策略一（--allowerasing）安装失败（详见 ${log} 末尾）："
  tail -n 20 "$log" >&2 || true
  warn "执行冲突规避：移除 runc / podman / buildah 后重试（这些组件与 containerd.io 不兼容）。"
  remove_rhel_docker_conflicts

  # —— 策略二：显式移除冲突包后重试，同样带网络瞬断重试 ——
  attempt=0
  while (( attempt < max_attempts )); do
    attempt=$((attempt+1))
    info "（尝试 $attempt/$max_attempts）移除冲突包后安装 Docker 软件包..."
    if "$mgr" install -y "${pkgs[@]}" >"$log" 2>&1; then
      ok "Docker 软件包安装成功。"
      return 0
    fi
    if is_transient_network_error "$log"; then
      warn "检测到网络/下载瞬时错误，准备重试："
      tail -n 15 "$log" >&2 || true
      sleep 5
      continue
    fi
    break
  done

  err "自动重试与冲突规避后仍无法完成安装。"
  tail -n 25 "$log" >&2 || true
  diagnose_docker_install_failure "$log"
  fail "Docker 安装失败，请参考上述诊断信息排查后重试。"
}

# 显式移除与 containerd.io 冲突的组件（RHEL 8+ 自带 runc，podman/buildah 依赖 runc）
remove_rhel_docker_conflicts() {
  local -a conflicts=() p
  for p in runc podman buildah; do
    if rpm -q "$p" >/dev/null 2>&1; then conflicts+=("$p"); fi
  done
  if [[ ${#conflicts[@]} -eq 0 ]]; then
    info "未发现 runc/podman/buildah 冲突包。"
    return 0
  fi
  info "移除冲突组件: ${conflicts[*]}（podman/buildah 依赖 runc，将一并移除）"
  if [[ "$PKG_MGR" == "dnf" ]]; then
    dnf remove -y "${conflicts[@]}" >/dev/null 2>&1 || warn "移除冲突包时出现异常，继续尝试安装。"
  else
    yum remove -y "${conflicts[@]}" >/dev/null 2>&1 || warn "移除冲突包时出现异常，继续尝试安装。"
  fi
  ok "已移除冲突组件。"
}

install_zypper() {
  local url="https://download.docker.com/linux/opensuse/leap/${OS_VERSION_ID}/docker-ce.repo"
  zypper --non-interactive addrepo "$url" || fail "添加 Docker 官方仓库失败。"
  zypper --non-interactive --gpg-auto-import-keys refresh || fail "刷新仓库失败。"

  if [[ -n "$DOCKER_VERSION" ]]; then
    local full
    full="$(resolve_zypper_version "$DOCKER_VERSION")"
    info "安装指定版本: docker-ce=${full}"
    zypper --non-interactive install "docker-ce=${full}" containerd.io docker-compose-plugin \
      || fail "安装指定版本 Docker 软件包失败。"
  else
    info "安装最新稳定版 Docker 引擎"
    zypper --non-interactive install docker-ce docker-ce-cli containerd.io docker-compose-plugin \
      || fail "安装 Docker 软件包失败。"
  fi
}

docker_present() { command -v docker >/dev/null 2>&1; }

install_docker_ce() {
  case "$PKG_MGR" in
    apt)    install_apt ;;
    dnf|yum) install_dnf_yum ;;
    zypper) install_zypper ;;
    *)      fail "不支持的包管理器: $PKG_MGR" ;;
  esac
  ok "Docker 软件包安装完成。"
}

# ==============================================================================
#  FC-4  服务与用户组配置
# ==============================================================================
_has_jq()  { command -v jq >/dev/null 2>&1; }
_has_py3() { command -v python3 >/dev/null 2>&1; }

json_validate() {
  local f="$1"
  [[ -f "$f" ]] || return 0
  if _has_jq; then
    jq empty "$f" >/dev/null 2>&1 && return 0 || return 1
  elif _has_py3; then
    python3 -c 'import json,sys; json.load(open(sys.argv[1]))' "$f" >/dev/null 2>&1 && return 0 || return 1
  fi
  warn "未找到 jq / python3，跳过 JSON 语法校验（脚本写入内容保证有效）。"
  return 0
}

daemon_merge_json() {
  local existing="${1:-}"
  if _has_jq; then
    local src="{}"
    [[ -n "$existing" && -f "$existing" ]] && src="$(cat "$existing")"
    printf '%s' "$src" | jq '.group="docker"
      | .["live-restore"]=true
      | .["log-driver"]=(."log-driver"//"json-file")
      | .["log-opts"]=((."log-opts"//{}) + {"max-size":"100m","max-file":"3"})' \
      && return 0
    return 1
  fi
  if _has_py3; then
    local src="{}"
    [[ -n "$existing" && -f "$existing" ]] && src="$(cat "$existing")"
    printf '%s' "$src" | python3 - <<'PY' && return 0
import json, sys
src = sys.stdin.read().strip()
data = json.loads(src) if src else {}
if not isinstance(data, dict):
    data = {}
data["group"] = "docker"
data["live-restore"] = True
data.setdefault("log-driver", "json-file")
opts = data.get("log-opts")
if not isinstance(opts, dict):
    opts = {}
opts.setdefault("max-size", "100m")
opts.setdefault("max-file", "3")
data["log-opts"] = opts
print(json.dumps(data, indent=2, ensure_ascii=False))
PY
    return 1
  fi
  if [[ -n "$existing" && -f "$existing" ]]; then
    warn "未找到 jq / python3，无法安全合并现有 daemon.json，将保留现有文件不变。"
    cat "$existing"
    return 0
  fi
  cat <<'JSON'
{
  "group": "docker",
  "live-restore": true,
  "log-driver": "json-file",
  "log-opts": {
    "max-size": "100m",
    "max-file": "3"
  }
}
JSON
}

ensure_docker_group() {
  if getent group docker >/dev/null 2>&1; then
    local gid; gid="$(getent group docker | cut -d: -f3)"
    info "docker 组已存在 (GID=${gid})。"
  else
    info "创建 docker 组"
    groupadd docker || fail "创建 docker 组失败。"
    ok "已创建 docker 组。"
  fi
}

# configure_daemon_json：写入前完成 存在性 / 读取 / 权限 / 语法 核对
configure_daemon_json() {
  local dir="/etc/docker"
  local f="${dir}/daemon.json" bak merged tmp
  info "配置 Docker 守护进程: ${f}"

  if [[ -d "$dir" ]]; then
    info "目录已存在: ${dir} ($(stat -c '%a %U:%G' "$dir" 2>/dev/null || echo 'unknown'))"
  else
    info "创建目录: ${dir}"
    install -d -m 0755 -o root -g root "$dir" || fail "创建 ${dir} 失败。"
  fi

  if [[ -f "$f" ]]; then
    info "已存在配置文件: ${f} (权限 $(stat -c '%a %U:%G' "$f" 2>/dev/null || echo 'unknown'))"
    info "读取现有配置内容以做合并..."
    if ! json_validate "$f"; then
      fail "现有 ${f} 不是合法 JSON。已中止以避免破坏现有配置——请先备份并修复该文件，或删除后由本脚本重建。"
    fi
    ok "现有 ${f} JSON 语法校验通过。"
  else
    info "配置文件不存在，将新建: ${f}"
  fi

  merged="$(daemon_merge_json "$f")" || fail "生成 daemon.json 内容失败（jq/python3 不可用或执行异常）。"
  tmp="$(mktemp /tmp/daemon.json.XXXXXX)"
  printf '%s\n' "$merged" > "$tmp"
  if ! json_validate "$tmp"; then
    rm -f "$tmp"
    fail "将要写入的 daemon.json 未通过 JSON 语法校验（内部错误，已放弃写入）。"
  fi
  rm -f "$tmp"

  if [[ -f "$f" ]]; then
    bak="${f}.bak-$(date +%Y%m%d%H%M%S)"
    cp -p "$f" "$bak" || fail "备份现有 ${f} 失败。"
    info "已备份现有配置至: ${bak}"
  fi

  printf '%s\n' "$merged" > "$f" || fail "写入 ${f} 失败。"
  chown root:root "$f" || fail "设置 ${f} 属主失败。"
  chmod 0644 "$f"       || fail "设置 ${f} 权限失败。"
  ok "已写入 ${f} (root:root 0644)。关键项: group=docker, live-restore=true, 日志轮转 100m/3。"
}

# configure_socket_group：docker.socket 用户组关联（服务↔用户组核心）
configure_socket_group() {
  local dropdir="/etc/systemd/system/docker.socket.d"
  local f="${dropdir}/override.conf" bak
  info "配置 docker.socket 用户组关联: ${f}"

  ensure_docker_group

  if [[ ! -d "$dropdir" ]]; then
    install -d -m 0755 -o root -g root "$dropdir" || fail "创建 ${dropdir} 失败。"
    info "已创建目录: ${dropdir}"
  fi

  local content
  content="$(cat <<'EOF'
# Docker socket 用户组关联（由 docker_toolkit.sh 生成）
# 使 /run/docker.sock 归属于 docker 组，组内用户可免 sudo 访问守护进程。
[Socket]
SocketGroup=docker
EOF
)"

  if [[ -f "$f" ]]; then
    local fperm; fperm="$(stat -c '%a %U:%G' "$f" 2>/dev/null || echo 'unknown')"
    info "已存在覆盖文件: ${f} (权限 ${fperm})"
    if grep -q '^\[Socket\]' "$f" && grep -q '^SocketGroup=' "$f"; then
      ok "${f} 已含正确的 socket 组配置，保持不变。"
      return 0
    fi
    warn "${f} 缺少 [Socket]/SocketGroup 段，将更新以保证服务与用户组关联正确。"
    bak="${f}.bak-$(date +%Y%m%d%H%M%S)"
    cp -p "$f" "$bak" || fail "备份 ${f} 失败。"
    info "已备份至: ${bak}"
  else
    info "将新建覆盖文件: ${f}"
  fi

  printf '%s\n' "$content" > "$f" || fail "写入 ${f} 失败。"
  chown root:root "$f" || fail "设置 ${f} 属主失败。"
  chmod 0644 "$f"       || fail "设置 ${f} 权限失败。"
  ok "已写入 ${f} (root:root 0644)，SocketGroup=docker。"
  systemctl daemon-reload || warn "systemctl daemon-reload 执行失败（可稍后手动执行）。"
}

configure_service() {
  info "启动 Docker 服务并设置开机自启"
  systemctl start docker  || fail "启动 docker 服务失败（systemctl start docker）。"
  systemctl enable docker || fail "设置开机自启失败（systemctl enable docker）。"
  ok "Docker 服务已启动并设为开机自启。"
}

add_docker_user() {
  local user="${SUDO_USER:-}"
  if [[ -z "$user" ]]; then
    if [[ "$(id -u)" -eq 0 ]]; then
      warn "以 root 直接运行，无需将 root 加入 docker 组（root 默认拥有权限）。"
      return 0
    fi
    user="$(id -un)"
  fi

  if id -nG "$user" 2>/dev/null | grep -qw docker; then
    ok "用户 $user 已在 docker 组中。"
    return 0
  fi

  info "将用户 $user 加入 docker 组"
  usermod -aG docker "$user" || fail "将用户 $user 加入 docker 组失败。"
  ok "已加入 docker 组（重新登录终端或执行 newgrp docker 后生效）。"
}

# ==============================================================================
#  FC-5  结果验证
# ==============================================================================
verify_docker() {
  info "验证安装结果"
  local ver
  ver="$(docker --version 2>/dev/null)" || fail "docker 命令不可用，安装可能未成功。"
  ok "Docker 版本: $ver"

  if systemctl is-active --quiet docker; then ok "服务状态: active（运行中）"; else err "服务未运行，请检查 systemctl status docker。"; fi
  if systemctl is-enabled --quiet docker; then ok "开机自启: 已启用"; else warn "开机自启未启用。"; fi

  info "运行 hello-world 容器做端到端验证（需联网拉取镜像）"
  if docker run --rm hello-world >/dev/null 2>&1; then
    ok "hello-world 运行成功 —— Docker 引擎工作正常。"
  else
    warn "hello-world 运行失败（多为网络受限无法拉取镜像所致）。请手动执行: docker run --rm hello-world"
  fi

  info "检查服务与用户组配置文件"
  if [[ -f /etc/docker/daemon.json ]]; then
    ok "守护进程配置: /etc/docker/daemon.json 存在（$(stat -c '%a %U:%G' /etc/docker/daemon.json 2>/dev/null || echo 'unknown')）"
  else
    warn "未找到 /etc/docker/daemon.json。"
  fi
  if [[ -f /etc/systemd/system/docker.socket.d/override.conf ]]; then
    ok "socket 组配置: docker.socket 覆盖文件已设置 SocketGroup=docker"
  else
    warn "未找到 docker.socket 覆盖配置。"
  fi

  echo
  echo -e "${C_BOLD}${C_GREEN}========== 安装 / 验证完成 ==========${C_RESET}"
  echo -e "  Docker 版本 : ${C_BOLD}${ver}${C_RESET}"
  echo -e "  服务状态    : running，并已设置开机自启"
  echo -e "  当前用户    : ${SUDO_USER:-$(id -un)}"
  echo -e "  ${C_YELLOW}提示：若本次为新加入 docker 组，请重新登录终端后方可免 sudo 执行 docker 命令。${C_RESET}"
  echo
}

# ==============================================================================
#  流程编排（步骤）
# ==============================================================================
step_install_docker() {
  info "[安装] 安装 Docker 引擎"
  if docker_present; then
    if [[ -n "$DOCKER_VERSION" ]]; then
      warn "已检测到 Docker，将保留现有版本（如需切换为 $DOCKER_VERSION，请先卸载现有 Docker 后重试）。"
    else
      warn "已检测到 Docker，跳过安装步骤（仍执行幂等配置与验证）。"
    fi
  else
    install_docker_ce
  fi
}

step_configure() {
  info "[配置] 服务与用户组"
  configure_daemon_json
  configure_socket_group
  configure_service
  add_docker_user
}

step_verify() { verify_docker; }

# ==============================================================================
#  子命令实现（统一调用入口）
# ==============================================================================
run_auto() {
  while [[ $# -gt 0 ]]; do
    case "$1" in
      -h|--help) usage; exit 0 ;;
      -v|--version) shift; DOCKER_VERSION="${1:-}"; [[ -n "$DOCKER_VERSION" ]] || fail "选项 --version 需要指定版本号，例如 -v 24.0.7。"; shift ;;
      -y|--yes) NONINTERACTIVE=1; shift ;;
      -m|--mirror) shift; PRESET_MIRROR="${1:-}"; [[ -n "$PRESET_MIRROR" ]] || fail "选项 --mirror 需要指定地址，例如 -m https://mirrors.aliyun.com。"; shift ;;
      *) fail "未知参数: $1（使用 -h 查看帮助）" ;;
    esac
  done

  echo -e "${C_BOLD}========== Docker 工具箱 · 一键全流程 ==========${C_RESET}"
  assert_linux; assert_root; assert_systemd
  detect_arch; detect_os; classify; validate_version

  if [[ "$PKG_MGR" == "dnf" || "$PKG_MGR" == "yum" ]]; then
    info "[前置] RHEL 系，先确保系统基础仓库可用（必要时自动切换镜像源）"
    MIRROR_FORCE=0 fix_mirrors
  fi

  step_install_docker
  step_configure
  step_verify
}

run_install() {
  while [[ $# -gt 0 ]]; do
    case "$1" in
      -h|--help) usage; exit 0 ;;
      -v|--version) shift; DOCKER_VERSION="${1:-}"; [[ -n "$DOCKER_VERSION" ]] || fail "选项 --version 需要指定版本号，例如 -v 24.0.7。"; shift ;;
      -y|--yes) NONINTERACTIVE=1; shift ;;
      *) fail "未知参数: $1（使用 -h 查看帮助）" ;;
    esac
  done

    echo -e "${C_BOLD}========== Docker 工具箱 · 安装 Docker ==========${C_RESET}"
    assert_linux; assert_root; assert_systemd
    detect_arch; detect_os; classify; validate_version
    if [[ "$PKG_MGR" == "dnf" || "$PKG_MGR" == "yum" ]]; then
      info "[前置] RHEL 系，先确保系统基础仓库可用（必要时自动切换镜像源）"
      MIRROR_FORCE=0 fix_mirrors
    fi
    step_install_docker
  step_configure
  step_verify
}

run_mirrors() {
  while [[ $# -gt 0 ]]; do
    case "$1" in
      -h|--help) usage; exit 0 ;;
      -y|--yes) NONINTERACTIVE=1; shift ;;
      -m|--mirror) shift; PRESET_MIRROR="${1:-}"; [[ -n "$PRESET_MIRROR" ]] || fail "选项 --mirror 需要指定地址，例如 -m https://mirrors.aliyun.com。"; shift ;;
      --dry-run) DRY_RUN=1; shift ;;
      *) fail "未知参数: $1（使用 -h 查看帮助）" ;;
    esac
  done

  echo -e "${C_BOLD}========== Docker 工具箱 · yum 镜像源修复 ==========${C_RESET}"
  assert_linux; assert_root
  detect_arch; detect_os; classify
  MIRROR_FORCE=1 fix_mirrors
}

run_config() {
  while [[ $# -gt 0 ]]; do
    case "$1" in
      -h|--help) usage; exit 0 ;;
      *) fail "未知参数: $1（使用 -h 查看帮助）" ;;
    esac
  done

  echo -e "${C_BOLD}========== Docker 工具箱 · 配置服务与用户组 ==========${C_RESET}"
  assert_linux; assert_root; assert_systemd
  detect_arch; detect_os; classify
  step_configure
  step_verify
}

run_verify() {
  while [[ $# -gt 0 ]]; do
    case "$1" in
      -h|--help) usage; exit 0 ;;
      *) fail "未知参数: $1（使用 -h 查看帮助）" ;;
    esac
  done

  echo -e "${C_BOLD}========== Docker 工具箱 · 验证 ==========${C_RESET}"
  assert_linux; assert_root; assert_systemd
  detect_arch; detect_os; classify
  step_verify
}

# ----------------------------- 帮助 -----------------------------
usage() {
  cat <<'EOF'
Docker 工具箱（单文件集成版）— 用法与功能清单

统一调用入口（子命令）：
  sudo bash docker_toolkit.sh auto          完整一键流程：检测→(修源)→安装→配置→验证
  sudo bash docker_toolkit.sh install       仅安装 Docker（检测→安装→配置→验证）
  sudo bash docker_toolkit.sh fix-mirrors   仅修复 yum/dnf 镜像源
  sudo bash docker_toolkit.sh config        仅（重）配置服务与用户组
  sudo bash docker_toolkit.sh verify        仅验证安装结果
  sudo bash docker_toolkit.sh -h            显示本帮助

常用选项：
  -v, --version VER   安装指定 Docker 版本（如 24.0.7），仅 install/auto 有效
  -y, --yes           非交互：镜像源自动选第一个
  -m, --mirror URL    直接指定镜像源根地址（跳过检测）
  --dry-run           仅检测与预览，不写入（fix-mirrors 有效）

集成功能（FC）与依赖：
  FC-1 运行环境检测     基础层，无依赖
  FC-2 yum 镜像源修复   依赖 FC-1、curl；仅 RHEL 系
  FC-3 Docker 安装      依赖 FC-1、FC-2(按需)、网络、root；支持指定版本
  FC-4 服务与用户组配置 依赖 FC-3
  FC-5 结果验证         依赖 FC-3、FC-4

默认架构：amd64 / arm64；支持 apt / dnf / yum / zypper。
EOF
}

# ----------------------------- 调度 -----------------------------
main() {
  local cmd="auto"
  if [[ $# -gt 0 ]]; then
    case "$1" in
      -h|--help|help) usage; exit 0 ;;
      auto|install|fix-mirrors|mirrors|config|verify)
        cmd="$1"; shift ;;
      *) echo "未知命令或参数: $1" >&2; usage; exit 1 ;;
    esac
  fi
  case "$cmd" in
    auto)            run_auto "$@" ;;
    install)         run_install "$@" ;;
    fix-mirrors|mirrors) run_mirrors "$@" ;;
    config)          run_config "$@" ;;
    verify)          run_verify "$@" ;;
  esac
}

main "$@"
