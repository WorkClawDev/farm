# 🎨 游戏资源下载指南

## 推荐下载的资源包

### 必需资源（高优先级）

#### 1. Kenney Farming Pack ⭐
- **链接**: https://kenney.nl/assets/farming-pack
- **内容**: 农场相关图标、作物、工具
- **许可**: CC0 (完全免费商用)
- **用途**: 作物、工具、农场图标

#### 2. 16x16 RPG Character Pack
- **链接**: https://mathew-dolan.itch.io/16x16-rpg-character-pack
- **内容**: 像素角色精灵
- **许可**: CC0
- **用途**: 玩家和NPC角色

#### 3. Farming Crop Pack
- **链接**: https://legnops.itch.io/farming-crop-pack
- **内容**: 作物生长阶段精灵
- **许可**: CC0
- **用途**: 作物生长动画

### 可选资源（中优先级）

#### 4. Pixel Art Top-Down Basic
- **链接**: https://cainos.itch.io/pixel-art-top-down-basic
- **内容**: 俯视角瓦片地图
- **用途**: 农场、村庄地图瓦片

#### 5. Modern Interiors
- **链接**: https://limezu.itch.io/moderninteriors
- **内容**: 室内瓦片
- **用途**: 房屋内部

#### 6. Caz Pixel Free
- **链接**: https://cazwolf.itch.io/caz-pixel-free
- **内容**: 角色和物品图标
- **用途**: NPC、物品图标

## 下载步骤

### 从 Kenney.nl 下载（推荐）
1. 打开链接
2. 点击 "Download" 按钮
3. 文件会直接下载（无需登录）

### 从 itch.io 下载
1. 打开链接
2. 点击 "Download" 按钮
3. 如果需要，选择 "No thanks, just take me to the downloads"
4. 选择免费版本下载
5. 解压 ZIP 文件

## 下载后的整理

将下载的资源放到以下目录：
```
pastoral-tales/
└── assets/
    └── downloads/
        ├── kenney_farming/
        ├── character_pack/
        └── crop_pack/
```

然后运行整理脚本：
```bash
python3 scripts/organize_assets.py
```

## 当前项目已有资源

- ✅ 玩家精灵 (占位)
- ✅ NPC精灵 (占位)
- ✅ 作物精灵 (占位)
- ✅ 工具精灵 (占位)
- ✅ 瓦片精灵 (占位)

## 资源命名规范

### 精灵图
- `{name}_walk_{direction}.png` - 行走动画
- `{name}_idle_{direction}.png` - 站立动画
- `crop_{name}_stage{0-3}.png` - 作物生长阶段

### 瓦片
- `tile_{type}_{variant}.png` - 瓦片图
- `tile_grass_01.png` - 草地变体1

### 物品
- `item_{name}.png` - 物品图标
- `tool_{name}.png` - 工具图标
