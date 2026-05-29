# GPU Setup — Manual Steps for Core Node

**Status:** Cannot SSH from this environment. These steps must be run manually on core.

## Quick Start

Copy and paste these commands into a terminal on **core** (100.93.114.9):

```bash
# SSH from blacknode (if needed)
tailscale ssh roger@core
# or
ssh user@100.93.114.9

# Download and run installation script
curl -fsSL https://raw.githubusercontent.com/RealPhantomLee/phantom-ai/main/install-nvidia.sh | bash
```

Or manually:

```bash
# Update system
sudo pacman -Syu --noconfirm

# Install NVIDIA drivers, utils, and container toolkit
sudo pacman -S --noconfirm nvidia nvidia-utils nvidia-container-toolkit

# Restart containerd
sudo systemctl restart containerd

# Verify installation
nvidia-smi --query-gpu=name,memory.total --format=csv,noheader
```

## Detailed Steps

### Step 1: SSH to Core

From **blacknode** (your control plane machine):

```bash
# Option A: Tailscale SSH
tailscale ssh 100.93.114.9

# Option B: Standard SSH
ssh user@100.93.114.9
```

### Step 2: Install NVIDIA Drivers

```bash
# Update system packages first
sudo pacman -Syu --noconfirm

# Install NVIDIA drivers and utilities
sudo pacman -S --noconfirm nvidia nvidia-utils

# Install NVIDIA container toolkit (critical for K8s)
sudo pacman -S --noconfirm nvidia-container-toolkit
```

### Step 3: Restart Container Runtime

```bash
# Restart containerd to register NVIDIA runtime
sudo systemctl restart containerd

# Verify NVIDIA runtime is available
sudo ctr runtime ls | grep nvidia
```

Expected output:
```
io.containerd.runc.v2          runc      io.containerd.runc.execute
io.containerd.nvidia           runc      io.containerd.nvidia.run
```

### Step 4: Identify Your GPU

```bash
# Get GPU model and VRAM
nvidia-smi --query-gpu=name,memory.total --format=csv,noheader

# Example output:
# NVIDIA GeForce RTX 3060,12288 MiB
```

### Step 5: Determine LLM Model

Based on VRAM from above:

| VRAM | Recommended Model | Command |
|------|-------------------|---------|
| 4–6GB | llama3.2:3b | `ollama pull llama3.2:3b` |
| 8GB | llama3.1:8b | `ollama pull llama3.1:8b` |
| 12–16GB | llama3.1:13b | `ollama pull llama3.1:13b` |
| 24GB+ | llama3.3:70b-q4 | `ollama pull llama3.3:70b-q4` |

### Step 6: Verify GPU Access in Kubernetes

From **blacknode**:

```bash
# Test GPU in container
kubectl run gpu-test \
  --image=nvidia/cuda:12.4.1-runtime-ubuntu22.04 \
  --limits='nvidia.com/gpu=1' \
  --nodeSelector=kubernetes.io/hostname=core \
  --rm -it \
  -- nvidia-smi
```

If successful, you should see GPU info. Ollama pod will automatically transition to `Running`.

### Step 7: Pull LLM Model

Once Ollama pod is Running:

```bash
# Port-forward to Ollama service
kubectl port-forward -n phantom-ai svc/ollama 11434:11434 &

# Pull your model (replace with VRAM-appropriate model)
sleep 2
curl http://localhost:11434/api/pull -d '{"name":"llama3.1:8b"}'

# Watch pull progress
kubectl logs -f -n phantom-ai deployment/ollama
```

### Step 8: Update phantom-ai Config

Update `.env` with your model choice:

```bash
cat > /home/roger/Projects/phantom-ai/.env <<EOF
OLLAMA_BASE_URL=http://ollama.phantom-ai.svc:11434
OLLAMA_MODEL=llama3.1:8b  # Update this line based on your GPU VRAM
EOF
```

## Troubleshooting

### `nvidia-smi: command not found`
NVIDIA drivers not installed. Re-run step 2.

### `permission denied` with `sudo`
Check that your user account has sudo access. May need to add to `sudoers`:
```bash
sudo usermod -aG wheel $USER
```

### `systemctl restart containerd` fails
Check containerd status:
```bash
sudo systemctl status containerd
sudo journalctl -xe | grep containerd
```

### Ollama pod still Pending after GPU install
Restart the Ollama deployment to force it to see GPU resources:

```bash
kubectl rollout restart deployment/ollama -n phantom-ai
kubectl get pods -n phantom-ai -w  # watch for Running
```

### Out of Memory errors in Ollama
Your model is too large for VRAM. Select a smaller model or quantized version:

```bash
kubectl exec -it -n phantom-ai deployment/ollama -- \
  ollama pull llama3.2:3b  # smaller model
```

## After GPU Setup Complete

Once Ollama is Running with a model loaded:

1. Verify Ollama service:
   ```bash
   kubectl port-forward -n phantom-ai svc/ollama 11434:11434
   curl http://localhost:11434/api/tags
   ```

2. Set up voice pipeline (systemd service on core)

3. Set up gimbal control (systemd service on core)

See `docs/phase2-gpu-setup.md` for full Phase 2 workflow.
