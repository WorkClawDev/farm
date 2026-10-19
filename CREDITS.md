# 致谢 / Credits

## 音乐 Music

### 程序化环境音（永久免版权）

所有背景音乐使用 FFmpeg 程序化生成（正弦波叠加 + LFO 调制 + 低通滤波），
**永久免版权，无需署名**。

| 曲目 | 文件 | 用途 | 基频 |
|------|------|------|------|
| 农场·清晨 | farm/farm_morning.ogg | 农场早6-9点 | C大调 |
| 农场·白天 | farm/farm_day.ogg | 农场早9-17点 | D大调 |
| 农场·傍晚 | farm/farm_evening.ogg | 农场晚17-20点 | A小调 |
| 农场·夜晚 | farm/farm_night.ogg | 农场夜20-6点 | G大调 |
| 村庄·白天 | village/village_day.ogg | 村庄白天 | E大调 |
| 村庄·夜晚 | village/village_night.ogg | 村庄夜晚 | C小调 |
| 森林·白天 | forest/forest_day.ogg | 森林白天 | F大调 |
| 森林·夜晚 | forest/forest_night.ogg | 森林夜晚 | Eb小调 |
| 节日·主旋律 | festival/festival_main.ogg | 节日庆典 | G大调 |
| 节日·丰收祭 | festival/festival_harvest.ogg | 丰收祭 | F大调 |

## 音效 Sound Effects

待补充 (计划使用 Freesound.org CC0 音效)

## 美术 Art Assets

- 瓦片集：使用 Godot 内置资源 + 自绘制像素风瓦片
- 物品图标 / 作物精灵：AI 生成 (MiniMax)
- 角色精灵：AI 生成 (MiniMax)，占位符使用色块
- Farm, animals, buildings and interior art: Top-Down Farm with Animals Pixel Art Asset Pack by CraftPix.net (https://craftpix.net) — via private submodule `assets/private/topdown_farm`
- Character / world tiles (existing): [Ninja Adventure Asset Pack](https://pixel-boy.itch.io/ninja-adventure-asset-pack) by Pixel-Boy / AAA
- Extra tiles / decor (existing): [Kenney](https://kenney.nl) CC0 asset packs

## 开发工具 Development Tools

- [Godot Engine 4.6](https://godotengine.org) — 游戏引擎
- [MiniMax AI](https://minimax.io) — 美术资源生成
- [PIL / Pillow](https://python-pillow.org) — 图像处理
- [FFmpeg](https://ffmpeg.org) — 音频格式转换
