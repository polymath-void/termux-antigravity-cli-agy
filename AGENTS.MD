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

### [2026-08-04] - Add glibc-runner Auto-Install, Smart Persistent Caching & Terminal Micro-Animations
- **Glibc & Runner Auto-Provisioning**: Updated `resolve_dependencies()` to automatically install `glibc-repo`, `glibc-runner`, and `glibc` packages via Termux package manager.
- **Smart Persistent Binary Caching**: Downloads are stored persistently in `$PREFIX/tmp/.agy-cache/antigravity-$TAG.tar.gz`. Subsequent script runs verify cached binary tarballs and skip re-downloading if already present.
- **Interactive Force Reinstall Prompt**: If installed version matches latest release tag, `agy.sh` displays an interactive prompt asking `"Would you like to force reinstall? [y/N]"`. If user declines (or non-interactive mode is active without `-f`), script exits cleanly with zero redundant downloads.
- **Terminal UI Micro-Animations**: Integrated animated terminal spinners (`spin_wait`) and 256-color palette styling during package resolution, downloading, and binary unpacking.

### [2026-08-09] - Fix Native Binary Execution: Glibc-Runner Integration, Path Resolution & Go DNS Resolver Fix
- **Fix (`agy.sh`)**: The native 64-bit binary was found to be glibc-linked, causing execution failure on native Termux (Bionic). Updated the binary deployment logic to generate a Bash wrapper that invokes the core engine (`agy.va39`) directly using `glibc-runner`. This bypasses the C bootstrapper (`agy.native`) which suffers from path resolution issues under `glibc-runner` (where `/proc/self/exe` evaluates to `ld.so` in `/usr/glibc/lib/`).
- **Bootstrapper Fix (`bootstrapper/main.c`)**: Added robust fallback path resolution to look in `$PREFIX/bin/agy.va39` if `agy.va39` is not found relative to `/proc/self/exe`. This ensures that even if the bootstrapper is executed via `glibc-runner`, it can find the engine.
- **Go DNS Resolver Fix (`agy.sh`)**: Added `export GODEBUG=netdns=cgo` to the wrappers. This forces the Go runtime in the dynamically linked `agy.va39` binary to use glibc's `getaddrinfo` (which correctly reads the glibc-prefixed `/etc/resolv.conf`) instead of Go's native resolver (which incorrectly defaults to `[::1]:53` and fails inside Termux because `/etc/resolv.conf` is missing from the Android filesystem root).
- **Verification**: Verified that `glibc-runner` successfully launches `agy.va39` directly, returning correct execution output (`1.1.10`). Also verified that the DNS is properly resolved inside the glibc environment.

### [2026-09-11] - Fix Glibc Dynamic Linker (ld.so) Execution and Update/Install Failures
- **Dynamic Linker Resolution in Bootstrapper (`bootstrapper/main.c`)**: Updated the native Bionic C launcher to automatically inspect `$PREFIX/glibc/lib/` for the architecture dynamic loader (`ld-linux-aarch64.so.1`, `ld.so`, `ld-linux-x86-64.so.2`). When found, it executes the glibc loader with `--library-path $PREFIX/glibc/lib` directly into `agy.va39`, eliminating the previous `cannot execute: required file not found` failure during direct `execv` calls and ensuring release binaries pass `--help` validation in upstream self-update pipelines.
- **Removed Duplicate Linker in Wrapper (`agy.sh`)**: Eliminated erroneous `glibc-runner <ld-linux.so> --library-path ...` calls which caused `loader cannot load itself` errors due to `glibc-runner` wrapping an already-invoked `ld.so`.
- **Dynamic Glibc Loader Launcher**: Added native binary compilation of `bootstrapper/main.c` on install, and generated a robust dynamic loader wrapper that dispatches directly via `$PREFIX/glibc/lib/ld*` with fallback to `glibc-runner` and `qemu-aarch64`.
- **Permissions and Dependency Verification**: Added automated detection of dynamic loader existence and enforced `chmod 0755` on `$PREFIX/glibc/lib/ld*` so unprivileged/restricted file extractions do not cause `Permission denied` during execution.
- **Update Flag Fix**: Updated `-u|--update` in `agy.sh` to enforce `FORCE_INSTALL=1` to ensure updates download cleanly when triggered.

### [2026-09-11] - Fix Workflow Stale Binary Loop & Migrate to Official Google Release
- **Fixed Stale Self-Referential Download Loop (`scripts/build_standalone.sh`)**: The build pipeline previously defined `URL1` as `polymath-void/termux-antigravity-cli-agy/releases/latest/download/...`. This caused GitHub Actions to continuously download the repo's own old release (stuck on 1.1.10) instead of fetching updates from Google. Removed self-referential downloads completely.
- **Official Google Antigravity Manifest Integration**: Rewrote `scripts/build_standalone.sh` to query the official Google auto-updater endpoint (`https://antigravity-cli-auto-updater-974169037036.us-central1.run.app/manifests/linux_arm64.json`) and retrieve the official Linux ARM64 binary archive (`cli_linux_arm64.tar.gz`) directly from Google Cloud Storage.
- **Automated Termux Compatibility Patcher (`scripts/patch_va39.py` & `scripts/patch_va39_rules.json`)**: Built a binary patcher that transforms the official Google `antigravity` build into `agy.va39` by replacing the `faccessat2` syscall (439 / `0x1b7`) with `faccessat` (48 / `0x30`) to eliminate Android kernel/seccomp `SIGSYS` crashes, and adjusting TCMalloc VA48 address-space bits to VA39 for Android ARM64 hardware compatibility.
- **Semantic Versioning in Release Workflow (`.github/workflows/sync-and-release.yml`)**: Updated the GitHub Actions workflow to extract the exact upstream version from `dist/VERSION` (e.g. `1.2.1`), tagging releases as `v${VERSION}` and setting `make_latest: true`.
- **Version Normalization in Installer (`agy.sh`)**: Normalized versions in `check_version()` by stripping leading `v` prefixes to ensure accurate comparison between installed versions and release tags.





