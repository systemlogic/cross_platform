"""Heart disease prediction using a PyTorch feedforward neural network.

Dataset: disease_prediction.csv (1000 rows)
  Train: first 950 rows
  Test:  last 50 rows

Usage:
  bazel run //examples/AI/heart_disease -- --device mps
  bazel run //examples/AI/heart_disease -- --device cpu --data /path/to/data.csv
"""

import argparse
import csv
import os
import torch
import torch.nn as nn
import torch.optim as optim


# ---------------------------------------------------------------------------
# Data loading & encoding
# ---------------------------------------------------------------------------

GENDER_MAP = {"Male": 1.0, "Female": 0.0}
BINARY_MAP = {"Yes": 1.0, "No": 0.0}
ACTIVITY_MAP = {"Low": 0.0, "Medium": 1.0, "High": 2.0}

FEATURE_COLS = [
    "age", "gender", "glucose_mg_dl", "cholesterol_mg_dl",
    "systolic_bp", "diastolic_bp", "bmi", "heart_rate",
    "smoking", "alcohol_consumption", "physical_activity", "family_history",
]


def encode_row(row: dict) -> tuple[list[float], float]:
    features = [
        float(row["age"]),
        GENDER_MAP[row["gender"]],
        float(row["glucose_mg_dl"]),
        float(row["cholesterol_mg_dl"]),
        float(row["systolic_bp"]),
        float(row["diastolic_bp"]),
        float(row["bmi"]),
        float(row["heart_rate"]),
        BINARY_MAP[row["smoking"]],
        BINARY_MAP[row["alcohol_consumption"]],
        ACTIVITY_MAP[row["physical_activity"]],
        BINARY_MAP[row["family_history"]],
    ]
    label = BINARY_MAP[row["disease"]]
    return features, label


def load_dataset(path: str) -> tuple[list, list]:
    with open(path, newline="") as f:
        rows = list(csv.DictReader(f))
    X, y = [], []
    for row in rows:
        feat, label = encode_row(row)
        X.append(feat)
        y.append(label)
    return X, y


def normalize(X_train: list, X_test: list) -> tuple[torch.Tensor, torch.Tensor]:
    train = torch.tensor(X_train, dtype=torch.float32)
    test = torch.tensor(X_test, dtype=torch.float32)
    mean = train.mean(dim=0)
    std = train.std(dim=0).clamp(min=1e-8)
    return (train - mean) / std, (test - mean) / std


# ---------------------------------------------------------------------------
# Model
# ---------------------------------------------------------------------------

class DiseaseNet(nn.Module):
    def __init__(self, in_features: int):
        super().__init__()
        self.net = nn.Sequential(
            nn.Linear(in_features, 64),
            nn.BatchNorm1d(64),
            nn.ReLU(),
            nn.Dropout(0.3),
            nn.Linear(64, 32),
            nn.BatchNorm1d(32),
            nn.ReLU(),
            nn.Dropout(0.2),
            nn.Linear(32, 1),
            nn.Sigmoid(),
        )

    def forward(self, x: torch.Tensor) -> torch.Tensor:
        return self.net(x).squeeze(1)


# ---------------------------------------------------------------------------
# Training
# ---------------------------------------------------------------------------

def train(
    model: nn.Module,
    X_train: torch.Tensor,
    y_train: torch.Tensor,
    epochs: int = 150,
    lr: float = 1e-3,
    batch_size: int = 64,
) -> None:
    optimizer = optim.Adam(model.parameters(), lr=lr, weight_decay=1e-4)
    scheduler = optim.lr_scheduler.StepLR(optimizer, step_size=50, gamma=0.5)
    criterion = nn.BCELoss()

    n = X_train.shape[0]
    model.train()
    for epoch in range(1, epochs + 1):
        perm = torch.randperm(n, device=X_train.device)
        X_shuf, y_shuf = X_train[perm], y_train[perm]
        epoch_loss = 0.0
        steps = 0
        for start in range(0, n, batch_size):
            xb = X_shuf[start:start + batch_size]
            yb = y_shuf[start:start + batch_size]
            optimizer.zero_grad()
            preds = model(xb)
            loss = criterion(preds, yb)
            loss.backward()
            optimizer.step()
            epoch_loss += loss.item()
            steps += 1
        scheduler.step()
        if epoch % 25 == 0 or epoch == 1:
            print(f"  Epoch {epoch:>3}/{epochs}  loss={epoch_loss/steps:.4f}")


# ---------------------------------------------------------------------------
# Evaluation
# ---------------------------------------------------------------------------

def evaluate(model: nn.Module, X: torch.Tensor, y: torch.Tensor, label: str) -> None:
    model.eval()
    with torch.no_grad():
        probs = model(X)
        preds = (probs >= 0.5).float()
        y_int = y.int()
        p_int = preds.int()

        tp = ((p_int == 1) & (y_int == 1)).sum().item()
        tn = ((p_int == 0) & (y_int == 0)).sum().item()
        fp = ((p_int == 1) & (y_int == 0)).sum().item()
        fn = ((p_int == 0) & (y_int == 1)).sum().item()

        accuracy  = (tp + tn) / (tp + tn + fp + fn)
        precision = tp / (tp + fp) if (tp + fp) > 0 else 0.0
        recall    = tp / (tp + fn) if (tp + fn) > 0 else 0.0
        f1        = (2 * precision * recall / (precision + recall)
                     if (precision + recall) > 0 else 0.0)

    print(f"\n{label} results ({int(y.shape[0])} samples):")
    print(f"  Accuracy : {accuracy:.4f}  ({int(tp+tn)}/{int(y.shape[0])} correct)")
    print(f"  Precision: {precision:.4f}")
    print(f"  Recall   : {recall:.4f}")
    print(f"  F1 Score : {f1:.4f}")
    print(f"  Confusion matrix — TP:{tp}  TN:{tn}  FP:{fp}  FN:{fn}")


# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------

TRAIN_SIZE = 950
SEED = 42

_DEFAULT_DATA = os.path.join(os.path.dirname(__file__), "disease_prediction.csv")


def _parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Heart disease prediction")
    parser.add_argument(
        "--data",
        default=_DEFAULT_DATA,
        help="Path to disease_prediction.csv (default: file bundled in runfiles)",
    )
    parser.add_argument(
        "--device",
        choices=["cpu", "mps", "cuda"],
        default="cpu",
        help="Compute device to use (default: cpu)",
    )
    return parser.parse_args()


def _resolve_device(name: str) -> torch.device:
    if name == "mps":
        if not torch.backends.mps.is_available():
            raise SystemExit("Error: MPS is not available on this machine.")
        return torch.device("mps")
    if name == "cuda":
        if not torch.cuda.is_available():
            raise SystemExit("Error: CUDA is not available on this machine.")
        return torch.device("cuda")
    return torch.device("cpu")


def main() -> None:
    args = _parse_args()
    torch.manual_seed(SEED)

    device = _resolve_device(args.device)
    print(f"Using device: {device}")

    print("Loading data from:", args.data)
    X, y = load_dataset(args.data)
    print(f"Total samples: {len(X)}  |  Train: {TRAIN_SIZE}  |  Test: {len(X)-TRAIN_SIZE}")

    X_train_raw, y_train_raw = X[:TRAIN_SIZE], y[:TRAIN_SIZE]
    X_test_raw,  y_test_raw  = X[TRAIN_SIZE:], y[TRAIN_SIZE:]

    X_train, X_test = normalize(X_train_raw, X_test_raw)
    y_train = torch.tensor(y_train_raw, dtype=torch.float32)
    y_test  = torch.tensor(y_test_raw,  dtype=torch.float32)

    X_train = X_train.to(device)
    X_test  = X_test.to(device)
    y_train = y_train.to(device)
    y_test  = y_test.to(device)

    pos = y_train.sum().item()
    print(f"Train class balance — disease: {int(pos)} ({pos/TRAIN_SIZE*100:.1f}%)  "
          f"no disease: {int(TRAIN_SIZE-pos)} ({(1-pos/TRAIN_SIZE)*100:.1f}%)")

    model = DiseaseNet(in_features=X_train.shape[1]).to(device)
    print(f"\nModel: {sum(p.numel() for p in model.parameters())} parameters")

    print("\nTraining …")
    train(model, X_train, y_train)

    evaluate(model, X_train, y_train, "Train set")
    evaluate(model, X_test,  y_test,  "Test set ")

    print("\nDone.")


if __name__ == "__main__":
    main()
