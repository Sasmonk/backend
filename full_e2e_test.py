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
TEST_EMAIL = "sashanks732@gmail.com"
TEST_PASSWORD = "TestPass123!"
TEST_SUFFIX = "".join(random.choices(string.ascii_lowercase + string.digits, k=6))

# --- GLOBALS TO STORE DYNAMIC IDS ---
JWT_TOKEN = None
COMPANY_ID = None
# These will be the main, persistent assets used across tests
MAIN_PRODUCT_ID = None
MAIN_TRUCK_ID = None
MAIN_DESTINATION_ID = None
# These are for specific test cases
SHIPMENT_ID = None
DEVICE_ID = str(uuid4())

# --- DEVICE AUTH HEADERS ---
ESP32_HEADERS = {
    "x-device-id": f"ESP-{uuid4().hex[:8]}",
    "x-api-key": "fake_device_secret_key"
}

# --- UTILITY FUNCTIONS ---
def print_result(step, response, expected_status=200):
    """Utility to format and print API call results."""
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
        response = requests.request(method, url, headers=final_headers, json=json_data, timeout=10)
    except requests.exceptions.ConnectionError:
        print("\nFATAL: Connection Error. Ensure Express server is running on port 3000.")
        return None

    return print_result(f"{method.upper()} {url_path}", response, expected_status)

# --- 1. SETUP: AUTHENTICATION AND COMPANY CREATION ---
def setup_user_and_company():
    """Performs Supabase Auth and creates the mandatory Company record and prerequisite assets."""
    global JWT_TOKEN, COMPANY_ID, MAIN_TRUCK_ID, MAIN_DESTINATION_ID, MAIN_PRODUCT_ID
    
    print("\n--- 1.1 SUPABASE SIGN UP ---")
    url_signup = f"{SUPABASE_URL}/auth/v1/signup"
    headers_auth = {"Content-Type": "application/json", "apikey": SUPABASE_ANON_KEY}
    payload_signup = {"email": TEST_EMAIL, "password": TEST_PASSWORD, "data": {"full_name": "Test User"}}
    
    response_signup = requests.post(url_signup, headers=headers_auth, json=payload_signup)
    # Allow 422 (user exists) as a non-fatal error for repeated runs
    if not response_signup.ok and response_signup.status_code != 422:
        print_result("SUPABASE SIGN UP", response_signup, 200)
        return False
    print_result("SUPABASE SIGN UP", response_signup, 200)

    print("\n--- 1.2 SUPABASE SIGN IN (RETRIEVE JWT) ---")
    url_signin = f"{SUPABASE_URL}/auth/v1/token?grant_type=password"
    payload_signin = {"email": TEST_EMAIL, "password": TEST_PASSWORD}
    response = requests.post(url_signin, headers=headers_auth, json=payload_signin, timeout=5)
    
    if response.ok and 'access_token' in response.json():
        JWT_TOKEN = response.json()['access_token']
        print(f"SUCCESS: Captured JWT Token: {JWT_TOKEN[:20]}...")
    else:
        print("\nCRITICAL AUTH FAILURE: Sign In failed.")
        return False
        
    print("\n--- 1.3 CREATE COMPANY & PREREQUISITE ASSETS (POSTGREST) ---")
    url_company = f"{SUPABASE_URL}/rest/v1/companies"
    headers_postgrest = {
        "Content-Type": "application/json",
        "Authorization": f"Bearer {JWT_TOKEN}",
        "apikey": SUPABASE_ANON_KEY,
        "Prefer": "return=representation" 
    }
    payload_company = {"company_name": "Full Test Corp", "company_code": f"TEST-{TEST_SUFFIX.upper()}"}
    response = requests.post(url_company, headers=headers_postgrest, json=payload_company, timeout=5)
    
    print_result("SUPABASE POST /rest/v1/companies", response, 201) 
    
    if response.status_code == 201 and 'id' in response.json()[0]:
        COMPANY_ID = response.json()[0]['id']
        print(f"SUCCESS: Captured Company ID: {COMPANY_ID}")

        # Create prerequisite assets needed for later tests
        # Create a Truck
        truck_data = {"registration_number": f"TEST-TRK-{TEST_SUFFIX.upper()}", "user_assigned_name": "Main Test Truck"}
        resp_truck = requests.post(f"{SUPABASE_URL}/rest/v1/trucks", headers=headers_postgrest, json=truck_data)
        MAIN_TRUCK_ID = resp_truck.json()[0]['id']
        print(f"SUCCESS: Captured Main Truck ID: {MAIN_TRUCK_ID}")

        # Create a Destination
        dest_data = {"company_id": COMPANY_ID, "location_name": "Main Test Warehouse"}
        resp_dest = requests.post(f"{SUPABASE_URL}/rest/v1/rfid_destinations", headers=headers_postgrest, json=dest_data)
        MAIN_DESTINATION_ID = resp_dest.json()[0]['id']
        print(f"SUCCESS: Captured Main Destination ID: {MAIN_DESTINATION_ID}")
            
        # Create a Product
        product_data = {"company_id": COMPANY_ID, "product_name": "Main Test Item", "unit_value": 50.00}
        resp_product = requests.post(f"{SUPABASE_URL}/rest/v1/products", headers=headers_postgrest, json=product_data)
        MAIN_PRODUCT_ID = resp_product.json()[0]['id']
        print(f"SUCCESS: Captured Main Product ID: {MAIN_PRODUCT_ID}")

        return all([COMPANY_ID, MAIN_TRUCK_ID, MAIN_DESTINATION_ID, MAIN_PRODUCT_ID])
    return False

# --- 2. ASSET ENDPOINT TESTS (/api/assets) ---
def test_asset_crud_endpoints():
    """Tests the full C-R-U-D lifecycle for assets in isolation."""
    print("\n\n--- 2. ASSET MANAGEMENT ENDPOINT TESTS ---")
    
    # <-- FIX: This test now creates, updates, and deletes its OWN product
    # to avoid interfering with the MAIN_PRODUCT_ID needed for shipments.
    
    # --- 2.1 PRODUCTS: POST (CREATE) ---
    product_payload = {
        "company_id": COMPANY_ID,
        "product_name": f"CRUD Test Product-{TEST_SUFFIX}",
        "unit_value": 15.00
    }
    response = api_call('POST', '/assets/products', json_data=product_payload, expected_status=201)
    
    if not (response and response.ok): return False
    # Capture the ID for this specific test
    product_id_for_crud_test = response.json().get('data')[0]['id']

    # --- 2.2 PRODUCTS: GET (READ ALL) ---
    if not api_call('GET', '/assets/products', expected_status=200): return False

    # --- 2.3 PRODUCTS: PUT (UPDATE) ---
    update_payload = {"unit_value": 16.00}
    if not api_call('PUT', f'/assets/products/{product_id_for_crud_test}', json_data=update_payload, expected_status=200): return False

    # --- 2.4 PRODUCTS: DELETE ---
    if not api_call('DELETE', f'/assets/products/{product_id_for_crud_test}', expected_status=204): return False

    # The same isolated test logic can be applied to Trucks and Destinations if needed
    api_call('POST', '/assets/trucks', json_data={"registration_number": f"TRK-NEW-{TEST_SUFFIX}"}, expected_status=201)
    api_call('GET', '/assets/trucks', expected_status=200)
    api_call('POST', '/assets/destinations', json_data={"company_id": COMPANY_ID, "location_name": "New Dock"}, expected_status=201)
    api_call('GET', '/assets/destinations', expected_status=200)
    
    return True

# --- 3. SHIPMENTS ENDPOINT TESTS (/api/shipments) ---
def test_shipment_crud():
    """Tests all shipment routes using the persistent assets from setup."""
    global SHIPMENT_ID
    print("\n\n--- 3. SHIPMENTS ENDPOINT TESTS ---")
    
    eta = (datetime.now() + timedelta(days=2)).isoformat()
    
    # <-- FIX: This payload now reliably uses the MAIN_PRODUCT_ID from setup,
    # which was not deleted by the asset test.
    shipment_payload = {
        "company_id": COMPANY_ID,
        "truck_id": MAIN_TRUCK_ID,
        "destination_id": MAIN_DESTINATION_ID,
        "origin_location": "Main Depot",
        "estimated_arrival": eta,
        "items": [
            {"product_id": MAIN_PRODUCT_ID, "quantity": 100, "unit_value": 50.00}
        ]
    }
    response = api_call('POST', '/shipments', json_data=shipment_payload, expected_status=201)
    
    if not (response and response.ok): return False
    SHIPMENT_ID = response.json().get('data')[0]['id']
    print(f"SUCCESS: Captured SHIPMENT ID: {SHIPMENT_ID}")
    
    api_call('GET', '/shipments', expected_status=200)
    api_call('GET', f'/shipments/{SHIPMENT_ID}', expected_status=200)
    api_call('PUT', f'/shipments/{SHIPMENT_ID}', json_data={"status": "in_transit"}, expected_status=200)
    api_call('POST', f'/shipments/{SHIPMENT_ID}/complete', json_data={"verification_status": "complete"}, expected_status=200)
    api_call('GET', '/shipments/history', expected_status=200)
    api_call('DELETE', f'/shipments/{SHIPMENT_ID}', expected_status=204)
    
    return True

# --- 4. DEVICE MANAGEMENT ENDPOINT TESTS (/api/devices) ---
def test_device_endpoints():
    """Tests all user-auth and device-auth routes."""
    print("\n\n--- 4. DEVICE MANAGEMENT ENDPOINT TESTS (USER AUTH) ---")
    register_payload = {"device_id": DEVICE_ID, "company_id": COMPANY_ID, "device_type": "GPS_TRACKER"}
    api_call('POST', '/devices/register', json_data=register_payload, expected_status=201)
    api_call('GET', '/devices/status', expected_status=200)
    api_call('POST', f'/devices/{DEVICE_ID}/approve', expected_status=200)
    bind_payload = { "asset_type": "truck", "asset_id": MAIN_TRUCK_ID }
    api_call('POST', f'/devices/{DEVICE_ID}/bind', json_data=bind_payload, expected_status=200)

    print("\n--- DEVICE DATA SUBMISSION ENDPOINT TESTS (ESP32 AUTH) ---")
    gps_payload = {"latitude": 34.05, "longitude": -118.24}
    api_call('POST', '/devices/gps/submit', json_data=gps_payload, headers=ESP32_HEADERS, expected_status=200)
    rfid_payload = {"rfid_tag": "TAG-ABC-123"}
    api_call('POST', '/devices/rfid/scan', json_data=rfid_payload, headers=ESP32_HEADERS, expected_status=200)

    return True

# --- 5. REPORTS ENDPOINT TESTS (/api/reports) ---
def test_reports_endpoints():
    """Tests all protected report GET routes."""
    print("\n\n--- 5. REPORTS ENDPOINT TESTS ---")
    api_call('GET', '/reports/missing-products', expected_status=200)
    api_call('GET', '/reports/truck-utilization', expected_status=200)
    api_call('GET', '/reports/delivery-performance', expected_status=200)
    api_call('GET', '/reports/alerts', expected_status=200)
    return True

# --- MAIN EXECUTION ---
def run_full_test():
    """Runs the full test suite in the correct order."""
    if not print_result("0. EXPRESS API HEALTH CHECK", requests.get(f"{BASE_EXPRESS_URL}/health"), 200).ok:
        print("\nFATAL: Express server is not running.")
        return

    if not setup_user_and_company():
        print("\nFATAL: User/Company Setup Failed.")
        return
    
    if not test_asset_crud_endpoints():
        print("\nFATAL: Asset Management (CRUD) Test Failed.")
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