### Executive Summary: Cross-Machine Git WIP Sync

#### Objective
Provide a reliable way to transfer a developer’s uncommitted and untracked work-in-progress (WIP) across machines so that the destination machine reproduces the same “dirty” state, without polluting Git history or altering the source machine.

#### How It Works
- Each machine publishes a single WIP branch per repo to the existing remote: wip/{hostname}.
- The branch contains a snapshot of the current working state (tracked + untracked files, respecting .gitignore).
- Other machines fetch these WIP branches and apply them as uncommitted changes to their working directories, keeping history clean.

#### Key Features
- Discovery and Control
  - Recursively scan one or more roots (default $HOME) to find Git repos.
  - Per-root JSON manifest tracks repos, remotes, permissions, WIP branches, and last-seen SHAs.
  - Users can mark repos as ignore; supports force rescan.

- Safe WIP Capture (Source)
  - Uses temporary Git worktrees so the source working tree is untouched.
  - Includes tracked and untracked files while respecting .gitignore.
  - Submodules are flattened in the WIP snapshot to faithfully reproduce contents (with tar fallback over size thresholds).

- Clean Restore (Destination)
  - Applies WIP as uncommitted changes (no merge commits), matching the original “dirty” state.
  - Idempotent via last-seen SHAs; retries and continues on errors per repo.

- Auth and Permissions
  - Uses existing SSH/HTTPS. For HTTPS, Git Credential Manager enables non-interactive cron runs.
  - gh/glab APIs (or dry push probe) verify write permissions. Repos without remotes or permissions are skipped and recorded.

- Concurrency and Scale
  - One WIP branch per machine prevents collisions; per-repo locks avoid local contention.
  - CLI and cron-friendly, with configurable parallelism; no imposed size limits.

- Traceability and Audit
  - WIP commits include structured metadata (machine, user, branch/commit, timestamp, tool version).
  - Metadata file (.wip-sync/manifest.json) inside the WIP snapshot.
  - Local per-root run logs and manifest updates for visibility.

#### Decisions and Defaults (v1)
- Roots: default $HOME; multiple roots via CLI; persisted defaults in ~/.config/wip-sync/config.json. Global index at ~/.config/wip-sync/index.json.
- Permissions: prefer gh/glab; fallback to dry-push.
- Apply on B: uncommitted and unstaged; no history changes.
- Conflicts: abort with no changes; log error and mark conflict.
- Idempotency: last_pushed_tree hash stored; skip identical pushes.
- Overwrite: force-push wip/{hostname}, no safety check.
- Security: respect .gitignore; warn if likely secrets not ignored.
- Performance: --jobs default min(4, CPU cores).
- Rate limits: after 3 API rate-limit hits, fallback to dry-push.
- Size thresholds for tar fallback: single file >50MB; submodule dir >200MB; overall WIP >1GB (warn, continue).

#### Commands
- wip-sync doctor — dependency and environment checks; optional auto-install (apt) for jq/gh/glab with confirmation.
- wip-sync scan [ROOT ...] [--force] — discover repos and update manifest(s).
- wip-sync push [ROOT ...] [--jobs N] — publish wip/{hostname} snapshots.
- wip-sync pull-apply [ROOT ...] [--jobs N] — apply other machines’ WIP as uncommitted changes.
- wip-sync ls-wip / clear — inspect and manage WIP branches.

#### Outcomes
- Source remains pristine; destination mirrors the same uncommitted state.
- Clean Git history on destination.
- Clear, auditable records of what was synced, when, and by whom.
