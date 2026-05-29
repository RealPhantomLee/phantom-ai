# Phase 2: GPU Setup & Driver Installation

## Step 1: Install NVIDIA Drivers and Container Toolkit on Core

This must be done on the `core` node (100.93.114.9) before Ollama can access the GPU.

### SSH to Core

```bash
tailscale ssh 100.93.114.9
# or
ssh -i ~/.ssh/id_ed25519 user@100.93.114.9
```

### Identify GPU

```bash
nvidia-smi --query-gpu=name,memory.total --format=csv,noheader
```

Record the GPU model and VRAM. Use this to select the LLM model:

| VRAM | Recommended Model |
|------|-------------------|
| 4–6GB | llama3.2:3b or phi3:mini |
| 8GB | llama3.1:8b |
| 12–16GB | llama3.1:13b or deepseek-r1:8b-q8 |
| 24GB+ | llama3.3:70b-q4 or qwen2.5:32b |

### Install NVIDIA Container Toolkit (Arch Linux)

On Arch Linux on core:

```bash
sudo pacman -S nvidia-container-toolkit
```

Then restart containerd to pick up the NVIDIA runtime:

```bash
sudo systemctl restart containerd
```

Verify the runtime is available:

```bash
sudo ctr runtime ls | grep nvidia
```

### Test GPU Access in Container

Create a test pod:

```bash
kubectl run gpu-test --image=nvidia/cuda:12.4.1-runtime-ubuntu22.04 \
  --limits='nvidia.com/gpu=1' \
  --rm -it \
  -- nvidia-smi
```

If this succeeds, GPU is properly configured.

## Step 2: Verify Ollama Deployment

Once NVIDIA toolkit is installed, Ollama pod should transition from Pending to Running:

```bash
kubectl get pods -n phantom-ai -w
```

Watch until `ollama-*` pod shows `Running` and `1/1 Ready`.

## Step 3: Pull Initial LLM Model

Connect to Ollama and pull the model selected based on VRAM:

```bash
kubectl exec -it -n phantom-ai deployment/ollama -- \
  ollama pull llama3.1:8b
```

(Replace `llama3.1:8b` with your VRAM-appropriate model.)

This download may take 5-10 minutes depending on network. Monitor progress:

```bash
kubectl logs -f -n phantom-ai deployment/ollama
```

## Step 4: Update phantom-ai Config

Update `/home/roger/Projects/phantom-ai/.env` with your GPU model:

```bash
OLLAMA_MODEL=llama3.1:8b  # or your model
```

Then restart Ollama to use the new model:

```bash
kubectl rollout restart deployment/ollama -n phantom-ai
```

## Troubleshooting

### nvidia-smi: command not found

NVIDIA drivers not installed. Run `pacman -S nvidia nvidia-utils` on core.

### NVIDIA runtime not found

Container toolkit not installed or containerd not restarted. Run:

```bash
sudo pacman -S nvidia-container-toolkit
sudo systemctl restart containerd
```

### GPU memory errors in Ollama logs

Model is too large for VRAM. Select a smaller model or use quantization:

```bash
# Smaller model
ollama pull llama3.2:3b

# Quantized version
ollama pull deepseek-r1:8b-q8
```

### Ollama pod stuck in CrashLoopBackOff

Check logs:

```bash
kubectl logs -f -n phantom-ai deployment/ollama
```

Common causes:
- GPU not accessible (run `nvidia-smi` test above)
- Model corrupted (delete PVC and re-pull)
- Out of memory (reduce model size)

## Next Steps

Once Ollama is running with a model loaded:

1. Test the REST API: `kubectl port-forward -n phantom-ai svc/ollama 11434:11434`
2. Query the model: `curl http://localhost:11434/api/generate -d '{"model":"llama3.1:8b","prompt":"Hello"}'`
3. Proceed to voice pipeline setup (systemd services on core)
