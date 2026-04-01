# 🧪 测试文档

## 测试结构

```
tests/
├── README.md                    # 测试文档
├── gut/                         # GUT 测试
│   ├── test_smoke.gd
│   ├── test_time_manager.gd
│   ├── test_inventory_manager.gd
│   └── test_save_manager.gd
├── run_tests.gd                 # 测试运行器
├── unit/                        # 单元测试
│   ├── test_time_manager.gd    # 时间管理器测试
│   ├── test_inventory.gd       # 背包系统测试
│   └── test_cooking_system.gd  # 烹饪系统测试
└── integration/                 # 集成测试
    └── test_game_startup.gd    # 游戏启动测试
```

## 运行测试

### 方法1: 使用 Godot 编辑器
1. 项目已安装 Gut 插件 (`addons/gut`)
2. 打开 Godot 后在插件里启用/运行 GUT

### 方法2: 使用命令行
```bash
# 运行所有测试
godot --script tests/run_tests.gd

# 运行集成测试
godot --script tests/integration/test_game_startup.gd

# 运行 GUT smoke test
godot --headless --path . -s res://addons/gut/gut_cmdln.gd -gconfig=res://.gutconfig.json -gexit
```

### 方法3: 手动验证
1. 打开 Godot 项目
2. 运行主场景 (Farm.tscn)
3. 验证游戏可以正常启动

## 测试覆盖

### 单元测试
- ✅ TimeManager - 时间、季节、暂停/恢复
- ✅ Inventory - 添加、移除、检查物品
- ✅ CookingSystem - 配方加载、学习

### GUT 核心测试
- ✅ TimeManager - 默认状态、跨天/跨季、存档回读
- ✅ InventoryManager - 堆叠、移除、存档回读
- ✅ SaveManager - 非法槽位、创建/删除存档、游戏时长格式化

### 集成测试
- ✅ 数据文件完整性
- ✅ 场景文件完整性
- ✅ 脚本文件完整性
- ✅ 项目配置正确性

## 手动测试清单

### 核心功能
- [ ] 玩家可以移动
- [ ] 玩家可以使用工具
- [ ] 时间正常流逝
- [ ] 可以打开背包
- [ ] 可以打开菜单

### 农场系统
- [ ] 可以耕地
- [ ] 可以种植种子
- [ ] 可以浇水
- [ ] 作物会生长
- [ ] 可以收获作物

### 经济系统
- [ ] 可以出售作物获得金钱
- [ ] 可以在商店购买种子

### 社交系统
- [ ] 可以与NPC对话
- [ ] 可以提升好感度

### 探索系统
- [ ] 可以钓鱼
- [ ] 可以接受任务

## 添加新测试

1. 在 `tests/unit/` 创建新的测试文件
2. 如果使用 GUT，在 `tests/gut/` 创建文件并继承 `GutTest`
3. 使用 `before_each()` 和 `after_each()` 设置/清理
4. 编写测试函数，使用 `assert_*` 断言
5. GUT 测试由 `.gutconfig.json` 自动发现；旧测试则继续在 `run_tests.gd` 中添加调用

## 示例

```gdscript
extends GutTest

func before_each() -> void:
    # 每个测试前的设置
    pass

func after_each() -> void:
    # 每个测试后的清理
    pass

func test_example() -> void:
    assert_true(true, "示例测试")
    assert_eq(1 + 1, 2, "数学应该正确")
```
