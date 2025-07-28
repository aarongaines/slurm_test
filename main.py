import torch
import torch.nn as nn
import torch.optim as optim

# Simple dataset: y = 2x + 1
X = torch.linspace(-1, 1, 100).unsqueeze(1)
y = 2 * X + 1 + 0.2 * torch.randn(X.size())

# Simple linear model
model = nn.Linear(1, 1)
criterion = nn.MSELoss()
optimizer = optim.SGD(model.parameters(), lr=0.1)

model.to(torch.device("cuda" if torch.cuda.is_available() else "cpu"))
X, y = X.to(model.weight.device), y.to(model.weight.device)

print("Starting training on device:", model.weight.device)

for epoch in range(10000):
    optimizer.zero_grad()
    outputs = model(X)
    loss = criterion(outputs, y)
    loss.backward()
    optimizer.step()
    if (epoch + 1) % 10 == 0:
        print(f"Epoch [{epoch+1}/100], Loss: {loss.item():.4f}")

print("Training complete.")
print("Learned parameters:", list(model.parameters()))
