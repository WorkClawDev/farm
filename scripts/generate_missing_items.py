#!/usr/bin/env python3
"""Generate missing item sprites using MiniMax Image API."""
import os
import sys
import time
import requests
from pathlib import Path

# Output directory
OUTPUT_DIR = "/home/admin/gameboy-workspace/pastoral-tales/assets/sprites/items"
Path(OUTPUT_DIR).mkdir(parents=True, exist_ok=True)

# API configuration
def get_api_key():
    bashrc = Path.home() / ".bashrc"
    if bashrc.exists():
        for line in bashrc.read_text().splitlines():
            if "MINIMAX_API_KEY" in line and "export" in line:
                parts = line.split("=")
                if len(parts) >= 2:
                    val = parts[1].strip().strip("'").strip('"')
                    if val:
                        return val
    return os.environ.get("MINIMAX_API_KEY", "")

API_KEY = get_api_key()
IMAGE_URL = "https://api.minimaxi.com/v1/image_generation"
PROXY = {"http": "http://127.0.0.1:7897", "https": "http://127.0.0.1:7897"}

HEADERS = {
    "Authorization": f"Bearer {API_KEY}",
    "Content-Type": "application/json",
}

NEGATIVE = "low quality, blurry, realistic, 3D render, photograph, non-pixel art, smooth gradients, anti-aliasing, high resolution, HD, photographic, modern art, abstract, text, watermark"

# Missing items categorized by type
MISSING_ITEMS = {
    # Food/Cooked items - high priority
    "food": [
        "bread", "fried_egg", "boiled_egg", "omelet", "baked_fish", "fish_stew",
        "grilled_fish", "farmers_breakfast", "corn_on_cob", "mashed_potato",
        "pumpkin_pie", "popcorn", "grilled_vegetables", "roasted_fish",
    ],
    # Raw crops already have sprites
    "crops": [],
    # Resources/Ores - high priority
    "resources": [
        "copper_ore", "copper_bar", "copper_ingot",
        "iron_ore", "iron_bar", "iron_ingot",
        "gold_ore", "gold_bar", "gold_ingot", "diamond",
        "stone", "wood", "hardwood", "hay", "fiber", "rope",
        "river_stone",
    ],
    # Tools - medium priority (tools folder has some)
    "tools": [
        "axe", "pickaxe", "hoe", "fishing_rod",
        "copper_axe", "copper_pickaxe", "iron_axe", "iron_pickaxe",
    ],
    # Processed products - medium priority
    "processed": [
        "cheese", "cheese_artisan", "cheese_plate", "flour", "honey",
        "mayonnaise", "bread", "egg",
    ],
    # Machines/Buildings
    "machines": [
        "cheese_press", "furnace", "bee_house", "mayonnaise_machine",
        "quality_feed", "quality_sprinkler",
    ],
    # Fish - 17 types, low priority (only generic fish.png exists)
    "fish": [
        "anglerfish", "bass", "carp", "catfish", "crucian_carp", "eel",
        "goldfish", "icefish", "mackerel", "perch", "pufferfish",
        "rainbow_trout", "salmon", "sardine", "squid", "swordfish", "tuna",
    ],
    # Mushrooms
    "mushrooms": ["chanterelle", "common_mushroom", "morel"],
    # Flowers/Decoration
    "flowers": ["daffodil", "flower_spring", "coral"],
    # Animal products
    "animal": [
        "duck_feather", "golden_egg", "quality_milk", "rabbit_foot",
        "wool", "truffle",
    ],
    # Special items
    "special": [
        "chest", "letter", "gold_coins", "quality_fertilizer",
        "basic_fertilizer", "bee_house", "quality_feed",
    ],
}

# Prompt templates for each category
PROMPT_TEMPLATES = {
    "food": "pixel art food item {name}, inventory icon, 32x32 pixels, transparent background, Stardew Valley style, detailed, appetizing",
    "resources": "pixel art resource material {name}, inventory icon, 32x32 pixels, transparent background, Stardew Valley style, detailed texture",
    "tools": "pixel art tool {name}, inventory icon, 32x32 pixels, transparent background, Stardew Valley style, detailed weapon or tool",
    "processed": "pixel art processed product {name}, inventory icon, 32x32 pixels, transparent background, Stardew Valley style, detailed",
    "machines": "pixel art machine building {name}, inventory icon, 32x32 pixels, transparent background, Stardew Valley style",
    "fish": "pixel art fish {name}, inventory icon, 32x32 pixels, transparent background, Stardew Valley style, detailed scales and fins",
    "mushrooms": "pixel art mushroom {name}, inventory icon, 32x32 pixels, transparent background, Stardew Valley style, detailed",
    "flowers": "pixel art flower {name}, inventory icon, 32x32 pixels, transparent background, Stardew Valley style, detailed petals",
    "animal": "pixel art animal product {name}, inventory icon, 32x32 pixels, transparent background, Stardew Valley style",
    "special": "pixel art item {name}, inventory icon, 32x32 pixels, transparent background, Stardew Valley style",
}

# Name mapping for better prompts
NAME_MAP = {
    "copper_ore": "copper ore chunk", "iron_ore": "iron ore chunk", "gold_ore": "gold ore chunk",
    "copper_bar": "copper bar", "iron_bar": "iron bar", "gold_bar": "gold bar",
    "copper_ingot": "copper ingot", "iron_ingot": "iron ingot", "gold_ingot": "gold ingot",
    "river_stone": "river stone", "hardwood": "hardwood log", "fiber": "plant fiber bundle",
    "fishing_rod": "fishing rod", "copper_pickaxe": "copper pickaxe", "iron_pickaxe": "iron pickaxe",
    "copper_axe": "copper axe", "iron_axe": "iron axe",
    "corn_on_cob": "corn on the cob", "mashed_potato": "mashed potato",
    "fish_stew": "fish stew", "baked_fish": "baked fish", "grilled_fish": "grilled fish",
    "roasted_fish": "roasted fish", "grilled_vegetables": "grilled vegetables",
    "farmers_breakfast": "farmer's breakfast", "pumpkin_pie": "pumpkin pie",
    "quality_milk": "quality milk", "quality_feed": "quality animal feed",
    "quality_fertilizer": "quality fertilizer", "basic_fertilizer": "basic fertilizer",
    "quality_sprinkler": "quality sprinkler",
    "cheese_artisan": "artisan cheese wheel", "cheese_plate": "cheese plate",
    "gold_coins": "gold coin pouch", "rabbit_foot": "rabbit's foot",
    "duck_feather": "duck feather", "golden_egg": "golden egg",
    "flower_spring": "spring flower", "common_mushroom": "common mushroom",
}

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
            if data is None:
                print(f"    Invalid JSON response")
                time.sleep(5)
                continue
            base = data.get("base_resp", {})
            if base.get("status_code") != 0:
                msg = base.get("status_msg", "unknown error")
                print(f"    API error {base.get('status_code')}: {msg}")
                if "usage limit" in msg.lower() or "rate limit" in msg.lower():
                    print(f"    Rate limited, waiting 30s...")
                    time.sleep(30)
                    continue
                if "token plan" in msg.lower():
                    return False
                time.sleep(5)
                continue
            urls = (data.get("data") or {}).get("image_urls", [])
            if not urls:
                print(f"    No image URL in response")
                time.sleep(5)
                continue
            img_resp = requests.get(urls[0], proxies=PROXY, timeout=30)
            with open(output_path, "wb") as f:
                f.write(img_resp.content)
            sz = Path(output_path).stat().st_size
            if sz < 1000:
                print(f"    ⚠️ File too small ({sz} bytes), retrying...")
                time.sleep(5)
                continue
            print(f"    ✅ {Path(output_path).name} ({sz//1024}KB)")
            return True
        except Exception as e:
            print(f"    Attempt {attempt+1} error: {e}")
            time.sleep(5)
    return False


def main():
    print(f"API Key: {'✅ set' if API_KEY else '❌ MISSING'} ({API_KEY[:8]}...)")
    print(f"Output: {OUTPUT_DIR}\n")

    total = 0
    success = 0
    failed = []

    for category, items in MISSING_ITEMS.items():
        if not items:
            continue
        template = PROMPT_TEMPLATES.get(category, PROMPT_TEMPLATES["special"])
        print(f"\n=== {category.upper()} ({len(items)} items) ===")

        for item_id in items:
            # Skip if already exists
            output_path = os.path.join(OUTPUT_DIR, f"{item_id}.png")
            if Path(output_path).exists():
                print(f"  ⏭️  {item_id}.png already exists, skipping")
                continue

            # Get display name
            display_name = NAME_MAP.get(item_id, item_id.replace("_", " "))
            prompt = template.format(name=display_name)

            print(f"  [{item_id}]")
            total += 1

            ok = generate_image(prompt, output_path)
            if ok:
                success += 1
                time.sleep(2)  # Rate limiting
            else:
                failed.append(item_id)
                print(f"    ❌ Failed to generate {item_id}")
                time.sleep(5)  # Longer wait on failure

    print("\n" + "="*50)
    print("SUMMARY")
    print("="*50)
    print(f"  Total attempted: {total}")
    print(f"  ✅ Success: {success}")
    print(f"  ❌ Failed: {len(failed)}")
    if failed:
        print(f"  Failed items: {', '.join(failed)}")


if __name__ == "__main__":
    main()
