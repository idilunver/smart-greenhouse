import json
import pandas as pd
import matplotlib.pyplot as plt
from sklearn.metrics import accuracy_score, f1_score
import os

# 1. Read JSON Data
# Ensure the file is located at 'backend/data/smart-greenhouse.json'
try:
    with open("data/smart-greenhouse.json") as f:
        data = json.load(f)
except FileNotFoundError:
    print("Error: JSON file not found!")
    exit()

# Access History according to the JSON structure
history = data["Greenhouse"]["History"] if "Greenhouse" in data else data.get("History", {})

# 2. Build DataFrame
rows = []
for key, val in history.items():
    row = {
        # Sensor Data
        "temp_inner": float(val.get("temp_inner", val.get("temp", 0))),
        "temp_outer": float(val.get("temp_outer", 0)),
        "soil": float(val.get("soil", 0)),
        "lux": float(val.get("lux", 0)),
        "co2": float(val.get("co2", 0)),

        # Decisions (fan, pump, light from Firebase — labelled as pred)
        "fan_pred": int(val.get("fan", 0)),
        "pump_pred": int(val.get("pump", 0)),
        "light_pred": int(val.get("light", 0))
    }
    rows.append(row)

df = pd.DataFrame(rows)
df = df.fillna(0)

# 3. Ideal Rules (Ground Truth — labelled as actual)
# Fan: if Temperature > 30 or CO2 > 900
df["fan_actual"] = df.apply(lambda r: 1 if (r["temp_inner"] > 30) or r["co2"] > 900 else 0, axis=1)
# Pump: if Soil Moisture < 25
df["pump_actual"] = df.apply(lambda x: 1 if x["soil"] < 25 else 0, axis=1)
# Light: if Lux < 300
df["light_actual"] = df.apply(lambda x: 1 if x["lux"] < 300 else 0, axis=1)

# 4. Performance Table and Metrics
metrics = []

def evaluate(name, actual, pred):
    acc = accuracy_score(actual, pred)
    # F1 Score requires at least one positive sample (class '1')
    f1 = f1_score(actual, pred) if len(actual.unique()) > 1 else 0
    metrics.append({"Unit": name, "Accuracy": acc, "F1_Score": f1})
    print(f"{name} -> Accuracy: {acc:.3f}, F1: {f1:.3f}")

print("\n--- SYSTEM PERFORMANCE ANALYSIS ---")
evaluate("FAN", df["fan_actual"], df["fan_pred"])
evaluate("PUMP", df["pump_actual"], df["pump_pred"])
evaluate("LIGHT", df["light_actual"], df["light_pred"])

# Save results as CSV (table for the thesis)
perf_df = pd.DataFrame(metrics)
perf_df.to_csv("../outputs/performans_sonuclari.csv", index=False)

# 5. Graph Plotting
def plot_graph(actual, pred, title, filename):
    # Calculate accuracy over time
    acc_list = [accuracy_score(actual[:i], pred[:i]) for i in range(2, len(actual) + 1)]
    plt.figure(figsize=(10, 5))
    plt.plot(acc_list, label="Accuracy", color='blue', linewidth=2)
    plt.title(f"{title} Decision Accuracy")
    plt.xlabel("Number of Data Points (Time)")
    plt.ylabel("Success Rate")
    plt.grid(True, linestyle='--')
    plt.legend()
    plt.savefig(os.path.join("..", "outputs", filename))
    plt.close()

plot_graph(df["fan_actual"], df["fan_pred"], "Fan (Ventilation)", "fan_accuracy.png")
plot_graph(df["pump_actual"], df["pump_pred"], "Pump (Irrigation)", "pump_accuracy.png")
plot_graph(df["light_actual"], df["light_pred"], "Light (Illumination)", "light_accuracy.png")

print("\nAnalysis complete! Table and graphs saved to the 'outputs' directory. ✅")