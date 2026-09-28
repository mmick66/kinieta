#!/usr/bin/env bash
# Herdr orchestration loop for a Beads backlog: one ticket at a time, one worker per Herdr tab,
# each worker in its own git worktree.
#
# Each ticket gets branch wt/<ticket>, created from the current branch of the main checkout, in
# $WT_ROOT/<ticket>. Beads resolves to the main checkout's database from inside a worktree, so
# workers see the same tickets. When a ticket closes with a commit and a clean worktree, the branch
# is fast-forwarded into the main checkout's branch and the worktree, branch and tab are removed.
# Anything else keeps the worktree and the tab for review.
#
# Run from anywhere inside the main checkout (not from a worktree), in a Herdr pane:
#   WORKSPACE=<herdr workspace id> bash .claude/orchestrate.sh
#
# Required:
#   WORKSPACE      Herdr workspace for the worker tabs (list IDs with: herdr workspace)
#
# Optional:
#   LIMIT          stop after this many tickets in total            (default 40)
#   DONE_SO_FAR    tickets dispatched in earlier runs, counted toward LIMIT (default 0)
#   AGENT_KIND     Herdr agent kind for the workers                  (default claude)
#   WORKER_PROMPT  worker instructions with TICKET_ID as placeholder (default .claude/worker-prompt.md)
#   NOTIFY         1 = macOS notification for finished tickets and stops, 0 = off (default 1)
#   WT_ROOT        folder for the per-ticket worktrees, outside the repository
#                  (default: <repo>-worktrees next to the repository)
#
# The repository is detected from the current directory; nothing project-specific is hard-coded.
#
# Exit codes:
#   0  nothing left in bd ready, or LIMIT reached
#   2  setup problem found before starting (all problems are listed)
#   3  a worker stayed blocked for more than 4 minutes, or went idle with its ticket still
#      in_progress (paused mid-ticket); the tab and worktree are named in the log
#   4  Herdr, Beads or git failure (tab/agent/worktree could not start, JSON or status unreadable)
#   5  uncommitted changes in the main checkout (finished tickets are merged there)
#   6  a finished ticket's branch does not fast-forward onto the main checkout's branch
#
# Every event is printed here and appended to .claude/orchestrate.log  (follow with: tail -f .claude/orchestrate.log)

set -u
export BD_JSON_ENVELOPE=0   # pin the bd --json shape, whatever shell starts this script

# ---- Configuration -------------------------------------------------------------
REPO=$(git rev-parse --show-toplevel 2>/dev/null) || REPO=""
WORKSPACE=${WORKSPACE:-}
LIMIT=${LIMIT:-40}
count=${DONE_SO_FAR:-0}
AGENT_KIND=${AGENT_KIND:-claude}
WORKER_PROMPT=${WORKER_PROMPT:-.claude/worker-prompt.md}
NOTIFY=${NOTIFY:-1}
WT_ROOT=${WT_ROOT:-}

# ---- Preflight: collect every problem, report them together, then stop ---------
problems=()

[ -n "$REPO" ] || problems+=("Not inside a git repository: cd into the project first.")
[ -n "$WORKSPACE" ] || problems+=("WORKSPACE is not set. Find the ID with 'herdr workspace', then run: WORKSPACE=<id> bash $0")
[ "${HERDR_ENV:-}" = 1 ] || problems+=("Not running inside a Herdr pane (HERDR_ENV is not 1). Start 'herdr' and run this from a pane.")

for cmd in bd herdr git python3; do
  command -v "$cmd" >/dev/null 2>&1 || problems+=("Required command not found: $cmd")
done

case "$LIMIT" in ''|*[!0-9]*) problems+=("LIMIT must be a whole number (got '$LIMIT').") ;; esac
case "$count" in ''|*[!0-9]*) problems+=("DONE_SO_FAR must be a whole number (got '$count').") ;; esac
case "$NOTIFY" in 0|1) ;; *) problems+=("NOTIFY must be 0 or 1 (got '$NOTIFY').") ;; esac

if [ -n "$REPO" ]; then
  case "$WORKER_PROMPT" in /*) ;; *) WORKER_PROMPT="$REPO/$WORKER_PROMPT" ;; esac
  if [ ! -f "$WORKER_PROMPT" ]; then
    problems+=("Worker prompt not found: $WORKER_PROMPT")
  elif ! grep -q TICKET_ID "$WORKER_PROMPT"; then
    problems+=("Worker prompt has no TICKET_ID placeholder: $WORKER_PROMPT")
  fi
  [ -d "$REPO/.beads" ] || problems+=("No Beads database in $REPO. Run: bd init")

  # Finished tickets are merged into the main checkout's branch, so run from there, on a branch.
  git_dir=$(git -C "$REPO" rev-parse --absolute-git-dir 2>/dev/null)
  common_dir=$(cd "$REPO" && cd "$(git rev-parse --git-common-dir 2>/dev/null)" 2>/dev/null && pwd -P)
  [ "$git_dir" = "$common_dir" ] || problems+=("$REPO is a linked worktree. Run this from the main checkout.")
  BASE=$(git -C "$REPO" symbolic-ref --quiet --short HEAD) \
    || problems+=("The main checkout is on a detached HEAD. Check out the branch finished tickets should land on.")

  [ -n "$WT_ROOT" ] || WT_ROOT="$(dirname "$REPO")/$(basename "$REPO")-worktrees"
  case "$WT_ROOT" in
    "$REPO"|"$REPO"/*) problems+=("WT_ROOT ($WT_ROOT) must be outside the repository, or git sees the worktrees as untracked files.") ;;
  esac
fi

if [ "${#problems[@]}" -gt 0 ]; then
  echo "orchestrate.sh cannot start:" >&2
  for p in "${problems[@]}"; do echo "  - $p" >&2; done
  exit 2
fi

cd "$REPO"
mkdir -p "$REPO/.claude" "$WT_ROOT"
LOG="$REPO/.claude/orchestrate.log"
PROJECT=$(basename "$REPO")

# Notifications need macOS's osascript; elsewhere they are silently skipped.
command -v osascript >/dev/null 2>&1 || NOTIFY=0

# ---- Helpers ---------------------------------------------------------------------

# Show a macOS notification (quotes and backslashes removed so AppleScript can't break).
notify() {
  [ "$NOTIFY" = 1 ] || return 0
  local msg="$*"
  msg=${msg//\\/}
  msg=${msg//\"/\'}
  osascript -e "display notification \"$msg\" with title \"Beads orchestrator: $PROJECT\"" >/dev/null 2>&1
}

# Print and log every event; notify only for finished tickets and anything that stops the loop.
log() {
  echo "$(date '+%Y-%m-%d %H:%M:%S') $*" | tee -a "$LOG"
  case "$*" in
    *closed*|*deferred*|*BLOCKED*|*DIRTY_TREE*|*READY_EMPTY*|*LIMIT_REACHED*|*FAILED*|*UNREADABLE*|*WITHOUT_COMMIT*)
      notify "$*" ;;
  esac
}

# Parse JSON from stdin and print a Python expression over it (the parsed value is bound to d).
json() { python3 -c "import json,sys; d=json.load(sys.stdin); print($1)"; }

# Accept either bd JSON shape: the bare payload, or the v2 envelope {schema_version, data}.
UNWRAP='d=d["data"] if isinstance(d,dict) and "data" in d else d'

# Print a ticket's status, or "unknown" if it cannot be read.
status_of() {
  bd show "$1" --json 2>/dev/null | python3 -c "
import json,sys
try:
    d=json.load(sys.stdin); $UNWRAP
    d=d[0] if isinstance(d,list) else d
    print(d.get('status','unknown'))
except Exception:
    print('unknown')"
}

# Print the highest-priority open ready ticket, "" if none, or "ERROR" if bd output is unreadable.
next_ticket() {
  bd ready --json 2>/dev/null | python3 -c "
import json,sys
try:
    d=json.load(sys.stdin); $UNWRAP
    d=[i for i in d if i.get('status')=='open']
except Exception:
    print('ERROR'); sys.exit()
d.sort(key=lambda i:i.get('priority',9))
print(d[0]['id'] if d else '')"
}

# Uncommitted work outside .claude/ and .beads/ (those hold this script, prompts, log and tracker data).
dirty_tree() { git status --porcelain -- . ':(exclude).claude' ':(exclude).beads'; }

# ---- Main loop ---------------------------------------------------------------------
log "START orchestrate in $REPO (done so far: $count, limit: $LIMIT, workspace: $WORKSPACE, agent: $AGENT_KIND)"

while [ "$count" -lt "$LIMIT" ]; do
  # Workers share one working tree: never hand one worker's leftovers to the next.
  if [ -n "$(dirty_tree)" ]; then
    log "DIRTY_TREE: uncommitted changes in $REPO; stopping. Inspect with: git status"
    exit 5
  fi

  T=$(next_ticket)
  if [ "$T" = ERROR ]; then log "READY_UNREADABLE: could not parse 'bd ready --json'"; exit 4; fi
  if [ -z "$T" ]; then log "READY_EMPTY after $count tickets"; exit 0; fi
  count=$((count+1))
  log "[$count/$LIMIT] $T dispatching"

  tab=$(herdr tab create --workspace "$WORKSPACE" --cwd "$REPO" --label "$T" --no-focus) \
    || { log "TAB_FAILED for $T (is '$WORKSPACE' a valid workspace?)"; exit 4; }
  tabid=$(echo "$tab" | json 'd["result"]["tab"]["tab_id"]')
  pane=$(echo "$tab"  | json 'd["result"]["root_pane"]["pane_id"]')

  started=no
  for attempt in 1 2 3 4 5 6 7 8 9 10; do
    if herdr agent start "$T" --kind "$AGENT_KIND" --pane "$pane" --timeout 60000 >/dev/null 2>&1; then
      started=yes; break
    fi
    sleep 3
  done
  [ "$started" = yes ] || { log "START_FAILED for $T in tab $tabid"; exit 4; }

  P="$(sed "s/TICKET_ID/$T/g" "$WORKER_PROMPT")"
  herdr agent prompt "$T" "$P" --wait --timeout 600000 >/dev/null 2>&1

  # Wait until the worker settles. Never answer its prompts; stop if it stays blocked for 4 minutes.
  while true; do
    st=$(herdr agent get "$T" 2>/dev/null | json 'd["result"]["agent"]["agent_status"]' 2>/dev/null || echo gone)
    case "$st" in
      idle|done|gone) break ;;
      blocked)
        if herdr agent wait "$T" --until working --until idle --until done --timeout 240000 >/dev/null 2>&1; then
          continue
        fi
        log "BLOCKED >4min: tab $tabid ($T) needs attention"
        exit 3 ;;
      working) herdr agent wait "$T" --timeout 600000 >/dev/null 2>&1 ;;
      *) sleep 15 ;;
    esac
  done

  # Beads, not the worker's own report, decides what happened.
  s=$(status_of "$T")
  case "$s" in
    closed)
      c=$(git log --oneline -1 --grep="$T" | cut -c1-70)
      if [ -n "$c" ]; then
        herdr tab close "$tabid" >/dev/null 2>&1
        log "  $T closed ($c); tab closed"
      else
        log "  CLOSED_WITHOUT_COMMIT: no commit names $T; tab $tabid left open for review"
      fi ;;
    deferred)
      log "  $T deferred by worker; tab $tabid left open" ;;
    unknown)
      log "STATUS_UNREADABLE for $T; stopping rather than guessing (tab $tabid left open)"
      exit 4 ;;
    *)
      bd update "$T" --append-notes "Orchestrator: worker in Herdr tab $tabid settled with the ticket still '$s'; deferred for review." >/dev/null 2>&1
      bd defer "$T" --reason="worker finished without closing; see Herdr tab $tabid" >/dev/null 2>&1
      log "  $T still $s -> noted and deferred; tab $tabid left open" ;;
  esac
done

log "LIMIT_REACHED at $count tickets"
