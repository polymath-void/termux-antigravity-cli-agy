#!/data/data/com.termux/files/usr/bin/env python3
"""
scripts/patch_va39.py - Patch official Google Antigravity Linux ARM64 binary for Android Termux.

Applies:
1. faccessat2 (syscall 439 / 0x1b7) -> faccessat (syscall 48 / 0x30) to prevent SIGSYS crashes
   under Android Linux kernels and seccomp filters.
2. TCMalloc and Go runtime VA39 pointer tagging & address-space adjustments (48-bit to 39-bit)
   to ensure stability on Android ARM64 devices.
"""

import sys
import os
import json

def patch_binary(input_file, output_file, rules_file=None):
    if rules_file is None:
        script_dir = os.path.dirname(os.path.abspath(__file__))
        rules_file = os.path.join(script_dir, "patch_va39_rules.json")

    if not os.path.exists(rules_file):
        raise FileNotFoundError(f"Rules file not found: {rules_file}")

    with open(rules_file, "r") as f:
        rules = json.load(f)

    with open(input_file, "rb") as f:
        data = bytearray(f.read())

    applied = 0
    for rule in rules:
        offset = rule["offset"]
        orig = bytes.fromhex(rule["orig"])
        patch = bytes.fromhex(rule["patch"])
        pre = bytes.fromhex(rule.get("pre", ""))
        post = bytes.fromhex(rule.get("post", ""))

        # Check direct offset
        if offset + len(orig) <= len(data) and data[offset:offset+len(orig)] == orig:
            data[offset:offset+len(orig)] = patch
            applied += 1
            continue

        # If direct offset did not match, search nearby window (+/- 8192 bytes) with context
        pattern = pre + orig + post
        search_start = max(0, offset - 8192)
        search_end = min(len(data), offset + 8192)
        idx = data.find(pattern, search_start, search_end)
        if idx != -1:
            target_idx = idx + len(pre)
            data[target_idx:target_idx+len(orig)] = patch
            applied += 1
        else:
            print(f"[PATCH] Warning: Rule for offset {hex(offset)} ({orig.hex()} -> {patch.hex()}) did not match", file=sys.stderr)

    with open(output_file, "wb") as f:
        f.write(data)

    os.chmod(output_file, 0o755)
    print(f"[PATCH] Applied {applied}/{len(rules)} patches to {output_file}")
    if applied == 0:
        raise RuntimeError("No patches could be applied to input binary.")

if __name__ == "__main__":
    if len(sys.argv) < 3:
        print(f"Usage: {sys.argv[0]} <input_antigravity_binary> <output_agy_va39_binary> [rules.json]")
        sys.exit(1)
    input_path = sys.argv[1]
    output_path = sys.argv[2]
    rules_path = sys.argv[3] if len(sys.argv) > 3 else None
    patch_binary(input_path, output_path, rules_path)
