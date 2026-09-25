# Host inventory (tailnet audit, 2026-09-25)

This inventory comes from a read-only audit run on core per `docs/handoff-host-audit.md`. The raw output lives only in `audits/` on core and is gitignored. There are no IPs or secrets here.

Hosts audited: **core**, **cyberdeck** and **blacknode**, all reached over non-interactive SSH. None failed. aipi is out of scope and decommissioned.

Script caveats:
- `scripts/audit-host.sh` → "Tailscale peers" came back empty on all three hosts. `run` pipes the JSON through `redact` before `jq`, which corrupts it. The fix is to run `jq` first and redact afterwards.
- cyberdeck has no `hostname` binary, so its report header is blank.
- The "Largest directories" section timed out on core and blacknode, so it's only partial.

---

## core

| | |
|---|---|
| Role | Main workstation. Worker node in k3s. Runs Ollama on the host, Kageki (daemon, voice, Discord bot/relay), life-os, most automations, Wazuh, Splunk and the investigations stack. |
| OS | Arch Linux, kernel 7.2 (x86_64) |
| Hardware | Ryzen 5 3600X (12 threads), 31 GiB RAM with 12 of 15 GiB swap in use (memory pressure). Root disk is 1.8 TB NVMe at **84% used**. |
| GPU | **One NVIDIA RTX 4060 Ti with 16 GB VRAM** (driver 615, compute 8.9). The "dual-GPU / 22 GB" in the Kageki docs is wrong: `nvidia-smi -L` and `lspci` both show a single GPU. |

**Key services and containers**
- **systemd services:**
  - Host Ollama (system unit). Models: `qwen2.5:7b`, `qwen2.5:14b`, `qwen2.5vl:7b`, `qwen2.5-coder:14b`, `nomic-embed-text`.
  - Kageki daemon (uvicorn), piper-server, whisper-server, kageki-discord-mod (bot plus relay/outbox).
  - life-os (Next.js), govcon-dashboard, flight-recorder, usage-guardian.
- **Docker:**
  - Wazuh single-node (manager, indexer, dashboard) and Splunk.
  - The investigations-core stack (app, worker, postgres/pgvector, redis, neo4j).
  - graphify neo4j and dashboard, and GovCon postgres/redis.
  - 3 exited or orphaned containers.
- **k3s (worker):**
  - `phantom-ai` ns runs chromadb, ollama and redis, all Running.
  - The `ollama` pod has **no GPU limit** (CPU only). The `gpu-detection` Job has been **Failed for 119 days**.
  - **The phantom-ai orchestrator itself is not deployed anywhere.** `phantom-ai-voice` and `phantom-ai-gimbal` units exist but are inactive.
  - No ArgoCD.

**Failed units:** none, at both system and user level.

**Existing automations and bots:** 30 custom user timers and services (see the table below). Highlights:
- **All 10 Claude agent timers are disabled.** This covers the 05:05 daily chain, founder-mode, life-coach, revenue-commander, project-closer, phantom-daily-blog, documentation-engineer, ecosystem audit/review and k8s-commander.
  - Their last runs, 2026-08-31 to 2026-09-05, were mostly `Failed with result 'exit-code'`.
  - Nothing has run since. The roster in `~/.claude/CLAUDE.md` still describes them as scheduled.
- Working: kageki-build, kageki-audit-sweep, kageki-dream-cycle, kageki-dataset-discovery, what-changed, the obsidian push/pull, life-os-backup, onedrive-sync, flight-recorder and govcon-daily-report.
- **Discord traffic today is life-os only.**
  - The relay outbox holds 256 messages over about 16 days (238 INFO, 18 REPORT), roughly 16 a day.
  - `tailnet-ops-monitor@core` runs every 5 minutes, but its relay environment file doesn't exist and the notifier swallows errors by design. **Its alerts can never reach Discord**; it only writes a local report file.

**Monitoring coverage**
- **Present:**
  - Wazuh (security events).
  - tailnet-ops-monitor: 11 "is the timer/service active" checks, all reporting OK, but it can't deliver.
  - flight-recorder healthcheck.
- **Missing:**
  - Prometheus, Alertmanager, node_exporter, Loki. There's no Watchdog.
  - Nothing watches for disabled timers, swap, disk, or kubelet warnings.
  - k8s events show **`FreeDiskSpaceFailed` ×727 on core** (the kubelet can't reclaim image disk), with no one alerted.

**Downloads backlog:** there's no `~/Downloads`. The equivalent intake is loose files in the home root: about 1.9 GB of screen-recording `.mp4`s from 2026-09-10 and 09-22, a Kismet capture (`OFH-01.*`), and stray handoff and markdown files.

**Repos**
- **Uncommitted work:**
  - `Documents/Obsidian Vault` (86 files, though pushes are still landing daily)
  - `Projects/life-os` (55)
  - `Projects/kageki` (33)
  - `Projects/govcon-dashboard` (25)
  - `Projects/aaip` (11, no remote)
  - `kageki-discord-mod` (1, no remote)
  - `~` itself is a git repo with 136 changes and no remote
- **Stale (untouched since May):** `toolchain-layer`, `system-backup-brick12`, `vaultkeeper`, `daracademy`, `logging-siem-wazuh` (dirty 2), `wazuh-docker` (dirty 4).
- **No remote at all:** `aaip`, `quantdeck`, `workbench`, `xmr-mining-k8s`, `opencode_upgrades`.

**Large or stale folders**
- `~/.local/share/Steam` (433 GB) and `~/Games` (97 GB).
- `~/.local/state` (71 GB).
- `~/aipi` (9.2 GB, left over from the decommissioned host).
- `~/sandbox` (708 MB rootfs).
- `~/BurpSuite` (944 MB).
- **Bug:** `~/.local/state/life-os/fr-staging` contains copies of itself nested **7 levels deep** (fr-staging/home/kageki/.local/state/life-os/fr-staging/…). I couldn't identify the writer: no match in Flight_Recorder, life-os/scripts or `~/scripts`. Needs investigation.

---

## cyberdeck

| | |
|---|---|
| Role | Raspberry Pi. k3s worker (agent). The "services box": DNS, web tunnels, Home Assistant, the monitoring UI and lots of self-hosted apps. |
| OS | Arch Linux ARM, 6.18 rpi kernel (aarch64) |
| Hardware | 4-core ARMv8, 7.8 GiB RAM with 2.1 of 4 GiB swap in use. Root is 234 GB at **88% used**. No GPU. It serves as a llama.cpp RPC worker. |

**Key services and containers**
- **Docker:**
  - Monitoring: prometheus, grafana, uptime-kuma and ntfy.
  - Network and DNS: pihole, adguard.
  - Apps: homeassistant, node-red, homarr, vaultwarden, gitea, anythingllm, code-server, filebrowser, navidrome, wetty.
  - Sites and sync: bashinsights, vaultkeeper-nginx/sync, tailnet-topology-http.
  - 5 exited or created leftovers.
- **systemd:**
  - Web and tunnels: cloudflared ×2 tunnels, cybersec-server (site).
  - Kageki and AI: kageki-backend (older Kageki), llama-rpc-server, ollama (CPU).
  - financial-os web and worker, and k3s-agent.

**Failed units**
- `unbound` (DNS resolver, failed since 2026-09-20).
- `vaultkeeper-update`.
- `phantom-blog-publish` (user).
- Not failed but broken: **`financial-os-web` (system) is crash-looping, with 57,211 restarts**, and **`financial-os-worker` runs twice** (one system copy and one user copy).

**Existing automations and bots**
- system-health: hourly `alert-runner --all`, sending email and ntfy.
- network-daily: `alert-runner --daily`.
- tailnet-ops-monitor@cyberdeck: also has no relay environment file, so it can't deliver.
- The tailnet-topology collector, ecosystem-snapshot, and phantom-blog-publish (failed).
- vaultkeeper backup and update (cron).
- Present on disk but not scheduled: the older Kageki Telegram bot and orchestrator scripts, the home-network-defense-grid new-device detector, and the `trading-engine`/`trading-oversight` units (inactive).

**Monitoring coverage**
- Prometheus exists but **scrapes only itself**, with **0 alert rules and 0 Alertmanagers**. In practice it collects nothing.
- Grafana is there for dashboards.
- Uptime Kuma is healthy, but its monitor list can't be seen without logging in.
- The kubelet logged `FreeDiskSpaceFailed` ×116.
- There's no Watchdog.

**Downloads backlog:** empty (0 files).

**Repos:** the git section is mostly vendor and tool clones. Most of cyberdeck's project work lives in the core and GitHub copies.

**Large or stale folders**
- `Projects` (4.3 GB), `Apps` and `apps` (1.5 GB + 598 MB, likely duplicates), `build` (1.3 GB) and `llama.cpp` (1.2 GB).
- The home root has **about 50 loose setup and debug scripts from April–July**, plus loose `smtp*.env` and `smtp*.conf` files. Those are credentials and must never be indexed.
- `Documents/ObsidianVault` exists but has **0 notes** (obsidian-git is configured).

---

## blacknode

| | |
|---|---|
| Role | Arch laptop. **k3s control-plane**, which puts the whole cluster's API on a laptop. Primary Obsidian editing host and runs the investigations stack. |
| OS | Arch Linux, kernel 7.2 (x86_64) |
| Hardware | i7-6700HQ (8 threads), 15 GiB RAM. Root is 930 GB at 76% used. **The NVIDIA GTX 960M driver isn't loaded** (`nvidia-smi` fails), so it runs on Intel HD 530 only. |

**Key services and containers**
- **Docker:** the investigations stack (app, worker, postgres/pgvector, redis, neo4j), plus 10 containers exited 1–4 months ago.
- **systemd:** k3s (server), docker, flight-recorder, thermal-watchdog, and a CPU thermal cap at 75%.
- Ollama is installed but inactive, and the phantom-server/tunnel units are inactive.

**Failed units:** `homarr-health-check` and `swaync`.

**Existing automations and bots**
- **All 17 user timers except two (homarr-health-check and thermal-watchdog) are disabled.** That includes the 8 `agent-*` script ports of the Claude agents and **every Obsidian sync timer** (push, pull, claude-sync, graphify, k8s-sync).
- The last vault push was **2026-09-06**. Notes were edited through 2026-09-21, and 4 files are uncommitted.
- No Discord or Telegram senders were found. There's one ntfy alert script in `brick-14-home-network-defense-grid`.

**Monitoring coverage:** **none.** There's no tailnet-ops-monitor instance, no exporters, and nothing watching the k3s control-plane. homarr-health-check is failed.

**Obsidian vault**

| Vault | Notes | Last note change | Last git commit | obsidian-git |
|---|---|---|---|---|
| `Documents/Obsidian Vault` (live) | 6,230 | 2026-09-21 | 2026-09-06, 4 dirty | yes |
| `Inbox/vault-backups/pre-consolidation-20260906` | 6,801 | 2026-09-06 | 2026-09-06 | yes |
| `Inbox/vault-backups/preserve-blacknode-20260906` | 1 | 2026-09-05 | | yes |
| `vaults/vaultkeeper` | 1,132 | 2026-06-15 | | no |

The pre-consolidation backup holds 571 more notes than the live vault.

**Downloads backlog:** 12 files (4.7 GB), 10 of them older than 30 days: 5 pdf, 2 zip, 2 sh, 1 txt, 1 gz, and 1 partial `.crdownload`.

**Repos**
- **Uncommitted work:** `Projects/homelab` (24), `Projects/VaultKeeper` (29), `Projects/Local-AI-Web-Workspace` (25), `Projects/govcon-dashboard` (11), `ARCHIVED/CyberSec-Web-Services` (56), `Investigations` (21, no remote), `device-activity-tracker` (22).
- **Stale:** there's a stale `Projects/phantom-ai` clone (last commit 2026-05-29, 4 dirty), and this repo's `CLAUDE.md` still points at it.

**Large or stale folders**
- `Investigations` (71 GB, case data, sensitive).
- **`aipi-sdcard-backup` (64 GB, last touched 2026-07-21, for a decommissioned host).**
- `Documents` (26 GB, including about 30 wordlist repos), `Projects` (21 GB), `config-backup` (4.4 GB, April), `ThemeAssets` (3.5 GB) and `go` (3.7 GB).

---

## Automation inventory

"Working?" is based on unit state, last journal result and outputs. Rows marked DISABLED have a timer file that is off.

| # | Name | Host | Trigger | Watches / does | Reports to | Working? | Duplicates? | Recommendation |
|---|---|---|---|---|---|---|---|---|
| 1 | agent-daily-chain (project-closer → life-coach → assignment-tracker → founder-mode) | core | 05:05 daily, DISABLED | Daily Claude brief chain | Obsidian and memory | no: failed 2026-09-05, then disabled | 2, 3, 4, 45 | merge (this is the Daily state) |
| 2 | claude-founder-mode | core | 07:00 daily, DISABLED | Daily brief | Obsidian | no: failed 09-05 | 1 | merge |
| 3 | claude-project-closer | core | Mon, DISABLED | Stalled-project scan | Obsidian | no: failed 08-31 | 1, 45 | merge (projects toolset) |
| 4 | claude-life-coach | core | Fri, DISABLED | Life check-in | Obsidian | no: failed 09-04 | 1 | retire timer (the chain covers it; the skill stays manual) |
| 5 | claude-revenue-commander | core | Mon, DISABLED | RFP/lead scan | Obsidian and memory | no: failed 08-31 | 45 | keep (business routine; TODO: re-enable?) |
| 6 | claude-phantom-daily-blog | core | daily, DISABLED | Blog content ops | Obsidian | no: failed 09-05 | pairs with 37 | keep (TODO: owner) |
| 7 | claude-documentation-engineer | core | Sun, DISABLED | Scan for undocumented systems | Obsidian | last OK 08-30, now off | 45 | keep (manual) |
| 8 | claude-ecosystem-audit / -review | core | Mon / Fri, DISABLED | Ecosystem health | `~/reports` | no: review failed 09-04 | 17, 18, 29, 45 | merge (incident + Changed) |
| 9 | claude-kubernetes-commander | core | monthly, DISABLED | Cluster health report | Obsidian | last OK 09-01, now off | 45 | merge (incident: k8s events) |
| 10 | kageki-build | core | 3-hourly | Advances the Kageki rebuild | repo / BUILD_STATE | yes | – | keep |
| 11 | kageki-audit-sweep | core | 4× daily | Audits Kageki's own jobs | Kageki API, `~/reports` | yes | – | keep |
| 12 | kageki-dream-cycle | core | 2-hourly | Kageki memory consolidation | Kageki DB | yes | – | keep |
| 13 | kageki-dataset-discovery | core | Mon | Dataset research | report and memory | yes | – | keep |
| 14 | kageki-discord-mod (bot + relay + outbox) | core | always on | Discord bot, moderation, relay for producers | Discord | yes (0 errors in 24 h) | – | keep (the single outbound channel) |
| 15 | kageki-discord-outbox-cleanup | core | daily | Purges sent relay rows older than 30 days | – | yes | – | keep |
| 16 | life-os notifications (via relay) | core | app events | Reminders and reports | Discord, about 16 a day | yes | – | merge (fold INFO into the daily digest; keep REPORT) |
| 17 | tailnet-ops-monitor@core | core | every 5 min | 11 active-checks | local report file only; **relay env file missing** | partial: checks run, alerts undeliverable | 29, 31 | merge (its JSON becomes an incident signal) |
| 18 | what-changed | core | 02:00 daily | System change report | `~/reports` | yes | 19 | merge (the Changed section) |
| 19 | ecosystem-snapshot | all 3 | Sun 22:00 | Node snapshot | reports | core and cyberdeck yes; blacknode DISABLED | 18 | merge |
| 20 | flight-recorder (+ sync, healthcheck, report) | core, blacknode | always on, 10 min, hourly, Wed | Activity recorder | GitHub, report | core yes; blacknode sync DISABLED | – | keep |
| 21 | govcon-daily-report | core | 06:00 daily | GovCon report | dashboard | yes | – | keep |
| 22 | life-os-backup | core | 03:30 daily | Backup | local | yes | – | keep |
| 23 | life-os-obsidian-import | core | DISABLED, never ran | Import vault into life-os | – | no | 24 | retire (TODO: owner) |
| 24 | obsidian-vault-push/pull, obsidian-claude-sync | core | daily | Vault git sync, CLAUDE.md aggregation | GitHub | yes | 46 | keep |
| 25 | obsidian-graphify-sync | core, blacknode | DISABLED, never ran | Graph sync | – | no | 26 | retire |
| 26 | graphify-refresh / graphify-sync (system) | core | 15 min / 5 min | Graph refresh and sync | graphify-out | yes | – | keep |
| 27 | onedrive-sync | core | daily | OneDrive sync | – | yes | – | keep |
| 28 | usage-guardian | core | always on | Polls Claude usage, pushes vault at a threshold | – | yes | – | keep |
| 29 | system-health (`alert-runner --all`) | cyberdeck | hourly | Host health checks | email + ntfy | yes | 17, 31 | merge |
| 30 | network-daily (`alert-runner --daily`) | cyberdeck | daily | Network summary | email + ntfy | unknown | – | merge |
| 31 | tailnet-ops-monitor@cyberdeck | cyberdeck | every 5 min | Checks | report file only (relay env missing) | partial | 17, 29 | merge |
| 32 | tailnet-topology collector | cyberdeck | timer | Topology for the Grafana node graph | Grafana | yes | – | keep |
| 33 | Prometheus + Grafana | cyberdeck | always on | Scrapes only itself, 0 rules, 0 Alertmanagers | Grafana | no (no real coverage) | – | keep and configure (the signal source) |
| 34 | Uptime Kuma | cyberdeck | always on | HTTP checks (list not visible) | unknown | unknown | 17 | keep (TODO: owner) |
| 35 | ntfy server | cyberdeck | always on | Push channel for alert-runner | phone | yes | a second channel beside Discord | retire once the orchestrator is the only notifier |
| 36 | node-red | cyberdeck | always on | Flows unknown | unknown | unknown | – | TODO: ask owner |
| 37 | phantom-blog-publish | cyberdeck | daily | Publishes the blog | web | no (unit failed) | pairs with 6 | keep and fix (TODO: owner) |
| 38 | vaultkeeper-update / -backup | cyberdeck | cron + timer | App update and backup | – | update no (failed); backup unknown | – | keep, fix update |
| 39 | financial-os-web (system) | cyberdeck | always on | Web app | – | **no: 57,211 restarts** | user-level copy of the unit | keep one, fix |
| 40 | financial-os-worker (user copy) | cyberdeck | always on | Worker | – | yes, but **running twice** | the system copy | retire the user copy |
| 41 | kageki-backend, kageki-motion, phantom-motion | cyberdeck | always on | Older Kageki backend; `motion_monitor.py` ×2 (inactive) | ? | backend yes, motion no | core Kageki | retire (TODO: confirm) |
| 42 | Kageki `telegram_bot.py` / `kageki_orchestrator.py` | cyberdeck | not scheduled | Earlier bot and orchestrator | Telegram | not running | core Kageki / phantom-ai | retire |
| 43 | home-network-defense-grid new-device detector | cyberdeck | timer file not installed | New-device alerts | ntfy | no | 32 | retire (TODO: owner) |
| 44 | trading-engine / trading-oversight | cyberdeck | services (inactive) | Trading scheduler | ? | not running | – | TODO: ask owner |
| 45 | `agent-*` ×8 (founder-mode, project-closer, revenue-commander, ecosystem audit/review, docs-engineer, cyber-career, k8s-health-snapshot) | blacknode | timers, all DISABLED | Script ports of the core agents | ? | no | 1–9 | retire |
| 46 | obsidian-vault-push/pull, claude-sync, k8s-sync | blacknode | timers, all DISABLED | Vault git sync | GitHub | **no: last push 2026-09-06** | 24 | keep and re-enable (TODO: confirm) |
| 47 | homarr-health-check | blacknode | timer | Homarr health | ? | no (unit failed) | 34 | merge |
| 48 | thermal-watchdog + CPU thermal cap | blacknode | timer / boot | Laptop thermal protection | local | yes | – | keep |
| 49 | refcheck | blacknode | timer, DISABLED | Unknown | ? | no | – | TODO: ask owner |
| 50 | `gpu-detection` Job (phantom-ai ns) | cluster | one-shot | GPU detection | – | failed 119 days ago | – | retire (delete with owner approval) |

**Totals:** 24 keep, 13 merge into the orchestrator, 10 retire, 3 unknown (ask the owner).

---

## Recommendations

**Toolsets each host needs**
- **core** hosts the orchestrator and needs:
  - **incident**: k8s events, kubelet disk GC, failed or disabled units, swap and disk.
  - **projects**: dirty repos, stalled routines.
  - **files**: nightly, limited to `Projects/`, `reports/`, `handoffs/` and the loose files in the home root.
- **cyberdeck** needs **incident only**: crash loops, failed units, disk at 88%, container health. There's nothing worth indexing, since Downloads is empty and the vault is empty. Most of its problems are config fixes: **no AI needed**.
- **blacknode** needs:
  - **incident**: the k3s control-plane currently has no monitoring at all.
  - **files**: vault stats and the Downloads backlog. `Investigations` must never be indexed.
  - **projects**: several dirty repos, including a stale phantom-ai clone.

**Monitoring gaps to fix before build step 2 (the explain-only incident loop)**
1. **There's no Alertmanager and no Watchdog anywhere.** Add Alertmanager with a Watchdog rule and route it to the orchestrator endpoint, not straight to Discord.
2. **Prometheus scrapes only itself.**
   - Add node_exporter on all 3 hosts, with the systemd collector for failed units and a textfile collector for "expected timer enabled + last success".
   - Scrape the kubelet and kube-state-metrics.
   - Add rules for disk over 85%, `FreeDiskSpaceFailed`/ImageGC, failed units, restart loops and stale timers.
3. **blacknode (the control-plane) is unmonitored.** Add it to both Prometheus and tailnet-ops-monitor.
4. **tailnet-ops-monitor can't deliver on core or cyberdeck.** The relay environment file is missing and failures are swallowed. Its checks only ask "is the timer active", so disabled timers go unseen. Don't revive its Discord path; have the orchestrator read its JSON report instead.
5. Fix or recover what's already broken before the incident loop inherits it:
   - `unbound` on cyberdeck (DNS)
   - the financial-os-web crash loop and the duplicate worker
   - kubelet disk GC on core and cyberdeck
   - the blacknode vault sync

**Discord alerts to retire once the orchestrator handles them**
- life-os INFO posts, about 15 a day: fold them into the daily-state digest and keep only the REPORT posts.
- The tailnet-ops-monitor Discord path (currently dead anyway). Its checks become incident inputs.
- cyberdeck's `alert-runner` email and ntfy (system-health, network-daily), plus homarr-health-check.
- Keep **kageki-discord-mod's relay** as the single outbound channel.

**Local model for core:** 16 GB VRAM on one RTX 4060 Ti.
- Use **`qwen2.5:14b`** (Q4, about 9 GB, already pulled) for judgment calls. That leaves roughly 6 GB for KV cache plus whisper.
- Fall back to `qwen2.5:7b` when the voice stack is loaded, and use `nomic-embed-text` for RAG.
- Point the orchestrator at the **host Ollama**. The in-cluster `ollama` pod has no GPU (no device plugin, and `gpu-detection` failed), so it's CPU-only and duplicates the host service. Scale it to 0 once the owner approves.
