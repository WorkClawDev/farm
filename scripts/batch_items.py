#!/usr/bin/env python3
"""Batch generate missing item sprites using MiniMax Image API."""
import os
import sys
import time
import requests
from pathlib import Path

# API configuration
API_KEY = 'sk-cp-Ftb6E2GTvC_SqzgcsrKnO2nNr0vA45mZ4ppm3Yz49SFv3yq6gXE3mG4GsSmdvRfS6dF9Mau-0e-bAIQL3TZhInWrkFsHoIs0dr8W6UcvD665Z-9Mocw6zYs'
IMAGE_URL = "https://api.minimaxi.com/v1/image_generation"
PROXY = {"http": "http://127.0.0.1:7897", "https": "http://127.0.0.1:7897"}
HEADERS = {
    "Authorization": f"Bearer {API_KEY}",
    "Content-Type": "application/json",
}

OUTPUT_DIR = Path("/home/admin/gameboy-workspace/pastoral-tales/assets/sprites/items")
OUTPUT_DIR.mkdir(parents=True, exist_ok=True)

NEGATIVE = "low quality, blurry, realistic, 3D render, photograph, non-pixel art, smooth gradients, anti-aliasing, high resolution, HD, photographic, modern art, abstract, text, watermark"

# Items to generate (prioritized)
ITEMS = [
    # High priority - food
    ("bread", "pixel art bread loaf, inventory icon, 32x32 pixels, transparent background, Stardew Valley style, detailed crust and soft inside"),
    ("fried_egg", "pixel art fried egg, sunny side up, inventory icon, 32x32 pixels, transparent background, Stardew Valley style, detailed white and yolk"),
    ("boiled_egg", "pixel art boiled egg, peeled and sliced, inventory icon, 32x32 pixels, transparent background, Stardew Valley style, detailed white and yolk"),
    ("omelet", "pixel art omelet, golden yellow, inventory icon, 32x32 pixels, transparent background, Stardew Valley style, detailed folded eggs"),
    ("baked_fish", "pixel art baked fish on plate, golden brown, inventory icon, 32x32 pixels, transparent background, Stardew Valley style, detailed scales"),
    ("fish_stew", "pixel art fish stew in bowl, steaming, inventory icon, 32x32 pixels, transparent background, Stardew Valley style, detailed vegetables and fish chunks"),
    ("corn_on_cob", "pixel art corn on the cob, golden yellow, inventory icon, 32x32 pixels, transparent background, Stardew Valley style, detailed kernels"),
    ("pumpkin_pie", "pixel art pumpkin pie slice, golden crust, inventory icon, 32x32 pixels, transparent background, Stardew Valley style, detailed whipped cream"),
    ("popcorn", "pixel art popcorn bucket, golden yellow, inventory icon, 32x32 pixels, transparent background, Stardew Valley style, detailed fluffy kernels"),
    
    # Resources - ores and bars
    ("copper_ore", "pixel art copper ore chunk, brown and orange, inventory icon, 32x32 pixels, transparent background, Stardew Valley style, detailed mineral veins"),
    ("iron_ore", "pixel art iron ore chunk, gray metallic, inventory icon, 32x32 pixels, transparent background, Stardew Valley style, detailed mineral veins"),
    ("gold_ore", "pixel art gold ore chunk, yellow glittering, inventory icon, 32x32 pixels, transparent background, Stardew Valley style, detailed precious metal"),
    ("copper_bar", "pixel art copper bar, orange metallic, inventory icon, 32x32 pixels, transparent background, Stardew Valley style, detailed ingot"),
    ("iron_bar", "pixel art iron bar, silver metallic, inventory icon, 32x32 pixels, transparent background, Stardew Valley style, detailed ingot"),
    ("gold_bar", "pixel art gold bar, yellow glittering, inventory icon, 32x32 pixels, transparent background, Stardew Valley style, detailed precious ingot"),
    
    # Processed foods
    ("cheese", "pixel art cheese wheel, yellow, inventory icon, 32x32 pixels, transparent background, Stardew Valley style, detailed holes and wedge cut"),
    ("flour", "pixel art flour bag, white powder, inventory icon, 32x32 pixels, transparent background, Stardew Valley style, detailed sack"),
    ("honey", "pixel art honey jar, golden amber, inventory icon, 32x32 pixels, transparent background, Stardew Valley style, detailed jar with honeycomb"),
    
    # Fish (high priority - 17 types)
    ("bass", "pixel art bass fish, silver and blue, inventory icon, 32x32 pixels, transparent background, Stardew Valley style, detailed scales and fins"),
    ("carp", "pixel art carp fish, orange and white, inventory icon, 32x32 pixels, transparent background, Stardew Valley style, detailed scales"),
    ("catfish", "pixel art catfish, gray with whiskers, inventory icon, 32x32 pixels, transparent background, Stardew Valley style, detailed barbels"),
    ("salmon", "pixel art salmon fish, pink orange, inventory icon, 32x32 pixels, transparent background, Stardew Valley style, detailed scales"),
    ("tuna", "pixel art tuna fish, dark blue and silver, inventory icon, 32x32 pixels, transparent background, Stardew Valley style, detailed body"),
    
    # Tools
    ("axe", "pixel art axe, wooden handle and metal blade, inventory icon, 32x32 pixels, transparent background, Stardew Valley style, detailed weapon"),
    ("pickaxe", "pixel art pickaxe, wooden handle and metal head, inventory icon, 32x32 pixels, transparent background, Stardew Valley style, detailed mining tool"),
    ("hoe", "pixel art hoe, wooden handle and metal blade, inventory icon, 32x32 pixels, transparent background, Stardew Valley style, detailed farming tool"),
    ("watering_can", "pixel art watering can, green metal, inventory icon, 32x32 pixels, transparent background, Stardew Valley style, detailed spout and handle"),
    
    # Materials
    ("stone", "pixel art stone pile, gray rocks, inventory icon, 32x32 pixels, transparent background, Stardew Valley style, detailed rocks"),
    ("wood", "pixel art wood log pile, brown, inventory icon, 32x32 pixels, transparent background, Stardew Valley style, detailed bark texture"),
    ("hardwood", "pixel art hardwood log, dark brown, inventory icon, 32x32 pixels, transparent background, Stardew Valley style, detailed grain texture"),
    ("fiber", "pixel art plant fiber bundle, green and brown, inventory icon, 32x32 pixels, transparent background, Stardew Valley style, detailed strands"),
    
    # Machines
    ("furnace", "pixel art furnace, stone brick with fire, inventory icon, 32x32 pixels, transparent background, Stardew Valley style, detailed flames"),
    ("bee_house", "pixel art bee house, brown wooden box, inventory icon, 32x32 pixels, transparent background, Stardew Valley style, detailed beehive pattern"),
    
    # Special items
    ("chest", "pixel art treasure chest, wooden brown, inventory icon, 32x32 pixels, transparent background, Stardew Valley style, detailed lid and lock"),
    ("diamond", "pixel art diamond gem, blue sparkling, inventory icon, 32x32 pixels, transparent background, Stardew Valley style, detailed facets"),
    ("gold_coins", "pixel art gold coins pouch, yellow glittering, inventory icon, 32x32 pixels, transparent background, Stardew Valley style, detailed coins"),
]

def generate_image(prompt: str, output_path: str) -> bool:
    payload = {
        "model": "image-01",
        "prompt": prompt,
        "aspect_ratio": "1:1",
        "negative_prompt": NEGATIVE,
    }
    for attempt in range(3):
        try:
            resp = requests.post(IMAGE_URL, headers=HEADERS, json=payload,
                                 proxies=PROXY, timeout=120)
            if resp.status_code != 200:
                print(f"    HTTP {resp.status_code}: {resp.text[:100]}")
                time.sleep(5)
                continue
            data = resp.json()
            base = data.get("base_resp", {})
            if base.get("status_code") != 0:
                msg = base.get("status_msg", "unknown error")
                print(f"    API error: {msg}")
                if "token plan" in msg.lower():
                    return False
                time.sleep(5)
                continue
            urls = (data.get("data") or {}).get("image_urls", [])
            if not urls:
                print(f"    No image URL")
                time.sleep(5)
                continue
            img_resp = requests.get(urls[0], proxies=PROXY, timeout=30)
            with open(output_path, "wb") as f:
                f.write(img_resp.content)
            sz = Path(output_path).stat().st_size
            if sz < 1000:
                print(f"    File too small ({sz} bytes), retrying...")
                time.sleep(5)
                continue
            print(f"    ✅ {Path(output_path).name} ({sz//1024}KB)")
            return True
        except Exception as e:
            print(f"    Attempt {attempt+1} error: {e}")
            time.sleep(5)
    return False


def main():
    print(f"API Key: {'✅ set' if API_KEY else '❌ MISSING'}")
    print(f"Output: {OUTPUT_DIR}\n")
    
    total = 0
    success = 0
    skipped = 0
    failed = []
    
    for item_id, prompt in ITEMS:
        output_path = OUTPUT_DIR / f"{item_id}.png"
        
        if output_path.exists():
            print(f"  ⏭️  {item_id}.png exists, skipping")
            skipped += 1
            continue
        
        print(f"  [{item_id}]")
        total += 1
        
        ok = generate_image(prompt, str(output_path))
        if ok:
            success += 1
            time.sleep(3)  # Rate limiting
        else:
            failed.append(item_id)
            print(f"    ❌ Failed")
            time.sleep(5)
    
    print("\n" + "="*50)
    print("SUMMARY")
    print("="*50)
    print(f"  Total: {total} attempted, {skipped} skipped")
    print(f"  ✅ Success: {success}")
    print(f"  ❌ Failed: {len(failed)}")
    if failed:
        print(f"  Failed items: {', '.join(failed)}")
    
    return 0 if not failed else 1


if __name__ == "__main__":
    sys.exit(main())
