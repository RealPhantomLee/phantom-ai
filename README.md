# phantom-ai

An autonomous AI system managing a k3s Kubernetes homelab cluster with voice, vision, and robotic gimbal control.

## Overview

`phantom-ai` is a specialized AI agent running on the `core` node (<CORE_TAILSCALE_IP> on Tailscale) with:
- **GPU-accelerated LLM inference** via Ollama (NVIDIA GPU)
- **Voice interface** (Blue Yeti mic + Piper TTS)
- **Vision processing** (Panasonic Lumix G7 via Cam Link 4K + Hailo AI Hat+ on aipi)
- **Robotic gimbal control** (Zhiyun Bluetooth gimbal with cable-aware rotation limits)
- **Kubernetes autonomous agent** (full cluster management with approval gates for destructive ops)
- **RAG pipeline** (vector-based retrieval over cluster docs, Obsidian vault, runbooks)
- **Daily reports** (18:00 Telegram + email digest of cluster health)

## Hardware

### `core` (<CORE_TAILSCALE_IP>, Arch Linux, 12c/32GB)
- **GPU**: NVIDIA (run `nvidia-smi` to identify VRAM tier at deploy time)
- **Camera**: Panasonic Lumix G7 → Cam Link 4K → `/dev/video0`
- **Microphone**: Blue Yeti (USB)
- **Speaker**: 3.5mm line out
- **Gimbal**: Zhiyun Bluetooth (pan ±270°, tilt ±45°, cable-limited)

### `aipi` (REDACTED_AIPI_IP, Raspberry Pi 5)
- **AI Hat+**: Hailo-8L NPU (13 TOPS) for edge vision inference (YOLOv8 object detection)

## Architecture

```
┌─────────────────────────────────────────────────┐
│ core (<CORE_TAILSCALE_IP>) — phantom-ai orchestrator  │
│                                                 │
│ Blue Yeti ──→ openwakeword ──→ faster-whisper  │
│               (CPU)              (GPU)          │
│                    │                            │
│              ┌─────▼──────────────────┐         │
│              │  Ollama + LLM          │         │
│              │  (GPU, VRAM-dependent) │         │
│              └─────┬──────────────────┘         │
│                    │                            │
│    Piper TTS ◀─────┤  ChromaDB + RAG            │
│    (CPU) ──┐       │  (vector retrieval)        │
│            │       │                            │
│     3.5mm  │  ┌────▼─────────────────┐         │
│     speaker└─►│ FastAPI Orchestrator │         │
│               │ (K8s agent, reports) │         │
│               └────┬─────────────────┘         │
│                    │                            │
│            Cam Link 4K ──┐                      │
│         (OpenCV) /dev   │  bleak (BLE)          │
│                   video0 │  Zhiyun gimbal       │
│                          │  control             │
│                    ┌─────▼──────────────┐      │
│                    │  Vision pipeline   │      │
│                    │  + Gimbal driver   │      │
│                    └─────────────────────┘      │
└─────────────────────────────────────────────────┘
           │                    │
           │                    │
      ┌────▼─────────┐    ┌────▼──────────────┐
      │ aipi         │    │ K8s Cluster      │
      │ (Hailo edge) │    │ (read/write)     │
      │ detection    │    │ (approval gates) │
      └──────────────┘    └──────────────────┘
           │                    │
      ┌────▼──────────────────────┘
      │
      ▼
  Telegram Bot + SMTP
  (18:00 daily report)
```

## Technology Stack

| Layer | Tool | Notes |
|-------|------|-------|
| LLM | Ollama | Native NVIDIA GPU, REST API |
| STT | faster-whisper + distil-large-v3 | 4× faster than base whisper |
| Wake Word | openwakeword | CPU-based, no cloud |
| TTS | piper-tts (en_US-lessac-medium) | <100ms latency, CPU |
| RAG | LangChain + ChromaDB | Ollama embeddings (nomic-embed-text) |
| K8s Client | kubernetes Python | Official, in-cluster auth |
| BLE | bleak | Async Python, Linux BlueZ |
| Vision | OpenCV + YOLOv8 | Edge inference on aipi (Hailo) |
| Orchestrator | FastAPI + asyncio | Single service, internal API |
| State | Redis | Gimbal position, voice session, agent queue |
| Notifications | python-telegram-bot + smtplib | Async Telegram, SMTP email |

## Phase 1 — Scaffold (this session)

✅ Project structure created
✅ Manifests templates in `k8s/`
✅ Python package stubs in `src/`
⏳ **Next:** Git init, push scaffold, create Obsidian note

## Phase 2 — Full Deploy (post-compact)

- [ ] GPU identification (`nvidia-smi` on core)
- [ ] Model selection based on VRAM
- [ ] NVIDIA device plugin + Ollama deployment
- [ ] Voice pipeline (systemd service initially)
- [ ] Vision capture + aipi edge service
- [ ] Gimbal BLE control (systemd service initially)
- [ ] K8s agent + approval gates
- [ ] RAG ingest pipeline
- [ ] Daily reports (Telegram + email)

## Project Map

```
phantom-ai/
├── README.md                       # You are here
├── CLAUDE.md                       # Session conventions
├── pyproject.toml                  # Python dependencies
├── .env.example                    # Config template
├── src/phantom_ai/                 # Main Python package
│   ├── config.py                   # Pydantic settings
│   ├── main.py                     # FastAPI app
│   ├── voice/                      # STT + TTS
│   ├── llm/                        # Ollama client
│   ├── rag/                        # ChromaDB + ingest
│   ├── vision/                     # OpenCV + edge client
│   ├── gimbal/                     # BLE controller
│   ├── agent/                      # K8s agent
│   ├── reports/                    # Daily report
│   └── api/                        # FastAPI routes
├── edge/src/aipi_vision/           # Code running on aipi
├── k8s/                            # Kubernetes manifests
│   ├── namespace.yaml
│   ├── ollama/                     # GPU Deployment + PVC
│   ├── orchestrator/               # FastAPI + RBAC
│   ├── redis/                      # State persistence
│   ├── edge-vision/                # aipi service
│   └── cronjobs/                   # Reports + RAG ingest
└── docs/                           # Reference docs
    ├── architecture.md
    ├── voice-setup.md
    ├── gimbal-protocol.md
    ├── k8s-agent-safety.md
    └── phase2-deploy.md
```

## Getting Started (Phase 2)

1. **Identify GPU**: `nvidia-smi --query-gpu=name,memory.total --format=csv`
2. **Select model** based on VRAM tier (see ARCHITECTURE.md)
3. **Install NVIDIA toolkit** on core: `nvidia-container-toolkit`
4. **Deploy Ollama**: `kubectl apply -k k8s/ollama/`
5. **Deploy orchestrator**: `kubectl apply -k k8s/orchestrator/`
6. See [phase2-deploy.md](docs/phase2-deploy.md) for full step-by-step.

## Secrets

All credentials live in Kubernetes Secrets or systemd environment files (never committed):
- `OLLAMA_BASE_URL` — Ollama service endpoint
- `TELEGRAM_BOT_TOKEN` — Telegram bot token (already configured)
- `TELEGRAM_CHAT_ID` — Your Telegram chat ID
- `SMTP_HOST`, `SMTP_PORT`, `SMTP_USER`, `SMTP_PASSWORD` — email credentials (already configured)

See SETUP.md for secret creation.

## References

- GitHub: [RealPhantomLee/phantom-ai](https://github.com/RealPhantomLee/phantom-ai)
- Homelab repo: [RealPhantomLee/homelab](https://github.com/RealPhantomLee/homelab) — ArgoCD pointer in `clusters/homelab/apps/phantom-ai.yaml`
- Obsidian vault: `02-Projects/phantom-ai.md` (on blacknode)

## License

Private project — see main homelab repo for license.
