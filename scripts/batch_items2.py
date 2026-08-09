#!/usr/bin/env python3
"""Batch generate remaining missing item sprites using MiniMax Image API."""
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

# Remaining items to generate
ITEMS = [
    # More fish
    ("anglerfish", "pixel art anglerfish, deep sea fish with light lure, inventory icon, 32x32 pixels, transparent background, Stardew Valley style, detailed bioluminescent lure"),
    ("eel", "pixel art eel fish, long slender, inventory icon, 32x32 pixels, transparent background, Stardew Valley style, detailed scales"),
    ("goldfish", "pixel art goldfish, orange and white, inventory icon, 32x32 pixels, transparent background, Stardew Valley style, detailed fins"),
    ("icefish", "pixel art icefish, pale translucent, inventory icon, 32x32 pixels, transparent background, Stardew Valley style, detailed body"),
    ("rainbow_trout", "pixel art rainbow trout, colorful stripes, inventory icon, 32x32 pixels, transparent background, Stardew Valley style, detailed iridescent scales"),
    ("sardine", "pixel art sardine fish, small silver, inventory icon, 32x32 pixels, transparent background, Stardew Valley style, detailed small fish"),
    ("pufferfish", "pixel art pufferfish, round spiky, inventory icon, 32x32 pixels, transparent background, Stardew Valley style, detailed inflated body"),
    
    # Mushrooms
    ("chanterelle", "pixel art chanterelle mushroom, golden yellow, inventory icon, 32x32 pixels, transparent background, Stardew Valley style, detailed fan shape"),
    ("common_mushroom", "pixel art common mushroom, brown cap, inventory icon, 32x32 pixels, transparent background, Stardew Valley style, detailed gills"),
    ("morel", "pixel art morel mushroom, honeycomb pattern, inventory icon, 32x32 pixels, transparent background, Stardew Valley style, detailed spongy cap"),
    
    # Flowers
    ("daffodil", "pixel art daffodil flower, yellow petals, inventory icon, 32x32 pixels, transparent background, Stardew Valley style, detailed trumpet center"),
    ("flower_spring", "pixel art spring flower bouquet, colorful mixed, inventory icon, 32x32 pixels, transparent background, Stardew Valley style, detailed petals"),
    ("coral", "pixel art coral piece, orange and pink, inventory icon, 32x32 pixels, transparent background, Stardew Valley style, detailed branching structure"),
    
    # Food items
    ("blackberry", "pixel art blackberries, dark purple cluster, inventory icon, 32x32 pixels, transparent background, Stardew Valley style, detailed berry texture"),
    ("ginger_root", "pixel art ginger root, tan knobby, inventory icon, 32x32 pixels, transparent background, Stardew Valley style, detailed root shape"),
    ("pork", "pixel art pork chop, raw meat cut, inventory icon, 32x32 pixels, transparent background, Stardew Valley style, detailed marbling"),
    ("mayonnaise", "pixel art mayonnaise jar, white creamy, inventory icon, 32x32 pixels, transparent background, Stardew Valley style, detailed glass jar"),
    ("coffee_beans", "pixel art coffee beans, dark brown, inventory icon, 32x32 pixels, transparent background, Stardew Valley style, detailed bean shape"),
    
    # Animal products
    ("duck_feather", "pixel art duck feather, white and gray, inventory icon, 32x32 pixels, transparent background, Stardew Valley style, detailed plume"),
    ("golden_egg", "pixel art golden egg, shimmering gold, inventory icon, 32x32 pixels, transparent background, Stardew Valley style, detailed metallic surface"),
    ("quality_milk", "pixel art quality milk bottle, white with star, inventory icon, 32x32 pixels, transparent background, Stardew Valley style, detailed glass bottle"),
    ("rabbit_foot", "pixel art rabbit's foot charm, white fluffy, inventory icon, 32x32 pixels, transparent background, Stardew Valley style, detailed lucky charm"),
    
    # Special items
    ("letter", "pixel art sealed letter, cream envelope, inventory icon, 32x32 pixels, transparent background, Stardew Valley style, detailed wax seal"),
    ("basic_fertilizer", "pixel art fertilizer bag, green label, inventory icon, 32x32 pixels, transparent background, Stardew Valley style, detailed sack"),
    ("quality_fertilizer", "pixel art quality fertilizer bag, gold label, inventory icon, 32x32 pixels, transparent background, Stardew Valley style, detailed premium bag"),
    ("quality_feed", "pixel art quality animal feed bag, premium label, inventory icon, 32x32 pixels, transparent background, Stardew Valley style, detailed feed bag"),
    ("sprinkler", "pixel art sprinkler device, metal head, inventory icon, 32x32 pixels, transparent background, Stardew Valley style, detailed water spray"),
    ("quality_sprinkler", "pixel art quality sprinkler device, gold metal, inventory icon, 32x32 pixels, transparent background, Stardew Valley style, detailed premium sprinkler"),
    ("mayonnaise_machine", "pixel art mayonnaise machine, white jar apparatus, inventory icon, 32x32 pixels, transparent background, Stardew Valley style, detailed mechanical device"),
    ("cheese_press", "pixel art cheese press, wooden and metal, inventory icon, 32x32 pixels, transparent background, Stardew Valley style, detailed pressing mechanism"),
    ("cheese_artisan", "pixel art artisan cheese wheel, aged wax coating, inventory icon, 32x32 pixels, transparent background, Stardew Valley style, detailed cheese texture"),
    ("cheese_plate", "pixel art cheese plate, sliced cheese on plate, inventory icon, 32x32 pixels, transparent background, Stardew Valley style, detailed arranged cheese"),
    
    # Other items
    ("fiber_seeds", "pixel art fiber seeds packet, plant fibers, inventory icon, 32x32 pixels, transparent background, Stardew Valley style, detailed seed packet"),
    ("fish_common", "pixel art common fish, generic silver fish, inventory icon, 32x32 pixels, transparent background, Stardew Valley style, detailed basic fish"),
    ("fish_rare", "pixel art rare fish, glowing colorful, inventory icon, 32x32 pixels, transparent background, Stardew Valley style, detailed precious fish"),
    ("scarecrow", "pixel art scarecrow, straw hat and clothes, inventory icon, 32x32 pixels, transparent background, Stardew Valley style, detailed straw figure"),
    ("seashell", "pixel art seashell, pink spiral, inventory icon, 32x32 pixels, transparent background, Stardew Valley style, detailed shell texture"),
    ("sickle", "pixel art sickle tool, curved blade, inventory icon, 32x32 pixels, transparent background, Stardew Valley style, detailed farming tool"),
    ("stone_brick", "pixel art stone bricks stack, gray building material, inventory icon, 32x32 pixels, transparent background, Stardew Valley style, detailed masonry"),
    ("sashimi", "pixel art sashimi plate, sliced raw fish, inventory icon, 32x32 pixels, transparent background, Stardew Valley style, detailed fresh fish slices"),
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
