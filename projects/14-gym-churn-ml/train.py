"""Учебный ML-проект: прогнозирование оттока клиентов фитнес-клуба."""
from pathlib import Path
import json
import numpy as np
import pandas as pd
import matplotlib.pyplot as plt
import seaborn as sns
from sklearn.ensemble import RandomForestClassifier
from sklearn.linear_model import LogisticRegression
from sklearn.metrics import (classification_report, confusion_matrix, f1_score,
                             precision_score, recall_score, roc_auc_score, RocCurveDisplay)
from sklearn.model_selection import train_test_split
from sklearn.pipeline import Pipeline
from sklearn.preprocessing import StandardScaler

RANDOM_STATE = 42
OUT = Path("artifacts")
OUT.mkdir(exist_ok=True)

def make_dataset(n=4000, seed=RANDOM_STATE):
    rng = np.random.default_rng(seed)
    age = rng.integers(18, 66, n)
    contract_months = rng.choice([1, 3, 6, 12], n, p=[.32, .20, .18, .30])
    visits = np.clip(rng.normal(8.5, 4.0, n), 0, 25).round(1)
    days_since_visit = np.clip(rng.gamma(2.0, 7.0, n), 0, 90).round(1)
    auto_payment = rng.binomial(1, .62, n)
    support_tickets = rng.poisson(0.7, n)
    satisfaction = np.clip(rng.normal(7.2, 1.6, n), 1, 10).round(1)
    logit = (-1.0 - .32 * visits + .055 * days_since_visit
             - .25 * auto_payment + .16 * support_tickets
             - .28 * satisfaction - .10 * contract_months
             + .01 * np.maximum(age - 45, 0))
    probability = 1 / (1 + np.exp(-logit))
    churn = rng.binomial(1, probability)
    return pd.DataFrame({
        "age": age, "contract_months": contract_months, "monthly_visits": visits,
        "days_since_visit": days_since_visit, "auto_payment": auto_payment,
        "support_tickets": support_tickets, "satisfaction": satisfaction,
        "churn": churn
    })

def evaluate(name, model, X_test, y_test):
    proba = model.predict_proba(X_test)[:, 1]
    pred = (proba >= .35).astype(int)
    return {
        "model": name,
        "roc_auc": round(float(roc_auc_score(y_test, proba)), 4),
        "precision": round(float(precision_score(y_test, pred)), 4),
        "recall": round(float(recall_score(y_test, pred)), 4),
        "f1": round(float(f1_score(y_test, pred)), 4),
        "classification_report": classification_report(y_test, pred, output_dict=True)
    }, proba, pred

def main():
    df = make_dataset()
    X, y = df.drop(columns="churn"), df["churn"]
    X_train, X_test, y_train, y_test = train_test_split(
        X, y, test_size=.25, stratify=y, random_state=RANDOM_STATE
    )
    models = {
        "logistic_regression": Pipeline([
            ("scale", StandardScaler()),
            ("model", LogisticRegression(max_iter=1000, random_state=RANDOM_STATE))
        ]),
        "random_forest": RandomForestClassifier(
            n_estimators=300, min_samples_leaf=8, class_weight="balanced",
            random_state=RANDOM_STATE, n_jobs=-1
        )
    }
    results = []
    predictions = {}
    for name, model in models.items():
        model.fit(X_train, y_train)
        metrics, proba, pred = evaluate(name, model, X_test, y_test)
        results.append(metrics)
        predictions[name] = (proba, pred)
    (OUT / "metrics.json").write_text(json.dumps(results, indent=2), encoding="utf-8")

    fig, ax = plt.subplots(figsize=(7, 5))
    for name, (proba, _) in predictions.items():
        RocCurveDisplay.from_predictions(y_test, proba, name=name, ax=ax)
    ax.set_title("ROC-кривые моделей")
    fig.tight_layout()
    fig.savefig(OUT / "roc_curves.png", dpi=160)
    plt.close(fig)

    rf = models["random_forest"]
    importance = pd.Series(rf.feature_importances_, index=X.columns).sort_values()
    plt.figure(figsize=(8, 5))
    sns.barplot(x=importance.values, y=importance.index, color="#2563eb")
    plt.title("Важность признаков Random Forest")
    plt.xlabel("Важность")
    plt.tight_layout()
    plt.savefig(OUT / "feature_importance.png", dpi=160)
    plt.close()
    print(pd.DataFrame([{k: v for k, v in r.items() if k != "classification_report"} for r in results]).to_string(index=False))

if __name__ == "__main__":
    main()
