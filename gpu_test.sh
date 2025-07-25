#!/bin/bash
#SBATCH --job-name=gpu-check
#SBATCH --gres=gpu:1
#SBATCH --output=gpu_test_output.txt

nvidia-smi