#!/usr/bin/env bash
# ==============================================================================
# scripts/build_standalone.sh - Automated Patch & Package Script
# Used by GitHub Actions to download upstream release, compile bootstrapper,
# apply TCMalloc VA39 patches, and bundle antigravity-termux-standalone.tar.gz.
# ==============================================================================
set -Eeuo pipefail

BUILD_DIR="$(pwd)/build_workspace"
OUTPUT_DIR="$(pwd)/dist"
CC="${CC:-aarch64-linux-gnu-gcc}"

echo "[BUILD] Cleaning workspace..."
rm -rf "$BUILD_DIR" "$OUTPUT_DIR"
mkdir -p "$BUILD_DIR" "$OUTPUT_DIR"

# 1. Fetch latest upstream Linux ARM64 binary
echo "[BUILD] Fetching upstream Antigravity standalone release binary..."
UPSTREAM_TARBALL="$BUILD_DIR/upstream.tar.gz"

# Primary & Fallback Upstream URLs
URL1="https://github.com/polymath-void/termux-antigravity-cli-agy/releases/latest/download/antigravity-termux-standalone.tar.gz"
URL2="https://github.com/wallentx/antigravity-cli-termux/releases/latest/download/antigravity-termux-standalone.tar.gz"
URL3="https://antigravity.google/cli/downloads/antigravity-linux-arm64.tar.gz"

if ! curl -fsSL --retry 3 --retry-delay 2 -o "$UPSTREAM_TARBALL" "$URL1"; then
  echo "[BUILD] Warning: Primary upstream URL failed, trying secondary URL..."
  if ! curl -fsSL --retry 3 --retry-delay 2 -o "$UPSTREAM_TARBALL" "$URL2"; then
    echo "[BUILD] Warning: Secondary upstream URL failed, trying Google direct URL..."
    curl -fsSL --retry 3 --retry-delay 2 -o "$UPSTREAM_TARBALL" "$URL3" || true
  fi
fi

if [[ -f "$UPSTREAM_TARBALL" && -s "$UPSTREAM_TARBALL" ]]; then
  echo "[BUILD] Extracting upstream binaries..."
  mkdir -p "$BUILD_DIR/extracted"
  tar -xzf "$UPSTREAM_TARBALL" -C "$BUILD_DIR/extracted" 2>/dev/null || true
  
  if [[ -f "$BUILD_DIR/extracted/agy.va39" ]]; then
    cp "$BUILD_DIR/extracted/agy.va39" "$BUILD_DIR/agy.va39"
  elif [[ -f "$BUILD_DIR/extracted/agy" ]]; then
    cp "$BUILD_DIR/extracted/agy" "$BUILD_DIR/agy.va39"
  fi
fi

if [[ ! -f "$BUILD_DIR/agy.va39" || ! -s "$BUILD_DIR/agy.va39" ]]; then
  echo "[BUILD] Error: Failed to acquire valid agy.va39 core engine binary."
  exit 1
fi

chmod +x "$BUILD_DIR/agy.va39"

# 2. Compile native C bootstrapper into agy
echo "[BUILD] Compiling C bootstrapper launcher..."
if command -v "$CC" >/dev/null 2>&1; then
  "$CC" -O2 -Wall bootstrapper/main.c -o "$BUILD_DIR/agy"
else
  echo "[BUILD] Compiler '$CC' not found. Using local gcc..."
  gcc -O2 -Wall bootstrapper/main.c -o "$BUILD_DIR/agy"
fi

chmod +x "$BUILD_DIR/agy"

# 3. Create standalone tarball package
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
