# Handoff: Tailnet host audit (run on core)

You are Claude Code running on **core**, with Tailscale access. A cloud session designed a personal-AI agent system but couldn't reach the tailnet. Your job is to audit three hosts and turn the results into the inputs the design needs. **The whole audit is read-only.**

## Why this exists

The owner's goal is fewer, better interruptions and something that tells them what to do next. Their Discord alerts fire with nothing handling them, and an earlier AI bot fell apart. The agreed design (see the artifact "Personal AI Org Chart") is:

- **One orchestrator agent** (the phantom-ai FastAPI app on core) with scoped **toolsets**: incident, files, projects. It is not a hierarchy of agents.
- **Routing done by code** (event type → handler). The LLM is used only for judgment.
- **Existing monitoring as the signal source:** Alertmanager plus its Watchdog alert (a dead man's switch), K8s events, and nightly file-scan diffs instead of live watchers.
- **Agent definitions, `profiles.yaml` and runbooks stored in git.** The repo is the registry, and a pull request is how a new agent gets created.
- **Daily state** (Now / Waiting / Problems / Changed) is the main thing the owner uses.

Rule: **no agent or toolset gets designed until this audit shows a real job for it.** "No AI needed here" is a valid finding.

## Hosts in scope

| Host | SSH target | Notes |
|---|---|---|
| core | local (`kageki`) | Run the script directly. GPU, k3s, Ollama, Redis, ChromaDB. |
| cyberdeck | `jolly@cyberdeck` | Owner confirmed it's authorized. |
| blacknode | `roger@blacknode` | Owner confirmed the username. Arch desktop with the Obsidian vault. |

Ignore any other tailnet peers (aipi is out of scope for this pass).

## Preflight

1. Find the repo on core (CLAUDE.md suggests `~/Projects/phantom-ai`, but paths may differ under `kageki`). Then `git fetch origin claude/beautiful-curie-2s84oo && git checkout claude/beautiful-curie-2s84oo && git pull`.
2. Run `tailscale status` and confirm cyberdeck and blacknode are online.
3. Test non-interactive access: `ssh -o BatchMode=yes -o ConnectTimeout=5 jolly@cyberdeck true`, then the same for `roger@blacknode`. If `ssh` fails, try `tailscale ssh`. If Tailscale SSH asks for a browser check, **stop and ask the owner**. Don't work around it.
4. `mkdir -p audits` in the repo. Anything matching `audit-*.md` is gitignored, so don't change that.

## Step 1: Run the audit script on each host

Run `scripts/audit-host.sh` without copying it to the remote host:

```bash
DATE=$(date +%F)
bash scripts/audit-host.sh "audits/audit-core-$DATE.md"

for target in jolly@cyberdeck roger@blacknode; do
  h=${target#*@}
  ssh -o BatchMode=yes "$target" "bash -s -- /tmp/phantom-audit.md" < scripts/audit-host.sh \
    && ssh -o BatchMode=yes "$target" "cat /tmp/phantom-audit.md; rm -f /tmp/phantom-audit.md" > "audits/audit-$h-$DATE.md"
done
```

If a host is offline or refuses the connection, write that down and keep going with the others.

## Step 2: Extra read-only checks the script doesn't cover

Run these per host where they apply. If a command isn't there, write that down; don't install anything.

- **Existing monitoring stack:** is any of these present, and on which host (container, pod or unit): Prometheus, Alertmanager, Grafana, Uptime Kuma, Netdata, node_exporter, Loki? Is a Watchdog / dead man's switch alert configured?
- **Alert senders:** what currently posts to Discord or Telegram? Search unit files, compose files, cron entries and scripts for `discord`/`telegram` **by filename and matching line numbers only** (`grep -rlI`, `grep -n` piped through the script's `redact` style). Never print webhook URLs or tokens.
- **core only:**
  - `nvidia-smi --query-gpu=name,memory.total --format=csv` (VRAM decides the local model; it's a known blocker)
  - `ollama list` or `curl -s localhost:11434/api/tags`
  - `kubectl get nodes`
  - `kubectl get pods -A`
  - whether ArgoCD is installed
  - state of the `phantom-ai` namespace
- **blacknode only:** where the Obsidian vault is, how many notes it has, when a note last changed, and whether obsidian-git is set up (check for `.obsidian/plugins/obsidian-git`). Don't read note contents.

## Hard rules

- Read-only. No installs, restarts, `systemctl start/stop/enable`, package changes, `kubectl apply/delete/scale`, or `sudo`.
- The only file written on a remote host is `/tmp/phantom-audit.md`, and it gets deleted right after.
- Never read or print `.env` files, keys, kubeconfigs, `~/.ssh`, password stores, browser profiles, or note or document contents.
- Never commit raw audit output, IP addresses, or Tailscale IPs. The repo already had to scrub one IP.
- Don't create agents, services or monitoring. This pass produces findings and drafts only.

## Deliverables (commit these to `claude/beautiful-curie-2s84oo`)

1. **`docs/host-inventory.md`**: a cleaned-up summary with one section per host:
   - role, OS, hardware (with VRAM for core)
   - key running services and containers
   - failed units
   - existing automations and bots
   - monitoring coverage and gaps
   - the Downloads backlog
   - stale repos and repos with uncommitted work
   - notable large or stale folders

   No IPs, no secrets.
2. **Automation inventory table** (inside `docs/host-inventory.md`) with these columns:
   - name
   - host
   - trigger
   - what it watches or does
   - where it reports
   - working? (yes / no / unknown)
   - duplicates something else?
   - recommendation: keep / merge into orchestrator / retire
3. **`config/profiles.yaml`** (draft): folder profiles using gitignore-style globs per host, with defaults plus exceptions. Each profile has:
   - `purpose`
   - `index` (yes / no / limited)
   - `scan` (nightly / hourly / none)
   - `toolset` (incident / files / projects / none)
   - `sensitive` (true means never index)

   Mark folders you couldn't classify with `# TODO: ask owner`, rather than guessing.
4. **Recommendations**, as a short section at the end of `docs/host-inventory.md`:
   - which toolsets each host actually needs
   - the monitoring gaps to fix before build step 2 (the explain-only incident loop)
   - which Discord alerts to retire once the orchestrator handles them
   - the local model to use on core given its VRAM

Commit with a clear message and push: `git push -u origin claude/beautiful-curie-2s84oo`.

## Report back to the owner

End with a summary of 15 lines or fewer:
- which hosts were audited and which failed, and why
- the top 3 findings (things that are broken or silently failing)
- the automation count: keep / merge / retire
- VRAM and the recommended local model
- open questions for the owner (the TODOs from `profiles.yaml`)

The owner will bring `docs/host-inventory.md` back to the cloud session to update the org chart's host cards.
