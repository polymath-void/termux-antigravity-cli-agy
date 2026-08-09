# Project: Termux Antigravity CLI (`agy`)

This repository is an automated installer and environment manager for running Google Antigravity CLI on Android Termux.

## Core Conventions
- **Target OS**: Android Termux (AArch64 / ARM64).
- **Tooling**: Bash scripts (`agy.sh`), C bootstrapper (`bootstrapper/main.c`), and build scripts (`scripts/build_standalone.sh`).
- **Dependency Handling**: Always use `pkg` or `apt` for package installation within Termux. Ensure shebangs are fixed via `termux-fix-shebang`.
- **Environment**: Always set `SSL_CERT_FILE` and `TMPDIR` as per project specs defined in `AGENTS.MD`.
- **Documentation**: All architectural changes or significant updates must be logged in `AGENTS.MD`.
- **Git Workflow**: Do not stage or commit without user instruction. Propose commit messages based on `git log` style.

## Skill Requirements
- Always activate `termux-environment` when working in this project.
