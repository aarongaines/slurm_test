import torch
# Check if PyTorch is installed and CUDA is available
print("Torch:", torch.__version__, " built with CUDA", torch.version.cuda if hasattr(torch, "version") and hasattr(torch.version, "cuda") else "N/A")
print("is_available:", torch.cuda.is_available())
if torch.cuda.is_available():
    print("device 0:", torch.cuda.get_device_name(0))
    x = torch.randn(4096,4096,device='cuda')
    y = x @ x
    torch.cuda.synchronize()
    print("OK, kernel ran")