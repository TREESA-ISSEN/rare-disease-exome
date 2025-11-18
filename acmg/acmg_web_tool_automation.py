from selenium import webdriver
from selenium.webdriver.common.by import By
from selenium.webdriver.chrome.service import Service
from selenium.common.exceptions import NoSuchElementException
import time
import os

# ---------------------
# 1️⃣ Configuration
# ---------------------
INPUT_FILE = "attributes.txt"  # text file with one line per variant, e.g. PM2,PP3
URL = "https://www.medschool.umaryland.edu/genetic_variant_interpretation_tool1.html/"

# Folder to save the CSV
DOWNLOAD_DIR = os.path.join(os.getcwd(), "downloads")
os.makedirs(DOWNLOAD_DIR, exist_ok=True)

# Map ACMG attributes to button IDs on the site
ATTRIBUTE_ID_MAP = {
    "PVS1": "pvs1",
    "PS1": "ps1",
    "PS2": "ps2",
    "PS3": "ps3",
    "PS4": "ps4",
    "PM1": "pm1",
    "PM2": "pm2",
    "PM3": "pm3",
    "PM4": "pm4",
    "PM5": "pm5",
    "PM6": "pm6",
    "PP1": "pp1",
    "PP2": "pp2",
    "PP3": "pp3",
    "PP4": "pp4",
    "PP5": "pp5",
    "BA1": "ba1",
    "BS1": "bs1",
    "BS2": "bs2",
    "BS3": "bs3",
    "BS4": "bs4",
    "BP1": "bp1",
    "BP2": "bp2",
    "BP3": "bp3",
    "BP4": "bp4",
    "BP5": "bp5",
    "BP6": "bp6",
    "BP7": "bp7",
}

# ---------------------
# 2️⃣ Helper Functions
# ---------------------
def safe_click(driver, element):
    """Scrolls element into view and clicks via JS to avoid interception issues."""
    driver.execute_script("arguments[0].scrollIntoView({block: 'center'});", element)
    time.sleep(0.2)
    driver.execute_script("arguments[0].click();", element)
    time.sleep(0.2)

def get_classification_text(driver):
    """Reads the current classification result from the page."""
    try:
        classification_elem = driver.find_element(By.ID, "classification")  # Adjust if needed
        return classification_elem.text.strip()
    except NoSuchElementException:
        return "(No classification text found)"

# ---------------------
# 3️⃣ Load Variants
# ---------------------
with open(INPUT_FILE, "r") as f:
    variants = [line.strip().split(",") for line in f if line.strip()]

# ---------------------
# 4️⃣ Setup WebDriver
# ---------------------
options = webdriver.ChromeOptions()
options.add_argument("--start-maximized")

# Set download folder
prefs = {"download.default_directory": DOWNLOAD_DIR}
options.add_experimental_option("prefs", prefs)

driver = webdriver.Chrome(service=Service(), options=options)
driver.get(URL)
time.sleep(2)

# ---------------------
# 5️⃣ Process Variants
# ---------------------
for idx, attributes in enumerate(variants, start=1):
    print(f"\n🔄 Processing variant {idx}/{len(variants)}: {attributes}")

    # Reset criteria after first variant
    if idx > 1:
        try:
            reset_button = driver.find_element(By.ID, "reset")
            safe_click(driver, reset_button)
            print("✅ Reset Criteria clicked.")
        except NoSuchElementException:
            print("⚠️ Could not find Reset Criteria button (continuing)")

    # Tick each attribute
    for attr in attributes:
        button_id = ATTRIBUTE_ID_MAP.get(attr)
        if not button_id:
            print(f"⚠️ Unknown attribute: {attr}, skipping.")
            continue
        try:
            btn = driver.find_element(By.ID, button_id)
            safe_click(driver, btn)
        except NoSuchElementException:
            print(f"⚠️ Could not click button for {attr} (id={button_id})")

    # Log classification before adding variant
    classification = get_classification_text(driver)
    print(f"📊 Classification result: {classification}")

    # Add to table
    try:
        add_button = driver.find_element(By.ID, "add_variant")
        safe_click(driver, add_button)
        print("✅ Variant added to table.")
    except NoSuchElementException:
        print("⚠️ Could not find Add Variant button")

# ---------------------
# 6️⃣ Trigger CSV download
# ---------------------
try:
    export_link = driver.find_element(By.ID, "export")
    driver.execute_script("arguments[0].scrollIntoView({block: 'center'});", export_link)
    driver.execute_script("arguments[0].click();", export_link)
    print(f"\n💾 CSV download triggered. It should be saved in: {DOWNLOAD_DIR}")
    time.sleep(5)  # wait to ensure download finishes
except NoSuchElementException:
    print("\n⚠️ Could not find CSV export link.")

# Close browser
driver.quit()
print("\n✅ Script completed.")
