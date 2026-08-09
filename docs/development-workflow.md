# Pastoral Tales 稳定交付流程

## 架构边界

- `MainMenu.tscn` 仍是稳定启动入口，正式地图场景路径保持不变，旧存档无需迁移场景路径。
- 跨整个应用且相互隔离的服务才允许成为 Autoload。会话期可变系统放入 `GameSession`；当前季节与天气已经作为首个试点迁入。
- 地图内容以 `src/world/maps/content/*Map.tscn` 与对应 `.tres` 为唯一权威；外层地图场景只保留玩家、HUD、NPC、交互和玩法逻辑。
- 正式地图禁止重新引入弃用的 `TileMap`，必须使用独立 `TileMapLayer`。

## 缩小改动

每个交付只允许一个主目标，并按以下顺序切片：

1. 数据/资源契约；
2. 一张内容地图；
3. 外层运行场景接线；
4. 该地图的校验和运行验收；
5. 完整检查与导出。

不要在地图交付中顺手重写任务、经济或 UI 系统。跨域问题记录到 `docs/todo.md`，另开交付处理。`tools/verify_delivery_contract.py` 会阻止 Autoload 数量回涨、旧 `TileMap` 回归以及地图内容场景断链。

## 本地检查

Windows：

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/check.ps1
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/export.ps1 -Mode pack
```

Linux/WSL：

```bash
bash scripts/check.sh
bash scripts/export.sh pack
```

发布模板已安装时运行 `release`，生成 Windows 可执行文件。`pack` 不依赖平台模板，用于每次修改后的快速导出图检查。

## 提交门槛

必须依次满足：当前地图校验通过、当前地图无头启动无错误、`scripts/check.sh` 全绿、PCK 导出无脚本错误。CI 会重复完整检查并导出 Windows artifact；任何一步失败都不得提交或合并。
