#!/usr/bin/env python3
"""
Generate multi-resolution Windows ICO and PNG icon files from the master high-res source icon.
Produces:
  - desktop/build/icon.ico (contains 16x16, 24x24, 32x32, 48x48, 64x64, 128x128, 256x256)
  - desktop/build/icon.png (512x512)
  - desktop/src/assets/logo.png (256x256)
"""

import os
import sys
from PIL import Image

def generate_icons():
    repo_root = os.path.abspath(os.path.join(os.path.dirname(__file__), '..', '..'))
    source_icon = os.path.join(repo_root, 'Assets', 'AppIcon-1024.png')
    
    if not os.path.exists(source_icon):
        source_icon = os.path.join(repo_root, 'Assets', 'AppIcon-512.png')
    if not os.path.exists(source_icon):
        print(f"Error: Master icon not found at {source_icon}", file=sys.stderr)
        sys.exit(1)

    build_dir = os.path.join(repo_root, 'desktop', 'build')
    assets_dir = os.path.join(repo_root, 'desktop', 'src', 'assets')
    os.makedirs(build_dir, exist_ok=True)
    os.makedirs(assets_dir, exist_ok=True)

    print(f"Loading master icon: {source_icon}")
    img = Image.open(source_icon).convert("RGBA")

    # 1. Multi-resolution .ico for Windows
    ico_sizes = [(16, 16), (24, 24), (32, 32), (48, 48), (64, 64), (128, 128), (256, 256)]
    ico_path = os.path.join(build_dir, 'icon.ico')
    img.save(ico_path, format='ICO', sizes=ico_sizes)
    print(f"Generated Windows multi-res ICO: {ico_path} ({os.path.getsize(ico_path)} bytes)")

    # 2. 512x512 PNG for electron-builder / Linux / window fallback
    png_512 = img.resize((512, 512), Image.Resampling.LANCZOS)
    png_path = os.path.join(build_dir, 'icon.png')
    png_512.save(png_path, format='PNG')
    print(f"Generated build PNG: {png_path} ({os.path.getsize(png_path)} bytes)")

    # 3. 256x256 PNG for in-app UI branding
    png_256 = img.resize((256, 256), Image.Resampling.LANCZOS)
    ui_logo_path = os.path.join(assets_dir, 'logo.png')
    png_256.save(ui_logo_path, format='PNG')
    print(f"Generated in-app UI logo: {ui_logo_path} ({os.path.getsize(ui_logo_path)} bytes)")

if __name__ == '__main__':
    generate_icons()
