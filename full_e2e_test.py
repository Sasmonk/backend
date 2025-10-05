import requests
import json
import random
import string
from uuid import uuid4
from datetime import datetime, timedelta

# --- CONFIGURATION ---
BASE_EXPRESS_URL = "http://localhost:3000/api"
SUPABASE_URL = "https://wwnpjzipreoalpwgerik.supabase.co"
SUPABASE_ANON_KEY = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Ind3bnBqemlwcmVvYWxwd2dlcmlrIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NTk1NTY5MDQsImV4cCI6MjA3NTEzMjkwNH0.TIqsXfHoccWikQhbYFvsyrycWAGsrrylBsv0COeAihU"

# --- DYNAMIC TEST DATA ---
# Use a new random email each time to ensure a clean user signup and avoid conflicts
TEST_EMAIL = f"sashanks732+{uuid4().hex[:6]}@gmail.com"
TEST_PASSWORD = "TestPass123!"
TEST_SUFFIX = "".join(random.choices(string.ascii_lowercase + string.digits, k=6))

# --- GLOBALS TO STORE DYNAMIC IDS ---
JWT_TOKEN = None
COMPANY_ID = None
MAIN_PRODUCT_ID = None
MAIN_TRUCK_ID = None
MAIN_DESTINATION_ID = None
SHIPMENT_ID = None
# This is the primary key (UUID) for the esp_devices table. We generate it once.
DEVICE_ID = str(uuid4())

# --- UTILITY FUNCTIONS ---
def print_result(step, response, expected_status=200):
    """Utility to format and print API call results."""
    if response is None:
        print("-" * 50)
        print(f"STEP: {step}")
        print("Status: FAILED (No response from server)")
        return None

    status_text = f"{response.status_code} "
    status_text += "(SUCCESS)" if response.status_code == expected_status else "(FAILED)"
    
    print("-" * 50)
    print(f"STEP: {step}")
    print(f"Status: {status_text} (Expected: {expected_status})")
    try:
        data = response.json()
        if len(response.text) > 250:
            print(f"Response: {response.text[:250]}... (Truncated)")
        else:
            print(f"Response: {json.dumps(data, indent=2)}")
    except json.JSONDecodeError:
        print(f"Response (Text): {response.text[:250]}...")
    
    return response

def api_call(method, url_path, json_data=None, expected_status=200, headers=None):
    """Generic function to handle authenticated Express API calls."""
    final_headers = {"Content-Type": "application/json"}
    if JWT_TOKEN:
        final_headers["Authorization"] = f"Bearer {JWT_TOKEN}"
    if headers:
        final_headers.update(headers)
        
    url = f"{BASE_EXPRESS_URL}{url_path}"
    
    try:
        response = requests.request(method, url, headers=final_headers, json=json_data, timeout=15)
    except requests.exceptions.RequestException as e:
        print(f"\nFATAL: API call failed for {method} {url_path}. Error: {e}")
        return None

    return print_result(f"{method.upper()} {url_path}", response, expected_status)

# --- TEST SUITE ---

def setup_user_and_company():
    """Performs Supabase Auth, creates a Company, and prerequisite assets."""
    global JWT_TOKEN, COMPANY_ID, MAIN_TRUCK_ID, MAIN_DESTINATION_ID, MAIN_PRODUCT_ID
    
    print("\n--- 1.1 SUPABASE SIGN UP ---")
    url_signup = f"{SUPABASE_URL}/auth/v1/signup"
    headers_auth = {"Content-Type": "application/json", "apikey": SUPABASE_ANON_KEY}
    payload_signup = {"email": TEST_EMAIL, "password": TEST_PASSWORD, "data": {"full_name": "Test User"}}
    
    response_signup = requests.post(url_signup, headers=headers_auth, json=payload_signup)
    print_result("SUPABASE SIGN UP", response_signup, 200)
    if not response_signup.ok: return False

    print("\n--- 1.2 SUPABASE SIGN IN (RETRIEVE JWT) ---")
    url_signin = f"{SUPABASE_URL}/auth/v1/token?grant_type=password"
    payload_signin = {"email": TEST_EMAIL, "password": TEST_PASSWORD}
    response = requests.post(url_signin, headers=headers_auth, json=payload_signin)
    
    if response.ok and 'access_token' in response.json():
        JWT_TOKEN = response.json()['access_token']
        print(f"SUCCESS: Captured JWT Token: {JWT_TOKEN[:20]}...")
    else:
        print_result("SUPABASE SIGN IN", response, 200)
        return False
        
    print("\n--- 1.3 CREATE COMPANY & PREREQUISITE ASSETS ---")
    headers_postgrest = {
        "Content-Type": "application/json", "Authorization": f"Bearer {JWT_TOKEN}",
        "apikey": SUPABASE_ANON_KEY, "Prefer": "return=representation" 
    }
    
    payload_company = {"company_name": "Full Test Corp", "company_code": f"TEST-{TEST_SUFFIX.upper()}"}
    resp_company = requests.post(f"{SUPABASE_URL}/rest/v1/companies", headers=headers_postgrest, json=payload_company)
    print_result("SUPABASE POST /rest/v1/companies", resp_company, 201)
    if not resp_company.ok: return False
    COMPANY_ID = resp_company.json()[0]['id']
    print(f"SUCCESS: Captured Company ID: {COMPANY_ID}")

    truck_data = {"registration_number": f"TEST-TRK-{TEST_SUFFIX.upper()}", "user_assigned_name": "Main Test Truck"}
    resp_truck = requests.post(f"{SUPABASE_URL}/rest/v1/trucks", headers=headers_postgrest, json=truck_data)
    MAIN_TRUCK_ID = resp_truck.json()[0]['id']
    print(f"SUCCESS: Captured Main Truck ID: {MAIN_TRUCK_ID}")

    dest_data = {"company_id": COMPANY_ID, "location_name": "Main Test Warehouse"}
    resp_dest = requests.post(f"{SUPABASE_URL}/rest/v1/rfid_destinations", headers=headers_postgrest, json=dest_data)
    MAIN_DESTINATION_ID = resp_dest.json()[0]['id']
    print(f"SUCCESS: Captured Main Destination ID: {MAIN_DESTINATION_ID}")
        
    product_data = {"company_id": COMPANY_ID, "product_name": "Main Test Item", "unit_value": 50.00}
    resp_product = requests.post(f"{SUPABASE_URL}/rest/v1/products", headers=headers_postgrest, json=product_data)
    MAIN_PRODUCT_ID = resp_product.json()[0]['id']
    print(f"SUCCESS: Captured Main Product ID: {MAIN_PRODUCT_ID}")

    return True

def test_asset_crud_endpoints():
    """Tests the C-R-U-D lifecycle for assets."""
    print("\n\n--- 2. ASSET MANAGEMENT ENDPOINT TESTS ---")
    
    product_payload = {"company_id": COMPANY_ID, "product_name": f"CRUD-Test-{TEST_SUFFIX}", "unit_value": 15.00}
    response = api_call('POST', '/assets/products', json_data=product_payload, expected_status=201)
    if not (response and response.ok): return False
    crud_product_id = response.json().get('data')[0]['id']

    if not api_call('GET', '/assets/products', expected_status=200): return False
    if not api_call('PUT', f'/assets/products/{crud_product_id}', json_data={"unit_value": 16.00}, expected_status=200): return False
    if not api_call('DELETE', f'/assets/products/{crud_product_id}', expected_status=204): return False
    
    return True

def test_shipment_crud():
    """Tests all shipment workflow routes."""
    global SHIPMENT_ID
    print("\n\n--- 3. SHIPMENTS ENDPOINT TESTS ---")
    
    eta = (datetime.now() + timedelta(days=2)).isoformat()
    shipment_payload = {
        "company_id": COMPANY_ID, "truck_id": MAIN_TRUCK_ID, "destination_id": MAIN_DESTINATION_ID,
        "origin_location": "Main Depot", "estimated_arrival": eta,
        "items": [{"product_id": MAIN_PRODUCT_ID, "quantity": 100, "unit_value": 50.00}]
    }
    response = api_call('POST', '/shipments', json_data=shipment_payload, expected_status=201)
    if not (response and response.ok): return False
    SHIPMENT_ID = response.json().get('data')[0]['id']
    print(f"SUCCESS: Captured SHIPMENT ID: {SHIPMENT_ID}")
    
    if not api_call('GET', '/shipments', expected_status=200): return False
    if not api_call('GET', f'/shipments/{SHIPMENT_ID}', expected_status=200): return False
    if not api_call('PUT', f'/shipments/{SHIPMENT_ID}', json_data={"status": "in_transit"}, expected_status=200): return False
    if not api_call('POST', f'/shipments/{SHIPMENT_ID}/complete', expected_status=200): return False
    if not api_call('GET', '/shipments/history', expected_status=200): return False
    
    response = api_call('POST', '/shipments', json_data=shipment_payload, expected_status=201)
    if not (response and response.ok): return False
    shipment_to_delete_id = response.json().get('data')[0]['id']
    if not api_call('DELETE', f'/shipments/{shipment_to_delete_id}', expected_status=204): return False
    
    return True

def test_device_endpoints():
    """Tests all user-auth and device-auth routes."""
    # This function no longer uses the global DEVICE_ID. It will capture the real one.
    
    # These will be captured from the server's response
    actual_device_primary_key = None
    esp_device_id_for_headers = None
    api_key_for_headers = None

    print("\n\n--- 4. DEVICE MANAGEMENT ENDPOINT TESTS (USER AUTH) ---")

    # We still send a UUID, but we won't assume the server uses it.
    register_payload = {
        "device_id": str(uuid4()), 
        "company_id": COMPANY_ID,
        "device_name": "Test GPS Tracker", 
        "device_type": "gps_tracker"
    }
    response = api_call('POST', '/devices/register', json_data=register_payload, expected_status=201)
    
    if not (response and response.ok): return False

    try:
        response_data = response.json()
        # **THE FIX**: Capture the REAL primary key returned by the server.
        actual_device_primary_key = response_data.get('device_id')
        esp_device_id_for_headers = response_data.get('esp_device_id')
        api_key_for_headers = response_data.get('api_key')
        
        if not actual_device_primary_key:
            print("ERROR: 'device_id' (primary key) was not found in the registration response.")
            return False

        print(f"SUCCESS: Captured Device Primary Key: {actual_device_primary_key}")
        print(f"SUCCESS: Captured ESP Device ID for headers: {esp_device_id_for_headers}")

    except (AttributeError, KeyError, json.JSONDecodeError):
        print("WARNING: Could not parse critical IDs from registration response.")
        return False

    if not api_call('GET', '/devices/status', expected_status=200): return False

    # **THE FIX**: Use the captured 'actual_device_primary_key' in the URL.
    approve_response = api_call('POST', f'/devices/{actual_device_primary_key}/approve', expected_status=200)
    if not (approve_response and approve_response.json().get('success')): return False

    bind_payload = {"bound_to_type": "truck", "bound_to_id": MAIN_TRUCK_ID}
    # **THE FIX**: Use the captured 'actual_device_primary_key' here as well.
    bind_response = api_call('POST', f'/devices/{actual_device_primary_key}/bind', json_data=bind_payload, expected_status=200)
    if not (bind_response and bind_response.json().get('success')): return False

    print("\n--- DEVICE DATA SUBMISSION ENDPOINT TESTS (ESP32 AUTH) ---")
    
    if not all([esp_device_id_for_headers, api_key_for_headers]):
        print("FATAL: Missing ESP Device ID or API Key for device-auth tests.")
        return False

    correct_esp32_headers = {
        "x-device-id": esp_device_id_for_headers,
        "x-api-key": api_key_for_headers
    }

    gps_payload = {"latitude": 34.05, "longitude": -118.24}
    if not api_call('POST', '/devices/gps/submit', json_data=gps_payload, headers=correct_esp32_headers, expected_status=200): return False
    
    rfid_payload = {"rfid_tag": "TAG-ABC-123"}
    if not api_call('POST', '/devices/rfid/scan', json_data=rfid_payload, headers=correct_esp32_headers, expected_status=200): return False

    return True

def test_reports_endpoints():
    """Tests all protected report GET routes."""
    print("\n\n--- 5. REPORTS ENDPOINT TESTS ---")
    if not api_call('GET', '/reports/missing-products', expected_status=200): return False
    if not api_call('GET', '/reports/truck-utilization', expected_status=200): return False
    if not api_call('GET', '/reports/delivery-performance', expected_status=200): return False
    if not api_call('GET', '/reports/alerts', expected_status=200): return False
    return True

# --- MAIN EXECUTION ---
def run_full_test():
    """Runs the full test suite in the correct order."""
    if not api_call('GET', '/health', expected_status=200):
        print("\nFATAL: Express server is not running.")
        return

    if not setup_user_and_company():
        print("\nFATAL: Initial user and company setup failed.")
        return
    
    if not test_asset_crud_endpoints():
        print("\nFATAL: Asset Management Test Failed.")
        return

    if not test_shipment_crud():
        print("\nFATAL: Shipment Workflow Test Failed.")
        return

    if not test_device_endpoints():
        print("\nFATAL: Device Endpoints Test Failed.")
        return

    if not test_reports_endpoints():
        print("\nFATAL: Reports Endpoint Test Failed.")
        return
    
    print("\n\n" + "#" * 55)
    print("✅ ALL ENDPOINTS TESTED SUCCESSFULLY. DEPLOYMENT READY! ✅")
    print("#" * 55)

if __name__ == "__main__":
    run_full_test()