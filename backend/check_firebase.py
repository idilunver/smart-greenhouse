import firebase_admin
from firebase_admin import credentials, db
import os
from dotenv import load_dotenv

load_dotenv()

CERT_PATH = os.getenv("SERVICE_ACCOUNT_KEY_PATH", "serviceAccountKey.json")
FIREBASE_DB_URL = os.getenv("FIREBASE_DATABASE_URL")

if not firebase_admin._apps:
    cred = credentials.Certificate(CERT_PATH)
    firebase_admin.initialize_app(cred, {
        'databaseURL': FIREBASE_DB_URL
    })

ref = db.reference('Greenhouse/Sensors')
data = ref.get()
print(f"SENSORS DATA: {data}")

settings_ref = db.reference('Greenhouse/Settings')
settings_data = settings_ref.get()
print(f"SETTINGS DATA: {settings_data}")
