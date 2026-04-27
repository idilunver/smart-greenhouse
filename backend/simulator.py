import firebase_admin
from firebase_admin import credentials, db
import random
import time
import os
from dotenv import load_dotenv

# --- Load Environment Variables ---
load_dotenv()

# --- Firebase Connection ---
CERT_PATH = os.getenv("SERVICE_ACCOUNT_KEY_PATH", "serviceAccountKey.json")
FIREBASE_DB_URL = os.getenv("FIREBASE_DATABASE_URL")

if not firebase_admin._apps:
    abs_cert_path = os.path.abspath(CERT_PATH)
    if not os.path.exists(abs_cert_path):
        print(f"ERROR: {abs_cert_path} not found!")
        exit(1)

    cred = credentials.Certificate(abs_cert_path)
    firebase_admin.initialize_app(cred, {
        'databaseURL': FIREBASE_DB_URL
    })

# --- Digital Twin State ---
state = {
    "temp_inner": 24.5,
    "humidity_inner": 55.0,
    "soil_moisture": 45.0,
    "fan_on": False,
    "pump_on": False,
    "light_on": False
}

def on_control_change(event):
    """
    Listens for control commands arriving from Firebase.

    FIXED: No longer calls db.get() — reads directly from event.data.
    This eliminates an unnecessary network call and associated latency.
    """
    global state
    if event.data is None:
        return

    # On initial connection, the full Controls object arrives (path "/")
    if isinstance(event.data, dict):
        state["fan_on"] = bool(event.data.get('fan', False))
        state["pump_on"] = bool(event.data.get('pump', False))
        state["light_on"] = bool(event.data.get('light', False))
        print(f"[*] Controls loaded: Fan={state['fan_on']}, Pump={state['pump_on']}, Light={state['light_on']}")
        return

    # Subsequent updates deliver a specific path (e.g. "/fan")
    path = event.path.strip("/")
    value = bool(event.data) if event.data != 0 else False

    if path == "fan":
        state["fan_on"] = value
        print(f"[Stream] Fan {'ACTIVATED ✅' if value else 'DEACTIVATED 🔴'}")
    elif path == "pump":
        state["pump_on"] = value
        print(f"[Stream] Pump {'ACTIVATED ✅' if value else 'DEACTIVATED 🔴'}")
    elif path == "light":
        state["light_on"] = value
        print(f"[Stream] Light {'ACTIVATED ✅' if value else 'DEACTIVATED 🔴'}")

def update_physics():
    """Simulates real-world physical dynamics."""
    global state

    ambient_temp = 18.2  # Ambient (outdoor) temperature
    ambient_hum = 45.0   # Ambient (outdoor) humidity

    # ---------------------------------------------------------
    # NOTE: STOP RUNNING THIS FILE ONCE THE COMPANION SERVER
    # STARTS SENDING REAL DATA! Otherwise a data conflict will occur.
    # ---------------------------------------------------------

    # 1. Temperature Physics
    if state["fan_on"]:
        # When the fan is active, temperature drops more rapidly
        state["temp_inner"] -= random.uniform(0.1, 0.2)
    else:
        # When the fan is inactive, temperature gradually converges to ambient
        if state["temp_inner"] > ambient_temp:
            state["temp_inner"] -= random.uniform(0.01, 0.03)
        else:
            state["temp_inner"] += random.uniform(0.01, 0.05)

    # Internal self-heating factor (devices, solar gain)
    state["temp_inner"] += random.uniform(0.00, 0.02)

    # 2. Soil Moisture Physics
    if state["pump_on"]:
        state["soil_moisture"] += random.uniform(0.5, 1.2)  # Soil moisture increases when the pump is active
    else:
        state["soil_moisture"] -= random.uniform(0.02, 0.08)  # Natural evapotranspiration

    # 3. Humidity Physics
    if state["light_on"]:
        state["humidity_inner"] += random.uniform(0.5, 1.0)  # Misting system active
    elif state["fan_on"]:
        state["humidity_inner"] -= random.uniform(0.2, 0.5)  # Humidity decreases as the fan ventilates
    else:
        if state["humidity_inner"] > ambient_hum:
            state["humidity_inner"] -= random.uniform(0.02, 0.05)
        else:
            state["humidity_inner"] += random.uniform(0.02, 0.05)

    # Enforce Boundaries
    state["temp_inner"] = max(15.0, min(40.0, state["temp_inner"]))
    state["soil_moisture"] = max(5.0, min(95.0, state["soil_moisture"]))
    state["humidity_inner"] = max(20.0, min(95.0, state["humidity_inner"]))

def start_simulating():
    print(">>> Smart Simulator (Digital Twin) Active...")
    print(">>> Data transmission interval: 15 seconds (Quota Protection Mode)")
    sensors_ref = db.reference('Greenhouse/Sensors')

    # Begin listening to the Controls node
    # firebase-admin automatically reconnects on stream disconnection
    db.reference('Greenhouse/Controls').listen(on_control_change)

    try:
        while True:
            update_physics()

            data = {
                "temp_inner": round(state["temp_inner"], 1),
                "temp_outer": 18.2,
                "humidity_inner": round(state["humidity_inner"], 1),
                "humidity_outer": 45,
                "soil_moisture": round(state["soil_moisture"], 1),
                "light_lux": 500 + random.randint(-50, 50),
                "CO2": 600 + random.randint(-20, 20),
            }

            sensors_ref.update(data)
            print(
                f"[Digital Twin] "
                f"T={data['temp_inner']}°C | "
                f"Hum={data['humidity_inner']}% | "
                f"Soil={data['soil_moisture']}% | "
                f"Fan={'ON' if state['fan_on'] else 'off'} | "
                f"Pump={'ON' if state['pump_on'] else 'off'}"
            )

            # QUOTA MANAGEMENT: 15-second interval
            # ~1920 Firebase write operations per day instead of 5760
            time.sleep(15)

    except KeyboardInterrupt:
        print("\n>>> Simulator stopped.")

if __name__ == "__main__":
    start_simulating()