### Product Requirements Document (PRD): Cross-Machine Git WIP Sync

#### 1. Overview
Enable developers to synchronize uncommitted and untracked work-in-progress (WIP) across machines while:
- Keeping Git history clean on destination machines.
- Leaving the source machine’s working tree unchanged.
- Operating across all Git repos under specified roots with a manifest for control and audit.

Primary users: Developers using WSL/Linux environments with multiple workstations; CLI and cron usage.

#### 2. Goals and Non-Goals
- Goals
  - Snapshot and push a machine’s current uncommitted/untracked state to the repo’s remote as a single WIP branch per machine.
  - Pull and apply other machines’ WIP as uncommitted changes locally without creating commits.
  - Respect .gitignore (v1) and warn on likely secrets not ignored.
  - Support CLI and cron operation; provide dependency checks and optional auto-install prompts.
  - Provide per-root manifest plus a global index for discovery, control, and auditing.
  - Include traceability metadata with each WIP snapshot.

- Non-Goals (v1)
  - Handling repos without remotes beyond skipping and recording.
  - Denylist/allowlist enforcement (future enhancement).
  - Complex submodule mechanics beyond faithful file-level reproduction (with tar fallback for large submodules).
  - GUI application.

#### 3. Key Concepts
- WIP Branch: One per machine per repo named wip/{hostname}. Contains a tree snapshot of the current working state (tracked + untracked respecting .gitignore).
- Machine Identity: Hostname used as machine_name.
- Manifests:
  - Per-root manifest: .wip-sync-manifest.json at each root
  - Global index manifest: ~/.config/wip-sync/index.json aggregating per-root status
- Clean History on B: Destination applies WIP as working-copy changes (uncommitted, unstaged), not commits.

#### 4. User Stories
- As a dev, I push my uncommitted changes from Machine A to the remote so Machine B can pick them up as if I had edited them there.
- As a dev, I want the system to find all repos in my home directory and let me ignore some repos via a manifest.
- As a dev, I want HTTPS auth to be non-interactive in cron via Git Credential Manager.
- As a dev, I want the destination to remain clean historically, with changes appearing uncommitted for immediate continuation.

#### 5. Environment and Dependencies
- Platform: WSL/Linux
- Dependencies: git (≥2.30), jq, gh and/or glab (optional but preferred), Git Credential Manager (GCM)
- doctor command: checks presence/versions; offers optional auto-install (apt) for jq/gh/glab with confirmation; provides guidance otherwise.

#### 6. Discovery and Manifest
- Roots: default $HOME; multiple roots via CLI (wip-sync scan /home/user [/path/2 ...]); defaults persisted in ~/.config/wip-sync/config.json
- Discovery: recursively detect repos via .git; canonical remote = origin else first fetch remote
- Permissions: prefer gh/glab API; fallback to dry push probe to refs/wip-sync-permcheck (then delete)
- Per-root Manifest schema (v1):
  - version: "1.0"
  - machine_name: string (hostname)
  - roots: string[]
  - repos: array of { path, remote_url, status: synced|pending|ignore|no-remote|no-write-permission|error, wip_branch, known_wip_branches: string[], last_seen_wip_sha_by_machine: { [machine]: sha }, last_checked_at, last_sync_at, last_sync_result: ok|error|skipped|conflict|null, notes, last_pushed_tree?: sha }
- Global Index: aggregates per-root manifests for summaries and cron reporting.

#### 7. WIP Capture (Machine A)
- Strategy: Temporary worktree to avoid modifying A
  - Create temp worktree at HEAD: .git/worktrees/wip-sync-{hostname}-{runid}
  - Within temp worktree:
    - Respect .gitignore: git add -A (no forced includes)
    - Submodules: flatten content for faithful reproduction
      - Deinit submodules in temp worktree; copy submodule working files as regular files
      - If submodule size > 200MB, tar the entire submodule directory into .wip-sync/blobs/<hash>.tar and record mapping
    - Large files: if single file > 50MB, store in tar at .wip-sync/blobs/<hash>.tar with path map; overall WIP >1GB -> warn but continue
    - Commit: "WIP from {hostname} at {timestamp}"
      - Metadata JSON in commit body and file at .wip-sync/manifest.json (machine, user, source_branch, source_head_sha, created_at, tool_version, file_count, total_bytes, submodule_treatment, tar_mappings)
    - Push: git push -f <remote> HEAD:refs/heads/wip/{hostname}
  - Cleanup: remove temp worktree on success/failure
- Idempotency: compute tree hash; if identical to last_pushed_tree in manifest, skip push

#### 8. WIP Apply (Machine B)
- Fetch: git fetch --all --prune
- For each repo:
  - Enumerate wip/*; skip wip/{hostname}
  - For each other machine’s WIP:
    - If remote SHA unchanged vs manifest.last_seen_wip_sha_by_machine, skip
    - Apply WIP as uncommitted, unstaged changes:
      - Compute binary diff between current tree and WIP tree; git apply --binary; then git reset to unstage
      - If .wip-sync/blobs tar mappings exist, extract them to original paths
    - On apply failure, abort without changes; mark conflict in manifest; log error
    - Update last_seen_wip_sha_by_machine[other] = remote SHA
- No merge commits or history modifications

#### 9. Auth and Permissions
- SSH keys used if configured; HTTPS via GCM (non-interactive cron)
- Permission checks via gh/glab; fallback to dry push probe; after 3 rate-limit errors, auto-fallback to dry-push for remainder of run

#### 10. Concurrency and Isolation
- One WIP branch per machine per repo: wip/{hostname}
- Per-repo lock file: .git/wip-sync.lock (v1); no global lock in v1
- Multiple users/machines operate concurrently without interference

#### 11. Traceability and Audit
- WIP commit metadata (commit body JSON and .wip-sync/manifest.json): machine_name, hostname, user_name, source_branch, source_head_sha, created_at, tool_version, repo_relative_path, roots_scanned, file_count, total_bytes, submodule_treatment, tar_mappings
- Local run logs per root: root/.wip-sync-run-logs/<timestamp>.json
- Global index manifest aggregates per-root status for reporting

#### 12. Error Handling and Exit Codes
- Continue across repos; summarize results
- Cron/quiet mode outputs machine-readable JSON summary
- Exit codes: 0 if any repo succeeded; non-zero only if all repos failed
- Retries: network operations retried (3 attempts, exponential backoff)

#### 13. Performance
- Parallelization: --jobs N; default min(4, CPU cores)
- Efficient temp worktrees; tar for large files/submodules to avoid excessive Git object overhead

#### 14. CLI Commands
- wip-sync doctor
  - Dependency/version checks; optional apt-based auto-install for jq/gh/glab with confirmation; guidance for others
- wip-sync scan [ROOT ...] [--force]
  - Discover repos; build/update per-root manifests; check permissions; honor ignore overrides
- wip-sync push [ROOT ...] [--jobs N]
  - Create/push WIP snapshots using temp worktrees; idempotent based on tree hash
- wip-sync pull-apply [ROOT ...] [--jobs N]
  - Fetch and apply other machines’ WIP as uncommitted, unstaged changes; handle tar-mapped content
- wip-sync ls-wip [ROOT ...]
  - List wip/* branches and last-seen SHAs per repo
- wip-sync clear [ROOT ...] [--machine <name>]
  - Delete remote WIP branches (admin only) or clear local last-seen markers

#### 15. Security
- v1 respects .gitignore; warns if likely secrets are present but not ignored (non-blocking)
- No automatic secret scanning/blocking in v1

#### 16. Acceptance Criteria
- Source machine remains unchanged after push (git status before/after is identical)
- Destination reproduces the exact uncommitted state (tracked/untracked per .gitignore) after pull-apply
- No history pollution on B; no merge commits created
- Manifests and global index update correctly; last-seen SHAs honored for idempotency
- Concurrent runs from different machines do not interfere; local per-repo lock prevents same-machine races
