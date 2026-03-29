#!/usr/bin/env python3
# /// script
# requires-python = ">=3.10"
# dependencies = [
#     "requests>=2.31.0",
# ]
# ///
"""
生成下一个待处理的资源
自动从 tracker 中读取待生成列表，生成一个资源后更新 tracker

Usage:
    uv run generate_next_asset.py --api-key sk-xxx
    uv run generate_next_asset.py --type crop --name tomato --stage 3
    uv run generate_next_asset.py --show-todo
"""

import argparse
import json
import os
import sys
from pathlib import Path
import subprocess
import time

# 路径配置
TRACKER_FILE = Path(__file__).parent / "asset_generation_tracker.json"
SKILL_DIR = Path.home() / ".openclaw" / "skills" / "game-asset-generator"
GENERATE_SCRIPT = SKILL_DIR / "scripts" / "generate_asset.py"

def load_tracker():
    """加载 tracker 文件"""
    if TRACKER_FILE.exists():
        with open(TRACKER_FILE, 'r', encoding='utf-8') as f:
            return json.load(f)
    return None

def save_tracker(tracker):
    """保存 tracker 文件"""
    with open(TRACKER_FILE, 'w', encoding='utf-8') as f:
        json.dump(tracker, f, indent=2, ensure_ascii=False)

def get_next_todo(tracker):
    """获取下一个待生成的任务"""
    todo = tracker.get("todo", {})
    completed = tracker.get("completed", {})
    
    # 优先顺序: crops stage 3 > crops other stages > items > dead_crops
    
    # 1. 检查 crops stage 3 (成熟阶段，玩家最常看到)
    crops_todo = todo.get("crops", {})
    for crop_name, stages in crops_todo.items():
        if 3 in stages:
            return {
                "type": "crop",
                "name": crop_name,
                "stage": 3
            }
    
    # 2. 检查 crops 其他阶段
    for crop_name, stages in crops_todo.items():
        if stages:
            return {
                "type": "crop",
                "name": crop_name,
                "stage": stages[0]
            }
    
    # 3. 检查 items
    items_todo = todo.get("items", {})
    for crop_name, types in items_todo.items():
        if types:
            return {
                "type": types[0],  # item or seed
                "name": crop_name
            }
    
    # 4. 检查 dead_crops
    dead_todo = todo.get("dead_crops", [])
    if dead_todo:
        return {
            "type": "crop",
            "name": dead_todo[0],
            "stage": "dead"
        }
    
    return None

def mark_completed(tracker, task):
    """标记任务为已完成"""
    todo = tracker.get("todo", {})
    completed = tracker.get("completed", {})
    
    if task["type"] == "crop":
        crop_name = task["name"]
        stage = task["stage"]
        
        # 从 todo 中移除
        if crop_name in todo.get("crops", {}):
            if stage in todo["crops"][crop_name]:
                todo["crops"][crop_name].remove(stage)
                if not todo["crops"][crop_name]:
                    del todo["crops"][crop_name]
        
        # 添加到 completed
        if "crops" not in completed:
            completed["crops"] = {}
        if crop_name not in completed["crops"]:
            completed["crops"][crop_name] = []
        if stage not in completed["crops"][crop_name]:
            completed["crops"][crop_name].append(stage)
    
    elif task["type"] in ["item", "seed"]:
        crop_name = task["name"]
        item_type = task["type"]
        
        # 从 todo 中移除
        if crop_name in todo.get("items", {}):
            if item_type in todo["items"][crop_name]:
                todo["items"][crop_name].remove(item_type)
                if not todo["items"][crop_name]:
                    del todo["items"][crop_name]
        
        # 添加到 completed
        if "items" not in completed:
            completed["items"] = {}
        if crop_name not in completed["items"]:
            completed["items"][crop_name] = []
        if item_type not in completed["items"][crop_name]:
            completed["items"][crop_name].append(item_type)

def show_todo_list(tracker):
    """显示待生成列表"""
    todo = tracker.get("todo", {})
    completed = tracker.get("completed", {})
    
    print("=" * 60)
    print("📋 资源生成待办列表")
    print("=" * 60)
    
    # Crops
    crops_todo = todo.get("crops", {})
    crops_completed = completed.get("crops", {})
    total_crops = sum(len(stages) for stages in crops_todo.values()) + sum(len(stages) for stages in crops_completed.values())
    done_crops = sum(len(stages) for stages in crops_completed.values())
    
    print(f"\n🌱 作物精灵: {done_crops}/{total_crops}")
    for crop, stages in sorted(crops_todo.items()):
        completed_stages = crops_completed.get(crop, [])
        status = "✓" if not stages else f"待生成: {stages}"
        print(f"  {crop}: {completed_stages} {status}")
    
    # Items
    items_todo = todo.get("items", {})
    items_completed = completed.get("items", {})
    total_items = sum(len(types) for types in items_todo.values()) + sum(len(types) for types in items_completed.values())
    done_items = sum(len(types) for types in items_completed.values())
    
    print(f"\n📦 物品图标: {done_items}/{total_items}")
    for crop, types in sorted(items_todo.items()):
        completed_types = items_completed.get(crop, [])
        status = "✓" if not types else f"待生成: {types}"
        print(f"  {crop}: {completed_types} {status}")
    
    # Dead crops
    dead_todo = todo.get("dead_crops", [])
    dead_completed = completed.get("dead_crops", [])
    total_dead = len(dead_todo) + len(dead_completed)
    done_dead = len(dead_completed)
    
    print(f"\n🥀 枯萎作物: {done_dead}/{total_dead}")
    if dead_todo:
        print(f"  待生成: {dead_todo}")
    
    print(f"\n总计: {done_crops + done_items + done_dead}/{total_crops + total_items + total_dead}")
    print("=" * 60)

def generate_single(task, api_key):
    """生成单个资源"""
    cmd = [
        "python3", str(GENERATE_SCRIPT),
        "--type", task["type"],
        "--name", task["name"]
    ]
    
    if task["type"] == "crop":
        cmd.extend(["--stage", str(task["stage"])])
    
    if api_key:
        cmd.extend(["--api-key", api_key])
    
    print(f"\n🎨 正在生成: {task['type']} - {task['name']}" + 
          (f" stage {task['stage']}" if task.get('stage') is not None else ""))
    print(f"命令: {' '.join(cmd)}\n")
    
    try:
        result = subprocess.run(cmd, capture_output=True, text=True, timeout=180)
        print(result.stdout)
        if result.stderr:
            print("stderr:", result.stderr, file=sys.stderr)
        return result.returncode == 0
    except subprocess.TimeoutExpired:
        print("❌ 超时", file=sys.stderr)
        return False
    except Exception as e:
        print(f"❌ 错误: {e}", file=sys.stderr)
        return False

def main():
    parser = argparse.ArgumentParser(description="生成下一个游戏资源")
    parser.add_argument("--api-key", "-k", help="DashScope API Key")
    parser.add_argument("--type", "-t", choices=["crop", "item", "seed"], help="强制指定类型")
    parser.add_argument("--name", "-n", help="强制指定名称")
    parser.add_argument("--stage", "-s", type=int, choices=[0, 1, 2, 3], help="强制指定阶段")
    parser.add_argument("--show-todo", action="store_true", help="显示待办列表")
    parser.add_argument("--dry-run", action="store_true", help="仅显示下一个任务，不生成")
    
    args = parser.parse_args()
    
    # 加载 tracker
    tracker = load_tracker()
    if not tracker:
        print("❌ 无法加载 tracker 文件", file=sys.stderr)
        sys.exit(1)
    
    # 显示待办列表
    if args.show_todo:
        show_todo_list(tracker)
        return
    
    # 确定任务
    if args.type and args.name:
        task = {
            "type": args.type,
            "name": args.name
        }
        if args.stage is not None:
            task["stage"] = args.stage
    else:
        task = get_next_todo(tracker)
    
    if not task:
        print("\n✅ 所有资源已生成完成！")
        return
    
    # 显示任务
    print(f"\n📌 下一个任务:")
    print(f"  类型: {task['type']}")
    print(f"  名称: {task['name']}")
    if 'stage' in task:
        print(f"  阶段: {task['stage']}")
    
    # 仅显示不生成
    if args.dry_run:
        return
    
    # 生成
    success = generate_single(task, args.api_key)
    
    if success:
        # 更新 tracker
        mark_completed(tracker, task)
        save_tracker(tracker)
        print(f"\n✅ 已更新 tracker")
        
        # 显示进度
        show_todo_list(tracker)
    else:
        print(f"\n❌ 生成失败，tracker 未更新")
        sys.exit(1)

if __name__ == "__main__":
    main()
