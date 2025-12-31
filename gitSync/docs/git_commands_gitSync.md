
### Git Command Sequences: Push/Apply (including tar-over-threshold)

#### Notation
- MACHINE = $(hostname)
- REMOTE = canonical remote (prefer `origin`)
- WIP_BRANCH = "wip/" + MACHINE
- RUN_ID = timestamp or UUID for temp paths
- THRESHOLDS
  - SINGLE_FILE_TAR = 50MB
  - SUBMODULE_TAR = 200MB (total size of submodule working dir)
  - TOTAL_WIP_WARN = 1GB

#### A) Push from Source (Machine A)

1) Preconditions and discovery
```bash
set -euo pipefail
MACHINE=$(hostname)
REMOTE=$(git remote | grep -E "^origin$" || git remote | head -n1)
WIP_BRANCH="wip/${MACHINE}"
RUN_ID=$(date -u +%Y%m%dT%H%M%SZ)
TMP_WT=".git/worktrees/wip-sync-${MACHINE}-${RUN_ID}"
CUR_BRANCH=$(git rev-parse --abbrev-ref HEAD)
HEAD_SHA=$(git rev-parse HEAD)
```

2) Create temporary worktree at HEAD
```bash
git worktree add --detach "${TMP_WT}" "${HEAD_SHA}"
cd "${TMP_WT}"
```

3) Prepare WIP area
- Ensure gitignore respected by default; we add tracked + untracked but not ignored.
- Build a list of candidate files and submodules.
```bash
# Ensure clean temp worktree index
git reset --hard

# Copy uncommitted and untracked files from the source repo working dir:
# Option 1 (simple): rsync from parent working dir; Option 2 (git plumbing).
# Here we use rsync to capture working copy faithfully while respecting .gitignore via a file list.

# From within the temp worktree, compute file list from the SOURCE repo
SRC_REPO=$(git -C .. rev-parse --show-toplevel)
FILE_LIST=$(mktemp)
(
  cd "$SRC_REPO"
  # List tracked modified files
  git ls-files -m
  # List untracked, excluding ignored
  git ls-files --others --exclude-standard
) | sort -u > "$FILE_LIST"

# Rsync only the listed files, preserving dirs
RSYNC_SRC=$(mktemp -d)
(
  cd "$SRC_REPO"
  tar -cf - -T "$FILE_LIST" | tar -xf - -C "$RSYNC_SRC"
)

# Place into temp worktree
rsync -a --delete "$RSYNC_SRC"/ .
rm -rf "$RSYNC_SRC" "$FILE_LIST"
```

4) Submodules flattening with size-aware tar fallback
```bash
# Identify submodule paths from source repo
SUBS=$(git -C .. submodule status --recursive 2>/dev/null | awk '{print $2}' || true)

mkdir -p .wip-sync/blobs
TAR_MAP=.wip-sync/tar_mappings.json
printf '{"entries":[]}' > "$TAR_MAP"

add_tar_mapping() {
  python3 - "$TAR_MAP" "$1" "$2" << 'PY'
import json,sys
p=sys.argv[1]; src=sys.argv[2]; tar=sys.argv[3]
with open(p) as f: d=json.load(f)
d['entries'].append({'path':src,'tar':tar})
with open(p,'w') as f: json.dump(d,f)
PY
}

size_bytes() { du -sb "$1" | awk '{print $1}'; }
SINGLE_FILE_TAR=$((50*1024*1024))
SUBMODULE_TAR=$((200*1024*1024))

for s in $SUBS; do
  # Copy working content from source repo submodule into temp worktree path
  SRC_SUB="$(git -C .. rev-parse --show-toplevel)/$s"
  [ -d "$SRC_SUB" ] || continue
  # Decide flatten or tar
  SZ=$(size_bytes "$SRC_SUB")
  if [ "$SZ" -gt "$SUBMODULE_TAR" ]; then
    HASH=$(printf "%s" "$s" | sha1sum | awk '{print $1}')
    TAR=.wip-sync/blobs/${HASH}.tar
    tar -C "$(dirname "$SRC_SUB")" -cf "$TAR" "$(basename "$SRC_SUB")"
    add_tar_mapping "$s" "$TAR"
    # Ensure path exists as marker dir
    mkdir -p "$s"
  else
    rsync -a --delete "$SRC_SUB"/ "$s"/
  fi
  git add -A "$s" || true
done
```

5) Large single-file tar fallback and overall size warning
```bash
# Tar large single files
find . -type f -size +50M -not -path './.git/*' -print0 | while IFS= read -r -d '' f; do
  # Skip already tar files under .wip-sync/blobs
  case "$f" in 
    ./.wip-sync/blobs/*) continue;; 
  esac
  HASH=$(printf "%s" "$f" | sha1sum | awk '{print $1}')
  TAR=.wip-sync/blobs/${HASH}.tar
  tar -cf "$TAR" -C "$(dirname "$f")" "$(basename "$f")"
  git rm -f --cached "$f" 2>/dev/null || true
  rm -f "$f"
  mkdir -p "$(dirname "$f")"
  touch "$f"  # placeholder so path exists
  add_tar_mapping "$f" "$TAR"
  git add -A "$f" "$TAR"
done

# Warn if overall payload > 1GB (log only)
TOTAL=$(du -sb . | awk '{print $1}')
if [ "$TOTAL" -gt $((1024*1024*1024)) ]; then
  echo "[wip-sync] WARN: WIP payload exceeds 1GB" >&2
fi
```

6) Stage, commit, and push WIP
```bash
git add -A

# Idempotency: compute tree hash
TREE_SHA=$(git write-tree)

# Compare to last pushed tree (caller updates manifest). If same, exit early.
# (Manifest read/write done by the CLI wrapper; shown here conceptually.)

META=.wip-sync/manifest.json
mkdir -p .wip-sync
cat > "$META" <<EOF
{
  "machine_name": "${MACHINE}",
  "hostname": "${MACHINE}",
  "user_name": "${USER}",
  "source_branch": "${CUR_BRANCH}",
  "source_head_sha": "${HEAD_SHA}",
  "created_at": "${RUN_ID}",
  "tool_version": "v1",
  "tree_sha": "${TREE_SHA}"
}
EOF

git add -A .wip-sync

MSG=$(cat <<EOM
WIP from ${MACHINE} at ${RUN_ID}

{ "machine_name": "${MACHINE}", "source_branch": "${CUR_BRANCH}", "source_head_sha": "${HEAD_SHA}", "created_at": "${RUN_ID}", "tool_version": "v1", "tree_sha": "${TREE_SHA}" }
EOM
)

git commit -m "$MSG" || true

git push -f "$REMOTE" HEAD:refs/heads/"$WIP_BRANCH"
```

7) Cleanup
```bash
cd - >/dev/null
git worktree remove -f "${TMP_WT}"
```

---

#### B) Apply on Destination (Machine B) without history changes

1) Fetch and enumerate WIP branches
```bash
set -euo pipefail
MACHINE=$(hostname)
REMOTE=$(git remote | grep -E "^origin$" || git remote | head -n1)

git fetch --all --prune

# List remote WIP branches except our own
mapfile -t WIPS < <(git ls-remote --heads "$REMOTE" "refs/heads/wip/*" | awk '{print $2}' | sed 's#refs/heads/##' | grep -v "wip/${MACHINE}" || true)
```

2) For each WIP, compute and apply diff as uncommitted changes
```bash
CUR_TREE=$(git rev-parse HEAD^{tree})

for BR in "${WIPS[@]}"; do
  WIP_SHA=$(git rev-parse "remotes/${REMOTE}/${BR}") || continue
  WIP_TREE=$(git rev-parse "${WIP_SHA}^{tree}")

  # Idempotency check (caller uses manifest last_seen to skip); shown here if needed

  # Create binary patch between current and WIP trees and apply without committing
  git diff --binary "${CUR_TREE}" "${WIP_TREE}" > .git/wip-sync.patch || true
  if [ -s .git/wip-sync.patch ]; then
    if git apply --index --allow-binary-replacement .git/wip-sync.patch; then
      # Leave changes unstaged for "dirty" feel
      git reset
    else
      echo "[wip-sync] ERROR: apply failed for ${BR}, leaving working tree unchanged" >&2
      git checkout -- . 2>/dev/null || true
      rm -f .git/wip-sync.patch
      continue
    fi
  fi

  # Handle tar-mapped blobs if present
  # Extract the WIP tree’s .wip-sync/tar_mappings.json (if exists) to a temp dir and apply
  TMPDIR=$(mktemp -d)
  git show "${WIP_SHA}:.wip-sync/tar_mappings.json" > "${TMPDIR}/tar_mappings.json" 2>/dev/null || true
  if [ -s "${TMPDIR}/tar_mappings.json" ]; then
    python3 - << 'PY'
import json,os,subprocess,sys,tempfile
p=sys.argv[1]
if not os.path.exists(p):
    sys.exit(0)
with open(p) as f:
    d=json.load(f)
for e in d.get('entries',[]):
    tar=e['tar']; path=e['path']
    # Extract tar into working tree at path parent
    parent=os.path.dirname(path) or '.'
    os.makedirs(parent, exist_ok=True)
    subprocess.check_call(['tar','-xf',tar,'-C', parent])
PY
    "${TMPDIR}/tar_mappings.json"
  fi
  rm -rf "${TMPDIR}" .git/wip-sync.patch

  # Update CUR_TREE after applying first WIP before computing next diff
  CUR_TREE=$(git write-tree)

done
```

---

#### Notes
- Manifest maintenance (last_pushed_tree, last_seen_wip_sha_by_machine) is handled by the CLI around these sequences.
- Error handling should continue to next repo/WIP on failure and log appropriately.
- Security warnings (likely secrets) are emitted by pre-checks in the CLI before committing.
