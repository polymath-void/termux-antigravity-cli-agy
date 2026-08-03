# AGENTS.MD - Agent Memory & Context Log

> **MANDATORY INSTRUCTION FOR ALL AI AGENTS**:
> Whenever you create a plan, perform an update, downgrade a component, or make any code or architecture changes in this repository, you **MUST** append a short entry to the [Change Log](#-change-log--execution-history) section of this file to preserve context for future agent sessions.

---

## 📌 Project Overview & Architecture

**Repository**: `polymath-void/termux-antigravity-cli-agy`  
**Purpose**: Native AArch64 Android Termux port and automated build pipeline for Google Antigravity CLI (`agy`).

### Key Modules:
- **`agy.sh`**: Primary user-facing installer and runtime manager. Handles dependency resolution (`curl`, `tar`, `git`, `ripgrep`, `ca-certificates`, `resolv-conf`), ARM64 LSE atomics check with QEMU fallback, version checks, and shell environment setup (`SSL_CERT_FILE`).
- **`bootstrapper/main.c`**: Native Bionic C binary wrapper. Strips interfering `LD_PRELOAD` variables, enforces `SSL_CERT_FILE` and `TMPDIR` paths, and launches core engine `agy.va39`.
- **`scripts/build_standalone.sh`**: Standalone packager script used locally and by GitHub Actions to download upstream release binaries, compile `bootstrapper/main.c`, apply TCmalloc patches, and create `antigravity-termux-standalone.tar.gz`.
- **`.github/workflows/sync-and-release.yml`**: Scheduled CI workflow (runs every 6 hours) to cross-compile the bootstrapper and publish GitHub releases.

---

## 🌐 Environment & System Knowledge

- **Target System**: Android 16 (AArch64 / ARM64) Termux Environment
- **Rootfs Paths**:
  - `$PREFIX`: `/data/data/com.termux/files/usr`
  - `$HOME`: `/data/data/com.termux/files/home`
  - Workspace: `/media/polymath-void/54A24AFDA24AE2DA/Antigravity/Git-void/termux-antigravity-cli-agy`
- **Execution Rules**:
  - Binary target is ARM64 Bionic libc compatible.
  - Requires `SSL_CERT_FILE=$PREFIX/etc/tls/cert.pem` and `TMPDIR=$PREFIX/tmp`.
  - Synced with `termux-environment` skill and 73 workspace skills (`~/.gemini/antigravity-cli/skills`).

---

## 📜 Change Log & Execution History

### [2026-08-04] - Codebase Audit, Bootstrapper Enhancement & Build Pipeline Verification
- **Codebase Review**: Completed full inspection of `agy.sh`, `bootstrapper/main.c`, `scripts/build_standalone.sh`, and GitHub Actions workflow.
- **Bootstrapper Update (`bootstrapper/main.c`)**:
  - Added automatic `TMPDIR` fallback setup pointing to `$PREFIX/tmp` or `/data/data/com.termux/files/usr/tmp`.
  - Verified local C cross-compilation (`gcc -O2 -Wall`) with 0 warnings.
- **Build Pipeline Update (`scripts/build_standalone.sh`)**:
  - Updated primary release URL to point directly to `polymath-void/termux-antigravity-cli-agy` with multi-tier mirrors.
  - Verified standalone build pipeline: generated 49.18 MB production release tarball (`dist/antigravity-termux-standalone.tar.gz`).
- **Repository Setup**:
  - Created `.gitignore` excluding `build_workspace/`, `dist/`, and build artifacts.
  - Created `AGENTS.MD` for agent context persistence.

### [2026-08-04] - Fix 32-bit Termux Userland Emulation & Alias Auto-Configuration
- **Root Cause Fix (`agy.sh`)**: Resolved `"agy is 64-bit instead of 32-bit"` error on 32-bit Termux userlands (`armv7l`, `armv8l`, `arm32`).
- **QEMU & PRoot Fallback**: Added auto-installation of `qemu-user-aarch64` and `proot`. Placed native 64-bit binary as `agy.native` and created a POSIX wrapper script at `$PREFIX/bin/agy` that dynamically invokes `qemu-aarch64 -L $PREFIX` when native 64-bit execution is unsupported by the OS kernel linker.
- **Shell Alias & PATH Persistence**: Added automatic `PATH` exports and `alias agy="$PREFIX/bin/agy"` into `$HOME/.bashrc`, `$HOME/.zshrc`, `$HOME/.profile`, and symlinks in `$HOME/.local/bin/agy` and `$HOME/bin/agy`.

