import pandas as pd
import torch
import numpy as np
from pytorch_model import DepressionModel
from fairlearn.metrics import MetricFrame, selection_rate
from sklearn.metrics import mean_absolute_error, accuracy_score
from sklearn.preprocessing import LabelEncoder

# Generate synthetic dataset with sensitive features
np.random.seed(42)
n_samples = 1000
screen_time = np.random.uniform(0.5, 10, n_samples)
true_score = 5 * screen_time + np.random.normal(0, 5, n_samples)
true_score = np.clip(true_score, 0, 100)

# Binary depression label: high score = depressed
true_label = (true_score > 50).astype(int)

# Sensitive features
gender = np.random.choice(['M', 'F'], n_samples)
age_group = np.random.choice(['young', 'adult', 'senior'], n_samples, p=[0.4, 0.4, 0.2])

data = pd.DataFrame({
    'screen_time': screen_time,
    'true_score': true_score,
    'true_label': true_label,
    'gender': gender,
    'age_group': age_group
})

# Save dataset
data.to_csv('dataset.csv', index=False)
print("Generated dataset.csv")

# Load trained model
model = DepressionModel()
model.load_state_dict(torch.load('pytorch_model.pt'))
model.eval()

# Predict
X = torch.tensor(data[['screen_time']].values, dtype=torch.float32)
with torch.no_grad():
    pred_score = model(X).numpy().flatten()
    pred_label = (pred_score > 50).astype(int)

data['pred_score'] = pred_score
data['pred_label'] = pred_label

# Fairness analysis by gender
mf_gender = MetricFrame(
    metrics={
        'selection_rate': selection_rate,
        'accuracy': accuracy_score
    },
    y_true=data['true_label'],
    y_pred=data['pred_label'],
    sensitive_features=data['gender']
)

print("\nFairness by Gender:")
print(mf_gender.by_group)
print(f"Overall disparity (selection rate): {mf_gender.difference()['selection_rate']:.4f}")

# By age group
mf_age = MetricFrame(
    metrics={
        'selection_rate': selection_rate,
        'accuracy': accuracy_score
    },
    y_true=data['true_label'],
    y_pred=data['pred_label'],
    sensitive_features=data['age_group']
)

print("\nFairness by Age Group:")
print(mf_age.by_group)
print(f"Overall disparity (selection rate): {mf_age.difference()['selection_rate']:.4f}")
