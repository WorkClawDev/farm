#!/usr/bin/env python3
"""
田园物语 - 占位符资源生成器
生成临时的像素艺术风格占位符图片
"""

from PIL import Image, ImageDraw
import os
import json

# 项目路径
PROJECT_ROOT = "/home/admin/gameboy-workspace/pastoral-tales"
ASSETS_DIR = os.path.join(PROJECT_ROOT, "assets")

# 作物颜色定义 (R, G, B)
CROP_COLORS = {
    "turnip": {"seed": (139, 90, 43), "stage0": (144, 238, 144), "stage1": (107, 142, 35), "stage2": (85, 107, 47), "stage3": (218, 165, 32), "item": (255, 223, 0)},
    "potato": {"seed": (139, 90, 43), "stage0": (144, 238, 144), "stage1": (107, 142, 35), "stage2": (139, 69, 19), "stage3": (160, 82, 45), "item": (210, 180, 140)},
    "tomato": {"seed": (255, 165, 0), "stage0": (144, 238, 144), "stage1": (107, 142, 35), "stage2": (255, 99, 71), "stage3": (220, 20, 60), "item": (255, 0, 0)},
    "corn": {"seed": (255, 215, 0), "stage0": (144, 238, 144), "stage1": (107, 142, 35), "stage2": (255, 215, 0), "stage3": (218, 165, 32), "item": (255, 215, 0)},
    "pumpkin": {"seed": (139, 69, 19), "stage0": (144, 238, 144), "stage1": (107, 142, 35), "stage2": (255, 140, 0), "stage3": (255, 69, 0), "item": (255, 117, 24)},
    "cauliflower": {"seed": (192, 192, 192), "stage0": (144, 238, 144), "stage1": (107, 142, 35), "stage2": (255, 255, 224), "stage3": (255, 250, 205), "item": (255, 255, 240)},
    "green_bean": {"seed": (0, 128, 0), "stage0": (144, 238, 144), "stage1": (107, 142, 35), "stage2": (34, 139, 34), "stage3": (0, 100, 0), "item": (0, 128, 0)},
    "strawberry": {"seed": (255, 192, 203), "stage0": (144, 238, 144), "stage1": (107, 142, 35), "stage2": (255, 105, 180), "stage3": (220, 20, 60), "item": (255, 0, 0)},
    "melon": {"seed": (0, 255, 127), "stage0": (144, 238, 144), "stage1": (107, 142, 35), "stage2": (144, 238, 144), "stage3": (0, 255, 127), "item": (0, 255, 127)},
    "blueberry": {"seed": (75, 0, 130), "stage0": (144, 238, 144), "stage1": (107, 142, 35), "stage2": (138, 43, 226), "stage3": (75, 0, 130), "item": (75, 0, 130)},
    "hot_pepper": {"seed": (255, 69, 0), "stage0": (144, 238, 144), "stage1": (107, 142, 35), "stage2": (255, 140, 0), "stage3": (255, 0, 0), "item": (255, 0, 0)},
    "radish": {"seed": (255, 182, 193), "stage0": (144, 238, 144), "stage1": (107, 142, 35), "stage2": (255, 192, 203), "stage3": (255, 105, 180), "item": (255, 20, 147)},
    "eggplant": {"seed": (128, 0, 128), "stage0": (144, 238, 144), "stage1": (107, 142, 35), "stage2": (147, 112, 219), "stage3": (128, 0, 128), "item": (128, 0, 128)},
    "cranberry": {"seed": (178, 34, 34), "stage0": (144, 238, 144), "stage1": (107, 142, 35), "stage2": (220, 20, 60), "stage3": (139, 0, 0), "item": (178, 34, 34)},
    "grape": {"seed": (75, 0, 130), "stage0": (144, 238, 144), "stage1": (107, 142, 35), "stage2": (138, 43, 226), "stage3": (75, 0, 130), "item": (128, 0, 128)},
    "sweet_potato": {"seed": (139, 69, 19), "stage0": (144, 238, 144), "stage1": (107, 142, 35), "stage2": (210, 105, 30), "stage3": (205, 92, 92), "item": (255, 140, 0)},
    "carrot": {"seed": (255, 140, 0), "stage0": (144, 238, 144), "stage1": (107, 142, 35), "stage2": (255, 165, 0), "stage3": (255, 69, 0), "item": (255, 140, 0)},
    "winter_root": {"seed": (139, 69, 19), "stage0": (144, 238, 144), "stage1": (107, 142, 35), "stage2": (160, 82, 45), "stage3": (139, 69, 19), "item": (139, 69, 19)},
    "cabbage": {"seed": (107, 142, 35), "stage0": (144, 238, 144), "stage1": (107, 142, 35), "stage2": (154, 205, 50), "stage3": (0, 128, 0), "item": (154, 205, 50)},
    "winter_melon": {"seed": (0, 100, 0), "stage0": (144, 238, 144), "stage1": (107, 142, 35), "stage2": (0, 128, 0), "stage3": (0, 100, 0), "item": (0, 100, 0)},
}

def create_crop_stage_image(crop_name, stage, size=32):
    """创建作物生长阶段的占位符图片"""
    colors = CROP_COLORS.get(crop_name, CROP_COLORS["turnip"])
    
    # 根据阶段选择颜色
    if stage == 0:
        color = colors["stage0"]
    elif stage == 1:
        color = colors["stage1"]
    elif stage == 2:
        color = colors["stage2"]
    else:
        color = colors["stage3"]
    
    # 创建图片
    img = Image.new('RGBA', (size, size), (0, 0, 0, 0))
    draw = ImageDraw.Draw(img)
    
    # 绘制简单的像素艺术风格作物
    center = size // 2
    
    if stage == 0:
        # 种子阶段 - 小点
        draw.ellipse([center-2, center-2, center+2, center+2], fill=color)
    elif stage == 1:
        # 幼苗阶段 - 小叶子
        draw.ellipse([center-4, center-4, center+4, center+4], fill=color)
        draw.line([center, center+4, center, center+8], fill=(139, 69, 19), width=2)
    elif stage == 2:
        # 生长阶段 - 大叶子
        draw.ellipse([center-6, center-6, center+6, center+6], fill=color)
        draw.ellipse([center-8, center-2, center-4, center+2], fill=color)
        draw.ellipse([center+4, center-2, center+8, center+2], fill=color)
        draw.line([center, center+6, center, center+10], fill=(139, 69, 19), width=2)
    else:
        # 成熟阶段 - 完整作物
        # 绘制茎
        draw.line([center, center+8, center, center+12], fill=(139, 69, 19), width=2)
        # 绘制叶子
        draw.ellipse([center-8, center-4, center+8, center+8], fill=colors["stage2"])
        # 绘制果实
        draw.ellipse([center-6, center-6, center+6, center+6], fill=colors["item"])
    
    return img

def create_item_image(crop_name, size=16):
    """创建物品图标"""
    colors = CROP_COLORS.get(crop_name, CROP_COLORS["turnip"])
    color = colors["item"]
    
    img = Image.new('RGBA', (size, size), (0, 0, 0, 0))
    draw = ImageDraw.Draw(img)
    
    center = size // 2
    
    # 绘制简单的圆形物品
    draw.ellipse([center-5, center-5, center+5, center+5], fill=color, outline=(0, 0, 0))
    
    return img

def create_seed_image(crop_name, size=16):
    """创建种子图标"""
    colors = CROP_COLORS.get(crop_name, CROP_COLORS["turnip"])
    color = colors["seed"]
    
    img = Image.new('RGBA', (size, size), (0, 0, 0, 0))
    draw = ImageDraw.Draw(img)
    
    center = size // 2
    
    # 绘制小种子形状
    draw.ellipse([center-3, center-3, center+3, center+3], fill=color, outline=(0, 0, 0))
    
    return img

def create_dead_crop_image(size=32):
    """创建枯萎作物图片"""
    img = Image.new('RGBA', (size, size), (0, 0, 0, 0))
    draw = ImageDraw.Draw(img)
    
    center = size // 2
    
    # 绘制枯萎的棕色植物
    draw.line([center, center+8, center, center+12], fill=(101, 67, 33), width=2)
    draw.ellipse([center-6, center-6, center+6, center+2], fill=(139, 69, 19))
    
    return img

def ensure_dir(path):
    """确保目录存在"""
    os.makedirs(path, exist_ok=True)

def generate_all_assets():
    """生成所有占位符资源"""
    print("开始生成占位符资源...")
    
    # 创建目录
    crops_dir = os.path.join(ASSETS_DIR, "sprites", "crops")
    items_dir = os.path.join(ASSETS_DIR, "sprites", "items")
    ensure_dir(crops_dir)
    ensure_dir(items_dir)
    
    generated_count = 0
    
    # 生成作物精灵
    print("\n生成作物精灵...")
    for crop_name in CROP_COLORS.keys():
        for stage in range(4):
            filename = f"{crop_name}_stage{stage}.png"
            filepath = os.path.join(crops_dir, filename)
            
            if not os.path.exists(filepath):
                img = create_crop_stage_image(crop_name, stage)
                img.save(filepath)
                generated_count += 1
                print(f"  生成: {filename}")
    
    # 生成枯萎作物
    dead_crop_path = os.path.join(crops_dir, "crop_dead.png")
    if not os.path.exists(dead_crop_path):
        img = create_dead_crop_image()
        img.save(dead_crop_path)
        generated_count += 1
        print(f"  生成: crop_dead.png")
    
    # 生成物品图标
    print("\n生成物品图标...")
    for crop_name in CROP_COLORS.keys():
        # 作物收获物
        item_filename = f"{crop_name}.png"
        item_path = os.path.join(items_dir, item_filename)
        
        if not os.path.exists(item_path):
            img = create_item_image(crop_name)
            img.save(item_path)
            generated_count += 1
            print(f"  生成: {item_filename}")
        
        # 种子
        seed_filename = f"{crop_name}_seed.png"
        seed_path = os.path.join(items_dir, seed_filename)
        
        if not os.path.exists(seed_path):
            img = create_seed_image(crop_name)
            img.save(seed_path)
            generated_count += 1
            print(f"  生成: {seed_filename}")
    
    print(f"\n✓ 共生成 {generated_count} 张占位符图片")
    print(f"  - 作物精灵: {len(CROP_COLORS) * 4 + 1} 张")
    print(f"  - 物品图标: {len(CROP_COLORS) * 2} 张")
    
    return generated_count

if __name__ == "__main__":
    count = generate_all_assets()
    print(f"\n占位符资源生成完成!")
