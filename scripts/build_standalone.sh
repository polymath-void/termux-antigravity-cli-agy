#!/usr/bin/env bash
# ==============================================================================
# scripts/build_standalone.sh - Automated Build & Packaging Pipeline
# Downloads the official Google Antigravity Linux ARM64 binary, applies
# the VA39 & faccessat2 compatibility patch for Android Termux, compiles
# the native C bootstrapper, and generates antigravity-termux-standalone.tar.gz.
# ==============================================================================
set -Eeuo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
BUILD_DIR="$ROOT_DIR/build_workspace"
OUTPUT_DIR="$ROOT_DIR/dist"
CC="${CC:-aarch64-linux-gnu-gcc}"

echo "[BUILD] Cleaning build workspace..."
rm -rf "$BUILD_DIR" "$OUTPUT_DIR"
mkdir -p "$BUILD_DIR" "$OUTPUT_DIR"

# 1. Resolve official Google Antigravity release
echo "[BUILD] Querying official Google Antigravity release manifest..."
MANIFEST_URL="https://antigravity-cli-auto-updater-974169037036.us-central1.run.app/manifests/linux_arm64.json"
MANIFEST_JSON=$(curl -fsSL --retry 3 --retry-delay 2 "$MANIFEST_URL" 2>/dev/null || true)

GOOGLE_DOWNLOAD_URL=""
OFFICIAL_VERSION=""
if [[ -n "$MANIFEST_JSON" ]]; then
  GOOGLE_DOWNLOAD_URL=$(echo "$MANIFEST_JSON" | grep -o '"url"[[:space:]]*:[[:space:]]*"[^"]*"' | cut -d'"' -f4 || true)
  OFFICIAL_VERSION=$(echo "$MANIFEST_JSON" | grep -o '"version"[[:space:]]*:[[:space:]]*"[^"]*"' | cut -d'"' -f4 || true)
fi

# Fallback direct Google URL
if [[ -z "$GOOGLE_DOWNLOAD_URL" ]]; then
  GOOGLE_DOWNLOAD_URL="https://antigravity.google/cli/downloads/antigravity-linux-arm64.tar.gz"
fi

if [[ -z "$OFFICIAL_VERSION" ]]; then
  OFFICIAL_VERSION="1.2.1"
fi

echo "[BUILD] Target Official Google Antigravity version: $OFFICIAL_VERSION"
echo "$OFFICIAL_VERSION" > "$OUTPUT_DIR/VERSION"

# 2. Download official Google binary archive
UPSTREAM_TARBALL="$BUILD_DIR/official_antigravity.tar.gz"
echo "[BUILD] Downloading official Google release archive from: $GOOGLE_DOWNLOAD_URL"
if ! curl -fsSL --retry 3 --retry-delay 2 -o "$UPSTREAM_TARBALL" "$GOOGLE_DOWNLOAD_URL" || [[ ! -s "$UPSTREAM_TARBALL" ]]; then
  echo "[BUILD] Warning: Primary Google URL failed. Trying direct Google downloads endpoint..."
  curl -fsSL --retry 3 --retry-delay 2 -o "$UPSTREAM_TARBALL" "https://antigravity.google/cli/downloads/antigravity-linux-arm64.tar.gz"
fi

if [[ ! -f "$UPSTREAM_TARBALL" || ! -s "$UPSTREAM_TARBALL" ]]; then
  echo "[BUILD] Error: Failed to download official Google Antigravity release archive."
  exit 1
fi

# 3. Extract official binary
echo "[BUILD] Extracting official Google binary..."
mkdir -p "$BUILD_DIR/extracted"
tar -xzf "$UPSTREAM_TARBALL" -C "$BUILD_DIR/extracted"

OFFICIAL_BIN=""
if [[ -f "$BUILD_DIR/extracted/antigravity" ]]; then
  OFFICIAL_BIN="$BUILD_DIR/extracted/antigravity"
elif [[ -f "$BUILD_DIR/extracted/agy" ]]; then
  OFFICIAL_BIN="$BUILD_DIR/extracted/agy"
else
  echo "[BUILD] Error: Extracted archive does not contain 'antigravity' binary."
  exit 1
fi

# 4. Apply VA39 & Android syscall compatibility patch
echo "[BUILD] Applying Android Termux compatibility patch (VA39 & faccessat2)..."
python3 "$SCRIPT_DIR/patch_va39.py" "$OFFICIAL_BIN" "$BUILD_DIR/agy.va39"
chmod +x "$BUILD_DIR/agy.va39"

# 5. Compile native C bootstrapper into agy
echo "[BUILD] Compiling native Bionic C bootstrapper launcher..."
if command -v "$CC" >/dev/null 2>&1; then
  "$CC" -O2 -Wall "$ROOT_DIR/bootstrapper/main.c" -o "$BUILD_DIR/agy"
else
  echo "[BUILD] Compiler '$CC' not found. Using local gcc..."
  gcc -O2 -Wall "$ROOT_DIR/bootstrapper/main.c" -o "$BUILD_DIR/agy"
fi

chmod +x "$BUILD_DIR/agy"

# 6. Create standalone tarball package
echo "[BUILD] Packaging antigravity-termux-standalone.tar.gz..."
TARBALL_PATH="$OUTPUT_DIR/antigravity-termux-standalone.tar.gz"
tar -czf "$TARBALL_PATH" -C "$BUILD_DIR" agy agy.va39

# Sanity check output size (>1MB)
SIZE=$(stat -c%s "$TARBALL_PATH" 2>/dev/null || stat -f%z "$TARBALL_PATH" 2>/dev/null || echo 0)
if (( SIZE < 1000000 )); then
  echo "[BUILD] Error: Output tarball size ($SIZE bytes) is too small."
  exit 1
fi

echo "[BUILD] Build complete! Package generated at: $TARBALL_PATH ($SIZE bytes)"
echo "[BUILD] Release Version: $OFFICIAL_VERSION"
