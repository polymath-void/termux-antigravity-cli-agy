# Google Antigravity CLI (`agy`) Termux Installer (`agy.sh`)

[![Termux Compatible](https://img.shields.io/badge/Termux-Native-brightgreen.svg)](https://termux.dev)
[![Architecture](https://img.shields.io/badge/Architecture-ARM64%20%2F%20aarch64-blue.svg)](#hardware-compatibility--arm64-lse-atomics)
[![License](https://img.shields.io/badge/License-MIT-orange.svg)](LICENSE)
[![Status](https://img.shields.io/badge/Release-Feature--Complete-success.svg)](#key-features)

The **definitive, zero-touch, feature-complete installer and manager (`agy.sh`)** for running **Google Antigravity CLI (`agy`)** natively inside **Android Termux** without requiring heavy PRoot containers, chroot, or virtual machines.

---

## ⚡ Quick Start (One-Liner Installation)

Run the following command inside your Termux terminal:

```bash
curl -fsSL https://raw.githubusercontent.com/polymath-void/termux-antigravity-cli-agy/main/agy.sh | bash
```

For unattended / silent installation (e.g. in automated scripts or CI):

```bash
curl -fsSL https://raw.githubusercontent.com/polymath-void/termux-antigravity-cli-agy/main/agy.sh | bash -s -- -y
```

---

## 🔍 Why `agy.sh` is Superior to Basic Downloader Scripts

When running Google's Antigravity CLI on Android Bionic libc, standard Linux glibc binaries often fail due to missing DNS configurations, missing SSL bundle locations, glibc dynamic loader mismatches, or missing ARM64 LSE atomic CPU instructions.

While minimal scripts (like basic downloader scripts) only unpack binaries, **`agy.sh` is a complete environment and lifecycle manager** that auto-resolves hardware and OS dependencies out of the box.

### Feature Comparison Matrix

| Technical Capability | Standard Downloader (`install.sh`) | `agy.sh` (This Repository) |
| :--- | :---: | :---: |
| **Native Termux ARM64 Support** | ✅ | ✅ |
| **Proactive Package Resolution** (`curl`, `tar`, `git`, `ripgrep`) | ❌ (Fails at runtime) | ✅ **Automated `pkg` Installer** |
| **DNS Resolver Fix** (`/etc/resolv.conf`) | ❌ (Causes connection error) | ✅ **Auto-Configures `resolv-conf`** |
| **SSL Certificate Export** (`SSL_CERT_FILE`) | ❌ (Causes OAuth SSL errors) | ✅ **Auto-Exports Termux TLS Certs** |
| **ARM64 LSE Atomics CPU Fallback** | ❌ (Crashes on older CPUs) | ✅ **Detects & Auto-Installs QEMU Wrapper** |
| **CLI Argument Parsing** (`-y`, `--check`, `--force`) | ❌ | ✅ **Full Command Line Interface** |
| **Shell Profile Integration** (`~/.bashrc`, `~/.zshrc`) | ❌ | ✅ **Automated Non-Duplicate Injection** |
| **Atomic Rollback on Error** | Limited | ✅ **Full Backup & Restoration Trap** |
| **Post-Install Health Diagnostics** | ❌ | ✅ **Runtime Binary Execution Test** |

---

## 🛠️ Command-Line Usage & Flags

`agy.sh` provides a complete CLI interface to manage your Antigravity installation:

```bash
./agy.sh [OPTIONS]
```

### Supported Options:

- `-y`, `--yes`, `--auto`: Run installation non-interactively (unattended mode).
- `-c`, `--check`: Query the latest available release version on GitHub vs your installed version.
- `-f`, `--force`: Force download and reinstall/repair existing `agy` binaries.
- `-p`, `--proot`: Automatically switch to Google's official installer for PRoot environments.
- `-u`, `--update`: Check for updates and automatically apply them if available.
- `-v`, `--version`: Output `agy.sh` installer version.
- `-h`, `--help`: Display usage manual.

---

## ⚙️ Hardware Compatibility & ARM64 LSE Atomics

Google Antigravity CLI binary uses Go runtime optimizations compiled with ARM64 LSE (Large System Extensions) atomic instructions. On older Android chipsets (e.g. Snapdragon 625, 650, 660, 820, or Cortex-A53 cores), executing the binary directly causes a kernel `SIGILL` (Illegal Instruction) crash.

**`agy.sh` resolves this automatically:**
1. Scans `/proc/cpuinfo` for native `atomics` instruction support.
2. If absent, it automatically installs `qemu-user-aarch64` from Termux repositories.
3. Wraps binary execution transparently via QEMU user emulation so `agy` runs smoothly on 100% of ARM64 Android devices.

---

## 🤖 Automated Build Pipeline (GitHub Actions)

This repository automatically syncs, patches, compiles, and publishes release assets every 6 hours using GitHub Actions:

```
├── .github/workflows/sync-and-release.yml    # 6-hour automated build workflow
├── bootstrapper/main.c                      # Native Bionic C launcher
├── scripts/build_standalone.sh         # Patching & packaging pipeline
└── agy.sh                           # Native Termux installer
```

---

## ❓ Frequently Asked Questions & Troubleshooting

<details>
<summary><b>1. Why does agy fail to connect or return OAuth errors?</b></summary>
Android does not store SSL certificates in standard Linux paths (<code>/etc/ssl/certs</code>). <code>agy.sh</code> automatically sets <code>SSL_CERT_FILE="$PREFIX/etc/tls/cert.pem"</code> and installs <code>ca-certificates</code> and <code>resolv-conf</code> to ensure secure network connectivity.
</details>

<details>
<summary><b>2. Can I use agy inside PRoot Ubuntu / Debian?</b></summary>
Yes! If you are inside a PRoot Linux environment, run <code>./agy.sh --proot</code> to automatically delegate installation to Google's official Linux binary script.
</details>

<details>
<summary><b>3. How do I fix terminal TUI flickering in Termux?</b></summary>
If you experience TUI rendering issues in your terminal, add <code>use-fullscreen-workaround = true</code> in <code>~/.termux/termux.properties</code> and run <code>termux-reload-settings</code>.
</details>

---

## 📜 License

Distributed under the MIT License. See [LICENSE](LICENSE) for more information.
