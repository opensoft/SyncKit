
### Doctor: Auto-Install Prompts and Safety Checks

Checks
- git: version >= 2.30; worktree support
- jq: presence and version
- gh/glab: presence, auth status (gh auth status / glab auth status)
- GCM: credential.helper configured to manager-core (or equivalent)
- Network reachability to remotes (optional quick check)

Prompts (apt-based systems only; WSL Ubuntu assumed)
- If jq missing: "jq not found. Install now via 'sudo apt-get update && sudo apt-get install -y jq'? [Y/n]"
- If gh missing: "GitHub CLI (gh) not found. Install now via apt? [Y/n]" (adds official repo if needed)
- If glab missing: "GitLab CLI (glab) not found. Install now via apt? [Y/n]"
- If GCM missing/unset: Provide official install link and command; guide to set credential.helper manager-core

Guardrails
- Never proceed with auto-install without explicit Y
- Show exact commands to be executed; require sudo password explicitly
- On non-apt distros, print distro-specific guidance (no auto-install)

Non-interactive readiness
- Verify HTTPS can be non-interactive: check git credential-helper config; suggest 'gh auth login' or 'git credential-manager configure' if needed
- Provide a dry-run test: attempt to access a remote with 'git ls-remote' and report auth prompt risks

Outputs
- Human-readable summary of checks and actions taken
- With --json: structured diagnostics including versions, install decisions, and errors
- Exit code: 0 if core deps ready, 1 otherwise
