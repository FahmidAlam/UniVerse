import os
import subprocess
import time

CHROME_PATH = r"C:\Program Files\Google\Chrome\Application\chrome.exe"
BASE_URL = "http://localhost:8085/#/preview/scheduling"
OUTPUT_DIR = r"D:\flutter projects\universe_v1\docs\screenshots\phase_2b"

os.makedirs(OUTPUT_DIR, exist_ok=True)

targets = [
    # Desktop 1440x900 - All 5 tabs + Docked Inspector
    ("desktop_1440_distribution.png", 1440, 900, f"{BASE_URL}?tab=distribution"),
    ("desktop_1440_inspector_open.png", 1440, 900, f"{BASE_URL}?tab=distribution&row=6"),
    ("desktop_1440_configuration.png", 1440, 900, f"{BASE_URL}?tab=configuration"),
    ("desktop_1440_readiness.png", 1440, 900, f"{BASE_URL}?tab=readiness"),
    ("desktop_1440_generate.png", 1440, 900, f"{BASE_URL}?tab=generate"),
    ("desktop_1440_review.png", 1440, 900, f"{BASE_URL}?tab=review"),

    # Laptop 1280x800
    ("laptop_1280_distribution.png", 1280, 800, f"{BASE_URL}?tab=distribution"),

    # Tablet 1024x768
    ("tablet_1024_distribution.png", 1024, 768, f"{BASE_URL}?tab=distribution"),

    # Mobile 390x844
    ("mobile_390_distribution.png", 390, 844, f"{BASE_URL}?tab=distribution"),
    ("mobile_390_inspector_sheet.png", 390, 844, f"{BASE_URL}?tab=distribution&row=6"),
    ("mobile_390_configuration.png", 390, 844, f"{BASE_URL}?tab=configuration"),
    ("mobile_390_readiness.png", 390, 844, f"{BASE_URL}?tab=readiness"),
]

def capture():
    print(f"Starting screenshot capture to {OUTPUT_DIR}...")
    for filename, width, height, url in targets:
        out_path = os.path.join(OUTPUT_DIR, filename)
        args = [
            CHROME_PATH,
            "--headless=new",
            f"--window-size={width},{height}",
            "--virtual-time-budget=7000",
            f"--screenshot={out_path}",
            url,
        ]
        print(f"Capturing {filename} ({width}x{height}) from {url}...")
        res = subprocess.run(args, capture_output=True, text=True)
        if os.path.exists(out_path):
            size = os.path.getsize(out_path)
            print(f"  -> OK: {filename} ({size} bytes)")
        else:
            print(f"  -> FAILED: {filename}. stderr: {res.stderr}")

if __name__ == "__main__":
    capture()
