
### CLI Command Behaviors and Exit Codes

Common options
- --roots [PATH ...]: one or more roots; defaults to global config default_roots or $HOME
- --jobs N: parallelism (default = min(4, CPU cores))
- --quiet: minimize stdout; machine-readable summaries still emitted if requested
- --json: emit JSON summary to stdout at end
- --force (scan): force rescanning filesystem and permissions

Exit code policy (all commands)
- 0: At least one repo processed successfully (for multi-repo operations)
- 1: All repos failed or a fatal precondition failed (e.g., no git)
- 2: Invalid arguments / config

Commands

1) wip-sync doctor
- Checks: git, jq, gh, glab, GCM; versions; credential helper setup; PATH issues
- Offers optional auto-install (apt) for jq/gh/glab if missing; never silent-install
- Verifies non-interactive HTTPS auth readiness (GCM configured)
- Output: human-readable diagnostics; with --json, structured results
- Exit codes: 0 if environment OK or user declined optional installs but core deps are present; 1 if core missing and not fixed

2) wip-sync scan [ROOT ...] [--force]
- Discovers repos; determines canonical remote and write permission (gh/glab API preferred, else dry-push probe)
- Creates/updates per-root manifest; preserves status=ignore
- Updates global index summary
- Output: summary table; with --json, per-repo details
- Exit codes: 0 if any repo scanned successfully; 1 if all roots failed/unreadable

3) wip-sync push [ROOT ...] [--jobs N]
- For each repo eligible (not ignore/no-remote/no-write-permission):
  - Build WIP snapshot via temp worktree
  - Apply size thresholds (tar mappings)
  - Respect .gitignore; warn on likely secrets not ignored
  - Idempotency: compute tree_sha; skip if identical to manifest.last_pushed_tree
  - Force-push to refs/heads/wip/{hostname}
  - Update manifest: last_sync_at/result, last_pushed_tree
- Output: per-repo results; with --json, structured summary
- Exit codes: 0 if any push succeeded; 1 if all eligible repos failed

4) wip-sync pull-apply [ROOT ...] [--jobs N]
- Fetch --all --prune
- For each repo: enumerate remote wip/* (excluding own)
  - Skip branches with unchanged tip (manifest last_seen)
  - Apply WIP changes as uncommitted, unstaged changes (git apply --binary + reset)
  - Extract tars per mappings
  - On failure, leave tree unchanged, mark conflict
  - Update last_seen_wip_sha_by_machine
- Output: per-repo results; with --json, structured summary
- Exit codes: 0 if any apply succeeded; 1 if all eligible repos failed

5) wip-sync ls-wip [ROOT ...]
- Lists remote wip/* branches and last-seen markers per repo
- Exit: 0 unless all roots failed

6) wip-sync clear [ROOT ...] [--machine <name>] [--remote REMOTE]
- Deletes remote WIP branches (admin/safe use only) or clears local last-seen markers
- Prompts for confirmation unless --yes specified
- Exit: 0 on success for at least one repo; 1 otherwise
