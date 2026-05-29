# CLAUDE.md — phantom-ai Project

Session guidance for implementing the phantom-ai Kubernetes AI system.

## Project Scope

`phantom-ai` is an autonomous AI agent managing a k3s homelab cluster with voice, vision, gimbal control, and RAG. Deployed across `core` (Ollama GPU, FastAPI orchestrator, voice/vision) and `aipi` (Hailo edge inference).

## Key Decisions

- **Full K8s autonomy** with approval gates for destructive ops (scale-to-0, delete, drain node)
- **RAG-first** (vector retrieval over cluster docs) + fine-tuning pipeline deferred until GPU VRAM confirmed
- **Systemd services (Phase 2a)** for voice and gimbal (simpler device access) before containerizing to K8s (Phase 2b)
- **No bypass for cluster-admin** — ClusterRole scoped to readers + writers in non-system namespaces only

## Quick Commands

**Development / testing:**
```bash
cd /home/roger/Projects/phantom-ai

# Install dependencies
pip install -e .

# Run orchestrator locally (against cluster)
python -m phantom_ai.main

# Test voice capture
python -m phantom_ai.voice.capture

# Test gimbal BLE
python -m phantom_ai.gimbal.controller --simulate

# Kubernetes manifests
kustomize build k8s/

# Deploy to cluster
kubectl apply -k k8s/
```

**GPU diagnostics (on core):**
```bash
nvidia-smi                        # Check GPU + VRAM
nvidia-smi --query-compute-cap    # CUDA capability
```

## File Structure Conventions

- **`src/phantom_ai/`** — Pure Python package, no CLI entry points; all code importable
- **`edge/`** — Separate package for aipi; uses same python version/structure
- **`k8s/`** — All Kubernetes manifests; kustomization.yaml at root and per-component
- **`docs/`** — Narrative documentation, not code comments; see note below
- **Tests:** No test directory yet; add `tests/` if/when pytest suite is needed

## Code Style

- Type hints on all functions (pydantic for API contracts)
- Async/await default for I/O-bound code (voice, vision, BLE, K8s client)
- Config via Pydantic (`config.py`), read from `.env` or K8s Secret volumes
- Logging: `structlog` for structured logs (or Python `logging` if already in use)
- No comments — code names are clear; docs in separate files explain *why*

## Secrets Management

Secrets are NEVER committed. For each Phase 2 deployment:
1. `kubectl create secret generic phantom-ai-notifications --from-literal=telegram-token=... --from-literal=chat-id=...`
2. `kubectl create secret generic phantom-ai-smtp --from-literal=host=... --from-literal=user=...`
3. Mount in pod via `secretKeyRef:` in manifests; reference in `config.py` via `os.getenv()`

Document the secret names and structure in `docs/secrets.md` (no values).

## Kubernetes Patterns

- **Namespace:** `phantom-ai` (own namespace, not kube-system or default)
- **ServiceAccount:** `phantom-ai-agent` with scoped ClusterRole (readers) + Role (non-system writers)
- **PVCs:** local-path storage (all on core), persistent across restarts
  - `ollama-models`: 60Gi
  - `chroma-data`: 20Gi
  - `redis-data`: 1Gi (or 5Gi if persistent cache)
- **Labels:** `app: phantom-ai`, `managed-by: argocd`
- **Images:** `ghcr.io/realphantomlee/phantom-ai:latest` (built from Dockerfile, pushed by CI)

## Phase 2 Order (Critical)

1. **GPU setup first** — `nvidia-smi`, toolkit, device plugin
2. **Ollama next** — all downstream assumes Ollama service exists at `ollama:11434`
3. **Redis** — gimbal position + voice session state
4. **Orchestrator** — FastAPI core; voice/gimbal/agent all call it
5. **Voice/gimbal as systemd** (initially) — avoids K8s device passthrough friction
6. **Edge vision on aipi** — independent of core, depends only on network

## When Stuck

- **GPU VRAM unknown**: Run `nvidia-smi`, check CONTRIBUTING.md for model selector
- **Gimbal BLE not responding**: Check ZY Play app on phone for Bluetooth pairing; add `--simulate` flag to test locally
- **Voice audio not captured**: Verify `arecord -l` lists Blue Yeti, check `/dev/snd/` permissions
- **K8s agent auth issues**: `kubectl auth can-i` to test permissions with SA token
- **Obsidian vault sync**: Use `obsidian-git` plugin in the vault; RAG ingest clones from private repo

## Documentation

Document in separate `.md` files in `docs/`, not code comments. Each doc answers a specific *why*:

- `architecture.md` — system design, data flows, threat model (K8s agent safety)
- `voice-setup.md` — Blue Yeti config, Whisper/Piper tuning, latency notes
- `gimbal-protocol.md` — Zhiyun BLE reverse-engineering, cable rotation limits
- `k8s-agent-safety.md` — approval gate design, RBAC scoping, audit logging
- `phase2-deploy.md` — step-by-step deploy + troubleshooting

## Obsidian Integration

The vault lives at `/home/roger/Documents/Obsidian Vault/` on blacknode (user's Arch machine).

- Vault is private (not on GitHub) — use `obsidian-git` plugin to push changes
- RAG ingest pulls from the private repo (via GitHub token in Secret)
- Document `phantom-ai` in `02-Projects/phantom-ai.md` with links to `[[Homelab]]`, `[[K8s-Cluster]]`
- Use Obsidian Tasks (`- [ ]`) in the note for Phase 2 checklist tracking

## Homelab Integration

- **homelab repo:** ArgoCD Application at `clusters/homelab/apps/phantom-ai.yaml` points to this repo's `k8s/` path
- **homelab docs:** Link to phantom-ai from `ARCHITECTURE.md` and `CONTRIBUTING.md`
- **Shared infra:** Ollama, Tailscale, K8s API all provided by homelab; phantom-ai only adds its services

## When Context Limit Approaches

If context usage reaches 85% during Phase 2, schedule remaining work (see `/schedule`) with:
- Task title + specific file paths
- Status of what's done vs. pending
- Current blockers (e.g., "waiting on VRAM confirmation from nvidia-smi")

Goal: Pick up Phase 2 exactly where you left off in the next session.

## See Also

- [README.md](README.md) — project overview
- [pyproject.toml](pyproject.toml) — dependencies (Python 3.10+)
- [homelab/CONTRIBUTING.md](../homelab/CONTRIBUTING.md) — how new workloads integrate
- [Obsidian vault](file:///home/roger/Documents/Obsidian%20Vault/02-Projects/phantom-ai.md) — ongoing progress tracker
