#!/usr/bin/env bash
# Watch the bujo swarm: exit 0 when qa broadcasts terminal verification
# to all roles (visible in handoffd.log), exit 1 on 30 minutes of quiet.
set -u
REPO=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd -P)
QLOG=$REPO/.swarmforge/daemon/handoffd.log
QUIET_LIMIT=1800
POLL=60

state() {
  git -C "$REPO" for-each-ref --format='%(refname:short) %(objectname)' refs/heads/
  wc -c <"$QLOG" 2>/dev/null
}

last_state=$(state)
last_change=$(date +%s)
log_mark=$(wc -l <"$QLOG" 2>/dev/null || echo 0)

while :; do
  sleep "$POLL"
  now=$(date +%s)

  if tail -n +"$((log_mark + 1))" "$QLOG" 2>/dev/null \
      | grep -q 'from_qa_to_specifier_coder_cleaner_architect_hardener'; then
    echo "=== QA TERMINAL BROADCAST ==="
    tail -n +"$((log_mark + 1))" "$QLOG" | grep 'from_qa' | tail -3
    git -C "$REPO" for-each-ref --format='%(refname:short) %(objectname:short) %(subject)' refs/heads/ | grep -v ' main '
    exit 0
  fi

  cur=$(state)
  if [ "$cur" != "$last_state" ]; then
    last_state=$cur
    last_change=$now
    continue
  fi

  if [ $((now - last_change)) -ge $QUIET_LIMIT ]; then
    echo "=== QUIET ALARM: no swarm activity for 30 minutes ==="
    git -C "$REPO" for-each-ref --format='%(refname:short) %(objectname:short) %(committerdate:relative) %(subject)' refs/heads/
    echo "--- last queue lines ---"
    tail -8 "$QLOG" 2>/dev/null
    exit 1
  fi
done
