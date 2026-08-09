#!/usr/bin/env python3
"""
田园物语 - 高质量占位符生成器
生成更美观的像素艺术风格占位符
"""

from PIL import Image, ImageDraw, ImageFont
import os
import random

# 项目路径
PROJECT_ROOT = "/home/admin/gameboy-workspace/pastoral-tales"
ASSETS_DIR = os.path.join(PROJECT_ROOT, "assets")

# 作物详细定义
CROPS = {
    "turnip": {
        "name": "芜菁",
        "colors": {
            "leaf": (107, 142, 35),
            "leaf_dark": (85, 107, 47),
            "bulb": (255, 223, 0),
            "bulb_dark": (218, 165, 32),
            "seed": (139, 90, 43)
        }
    },
    "potato": {
        "name": "土豆",
        "colors": {
            "leaf": (107, 142, 35),
            "leaf_dark": (85, 107, 47),
            "bulb": (210, 180, 140),
            "bulb_dark": (160, 82, 45),
            "seed": (139, 90, 43)
        }
    },
    "tomato": {
        "name": "番茄",
        "colors": {
            "leaf": (34, 139, 34),
            "leaf_dark": (0, 100, 0),
            "bulb": (255, 0, 0),
            "bulb_dark": (178, 34, 34),
            "seed": (255, 140, 0)
        }
    },
    "corn": {
        "name": "玉米",
        "colors": {
            "leaf": (107, 142, 35),
            "leaf_dark": (85, 107, 47),
            "bulb": (255, 215, 0),
            "bulb_dark": (218, 165, 32),
            "seed": (255, 215, 0)
        }
    },
    "pumpkin": {
        "name": "南瓜",
        "colors": {
            "leaf": (107, 142, 35),
            "leaf_dark": (85, 107, 47),
            "bulb": (255, 117, 24),
            "bulb_dark": (255, 69, 0),
            "seed": (139, 69, 19)
        }
    },
    "cauliflower": {
        "name": "花椰菜",
        "colors": {
            "leaf": (107, 142, 35),
            "leaf_dark": (85, 107, 47),
            "bulb": (255, 255, 240),
            "bulb_dark": (240, 230, 140),
            "seed": (192, 192, 192)
        }
    },
    "green_bean": {
        "name": "青豆",
        "colors": {
            "leaf": (107, 142, 35),
            "leaf_dark": (85, 107, 47),
            "bulb": (0, 128, 0),
            "bulb_dark": (0, 100, 0),
            "seed": (0, 128, 0)
        }
    },
    "strawberry": {
        "name": "草莓",
        "colors": {
            "leaf": (34, 139, 34),
            "leaf_dark": (0, 100, 0),
            "bulb": (255, 0, 0),
            "bulb_dark": (178, 34, 34),
            "seed": (255, 192, 203)
        }
    },
    "melon": {
        "name": "甜瓜",
        "colors": {
            "leaf": (107, 142, 35),
            "leaf_dark": (85, 107, 47),
            "bulb": (0, 255, 127),
            "bulb_dark": (0, 200, 100),
            "seed": (0, 255, 127)
        }
    },
    "blueberry": {
        "name": "蓝莓",
        "colors": {
            "leaf": (107, 142, 35),
            "leaf_dark": (85, 107, 47),
            "bulb": (75, 0, 130),
            "bulb_dark": (138, 43, 226),
            "seed": (75, 0, 130)
        }
    },
    "hot_pepper": {
        "name": "辣椒",
        "colors": {
            "leaf": (107, 142, 35),
            "leaf_dark": (85, 107, 47),
            "bulb": (255, 0, 0),
            "bulb_dark": (178, 34, 34),
            "seed": (255, 69, 0)
        }
    },
    "radish": {
        "name": "萝卜",
        "colors": {
            "leaf": (107, 142, 35),
            "leaf_dark": (85, 107, 47),
            "bulb": (255, 20, 147),
            "bulb_dark": (199, 21, 133),
            "seed": (255, 182, 193)
        }
    },
    "eggplant": {
        "name": "茄子",
        "colors": {
            "leaf": (107, 142, 35),
            "leaf_dark": (85, 107, 47),
            "bulb": (128, 0, 128),
            "bulb_dark": (75, 0, 130),
            "seed": (128, 0, 128)
        }
    },
    "cranberry": {
        "name": "蔓越莓",
        "colors": {
            "leaf": (107, 142, 35),
            "leaf_dark": (85, 107, 47),
            "bulb": (178, 34, 34),
            "bulb_dark": (139, 0, 0),
            "seed": (178, 34, 34)
        }
    },
    "grape": {
        "name": "葡萄",
        "colors": {
            "leaf": (107, 142, 35),
            "leaf_dark": (85, 107, 47),
            "bulb": (128, 0, 128),
            "bulb_dark": (75, 0, 130),
            "seed": (75, 0, 130)
        }
    },
    "sweet_potato": {
        "name": "红薯",
        "colors": {
            "leaf": (107, 142, 35),
            "leaf_dark": (85, 107, 47),
            "bulb": (255, 140, 0),
            "bulb_dark": (210, 105, 30),
            "seed": (139, 69, 19)
        }
    },
    "carrot": {
        "name": "胡萝卜",
        "colors": {
            "leaf": (107, 142, 35),
            "leaf_dark": (85, 107, 47),
            "bulb": (255, 140, 0),
            "bulb_dark": (255, 69, 0),
            "seed": (255, 140, 0)
        }
    },
    "winter_root": {
        "name": "冬根",
        "colors": {
            "leaf": (107, 142, 35),
            "leaf_dark": (85, 107, 47),
            "bulb": (139, 69, 19),
            "bulb_dark": (101, 67, 33),
            "seed": (139, 69, 19)
        }
    },
    "cabbage": {
        "name": "卷心菜",
        "colors": {
            "leaf": (107, 142, 35),
            "leaf_dark": (85, 107, 47),
            "bulb": (154, 205, 50),
            "bulb_dark": (0, 128, 0),
            "seed": (107, 142, 35)
        }
    },
    "winter_melon": {
        "name": "冬瓜",
        "colors": {
            "leaf": (107, 142, 35),
            "leaf_dark": (85, 107, 47),
            "bulb": (0, 100, 0),
            "bulb_dark": (0, 64, 0),
            "seed": (0, 100, 0)
        }
    },
}

def draw_pixel_rect(draw, x, y, w, h, color):
    """绘制像素风格的矩形"""
    draw.rectangle([x, y, x+w-1, y+h-1], fill=color)

def create_crop_stage_improved(crop_name, stage, size=32):
    """创建改进的作物生长阶段图片"""
    crop = CROPS.get(crop_name, CROPS["turnip"])
    colors = crop["colors"]
    
    img = Image.new('RGBA', (size, size), (0, 0, 0, 0))
    draw = ImageDraw.Draw(img)
    
    center_x = size // 2
    ground_y = size - 4
    
    if stage == 0:
        # 种子阶段 - 小芽
        # 茎
        draw_pixel_rect(draw, center_x-1, ground_y-6, 2, 6, (139, 69, 19))
        # 小叶子
        draw_pixel_rect(draw, center_x-3, ground_y-8, 6, 4, colors["leaf"])
        draw_pixel_rect(draw, center_x-2, ground_y-9, 4, 2, colors["leaf_dark"])
        
    elif stage == 1:
        # 幼苗阶段
        # 茎
        draw_pixel_rect(draw, center_x-1, ground_y-10, 2, 10, (139, 69, 19))
        # 叶子
        draw_pixel_rect(draw, center_x-5, ground_y-12, 10, 6, colors["leaf"])
        draw_pixel_rect(draw, center_x-3, ground_y-14, 6, 4, colors["leaf_dark"])
        # 小果实芽
        draw_pixel_rect(draw, center_x-2, ground_y-16, 4, 3, colors["bulb_dark"])
        
    elif stage == 2:
        # 生长阶段
        # 主茎
        draw_pixel_rect(draw, center_x-2, ground_y-14, 4, 14, (139, 69, 19))
        # 大叶子
        draw_pixel_rect(draw, center_x-8, ground_y-12, 16, 8, colors["leaf"])
        draw_pixel_rect(draw, center_x-6, ground_y-16, 12, 6, colors["leaf_dark"])
        # 果实
        draw_pixel_rect(draw, center_x-5, ground_y-20, 10, 10, colors["bulb"])
        draw_pixel_rect(draw, center_x-3, ground_y-18, 6, 6, colors["bulb_dark"])
        
    else:
        # 成熟阶段
        # 主茎
        draw_pixel_rect(draw, center_x-2, ground_y-16, 4, 16, (139, 69, 19))
        # 大叶子
        draw_pixel_rect(draw, center_x-10, ground_y-14, 20, 10, colors["leaf"])
        draw_pixel_rect(draw, center_x-8, ground_y-18, 16, 8, colors["leaf_dark"])
        draw_pixel_rect(draw, center_x-6, ground_y-20, 4, 6, colors["leaf"])
        draw_pixel_rect(draw, center_x+2, ground_y-20, 4, 6, colors["leaf"])
        # 大果实
        draw_pixel_rect(draw, center_x-7, ground_y-24, 14, 14, colors["bulb"])
        draw_pixel_rect(draw, center_x-5, ground_y-22, 10, 10, colors["bulb_dark"])
        # 高光
        draw_pixel_rect(draw, center_x-3, ground_y-20, 4, 4, (
            min(255, colors["bulb"][0] + 30),
            min(255, colors["bulb"][1] + 30),
            min(255, colors["bulb"][2] + 30)
        ))
    
    return img

def create_item_icon_improved(crop_name, size=16):
    """创建改进的物品图标"""
    crop = CROPS.get(crop_name, CROPS["turnip"])
    colors = crop["colors"]
    
    img = Image.new('RGBA', (size, size), (0, 0, 0, 0))
    draw = ImageDraw.Draw(img)
    
    center = size // 2
    
    # 绘制圆形果实
    draw.ellipse([center-5, center-5, center+5, center+5], fill=colors["bulb"], outline=colors["bulb_dark"])
    # 高光
    draw.ellipse([center-3, center-3, center+1, center+1], fill=(
        min(255, colors["bulb"][0] + 40),
        min(255, colors["bulb"][1] + 40),
        min(255, colors["bulb"][2] + 40)
    ))
    
    return img

def create_seed_icon_improved(crop_name, size=16):
    """创建改进的种子图标"""
    crop = CROPS.get(crop_name, CROPS["turnip"])
    colors = crop["colors"]
    
    img = Image.new('RGBA', (size, size), (0, 0, 0, 0))
    draw = ImageDraw.Draw(img)
    
    center = size // 2
    
    # 绘制种子形状
    draw.ellipse([center-3, center-4, center+3, center+4], fill=colors["seed"], outline=(101, 67, 33))
    # 高光
    draw.ellipse([center-1, center-2, center+1, center], fill=(
        min(255, colors["seed"][0] + 30),
        min(255, colors["seed"][1] + 30),
        min(255, colors["seed"][2] + 30)
    ))
    
    return img

def create_dead_crop_improved(size=32):
    """创建改进的枯萎作物图片"""
    img = Image.new('RGBA', (size, size), (0, 0, 0, 0))
    draw = ImageDraw.Draw(img)
    
    center_x = size // 2
    ground_y = size - 4
    
    # 枯萎的茎
    draw_pixel_rect(draw, center_x-1, ground_y-8, 2, 8, (101, 67, 33))
    # 枯萎的叶子
    draw_pixel_rect(draw, center_x-6, ground_y-10, 12, 6, (139, 69, 19))
    draw_pixel_rect(draw, center_x-4, ground_y-12, 8, 4, (160, 82, 45))
    # 枯萎的果实
    draw_pixel_rect(draw, center_x-4, ground_y-14, 8, 6, (101, 67, 33))
    
    return img

def generate_all_improved():
    """生成所有改进的占位符"""
    print("=" * 60)
    print("生成改进的占位符资源...")
    print("=" * 60)
    print()
    
    # 创建目录
    crops_dir = os.path.join(ASSETS_DIR, "sprites", "crops")
    items_dir = os.path.join(ASSETS_DIR, "sprites", "items")
    os.makedirs(crops_dir, exist_ok=True)
    os.makedirs(items_dir, exist_ok=True)
    
    generated_count = 0
    
    # 生成作物精灵
    print("生成作物精灵 (改进版)...")
    for crop_name in CROPS.keys():
        for stage in range(4):
            filename = f"{crop_name}_stage{stage}.png"
            filepath = os.path.join(crops_dir, filename)
            
            img = create_crop_stage_improved(crop_name, stage)
            img.save(filepath)
            generated_count += 1
    
    # 生成枯萎作物
    dead_crop_path = os.path.join(crops_dir, "crop_dead.png")
    img = create_dead_crop_improved()
    img.save(dead_crop_path)
    generated_count += 1
    print(f"  生成: crop_dead.png (改进版)")
    
    # 生成物品图标
    print("\n生成物品图标 (改进版)...")
    for crop_name in CROPS.keys():
        # 作物收获物
        item_filename = f"{crop_name}.png"
        item_path = os.path.join(items_dir, item_filename)
        
        img = create_item_icon_improved(crop_name)
        img.save(item_path)
        generated_count += 1
        
        # 种子
        seed_filename = f"{crop_name}_seed.png"
        seed_path = os.path.join(items_dir, seed_filename)
        
        img = create_seed_icon_improved(crop_name)
        img.save(seed_path)
        generated_count += 1
    
    print(f"\n{'=' * 60}")
    print(f"✓ 共生成 {generated_count} 张改进的占位符图片")
    print(f"  - 作物精灵: {len(CROPS) * 4 + 1} 张")
    print(f"  - 物品图标: {len(CROPS) * 2} 张")
    print(f"{'=' * 60}")
    
    return generated_count

if __name__ == "__main__":
    count = generate_all_improved()
    print(f"\n改进的占位符资源生成完成!")
    print(f"这些资源比之前的版本更美观，但仍建议后期替换为真实像素艺术资源。")
