#!/usr/bin/env bash
# Read-only host audit for phantom-ai planning. Collects no file contents, env vars, or secrets.
set -u

HOST="$(hostname -s 2>/dev/null || hostname)"
OUT="${1:-./audit-${HOST}-$(date +%F).md}"
HOME_DIR="${HOME}"
PRUNE=( -name .git -o -name node_modules -o -name .cache -o -name .venv -o -name venv -o -name __pycache__ -o -name .local -o -name .npm -o -name .cargo -o -name .rustup -o -name go -o -name snap -o -name .steam -o -name .mozilla )

have() { command -v "$1" >/dev/null 2>&1; }

redact() {
  sed -E \
    -e 's#(https?://)[^/@[:space:]]+@#\1REDACTED@#g' \
    -e 's#(https?://[^/[:space:]]+)/[^[:space:]"'"'"']*#\1/…#g' \
    -e 's#[A-Za-z0-9_\-]{32,}#REDACTED#g' \
    -e 's#((token|key|secret|password|passwd|pwd)[=: ]+)[^[:space:]]+#\1REDACTED#Ig'
}

section() { printf '\n## %s\n\n```\n' "$1"; }
endsection() { printf '```\n'; }
run() { timeout "${T:-30}" "$@" 2>&1 | redact; }

{
  printf '# Host audit: %s\n\n' "$HOST"
  printf 'Generated %s by %s\n' "$(date -Is)" "$(whoami)"

  section "System"
  run cat /etc/os-release | grep -E '^(PRETTY_NAME|ID)='
  run uname -srm
  run uptime -p
  printf 'CPU: %s cores — %s\n' "$(nproc)" "$(grep -m1 'model name' /proc/cpuinfo 2>/dev/null | cut -d: -f2 | xargs)"
  run free -h
  run df -hT -x tmpfs -x devtmpfs -x squashfs -x overlay -x efivarfs
  endsection

  section "GPU / accelerators"
  if have nvidia-smi; then run nvidia-smi --query-gpu=name,memory.total,driver_version,compute_cap --format=csv; else echo "nvidia-smi: not installed"; fi
  have lspci && run lspci | grep -iE 'vga|3d|display|hailo|neural|coral'
  ls /dev/hailo* 2>/dev/null
  endsection

  section "Tailscale peers (names/OS/online only)"
  if have tailscale; then
    if have jq; then
      # jq must see the raw JSON: redact() rewrites key-like values and breaks the quoting
      timeout "${T:-30}" tailscale status --json 2>/dev/null | jq -r '.Self as $s | ([$s] + [.Peer[]?]) | .[] | "\(.HostName)\t\(.OS)\tonline=\(.Online)"' 2>&1 | redact
    else
      run tailscale status | awk '{print $2, $3, $4, $5}'
    fi
  else echo "tailscale: not installed"; fi
  endsection

  section "Listening ports (process names)"
  if have ss; then run ss -tlnpH | awk '{print $4, $6}' | sed -E 's/users:\(\("([^"]+)".*/\1/' | sort -u; fi
  endsection

  section "Failed systemd units"
  run systemctl --failed --no-legend --plain
  run systemctl --user --failed --no-legend --plain
  endsection

  section "Custom systemd units (system + user)"
  for d in /etc/systemd/system "$HOME_DIR/.config/systemd/user"; do
    [ -d "$d" ] || continue
    echo "[$d]"
    find "$d" -maxdepth 1 -type f \( -name '*.service' -o -name '*.timer' -o -name '*.path' \) -printf '%f\n' | sort
  done
  endsection

  section "Running services"
  run systemctl list-units --type=service --state=running --no-legend --plain | awk '{print $1}'
  echo "--- user ---"
  run systemctl --user list-units --type=service --state=running --no-legend --plain | awk '{print $1}'
  endsection

  section "Timers"
  run systemctl list-timers --all --no-legend --plain | awk '{print $(NF-1), $NF}'
  run systemctl --user list-timers --all --no-legend --plain | awk '{print $(NF-1), $NF}'
  endsection

  section "Cron (redacted)"
  run crontab -l
  ls /etc/cron.d 2>/dev/null
  endsection

  section "Containers"
  if have docker; then run docker ps -a --format '{{.Names}}\t{{.Image}}\t{{.Status}}'; else echo "docker: not installed"; fi
  if have podman; then run podman ps -a --format '{{.Names}}\t{{.Image}}\t{{.Status}}'; fi
  if have kubectl && kubectl version --request-timeout=5s >/dev/null 2>&1; then
    echo "--- k8s nodes ---"; run kubectl get nodes -o wide --no-headers | awk '{print $1, $2, $3, $5}'
    echo "--- k8s namespaces ---"; run kubectl get ns --no-headers | awk '{print $1}'
    echo "--- k8s pods not Running/Completed ---"; run kubectl get pods -A --no-headers | awk '$4!="Running" && $4!="Completed"'
  fi
  endsection

  section "Likely bots / agents / automations (paths only)"
  T=60 run find "$HOME_DIR" -maxdepth 5 \( "${PRUNE[@]}" \) -prune -o -type f \( \
    -iname '*bot*.py' -o -iname '*agent*.py' -o -iname '*webhook*' -o -iname '*monitor*.py' -o -iname '*watch*.py' \
    -o -iname 'docker-compose*.y*ml' -o -iname 'compose.y*ml' -o -iname '*.service' -o -iname 'Modelfile' \
    -o -iname 'n8n*' -o -iname '*.workflow.json' \) -print | sed "s#^$HOME_DIR#~#" | sort | head -200
  endsection

  section "Home top-level: size, last modified"
  for p in "$HOME_DIR"/* "$HOME_DIR"/.obsidian*; do
    [ -e "$p" ] || continue
    size="$(timeout 60 du -sh "$p" 2>/dev/null | cut -f1)"
    mod="$(stat -c '%y' "$p" 2>/dev/null | cut -d' ' -f1)"
    printf '%-8s %s  %s\n' "${size:-?}" "$mod" "${p#$HOME_DIR/}"
  done
  endsection

  section "Directory tree, depth 2 (dirs only, with newest file date)"
  T=120 run find "$HOME_DIR" -mindepth 1 -maxdepth 2 \( "${PRUNE[@]}" -o -name '.*' \) -prune -o -type d -print | sort | while read -r d; do
    newest="$(timeout 10 find "$d" -maxdepth 3 -type f -printf '%TY-%Tm-%Td\n' 2>/dev/null | sort -r | head -1)"
    count="$(timeout 10 find "$d" -maxdepth 3 -type f 2>/dev/null | wc -l)"
    printf '%s  files=%-6s newest=%s\n' "${d#$HOME_DIR/}" "$count" "${newest:-none}"
  done
  endsection

  section "Downloads intake"
  if [ -d "$HOME_DIR/Downloads" ]; then
    printf 'files: %s\n' "$(find "$HOME_DIR/Downloads" -maxdepth 1 -type f | wc -l)"
    printf 'older than 30 days: %s\n' "$(find "$HOME_DIR/Downloads" -maxdepth 1 -type f -mtime +30 | wc -l)"
    echo "by extension:"
    find "$HOME_DIR/Downloads" -maxdepth 1 -type f -name '*.*' | sed 's/.*\.//' | tr 'A-Z' 'a-z' | sort | uniq -c | sort -rn | head -15
  else echo "no ~/Downloads"; fi
  endsection

  section "Git repositories: last commit, uncommitted files, remote host"
  T=90 run find "$HOME_DIR" -maxdepth 5 \( -name node_modules -o -name .cache -o -name .venv -o -name .local \) -prune -o -type d -name .git -print | while read -r g; do
    r="$(dirname "$g")"
    last="$(git -C "$r" log -1 --format=%cs 2>/dev/null)"
    dirty="$(git -C "$r" status --porcelain 2>/dev/null | wc -l)"
    remote="$(git -C "$r" remote get-url origin 2>/dev/null | sed -E 's#^(https?://)[^@]*@#\1#; s#^git@([^:]+):#\1/#' | cut -d/ -f1-3)"
    printf '%s  last=%s  dirty=%s  remote=%s\n' "${r#$HOME_DIR/}" "${last:-none}" "$dirty" "${remote:-none}"
  done
  endsection

  section "Largest directories under home (depth 2)"
  T=180 run du -h --max-depth=2 "$HOME_DIR" 2>/dev/null | sort -rh | head -20 | sed "s#$HOME_DIR#~#"
  endsection
} > "$OUT"

echo "Wrote $OUT ($(wc -l < "$OUT") lines). Review it, then share it back."
