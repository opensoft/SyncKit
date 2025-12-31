
### JSON Schemas: Config and Manifests

#### 1) Global Config (~/.config/wip-sync/config.json)
```json
{
  "version": "1.0",
  "machine_name": "<hostname default>",
  "default_roots": ["/home/user"],
  "jobs": null,
  "log_level": "info",
  "quiet": false
}
```
- machine_name: default from hostname; can be overridden.
- default_roots: used when CLI/cron runs without explicit roots.
- jobs: null = auto (min(4, CPU cores)); integer to pin.
- quiet: reduce human-readable output; still emits JSON summary when requested.

#### 2) Per-Root Manifest (<ROOT>/.wip-sync-manifest.json)
```json
{
  "version": "1.0",
  "machine_name": "ws1",
  "root": "/home/user",
  "repos": [
    {
      "path": "/home/user/projects/foo",
      "remote_url": "git@github.com:org/foo.git",
      "status": "synced",
      "wip_branch": "wip/ws1",
      "known_wip_branches": ["ws1","ws2"],
      "last_seen_wip_sha_by_machine": {"ws2": "1a2b3c..."},
      "last_checked_at": "2025-10-06T10:02:00Z",
      "last_sync_at": "2025-10-06T10:03:10Z",
      "last_sync_result": "ok",
      "last_pushed_tree": "deadbeef...",
      "notes": ""
    }
  ]
}
```
- status enum: synced | pending | ignore | no-remote | no-write-permission | error | conflict
- last_pushed_tree: tree SHA for idempotency

#### 3) Global Index (~/.config/wip-sync/index.json)
```json
{
  "version": "1.0",
  "machine_name": "ws1",
  "updated_at": "2025-10-06T10:04:00Z",
  "roots": [
    {
      "path": "/home/user",
      "manifest_path": "/home/user/.wip-sync-manifest.json",
      "repo_counts": {"total": 42, "synced": 38, "pending": 2, "ignored": 1, "errors": 1}
    }
  ]
}
```
- Summarizes per-root manifests for dashboards and cron reports.

#### 4) Embedded WIP Metadata (.wip-sync/manifest.json inside WIP snapshot)
```json
{
  "machine_name": "ws1",
  "hostname": "ws1",
  "user_name": "alice",
  "source_branch": "main",
  "source_head_sha": "abc123...",
  "created_at": "2025-10-06T10:03:10Z",
  "tool_version": "v1",
  "tree_sha": "deadbeef...",
  "file_count": 1234,
  "total_bytes": 987654321,
  "submodule_treatment": "flattened",
  "tar_mappings": {"entries": [{"path": "subA/", "tar": ".wip-sync/blobs/abcd.tar"}]}
}
```
