import firebase_admin
from firebase_admin import credentials, db
import time
import math
import os
import google.generativeai as genai
from dotenv import load_dotenv

# --- Load Environment Variables ---
load_dotenv()

# --- Configuration (From Environment Variables) ---
CERT_PATH = os.getenv("SERVICE_ACCOUNT_KEY_PATH", "serviceAccountKey.json")
GEMINI_API_KEY = os.getenv("GEMINI_API_KEY")
FIREBASE_DB_URL = os.getenv("FIREBASE_DATABASE_URL")

# --- QUOTA MANAGEMENT: Time Thresholds ---
AI_COOLDOWN = 300           # Normal: at most ~12 Gemini requests per hour
CRITICAL_AI_COOLDOWN = 60   # Critical: at most ~60 Gemini requests per hour
HISTORY_INTERVAL = 600      # Record history every 10 minutes
PROCESSING_INTERVAL = 30    # Process backend at most every 30 seconds

last_ai_time = 0
last_history_time = 0
last_processing_time = 0
last_known_temp = None       # For delta-based triggering
cached_settings = {}         # For caching settings data

# Gemini Setup - Quota-friendly model
genai.configure(api_key=GEMINI_API_KEY)
model = genai.GenerativeModel('gemini-flash-lite-latest')

def initialize_firebase():
    if not firebase_admin._apps:
        abs_cert_path = os.path.abspath(CERT_PATH)
        if not os.path.exists(abs_cert_path):
            print(f"ERROR: {abs_cert_path} not found! Please verify the Service Account JSON file.")
            return False

        cred = credentials.Certificate(abs_cert_path)
        firebase_admin.initialize_app(cred, {
            'databaseURL': FIREBASE_DB_URL
        })
    print(">>> AI-Powered Greenhouse Backend System (Cloud Mode) Active...")
    return True

def calculate_vpd(temp, humidity):
    """Calculates VPD (Vapour Pressure Deficit)."""
    svp = 0.61078 * math.exp((17.27 * temp) / (temp + 237.3))
    avp = svp * (humidity / 100)
    return round(svp - avp, 2)

def get_gemini_advice(temp, hum, soil, vpd, et_rate, plants):
    """Sends current data and historical trends to Gemini."""
    clean_plants = [p.split(" ")[0] for p in plants] if plants else ["genel bitkiler"]
    plants_text = ", ".join(clean_plants)

    # Fetch history for trend analysis
    trend_text = "Stable"
    try:
        history = db.reference('Greenhouse/History').order_by_child('timestamp').limit_to_last(10).get()
        if history and len(history) >= 2:
            items = list(history.values())
            temp_diff = items[-1]['temp'] - items[0]['temp']
            if temp_diff > 1: trend_text = "Rising trend (Warming)"
            elif temp_diff < -1: trend_text = "Declining trend (Cooling)"
            else: trend_text = "Maintaining stability"
    except: pass

    prompt = f"""
    You are the living intelligence and digital guardian of this smart greenhouse. You possess the knowledge
    of an agricultural expert and the warmth of a nature enthusiast. Speak like an assistant who loves plants
    and understands their needs.

    Currently cultivated plants: {plants_text}
    Data: Temperature {temp}°C (Trend: {trend_text}), Humidity {hum}%, Soil Moisture {soil}%, VPD: {vpd} kPa.

    Critical Rules and Instructions:
    1. Sensor Error Detection: If any sensor reading is 0, abnormally low, or unreasonably high (e.g. Temperature 0 or 99, Humidity 0), issue this warning directly: "I have detected an error in the sensor connections, please check the wiring."
    2. Plant-Specific Approach: Consider the general characteristics of the '{plants_text}' plant (e.g. lettuce prefers cool conditions, tomatoes prefer light and warmth). Tailor your interpretation precisely to that plant.
    3. Do not use personal names. Begin with a warm, informal greeting (e.g. "Hello", "Hi there").
    4. Introduce technical data naturally, but select only the 1 or 2 most critical values for the current condition — do not enumerate all of them.
    5. UI Design Rule: STRICTLY limit the response to AT MOST 2 SHORT SENTENCES. Do not over-elaborate under any circumstances.
    """
    try:
        response = model.generate_content(prompt)
        return response.text.strip()
    except Exception as e:
        print(f"Gemini Error (get_gemini_advice): {e}")
        if "429" in str(e):
            return "Daily AI quota exhausted. Data continues to be monitored normally."
        return "Data is being analysed, please monitor the trend."

# --- Plant Library & Ideal Values ---
PLANT_RULES = {
    "Domates": {"temp": (18, 28), "hum": (60, 80), "soil": (40, 60)},
    "Biber": {"temp": (20, 30), "hum": (50, 70), "soil": (30, 50)},
    "Marul": {"temp": (15, 22), "hum": (70, 90), "soil": (50, 70)},
    "Salatalık": {"temp": (22, 30), "hum": (70, 90), "soil": (40, 60)},
    "genel bitkiler": {"temp": (20, 30), "hum": (50, 80), "soil": (30, 60)}
}

sensor_state = {
    'temp_inner': 25.0,
    'humidity_inner': 50.0,
    'soil_moisture': 40.0,
    'light_lux': 0.0,
    'CO2': 0.0
}

def handle_sensor_change(event):
    global last_ai_time, last_history_time, last_processing_time, last_known_temp, sensor_state

    print(f"[*] Trigger received from Firebase! Path: {event.path}, Data: {event.data}", flush=True)

    if event.data is None:
        return

    # If Data is a dict, all values have arrived / been updated
    if isinstance(event.data, dict):
        for key, value in event.data.items():
            if key in sensor_state:
                sensor_state[key] = float(value)
    # If Data is not a dict, a specific path has arrived (e.g. /temp_inner)
    else:
        path_key = event.path.strip("/")
        if path_key in sensor_state:
            sensor_state[path_key] = float(event.data)

    # Use current values
    temp = sensor_state['temp_inner']
    hum = sensor_state['humidity_inner']
    soil = sensor_state['soil_moisture']

    # --- DATA VALIDATION & SAFE MODE (FAIL-SAFE) ---
    if temp < 0 or temp > 60 or hum < 0 or hum > 100 or soil < 0 or soil > 100:
        print(f"[!!!] CRITICAL ERROR: Anomalous data detected (Temp: {temp}, Hum: {hum}, Soil: {soil}). Switching to safe mode...")
        try:
            db.reference('Greenhouse/System_Status').update({'error_log': 'SENSOR_ERROR'})
            # Emergency shutdown of fan, pump, and light (0 or False can be sent)
            db.reference('Greenhouse/Controls').update({'fan': 0, 'pump': 0, 'light': 0})
        except Exception as e:
            pass
        return  # Terminate function to avoid processing erroneous data
    else:
        # Clear error flag when sensor readings return to normal
        try:
            db.reference('Greenhouse/System_Status').update({
                'error_log': 'No errors',
                'is_online': True,
                'last_ping': time.strftime('%d-%m-%Y %H:%M')
            })
        except:
            pass



    # ─────────────────────────────────────────────────────
    # QUOTA MANAGEMENT - LAYER 2: Processing Throttle
    # Critical conditions are always processed. Normal conditions wait 30 s.
    # ─────────────────────────────────────────────────────
    is_critical = (temp > 32 or soil < 20 or hum < 40)
    current_time = time.time()

    if not is_critical and (current_time - last_processing_time < PROCESSING_INTERVAL):
        # Not critical and 30-second interval not elapsed — skip this trigger
        return

    last_processing_time = current_time
    print(f"\n--- Processing Data ({time.strftime('%H:%M:%S')}) ---")

    # Fetch Current Settings (From Cache)
    global cached_settings
    selected_plants = cached_settings.get('plants', [])
    auto_mode = cached_settings.get('auto_mode', False)

    # Mathematical Calculations
    vpd = calculate_vpd(temp, hum)
    et_rate = round(vpd * 0.4, 2)

    actions = {}
    # Intelligent Automation (The Brain)
    if auto_mode:
        plant_name = "genel bitkiler"
        if selected_plants and isinstance(selected_plants, list) and len(selected_plants) > 0:
            first_plant = str(selected_plants[0])
            plant_name = first_plant.split(" ")[0]

        target_rule = PLANT_RULES.get(plant_name, PLANT_RULES["genel bitkiler"])
        controls_ref = db.reference('Greenhouse/Controls')

        # Temperature Control (Fan)
        if temp > target_rule["temp"][1]: actions['fan'] = True
        elif temp < target_rule["temp"][0] + 2: actions['fan'] = False

        # Soil Moisture (Pump)
        if soil < target_rule["soil"][0]: actions['pump'] = True
        elif soil > target_rule["soil"][1]: actions['pump'] = False

        # Humidity Control (Light/Misting)
        if hum < target_rule["hum"][0]: actions['light'] = True

        if actions:
            controls_ref.update(actions)
            for act, val in actions.items():
                log_msg = f"{act} {'ACTIVATED' if val else 'DEACTIVATED'} for {selected_plants[0] if selected_plants else 'System'}"
                print(f"[AUTOMATION] {log_msg}")
                try:
                    db.reference('Greenhouse/Logs').push({
                        'msg': log_msg,
                        'timestamp': int(time.time()),
                        'type': act
                    })
                except: pass

    # ─────────────────────────────────────────────────────
    # QUOTA MANAGEMENT - LAYER 3: AI Call Control via Delta + Cooldown
    # ─────────────────────────────────────────────────────
    MIN_TEMP_DELTA = 1.5  # AI is not triggered for changes below this threshold
    temp_changed_enough = (
        last_known_temp is None or
        abs(temp - last_known_temp) >= MIN_TEMP_DELTA
    )
    last_known_temp = temp

    time_since_last_ai = current_time - last_ai_time
    should_call_ai = False

    if is_critical:
        if time_since_last_ai > CRITICAL_AI_COOLDOWN:
            should_call_ai = True
            print("[!] CRITICAL CONDITION: Requesting emergency AI advisory...")
    else:
        if time_since_last_ai > AI_COOLDOWN and temp_changed_enough:
            should_call_ai = True
            print("[*] Retrieving periodic AI advisory...")

    ai_advice = None
    if should_call_ai:
        ai_advice = get_gemini_advice(temp, hum, soil, vpd, et_rate, selected_plants)
        last_ai_time = current_time

    # Historical Data Recording (Every 10 Minutes)
    if current_time - last_history_time > HISTORY_INTERVAL:
        try:
            db.reference('Greenhouse/History').push({
                'temp': temp,
                'hum': hum,
                'soil': soil,
                'lux': sensor_state.get('light_lux', 0.0),
                'co2': sensor_state.get('CO2', 0.0),
                'ai_advice': ai_advice,
                'ai_decision': "Irrigate" if actions.get('pump') else "Standby",
                'timestamp': int(current_time)
            })
            last_history_time = current_time
            print("[*] Historical data saved to Firebase (AI-assisted).")
        except Exception as e:
            print(f"History Error: {e}")

    # Write to Firebase (Analysis)
    try:
        analysis_ref = db.reference('Greenhouse/AI_Analysis')
        update_data = {
            'et_rate': float(et_rate),
            'vpd_val': float(vpd),
            'last_sync': time.strftime('%H:%M:%S')
        }
        if ai_advice:
            update_data['advice'] = ai_advice

        analysis_ref.update(update_data)
        if ai_advice:
            print(f"[*] AI Advisory: {ai_advice}")
        print(f"[*] VPD={vpd} kPa, ET={et_rate} mm/h | Temperature={temp}°C, Humidity={hum}%, Soil={soil}%")
    except Exception as e:
        print(f"Error: {e}")


def on_settings_change(event):
    """Updates the cache when settings are changed."""
    global cached_settings
    if event.data is not None and isinstance(event.data, dict):
        cached_settings = event.data
    elif event.data is not None and isinstance(event.data, bool) or isinstance(event.data, str):
         # When a specific value is updated
         path = event.path.strip("/")
         if path:
             cached_settings[path] = event.data

def start_with_reconnect():
    """
    Establishes the stream connection and automatically reconnects on disconnection.
    This function keeps the backend running indefinitely.
    """
    sensors_ref = db.reference('Greenhouse/Sensors')
    settings_ref = db.reference('Greenhouse/Settings')
    retry_delay = 5  # Initial wait duration

    while True:
        try:
            print(f">>> Establishing stream connection... (Greenhouse/Sensors & Settings)")
            sensor_listener = sensors_ref.listen(handle_sensor_change)
            settings_listener = settings_ref.listen(on_settings_change)
            print(">>> Stream active. Awaiting data...")

            # Keep waiting while the stream is active
            while True:
                time.sleep(1)

        except KeyboardInterrupt:
            print("\n>>> Stopped.")
            if 'sensor_listener' in locals():
                sensor_listener.close()
            if 'settings_listener' in locals():
                settings_listener.close()
            break
        except Exception as e:
            print(f"[!] Stream error: {e}")
            print(f"[!] Reconnecting in {retry_delay} seconds...")
            time.sleep(retry_delay)
            retry_delay = min(retry_delay * 2, 60)  # Exponential backoff, max 60s


if __name__ == "__main__":
    if initialize_firebase():
        start_with_reconnect()