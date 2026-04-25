import json
import pandas as pd
import matplotlib.pyplot as plt
from sklearn.metrics import accuracy_score, f1_score
import os

# 1. JSON Verisini Oku
# Dosyanın 'backend/data/smart-greenhouse.json' yolunda olduğundan emin ol
try:
    with open("data/smart-greenhouse.json") as f:
        data = json.load(f)
except FileNotFoundError:
    print("Hata: JSON dosyası bulunamadı!")
    exit()

# JSON yapısına göre History'ye erişim
history = data["Greenhouse"]["History"] if "Greenhouse" in data else data.get("History", {})

# 2. DataFrame Oluşturma
rows = []
for key, val in history.items():
    row = {
        # Sensör Verileri
        "temp_inner": float(val.get("temp_inner", val.get("temp", 0))),
        "temp_outer": float(val.get("temp_outer", 0)),
        "soil": float(val.get("soil", 0)),
        "lux": float(val.get("lux", 0)),
        "co2": float(val.get("co2", 0)),
        
        # Kararlar (Firebase'den gelen fan, pump, light -> pred olarak adlandırıyoruz)
        "fan_pred": int(val.get("fan", 0)),
        "pump_pred": int(val.get("pump", 0)),
        "light_pred": int(val.get("light", 0))
    }
    rows.append(row)

df = pd.DataFrame(rows)
df = df.fillna(0)

# 3. İdeal Kurallar (Ground Truth -> actual olarak adlandırıyoruz)
# Fan: Sıcaklık > 30 veya CO2 > 900 ise
df["fan_actual"] = df.apply(lambda r: 1 if (r["temp_inner"] > 30) or r["co2"] > 900 else 0, axis=1)
# Pompa: Toprak nemi < 25 ise
df["pump_actual"] = df.apply(lambda x: 1 if x["soil"] < 25 else 0, axis=1)
# Işık: Lux < 300 ise
df["light_actual"] = df.apply(lambda x: 1 if x["lux"] < 300 else 0, axis=1)

# 4. Performans Tablosu ve Metrikler
metrics = []

def evaluate(name, actual, pred):
    acc = accuracy_score(actual, pred)
    # F1 Score için en az bir tane '1' (pozitif örnek) olması gerekir
    f1 = f1_score(actual, pred) if len(actual.unique()) > 1 else 0
    metrics.append({"Birim": name, "Accuracy": acc, "F1_Score": f1})
    print(f"{name} -> Accuracy: {acc:.3f}, F1: {f1:.3f}")

print("\n--- SİSTEM PERFORMANS ANALİZİ ---")
evaluate("FAN", df["fan_actual"], df["fan_pred"])
evaluate("PUMP", df["pump_actual"], df["pump_pred"])
evaluate("LIGHT", df["light_actual"], df["light_pred"])

# Sonuçları CSV olarak kaydet (Tezin için tablo)
perf_df = pd.DataFrame(metrics)
perf_df.to_csv("../outputs/performans_sonuclari.csv", index=False)

# 5. Grafik Çizimi
def plot_graph(actual, pred, title, filename):
    # Zamanla değişen doğruluğu hesapla
    acc_list = [accuracy_score(actual[:i], pred[:i]) for i in range(2, len(actual) + 1)]
    plt.figure(figsize=(10, 5))
    plt.plot(acc_list, label="Accuracy", color='blue', linewidth=2)
    plt.title(f"{title} Karar Doğruluğu")
    plt.xlabel("Veri Sayısı (Zaman)")
    plt.ylabel("Başarı Oranı")
    plt.grid(True, linestyle='--')
    plt.legend()
    plt.savefig(os.path.join("..", "outputs", filename))
    plt.close()

plot_graph(df["fan_actual"], df["fan_pred"], "Fan (Havalandırma)", "fan_accuracy.png")
plot_graph(df["pump_actual"], df["pump_pred"], "Pompa (Sulama)", "pump_accuracy.png")
plot_graph(df["light_actual"], df["light_pred"], "Işık (Aydınlatma)", "light_accuracy.png")

print("\nAnaliz tamamlandı! Tablo ve grafikler 'outputs' klasörüne kaydedildi. ✅")