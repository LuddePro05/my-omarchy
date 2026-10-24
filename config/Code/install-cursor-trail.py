#!/usr/bin/env python3
"""
install-cursor-trail.py
Deploys the Catppuccin Mocha cursor trail into VS Code and recalculates
file checksums in product.json so integrity checks pass cleanly.
"""

import os
import shutil
import hashlib
import base64
import json
import sys

CODE_BASE = "/usr/share/code/resources/app"
WORKBENCH_DIR = os.path.join(CODE_BASE, "out/vs/code/electron-browser/workbench")
HTML_PATH = os.path.join(WORKBENCH_DIR, "workbench.html")
PRODUCT_PATH = os.path.join(CODE_BASE, "product.json")
SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))
TRAIL_SRC = os.path.join(SCRIPT_DIR, "cursor-trail.js")
TRAIL_DEST = os.path.join(WORKBENCH_DIR, "cursor-trail.js")

def main():
    if not os.path.exists(WORKBENCH_DIR):
        print(f"VS Code workbench directory not found: {WORKBENCH_DIR}")
        sys.exit(0)

    # 1. Copy cursor-trail.js
    print(f"Deploying cursor-trail.js to {TRAIL_DEST}...")
    shutil.copy2(TRAIL_SRC, TRAIL_DEST)

    # 2. Patch workbench.html if not already patched
    with open(HTML_PATH, "r", encoding="utf-8") as f:
        html = f.read()

    tag = '<script src="./cursor-trail.js" type="module"></script>'
    if tag not in html:
        print("Adding cursor-trail.js script tag to workbench.html...")
        target = '<script src="./workbench.js" type="module"></script>'
        if target in html:
            html = html.replace(target, f"{target}\n\t{tag}")
            with open(HTML_PATH, "w", encoding="utf-8") as f:
                f.write(html)
        else:
            print("Warning: workbench.js script tag not found in workbench.html")

    # 3. Recalculate checksum and update product.json
    if os.path.exists(PRODUCT_PATH):
        with open(HTML_PATH, "rb") as f:
            content = f.read().replace(b"\r\n", b"\n")
        checksum = base64.b64encode(hashlib.sha256(content).digest()).decode("utf-8").rstrip("=")

        with open(PRODUCT_PATH, "r", encoding="utf-8") as f:
            product = json.load(f)

        if "checksums" in product:
            rel_path = "vs/code/electron-browser/workbench/workbench.html"
            product["checksums"][rel_path] = checksum
            with open(PRODUCT_PATH, "w", encoding="utf-8") as f:
                json.dump(product, f, indent="\t")
            print(f"Updated product.json checksum ({checksum}) successfully!")

    print("VS Code cursor trail installation complete!")

if __name__ == "__main__":
    main()
