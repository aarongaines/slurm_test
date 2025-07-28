#!/bin/bash
#SBATCH -J torch-test
#SBATCH -o slurm-%j.out
#SBATCH -p mlnodes           # your partition
#SBATCH --gres=gpu:1
#SBATCH --cpus-per-task=4
#SBATCH --mem=8G
#SBATCH -t 00:05:00

# Load modules if your cluster uses them
# module load cuda/12.2  anaconda/2024

python - <<'PY'
import torch, platform
print("Torch:", torch.__version__, " built with CUDA", torch.version.cuda)
print("is_available:", torch.cuda.is_available())
if torch.cuda.is_available():
    print("device 0:", torch.cuda.get_device_name(0))
    x = torch.randn(4096,4096,device='cuda')
    y = x @ x
    torch.cuda.synchronize()
    print("OK, kernel ran")
PY
