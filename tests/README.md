# 🧪 测试文档

## 测试结构

```
tests/
├── README.md                    # 测试文档
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
1. 安装 Gut 插件 (Godot 单元测试框架)
2. 在编辑器中运行测试场景

### 方法2: 使用命令行
```bash
# 运行所有测试
godot --script tests/run_tests.gd

# 运行集成测试
godot --script tests/integration/test_game_startup.gd
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
2. 继承 `GutTest` 类
3. 使用 `before_each()` 和 `after_each()` 设置/清理
4. 编写测试函数，使用 `assert_*` 断言
5. 在 `run_tests.gd` 中添加测试调用

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
