import ctypes
import torch
import os
import sys

try:
    ctypes.CDLL("libcuda.so")
    print("✓ libcuda loaded")
except OSError as e:
    print("✗ libcuda load failed:", e); sys.exit(1)

print("Torch:", torch.__version__, "CUDA:", torch.version.cuda)
print("is_available:", torch.cuda.is_available())
if torch.cuda.is_available():
    print("device:", torch.cuda.get_device_name(0))