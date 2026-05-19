import pandas as pd
import torch
import torch.nn as nn
import torch.optim as optim
from pytorch_model import DepressionModel
import numpy as np
import os

# Generate larger synthetic dataset
np.random.seed(42)
n_samples = 1000
screen_time = np.random.uniform(0.5, 10, n_samples)
score = 5 * screen_time + np.random.normal(0, 5, n_samples)  # Linear relation
score = np.clip(score, 0, 100)

data = {
    "screen_time": screen_time,
    "score": score
}
df = pd.DataFrame(data)

# Prepare tensors
X = torch.tensor(df[["screen_time"]].values, dtype=torch.float32)
y = torch.tensor(df["score"].values, dtype=torch.float32).unsqueeze(1)

# Model, loss, optimizer
model = DepressionModel()
criterion = nn.MSELoss()
optimizer = optim.Adam(model.parameters(), lr=0.01)

# Train
model.train()
for epoch in range(200):
    optimizer.zero_grad()
    outputs = model(X)
    loss = criterion(outputs, y)
    loss.backward()
    optimizer.step()

# Save
torch.save(model.state_dict(), "pytorch_model.pt")
print(f"Model trained and saved. Final loss: {loss.item():.4f}")
