#!/usr/bin/env python3
"""
田园物语 - 资源下载脚本
尝试从多个来源下载开源游戏资源
"""

import urllib.request
import urllib.error
import os
import ssl
import time

# 禁用 SSL 验证 (某些网站需要)
ssl._create_default_https_context = ssl._create_unverified_context

# 项目路径
PROJECT_ROOT = "/home/admin/gameboy-workspace/pastoral-tales"
DOWNLOAD_DIR = os.path.join(PROJECT_ROOT, "assets", "downloaded")

# 确保下载目录存在
os.makedirs(DOWNLOAD_DIR, exist_ok=True)
os.makedirs(os.path.join(DOWNLOAD_DIR, "crops"), exist_ok=True)
os.makedirs(os.path.join(DOWNLOAD_DIR, "ui"), exist_ok=True)
os.makedirs(os.path.join(DOWNLOAD_DIR, "characters"), exist_ok=True)

# 资源 URL 列表
RESOURCE_URLS = {
    # LPC (Liberated Pixel Cup) 资源
    "lpc_farming": {
        "url": "https://raw.githubusercontent.com/LiberatedPixelCup/lpc-farming/master/farming.png",
        "filename": "lpc_farming.png",
        "category": "crops"
    },
    
    # Kenney 资源 (通过 GitHub)
    "kenney_rpg": {
        "url": "https://raw.githubusercontent.com/kenneynl/kenney-rpg/main/Spritesheet/rpg_spritesheet.png",
        "filename": "kenney_rpg.png",
        "category": "characters"
    },
    
    # 示例作物精灵
    "sample_crops": {
        "url": "https://raw.githubusercontent.com/game-icons/icons/master/crops.png",
        "filename": "sample_crops.png",
        "category": "crops"
    },
}

def download_file(url, filepath, timeout=30):
    """下载文件"""
    try:
        headers = {
            'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36'
        }
        request = urllib.request.Request(url, headers=headers)
        
        with urllib.request.urlopen(request, timeout=timeout) as response:
            if response.status == 200:
                with open(filepath, 'wb') as f:
                    f.write(response.read())
                return True, f"下载成功 ({os.path.getsize(filepath)} bytes)"
            else:
                return False, f"HTTP {response.status}"
    except urllib.error.HTTPError as e:
        return False, f"HTTP Error {e.code}: {e.reason}"
    except urllib.error.URLError as e:
        return False, f"URL Error: {e.reason}"
    except Exception as e:
        return False, f"Error: {str(e)}"

def download_all():
    """下载所有资源"""
    print("=" * 60)
    print("田园物语 - 资源下载脚本")
    print("=" * 60)
    print()
    
    success_count = 0
    failed_count = 0
    
    for name, info in RESOURCE_URLS.items():
        url = info["url"]
        filename = info["filename"]
        category = info["category"]
        
        # 构建保存路径
        category_dir = os.path.join(DOWNLOAD_DIR, category)
        os.makedirs(category_dir, exist_ok=True)
        filepath = os.path.join(category_dir, filename)
        
        print(f"[{name}]")
        print(f"  URL: {url}")
        print(f"  保存到: {filepath}")
        
        # 检查是否已存在
        if os.path.exists(filepath):
            print(f"  状态: 已存在 (跳过)")
            print()
            continue
        
        # 下载
        print(f"  下载中...", end=" ", flush=True)
        success, message = download_file(url, filepath)
        
        if success:
            print(f"✓ {message}")
            success_count += 1
        else:
            print(f"✗ {message}")
            failed_count += 1
        
        print()
        time.sleep(0.5)  # 避免请求过快
    
    print("=" * 60)
    print(f"下载完成: {success_count} 成功, {failed_count} 失败")
    print(f"资源保存位置: {DOWNLOAD_DIR}")
    print("=" * 60)
    
    return success_count, failed_count

def create_placeholder_readme():
    """创建说明文件"""
    readme_path = os.path.join(DOWNLOAD_DIR, "README.md")
    with open(readme_path, 'w', encoding='utf-8') as f:
        f.write("""# 下载的资源

此目录包含从网络下载的开源游戏资源。

## 许可说明

下载的资源可能受不同许可证约束，请查看原始来源:
- LPC 资源: CC-BY-SA 3.0 / GPL 3.0
- Kenney 资源: CC0 (公共领域)

## 使用建议

1. 检查每个资源的许可证
2. 确保符合项目需求
3. 必要时替换为自定义资源

## 手动下载推荐

如果自动下载失败，请手动访问:
- https://opengameart.org/ (搜索 "farming", "crops", "pixel art")
- https://kenney.nl/assets (免费资源)
- https://itch.io/game-assets/free (免费资源)

""")
    print(f"创建说明文件: {readme_path}")

if __name__ == "__main__":
    success, failed = download_all()
    create_placeholder_readme()
    
    print()
    print("提示: 如果下载失败，请手动访问以下网站获取资源:")
    print("  1. https://opengameart.org/ (搜索 'farming crops pixel art')")
    print("  2. https://kenney.nl/assets (免费商用资源)")
    print("  3. https://itch.io/game-assets/free (免费资源)")
