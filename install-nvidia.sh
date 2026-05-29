#!/bin/bash
# Install NVIDIA drivers and container toolkit on Arch Linux (core node)
# Run this on core: bash /path/to/install-nvidia.sh

set -e

echo "=== NVIDIA Driver & Container Toolkit Installation ==="
echo "Running on: $(hostname)"
echo "User: $(whoami)"
echo ""

# Check if already installed
if command -v nvidia-smi &> /dev/null; then
    echo "✅ nvidia-smi already available"
    echo ""
    echo "Current GPU:"
    nvidia-smi --query-gpu=name,memory.total --format=csv,noheader
    exit 0
fi

echo "Installing NVIDIA drivers, utils, and container toolkit..."
echo ""

# Update system
echo "[1/4] Updating system packages..."
sudo pacman -Syu --noconfirm

# Install NVIDIA drivers and utils
echo "[2/4] Installing NVIDIA drivers and utilities..."
sudo pacman -S --noconfirm nvidia nvidia-utils

# Install container toolkit
echo "[3/4] Installing NVIDIA container toolkit..."
sudo pacman -S --noconfirm nvidia-container-toolkit

# Restart containerd
echo "[4/4] Restarting containerd to apply NVIDIA runtime..."
sudo systemctl restart containerd

echo ""
echo "✅ Installation complete!"
echo ""
echo "GPU Information:"
nvidia-smi --query-gpu=name,memory.total --format=csv,noheader
echo ""

# Get CUDA capability
echo "CUDA Capability:"
nvidia-smi --query-compute-cap --format=csv,noheader

echo ""
echo "✅ NVIDIA container toolkit ready"
echo "Verify with: kubectl run gpu-test --image=nvidia/cuda:12.4.1-runtime-ubuntu22.04 --limits='nvidia.com/gpu=1' --rm -it -- nvidia-smi"
