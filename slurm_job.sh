#!/bin/bash
#SBATCH --job-name=pytorch_test
#SBATCH --output=slurm_output.txt
#SBATCH --error=slurm_error.txt

# Load modules if needed (uncomment and edit if using modules)
# module load python/3.13
# module load cuda/12.0

# Ensure uv is installed (uncomment if needed)
# pip install uv

# Sync the environment from pyproject.toml
uv venv .venv
uv sync

# Run the training script using uv
uv venv exec python main.py