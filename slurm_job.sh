#!/bin/bash
#SBATCH --job-name=gpu_diag
#SBATCH --gres=gpu:1
#SBATCH --cpus-per-task=2
#SBATCH --time=05:00
#SBATCH -o slurm-%j.out

export LD_LIBRARY_PATH=/usr/lib/x86_64-linux-gnu:$LD_LIBRARY_PATH

echo "USER  : $USER"
echo "GROUPS: $(id -Gn)"
echo "CUDA_VISIBLE_DEVICES=$CUDA_VISIBLE_DEVICES"
ls -l /dev/nvidia*

# Sync the environment from pyproject.toml
uv venv .venv
uv sync

# Run the training script using uv
uv run main.py