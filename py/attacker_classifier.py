"""Attacker classifier (PI decision 2026-11-06, item 3, second step).

Trains a logistic regression on VIINA's 2025+ initiator labels (a_rus_init_b / a_ukr_init_b,
unambiguous cases only, strike-like reports) using:
  * character 2-5-grams of the lower-cased headline (captures 'зсу', 'окупант', 'ворог', ...)
  * territorial control of the reported place (from R/10_attacker.R) and the text-cue flag
Validation: train on 2025, test on 2026 (time split), so the score reflects use on unseen periods.
Then applies the model to every strike-like report (2022-2026).

NB: the VIINA labels are themselves BERT predictions (F1 0.82 RU / 0.76 UA), so "accuracy" here is
agreement with VIINA's model, not ground truth.

Run from repo root after R/10_attacker.R:  python3 py/attacker_classifier.py
Outputs: data/interim/viina_attacker_clf.parquet, output/attacker_classifier_validation.csv
"""
import pandas as pd, numpy as np
from sklearn.feature_extraction.text import TfidfVectorizer
from sklearn.linear_model import LogisticRegression
from sklearn.preprocessing import OneHotEncoder
from sklearn.compose import ColumnTransformer
from sklearn.pipeline import Pipeline
from sklearn.metrics import classification_report, accuracy_score

ev = pd.read_parquet("data/interim/viina_events.parquet", columns=["event_id", "date", "text"])
at = pd.read_parquet("data/interim/viina_attacker.parquet")
d = ev.merge(at, on="event_id")
d = d[d["strike_like"].fillna(False)].copy()
d["text"] = d["text"].fillna("").str.lower()
d["ctrl"] = d["ctrl_status"].fillna("none")
d["rule"] = d["attacker_rule"].fillna("none")
d["year"] = pd.to_datetime(d["date"]).dt.year

feats = ColumnTransformer([
    ("txt", TfidfVectorizer(analyzer="char_wb", ngram_range=(2, 5), min_df=3, max_features=300000, sublinear_tf=True), "text"),
    ("cat", OneHotEncoder(handle_unknown="ignore"), ["ctrl", "rule"]),
])
model = Pipeline([("f", feats), ("lr", LogisticRegression(max_iter=2000, C=4.0, class_weight="balanced"))])

lab = d[d["attacker_viina"].notna()]
train, test = lab[lab["year"] == 2025], lab[lab["year"] == 2026]
model.fit(train[["text", "ctrl", "rule"]], train["attacker_viina"])
pred = model.predict(test[["text", "ctrl", "rule"]])
rep = classification_report(test["attacker_viina"], pred, output_dict=True)
rule_acc = (test["attacker_rule"] == test["attacker_viina"]).mean()
rows = [{"metric": "classifier_accuracy_2026_holdout", "value": accuracy_score(test["attacker_viina"], pred), "n": len(test)},
        {"metric": "rule_accuracy_2026_holdout", "value": rule_acc, "n": len(test)}]
for k in ("RU", "UA"):
    rows += [{"metric": f"classifier_recall_{k}", "value": rep[k]["recall"], "n": rep[k]["support"]},
             {"metric": f"classifier_precision_{k}", "value": rep[k]["precision"], "n": rep[k]["support"]}]
    m = test["attacker_viina"] == k
    rows += [{"metric": f"rule_recall_{k}", "value": (test.loc[m, "attacker_rule"] == k).mean(), "n": int(m.sum())}]
val = pd.DataFrame(rows)
val.to_csv("output/attacker_classifier_validation.csv", index=False)
print(val.to_string(index=False))

# final model on all labelled data, applied to every strike-like report
model.fit(lab[["text", "ctrl", "rule"]], lab["attacker_viina"])
proba = model.predict_proba(d[["text", "ctrl", "rule"]])
cls = list(model.classes_)
d["p_ua"] = proba[:, cls.index("UA")]
d["attacker_clf"] = np.where(d["p_ua"] >= 0.5, "UA", "RU")
d[["event_id", "attacker_clf", "p_ua"]].to_parquet("data/interim/viina_attacker_clf.parquet", index=False)
print(d.groupby("year")["attacker_clf"].value_counts().unstack())
