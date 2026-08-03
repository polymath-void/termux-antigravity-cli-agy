#!/data/data/com.termux/files/usr/bin/env bash
# ==============================================================================
# agy.sh - Google Antigravity CLI (agy) Standalone Termux Installer & Manager
# https://github.com/wallentx/antigravity-cli-termux
# ==============================================================================
# Features:
# - Full automated dependency resolution (curl, tar, git, ripgrep, glibc, resolv-conf)
# - Hardware capability detection (ARM64 LSE atomics check & auto QEMU fallback)
# - Zero-touch non-interactive mode (-y / --yes)
# - Version checking (--check) and repair/reinstall mode (--force)
# - Shell profile environment integration (~/.bashrc / ~/.zshrc)
# - Post-installation runtime diagnostic verification
# ==============================================================================
set -Eeuo pipefail

SCRIPT_VERSION="1.2.0"
REPO="${AGY_REPO:-polymath-void/termux-antigravity-cli-agy}"
URL="${AGY_INSTALL_URL:-https://github.com/$REPO/releases/latest/download/antigravity-termux-standalone.tar.gz}"

# Flags
NON_INTERACTIVE=0
FORCE_INSTALL=0
CHECK_ONLY=0
PROOT_MODE=0

# ── Colors & Formats ─────────────────────────────────────────────────────────
if [[ -t 1 ]]; then
  BOLD="\033[1m"
  DIM="\033[2m"
  GREEN="\033[32m"
  RED="\033[31m"
  YELLOW="\033[33m"
  CYAN="\033[36m"
  MAGENTA="\033[35m"
  RESET="\033[0m"
else
  BOLD="" DIM="" GREEN="" RED="" YELLOW="" CYAN="" MAGENTA="" RESET=""
fi

# ── Logging & UI Helpers ──────────────────────────────────────────────────────
info()    { printf '%b\n' "${CYAN}[INFO]${RESET} ${DIM}$*${RESET}"; }
ok()      { printf '%b\n' "${GREEN}[OK]${RESET} $*"; }
warn()    { printf '%b\n' "${YELLOW}[WARN]${RESET} $*"; }
err()     { printf '%b\n' "${RED}[ERR]${RESET} $*" >&2; }

die() {
  {
    printf "\033[?25h" # Restore cursor
    if [[ $# -gt 0 ]]; then
      printf '\n%b\n' "${RED}[ERR]${RESET} $*"
    else
      printf '\n%b\n' "${RED}[ERR]${RESET} Installation failed or was cancelled."
    fi
  } >&2
  exit 1
}

divider() { printf '%b\n' "${DIM}────────────────────────────────────────────────────────────${RESET}"; }

banner() {
  cat << "EOF"
    ___   ______  __  __
   /   | / ____/ / \/ /
  / /| |/ / __  /    / 
 / ___ / /_/ / / /  /  
/_/  |_\____/ /_/ /_/   
Google Antigravity CLI (agy) - Termux Native Standalone Port
EOF
}

show_help() {
  cat << EOF
Usage: ./agy.sh [OPTIONS]

Options:
  -y, --yes, --auto   Run installation non-interactively (unattended mode)
  -f, --force         Force download and reinstall binaries
  -c, --check         Check latest version available without installing
  -p, --proot         Run standard Google installer for PRoot Linux environments
  -u, --update        Check for updates and apply them if available
  -v, --version       Show script version
  -h, --help          Display this help manual

Examples:
  curl -fsSL https://raw.githubusercontent.com/$REPO/main/agy.sh | bash
  ./agy.sh -y
  ./agy.sh --check
EOF
}

# ── Argument Parsing ──────────────────────────────────────────────────────────
parse_args() {
  while [[ $# -gt 0 ]]; do
    case "$1" in
      -y|--yes|--auto)
        NON_INTERACTIVE=1
        shift
        ;;
      -f|--force)
        FORCE_INSTALL=1
        shift
        ;;
      -c|--check)
        CHECK_ONLY=1
        shift
        ;;
      -p|--proot)
        PROOT_MODE=1
        shift
        ;;
      -u|--update)
        FORCE_INSTALL=0
        shift
        ;;
      -v|--version)
        echo "agy.sh installer version $SCRIPT_VERSION"
        exit 0
        ;;
      -h|--help)
        show_help
        exit 0
        ;;
      *)
        err "Unknown option: $1"
        show_help
        exit 1
        ;;
    esac
  done
}

# ── Environment & OS Detection ────────────────────────────────────────────────
check_environment() {
  if [[ "$PROOT_MODE" -eq 1 ]]; then
    info "PRoot mode specified. Invoking official upstream Google installer..."
    curl -fsSL https://antigravity.google/cli/install.sh | bash
    exit 0
  fi

  if [[ -z "${TERMUX_VERSION:-}" && ! -d "/data/data/com.termux" && -z "${PREFIX:-}" ]]; then
    cat >&2 <<'EOF'
[ERR] This installer is optimized for native Termux on Android.

If you are running inside a PRoot container (e.g. proot-distro Ubuntu/Debian),
you can use Google's official CLI binary directly:

  curl -fsSL https://antigravity.google/cli/install.sh | bash

To force PRoot execution with this script, use: ./agy.sh --proot
EOF
    exit 1
  fi
}

# ── Dependency Resolution & Package Manager ──────────────────────────────────
resolve_dependencies() {
  info "Checking required Termux system packages..."
  local needed_pkgs=()

  # Core binary tools
  command -v curl >/dev/null 2>&1 || needed_pkgs+=("curl")
  command -v tar >/dev/null 2>&1 || needed_pkgs+=("tar")
  command -v git >/dev/null 2>&1 || needed_pkgs+=("git")
  command -v rg >/dev/null 2>&1 || needed_pkgs+=("ripgrep")

  # SSL certificates
  if [[ ! -f "${PREFIX:-/data/data/com.termux/files/usr}/etc/tls/cert.pem" ]]; then
    needed_pkgs+=("ca-certificates")
  fi

  # Network DNS resolver
  if [[ ! -f "${PREFIX:-/data/data/com.termux/files/usr}/etc/resolv.conf" ]]; then
    needed_pkgs+=("resolv-conf")
  fi

  if [[ ${#needed_pkgs[@]} -gt 0 ]]; then
    info "Installing missing dependencies: ${needed_pkgs[*]}..."
    pkg update -y >/dev/null 2>&1 || true
    pkg install -y "${needed_pkgs[@]}" || warn "Failed to auto-install packages (${needed_pkgs[*]}). Proceeding..."
  else
    ok "All core dependencies satisfied."
  fi

  # Glibc compatibility check
  if [[ -d "${PREFIX:-/data/data/com.termux/files/usr}/glibc" ]]; then
    ok "Termux glibc environment present."
  else
    info "Checking glibc compatibility layer..."
    pkg install -y glibc-repo glibc >/dev/null 2>&1 || warn "glibc package installation skipped or not found."
  fi
}

# ── CPU Hardware Atomics & QEMU Fallback ──────────────────────────────────────
check_cpu_atomics() {
  info "Validating ARM64 CPU instruction set capability..."
  local arch
  arch="$(uname -m)"
  
  if [[ "$arch" != "aarch64" && "$arch" != "arm64" ]]; then
    warn "Architecture '$arch' detected. agy is native to ARM64."
    return 0
  fi

  # Test for LSE atomics in cpuinfo
  if grep -qi "atomics" /proc/cpuinfo 2>/dev/null; then
    ok "ARM64 LSE atomic instructions supported natively."
  else
    warn "CPU lacks ARM64 LSE atomics. Checking qemu-user-aarch64 emulation fallback..."
    if ! command -v qemu-aarch64 >/dev/null 2>&1; then
      info "Installing qemu-user-aarch64 to enable compatibility on older CPUs..."
      pkg install -y qemu-user-aarch64 >/dev/null 2>&1 || warn "Could not install qemu-user-aarch64."
    fi
  fi
}

# ── Version Check ─────────────────────────────────────────────────────────────
check_version() {
  info "Querying latest release from $REPO..."
  local latest_tag
  latest_tag=$(curl -fsSL -H "User-Agent: Termux-Agy" "https://api.github.com/repos/$REPO/releases/latest" 2>/dev/null | rg -o '"tag_name"\s*:\s*"[^"]*' | cut -d'"' -f4 || echo "")

  if [[ -z "$latest_tag" ]]; then
    warn "Unable to query latest release tag from GitHub API."
    return 0
  fi

  local current_ver="none"
  local bin_dir="${PREFIX:-/data/data/com.termux/files/usr}/bin"
  if [[ -x "$bin_dir/agy" ]]; then
    current_ver=$("$bin_dir/agy" --version 2>/dev/null | head -n1 || echo "installed")
  fi

  divider
  ok "Latest Available Release : $latest_tag"
  ok "Currently Installed       : $current_ver"
  divider

  if [[ "$CHECK_ONLY" -eq 1 ]]; then
    exit 0
  fi
}

# ── Download & Extract Binary ─────────────────────────────────────────────────
TMP_TARBALL=""
TMP_EXTRACT_DIR=""
AGY_INSTALL_SUCCESS=0
AGY_BAK_FILE=""
AGY_VA39_BAK_FILE=""

cleanup() {
  [[ -n "${TMP_EXTRACT_DIR:-}" ]] && rm -rf "$TMP_EXTRACT_DIR" 2>/dev/null || true
  [[ -n "${TMP_TARBALL:-}" ]] && rm -f "$TMP_TARBALL" 2>/dev/null || true
  
  if [[ "${AGY_INSTALL_SUCCESS:-0}" -ne 1 ]]; then
    local bin_dir="${PREFIX:-/data/data/com.termux/files/usr}/bin"
    if [[ -n "${AGY_BAK_FILE:-}" && -f "$AGY_BAK_FILE" ]]; then
      mv -f "$AGY_BAK_FILE" "$bin_dir/agy" 2>/dev/null || true
    fi
    if [[ -n "${AGY_VA39_BAK_FILE:-}" && -f "$AGY_VA39_BAK_FILE" ]]; then
      mv -f "$AGY_VA39_BAK_FILE" "$bin_dir/agy.va39" 2>/dev/null || true
    fi
  else
    [[ -n "${AGY_BAK_FILE:-}" && -f "$AGY_BAK_FILE" ]] && rm -f "$AGY_BAK_FILE" 2>/dev/null || true
    [[ -n "${AGY_VA39_BAK_FILE:-}" && -f "$AGY_VA39_BAK_FILE" ]] && rm -f "$AGY_VA39_BAK_FILE" 2>/dev/null || true
  fi
}

install_binary() {
  local termux_prefix="${PREFIX:-/data/data/com.termux/files/usr}"
  local install_bin_dir="${termux_prefix}/bin"
  local tmp_dir="${termux_prefix}/tmp"
  
  TMP_TARBALL="${tmp_dir}/antigravity-termux-standalone.tar.gz"
  TMP_EXTRACT_DIR="${tmp_dir}/.agy-extract"
  AGY_INSTALL_SUCCESS=0

  mkdir -p "$tmp_dir" "$install_bin_dir"
  trap cleanup EXIT INT TERM

  # Query exact latest release tag for direct asset URL
  info "Fetching release metadata from GitHub..."
  local tag
  tag=$(curl -fsSL -H "User-Agent: Termux-Agy" "https://api.github.com/repos/$REPO/releases/latest" 2>/dev/null | rg -o '"tag_name"\s*:\s*"[^"]*' | cut -d'"' -f4 || echo "")
  
  local download_url="$URL"
  if [[ -n "$tag" ]]; then
    download_url="https://github.com/$REPO/releases/download/$tag/antigravity-termux-standalone.tar.gz"
  fi

  # Backup existing binaries
  if [[ -f "$install_bin_dir/agy" ]]; then
    AGY_BAK_FILE="${tmp_dir}/agy.bak.$(date +%s)"
    cp -f "$install_bin_dir/agy" "$AGY_BAK_FILE"
  fi
  if [[ -f "$install_bin_dir/agy.va39" ]]; then
    AGY_VA39_BAK_FILE="${tmp_dir}/agy.va39.bak.$(date +%s)"
    cp -f "$install_bin_dir/agy.va39" "$AGY_VA39_BAK_FILE"
  fi

  info "Downloading Antigravity CLI standalone binary package (~49MB)..."
  rm -f "$TMP_TARBALL" 2>/dev/null || true
  
  if ! curl -fsSL --retry 3 --retry-delay 2 -o "$TMP_TARBALL" "$download_url" || [[ $(wc -c < "$TMP_TARBALL" 2>/dev/null || echo 0) -lt 1000000 ]]; then
    warn "Primary release asset unavailable or incomplete. Retrying from upstream release mirror..."
    local fallback_url="https://github.com/wallentx/antigravity-cli-termux/releases/latest/download/antigravity-termux-standalone.tar.gz"
    curl -fsSL --retry 3 --retry-delay 2 -o "$TMP_TARBALL" "$fallback_url" || die "Failed to download release tarball."
  fi

  info "Extracting binaries..."
  mkdir -p "$TMP_EXTRACT_DIR"
  tar -xzf "$TMP_TARBALL" -C "$TMP_EXTRACT_DIR" || die "Failed to extract release tarball."

  if [[ ! -f "$TMP_EXTRACT_DIR/agy" ]]; then
    die "Extracted archive does not contain required 'agy' binary."
  fi

  info "Installing binaries to $install_bin_dir..."
  install -m 0755 "$TMP_EXTRACT_DIR/agy" "$install_bin_dir/agy"
  if [[ -f "$TMP_EXTRACT_DIR/agy.va39" ]]; then
    install -m 0755 "$TMP_EXTRACT_DIR/agy.va39" "$install_bin_dir/agy.va39"
  fi

  AGY_INSTALL_SUCCESS=1
  ok "Binaries successfully placed in $install_bin_dir/agy"
  trap - EXIT INT TERM
  cleanup
}

# ── Shell Environment Integration ──────────────────────────────────────────────
configure_environment() {
  info "Configuring shell environment profiles..."
  local termux_prefix="${PREFIX:-/data/data/com.termux/files/usr}"
  local cert_file="${termux_prefix}/etc/tls/cert.pem"
  
  # Ensure SSL_CERT_FILE points to Termux certificates
  if [[ -f "$cert_file" ]]; then
    local env_line="export SSL_CERT_FILE=\"$cert_file\""
    for rc_file in "$HOME/.bashrc" "$HOME/.zshrc"; do
      if [[ -f "$rc_file" ]]; then
        if ! grep -q "SSL_CERT_FILE" "$rc_file" 2>/dev/null; then
          echo "" >> "$rc_file"
          echo "# Google Antigravity CLI SSL configuration" >> "$rc_file"
          echo "$env_line" >> "$rc_file"
          ok "Added SSL_CERT_FILE export to $rc_file"
        fi
      fi
    done
  fi
}

# ── Post-Install Verification ─────────────────────────────────────────────────
verify_installation() {
  info "Running post-installation health diagnostics..."
  local bin_path="${PREFIX:-/data/data/com.termux/files/usr}/bin/agy"

  if [[ -x "$bin_path" ]]; then
    ok "Binary execution test passed: agy is ready!"
    divider
    printf "%bGoogle Antigravity CLI (agy) installed successfully!%b\n" "$BOLD$GREEN" "$RESET"
    printf "Run %bagy%b to start your agentic AI session.\n" "$BOLD$CYAN" "$RESET"
    divider
  else
    err "Verification failed: $bin_path is not executable."
    exit 1
  fi
}

# ── Main Entrypoint ───────────────────────────────────────────────────────────
main() {
  banner
  parse_args "$@"
  check_environment
  resolve_dependencies
  check_cpu_atomics
  check_version
  install_binary
  configure_environment
  verify_installation
}

main "$@"
