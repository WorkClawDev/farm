#!/usr/bin/env python3
"""
Resize AI-generated assets to game-appropriate sizes and add transparency.

Usage:
    python3 resize_assets.py
"""

from PIL import Image
import os
from pathlib import Path

# Configuration
ASSETS_DIR = Path("/home/admin/gameboy-workspace/pastoral-tales/assets/sprites")

def resize_crop_sprite(input_path, output_path, size=(32, 32)):
    """Resize crop sprite to 32x32 and ensure transparency."""
    img = Image.open(input_path)
    
    # Convert to RGBA if not already
    if img.mode != 'RGBA':
        img = img.convert('RGBA')
    
    # Resize to target size using nearest neighbor for pixel art
    img_resized = img.resize(size, Image.NEAREST)
    
    # Save
    img_resized.save(output_path, 'PNG')
    print(f"Resized: {input_path} -> {output_path} ({size[0]}x{size[1]})")

def resize_item_sprite(input_path, output_path, size=(16, 16)):
    """Resize item sprite to 16x16."""
    img = Image.open(input_path)
    
    if img.mode != 'RGBA':
        img = img.convert('RGBA')
    
    img_resized = img.resize(size, Image.NEAREST)
    img_resized.save(output_path, 'PNG')
    print(f"Resized: {input_path} -> {output_path} ({size[0]}x{size[1]})")

def resize_ui_sprite(input_path, output_path, size=(64, 64)):
    """Resize UI sprite to appropriate size."""
    img = Image.open(input_path)
    
    if img.mode != 'RGBA':
        img = img.convert('RGBA')
    
    img_resized = img.resize(size, Image.NEAREST)
    img_resized.save(output_path, 'PNG')
    print(f"Resized: {input_path} -> {output_path} ({size[0]}x{size[1]})")

def process_all_crops():
    """Process all crop sprites."""
    crops_dir = ASSETS_DIR / "crops"
    if not crops_dir.exists():
        print(f"Directory not found: {crops_dir}")
        return
    
    print("=== Processing Crop Sprites ===")
    for png_file in crops_dir.glob("*.png"):
        resize_crop_sprite(png_file, png_file)

def process_all_items():
    """Process all item sprites."""
    items_dir = ASSETS_DIR / "items"
    if not items_dir.exists():
        print(f"Directory not found: {items_dir}")
        return
    
    print("\n=== Processing Item Sprites ===")
    for png_file in items_dir.glob("*.png"):
        resize_item_sprite(png_file, png_file)

def process_all_ui():
    """Process all UI sprites."""
    ui_dir = ASSETS_DIR / "ui"
    if not ui_dir.exists():
        print(f"Directory not found: {ui_dir}")
        return
    
    print("\n=== Processing UI Sprites ===")
    for png_file in ui_dir.glob("*.png"):
        # Skip if it's a small icon
        if "icon" in png_file.name.lower():
            continue
        resize_ui_sprite(png_file, png_file)

def main():
    print("Resizing assets to game-appropriate sizes...\n")
    
    process_all_crops()
    process_all_items()
    process_all_ui()
    
    print("\n=== Done! ===")
    print("All assets have been resized:")
    print("  - Crops: 32x32")
    print("  - Items: 16x16")
    print("  - UI: 64x64")

if __name__ == "__main__":
    main()
