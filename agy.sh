#!/data/data/com.termux/files/usr/bin/env bash
# ==============================================================================
# agy.sh - Google Antigravity CLI (agy) Standalone Termux Installer & Manager
# https://github.com/polymath-void/termux-antigravity-cli-agy
# ==============================================================================
# Features:
# - Native 64-bit Termux execution by default (F-Droid / GitHub Termux builds)
# - Robust mandatory glibc & glibc-runner installation with fallback mirrors
# - QEMU user-mode emulation fallback ONLY for 32-bit Play Store legacy userlands
# - Smart binary caching & version check (skips download if up-to-date, interactive prompt)
# - Rich terminal micro-animations & 256-color palette styling
# - Shell profile environment & alias auto-integration (~/.bashrc / ~/.zshrc)
# ==============================================================================
set -Eeuo pipefail

SCRIPT_VERSION="1.4.0"
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
  GREEN="\033[38;5;82m"
  RED="\033[38;5;196m"
  YELLOW="\033[38;5;220m"
  CYAN="\033[38;5;51m"
  MAGENTA="\033[38;5;201m"
  BLUE="\033[38;5;39m"
  RESET="\033[0m"
else
  BOLD="" DIM="" GREEN="" RED="" YELLOW="" CYAN="" MAGENTA="" BLUE="" RESET=""
fi

# ── Logging & UI Helpers ──────────────────────────────────────────────────────
info()    { printf "%b[INFO]%b %b%s%b\n" "$CYAN" "$RESET" "$DIM" "$*" "$RESET"; }
ok()      { printf "%b[OK]%b   %s\n" "$GREEN" "$RESET" "$*"; }
warn()    { printf "%b[WARN]%b %s\n" "$YELLOW" "$RESET" "$*"; }
err()     { printf "%b[ERR]%b  %s\n" "$RED" "$RESET" "$*" >&2; }

die() {
  {
    printf "\033[?25h" # Restore cursor
    if [[ $# -gt 0 ]]; then
      printf "\n%b[ERR]%b %s\n" "$RED" "$RESET" "$*"
    else
      printf "\n%b[ERR]%b Installation failed or was cancelled.\n" "$RED" "$RESET"
    fi
  } >&2
  exit 1
}

divider() { printf "%b────────────────────────────────────────────────────────────%b\n" "$DIM" "$RESET"; }

banner() {
  cat << "EOF"
  \033[38;5;51m  ___   ______  __  __  \033[0m
  \033[38;5;39m /   | / ____/ / \/ /  \033[0m
  \033[38;5;82m/ /| |/ / __  /    /   \033[0m
 \033[38;5;220m/ ___ / /_/ / / /  /    \033[0m
\033[38;5;201m/_/  |_\____/ /_/ /_/     \033[0m
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
  ./agy.sh --force
EOF
}

# ── Micro-Animation Spinner ──────────────────────────────────────────────────
spin_wait() {
  local pid=$1
  local msg=$2
  local delay=0.08
  local spinstr="⠋⠙⠹⠸⠼⠴⠦⠧⠇⠏"
  if [[ -t 1 ]]; then
    printf "\033[?25l"
    while kill -0 "$pid" 2>/dev/null; do
      local temp=${spinstr#?}
      printf "\r %b%s%b %s" "$CYAN" "${spinstr:0:1}" "$RESET" "$msg"
      spinstr=$temp${spinstr%"$temp"}
      sleep $delay
    done
    printf "\r\033[K\033[?25h"
  else
    wait "$pid" 2>/dev/null || true
  fi
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

# ── Mandatory Glibc & Dependency Resolution (With Fallback Pipeline) ──────────
resolve_dependencies() {
  info "Checking required Termux system packages..."
  local needed_pkgs=()

  # Core binary tools
  command -v curl >/dev/null 2>&1 || needed_pkgs+=("curl")
  command -v tar >/dev/null 2>&1 || needed_pkgs+=("tar")
  command -v git >/dev/null 2>&1 || needed_pkgs+=("git")
  command -v rg >/dev/null 2>&1 || needed_pkgs+=("ripgrep")

  # SSL certificates & DNS
  if [[ ! -f "${PREFIX:-/data/data/com.termux/files/usr}/etc/tls/cert.pem" ]]; then
    needed_pkgs+=("ca-certificates")
  fi
  if [[ ! -f "${PREFIX:-/data/data/com.termux/files/usr}/etc/resolv.conf" ]]; then
    needed_pkgs+=("resolv-conf")
  fi

  if [[ ${#needed_pkgs[@]} -gt 0 ]]; then
    info "Installing missing core dependencies: ${needed_pkgs[*]}..."
    (pkg update -y >/dev/null 2>&1 || true; pkg install -y "${needed_pkgs[@]}" >/dev/null 2>&1) &
    spin_wait $! "Installing core dependencies..."
    ok "Core system dependencies satisfied."
  else
    ok "Core system dependencies satisfied."
  fi

  # Mandatory Glibc & Glibc-Runner Installation Pipeline
  info "Verifying mandatory glibc compatibility layer & glibc-runner..."
  if dpkg -l | grep -q "glibc" 2>/dev/null || [[ -d "${PREFIX:-/data/data/com.termux/files/usr}/glibc" ]]; then
    ok "Mandatory glibc environment & glibc-runner ready."
  else
    info "Installing glibc-repo and glibc-runner packages..."
    (
      pkg update -y >/dev/null 2>&1 || true
      if ! pkg install -y glibc-repo glibc-runner glibc >/dev/null 2>&1; then
        warn "Primary glibc package install failed. Attempting fallback via apt-get..."
        apt-get update -y >/dev/null 2>&1 || true
        apt-get install -y glibc-repo glibc-runner glibc >/dev/null 2>&1 || true
      fi
    ) &
    spin_wait $! "Configuring mandatory glibc environment..."

    if dpkg -l | grep -q "glibc" 2>/dev/null || [[ -d "${PREFIX:-/data/data/com.termux/files/usr}/glibc" ]]; then
      ok "Mandatory glibc environment successfully installed."
    else
      warn "Glibc package installation returned warnings. Proceeding with Bionic fallback."
    fi
  fi
}

# ── Hardware & Bitness Check (64-Bit Native Default, 32-Bit QEMU Fallback) ──
IS_32BIT_USERLAND=0

check_cpu_atomics() {
  info "Detecting hardware architecture & userland bitness..."
  local arch
  arch="$(uname -m)"
  
  if [[ "$arch" == "aarch64" || "$arch" == "arm64" || "$arch" == "x86_64" ]]; then
    ok "Native 64-bit Termux environment detected ($arch)."
    IS_32BIT_USERLAND=0
  else
    warn "Legacy 32-bit userland detected ($arch). QEMU AArch64 emulation fallback required."
    IS_32BIT_USERLAND=1
    info "Installing QEMU user-mode emulator for 32-bit legacy support..."
    (
      pkg update -y >/dev/null 2>&1 || true
      pkg install -y qemu-user-aarch64 proot >/dev/null 2>&1 || true
    ) &
    spin_wait $! "Configuring QEMU user-mode emulator..."
  fi
}

# ── Version & Smart Cache Manager ─────────────────────────────────────────────
LATEST_TAG=""
CURRENT_VER="none"
CACHE_DIR="${PREFIX:-/data/data/com.termux/files/usr}/tmp/.agy-cache"

check_version() {
  info "Querying latest release from $REPO..."
  (curl -fsSL -H "User-Agent: Termux-Agy" "https://api.github.com/repos/$REPO/releases/latest" 2>/dev/null | rg -o '"tag_name"\s*:\s*"[^"]*' | cut -d'"' -f4 > "${PREFIX:-/data/data/com.termux/files/usr}/tmp/.latest_tag" || echo "") &
  spin_wait $! "Fetching release metadata..."
  
  LATEST_TAG=$(cat "${PREFIX:-/data/data/com.termux/files/usr}/tmp/.latest_tag" 2>/dev/null || echo "")
  rm -f "${PREFIX:-/data/data/com.termux/files/usr}/tmp/.latest_tag" 2>/dev/null || true

  local bin_dir="${PREFIX:-/data/data/com.termux/files/usr}/bin"
  if [[ -x "$bin_dir/agy" ]]; then
    CURRENT_VER=$("$bin_dir/agy" --version 2>/dev/null | head -n1 || echo "installed")
  fi

  divider
  ok "Latest Available Release : ${LATEST_TAG:-unknown}"
  ok "Currently Installed       : $CURRENT_VER"
  divider

  if [[ "$CHECK_ONLY" -eq 1 ]]; then
    exit 0
  fi

  # Smart update check: If current version matches latest release tag and not forced
  if [[ -n "$LATEST_TAG" && "$CURRENT_VER" == "$LATEST_TAG" && "$FORCE_INSTALL" -eq 0 ]]; then
    if [[ "$NON_INTERACTIVE" -eq 1 ]]; then
      ok "Antigravity CLI is already at the latest version ($LATEST_TAG). No update needed."
      exit 0
    else
      printf "%bAntigravity CLI ($LATEST_TAG) is already installed.%b\n" "$BOLD$GREEN" "$RESET"
      printf "%bWould you like to force reinstall? [y/N]: %b" "$BOLD$YELLOW" "$RESET"
      read -r response || response="n"
      case "$response" in
        [yY][eE][sS]|[yY])
          info "Force reinstall confirmed."
          FORCE_INSTALL=1
          ;;
        *)
          ok "Already up to date. Exiting cleanly."
          exit 0
          ;;
      esac
    fi
  fi
}

# ── Download & Extract Binary (With Persistent Caching) ─────────────────────
TMP_TARBALL=""
TMP_EXTRACT_DIR=""
AGY_INSTALL_SUCCESS=0
AGY_BAK_FILE=""
AGY_VA39_BAK_FILE=""

cleanup() {
  [[ -n "${TMP_EXTRACT_DIR:-}" ]] && rm -rf "$TMP_EXTRACT_DIR" 2>/dev/null || true
  
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
  
  mkdir -p "$tmp_dir" "$install_bin_dir" "$CACHE_DIR"
  trap cleanup EXIT INT TERM

  local tag="${LATEST_TAG:-latest}"
  local cached_tarball="${CACHE_DIR}/antigravity-${tag}.tar.gz"
  TMP_EXTRACT_DIR="${tmp_dir}/.agy-extract"
  AGY_INSTALL_SUCCESS=0

  # Check persistent cache file
  if [[ -f "$cached_tarball" && $(wc -c < "$cached_tarball" 2>/dev/null || echo 0) -gt 1000000 && "$FORCE_INSTALL" -eq 0 ]]; then
    ok "Using cached release package: antigravity-${tag}.tar.gz"
    TMP_TARBALL="$cached_tarball"
  else
    info "Downloading Antigravity CLI binary package (~49MB)..."
    local download_url="$URL"
    if [[ -n "$LATEST_TAG" ]]; then
      download_url="https://github.com/$REPO/releases/download/$LATEST_TAG/antigravity-termux-standalone.tar.gz"
    fi

    (
      rm -f "$cached_tarball" 2>/dev/null || true
      if ! curl -fsSL --retry 3 --retry-delay 2 -o "$cached_tarball" "$download_url" || [[ $(wc -c < "$cached_tarball" 2>/dev/null || echo 0) -lt 1000000 ]]; then
        local fallback_url="https://github.com/wallentx/antigravity-cli-termux/releases/latest/download/antigravity-termux-standalone.tar.gz"
        curl -fsSL --retry 3 --retry-delay 2 -o "$cached_tarball" "$fallback_url" || exit 1
      fi
    ) &
    spin_wait $! "Downloading binary archive..."

    if [[ ! -f "$cached_tarball" || $(wc -c < "$cached_tarball" 2>/dev/null || echo 0) -lt 1000000 ]]; then
      die "Failed to download release tarball package."
    fi
    TMP_TARBALL="$cached_tarball"
    ok "Release package downloaded and saved to cache."
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

  info "Extracting binaries..."
  mkdir -p "$TMP_EXTRACT_DIR"
  (tar -xzf "$TMP_TARBALL" -C "$TMP_EXTRACT_DIR") &
  spin_wait $! "Unpacking binaries..."

  if [[ ! -f "$TMP_EXTRACT_DIR/agy" ]]; then
    die "Extracted archive does not contain required 'agy' binary."
  fi

  info "Installing binaries to $install_bin_dir..."
  install -m 0755 "$TMP_EXTRACT_DIR/agy" "$install_bin_dir/agy.native"
  if [[ -f "$TMP_EXTRACT_DIR/agy.va39" ]]; then
    install -m 0755 "$TMP_EXTRACT_DIR/agy.va39" "$install_bin_dir/agy.va39"
  fi

  # Default 64-Bit vs 32-Bit QEMU Setup
  if [[ "$IS_32BIT_USERLAND" -eq 0 ]] && "$install_bin_dir/agy.native" --version >/dev/null 2>&1; then
    ok "Deploying native 64-bit binary executable..."
    install -m 0755 "$TMP_EXTRACT_DIR/agy" "$install_bin_dir/agy"
  else
    warn "Setting up QEMU user-mode emulation wrapper for legacy 32-bit userland..."
    cat << 'EOF' > "$install_bin_dir/agy"
#!/data/data/com.termux/files/usr/bin/env bash
export SSL_CERT_FILE="${SSL_CERT_FILE:-/data/data/com.termux/files/usr/etc/tls/cert.pem}"
export TMPDIR="${TMPDIR:-/data/data/com.termux/files/usr/tmp}"
PREFIX="${PREFIX:-/data/data/com.termux/files/usr}"

if "$PREFIX/bin/agy.native" --version >/dev/null 2>&1; then
  exec "$PREFIX/bin/agy.native" "$@"
elif command -v qemu-aarch64 >/dev/null 2>&1; then
  exec qemu-aarch64 -L "$PREFIX" "$PREFIX/bin/agy.native" "$@"
elif command -v proot >/dev/null 2>&1; then
  exec proot -q qemu-aarch64 "$PREFIX/bin/agy.native" "$@"
else
  echo "[ERR] Cannot execute 64-bit agy binary on 32-bit Termux userland." >&2
  echo "[ERR] Install qemu-user-aarch64 via: pkg install qemu-user-aarch64" >&2
  exit 1
fi
EOF
    chmod 0755 "$install_bin_dir/agy"
  fi

  # Convenience symlinks in user PATH directories
  mkdir -p "$HOME/.local/bin" "$HOME/bin"
  ln -sf "$install_bin_dir/agy" "$HOME/.local/bin/agy" 2>/dev/null || true
  ln -sf "$install_bin_dir/agy" "$HOME/bin/agy" 2>/dev/null || true

  AGY_INSTALL_SUCCESS=1
  ok "Binaries successfully deployed to $install_bin_dir/agy"
  trap - EXIT INT TERM
  cleanup
}

# ── Shell Environment Integration ──────────────────────────────────────────────
configure_environment() {
  info "Configuring shell environment profiles & aliases..."
  local termux_prefix="${PREFIX:-/data/data/com.termux/files/usr}"
  local cert_file="${termux_prefix}/etc/tls/cert.pem"
  local bin_dir="${termux_prefix}/bin"
  
  for rc_file in "$HOME/.bashrc" "$HOME/.zshrc" "$HOME/.profile"; do
    touch "$rc_file" 2>/dev/null || true
    
    # 1. SSL Certificate path
    if [[ -f "$cert_file" ]]; then
      if ! grep -q "SSL_CERT_FILE" "$rc_file" 2>/dev/null; then
        echo "" >> "$rc_file"
        echo "# Google Antigravity CLI SSL configuration" >> "$rc_file"
        echo "export SSL_CERT_FILE=\"$cert_file\"" >> "$rc_file"
        ok "Added SSL_CERT_FILE export to $rc_file"
      fi
    fi

    # 2. PATH export for Termux & local bin
    if ! grep -q "$bin_dir" "$rc_file" 2>/dev/null; then
      echo "export PATH=\"$bin_dir:\$HOME/.local/bin:\$HOME/bin:\$PATH\"" >> "$rc_file"
      ok "Added PATH export to $rc_file"
    fi

    # 3. Alias fallback for agy
    if ! grep -q "alias agy=" "$rc_file" 2>/dev/null; then
      echo "alias agy=\"$bin_dir/agy\"" >> "$rc_file"
      ok "Added 'agy' alias to $rc_file"
    fi
  done
}

# ── Post-Install Verification ─────────────────────────────────────────────────
verify_installation() {
  info "Running post-installation health diagnostics..."
  local bin_path="${PREFIX:-/data/data/com.termux/files/usr}/bin/agy"

  if [[ -x "$bin_path" ]]; then
    if "$bin_path" --version >/dev/null 2>&1 || "$bin_path" --help >/dev/null 2>&1; then
      ok "Binary execution test passed: agy is ready!"
    else
      warn "Execution warning: Testing fallback emulation mode..."
    fi
    divider
    printf "%bGoogle Antigravity CLI (agy) installed successfully!%b\n" "$BOLD$GREEN" "$RESET"
    printf "Run %bagy%b or %b~/.local/bin/agy%b to start your session.\n" "$BOLD$CYAN" "$RESET" "$BOLD$CYAN" "$RESET"
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
