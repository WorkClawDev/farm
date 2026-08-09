# 地图数据

地图内容以 `.tscn/.tres` 为唯一权威来源。

- 农场内容场景：`res://src/world/maps/content/FarmMap.tscn`
- 农场配置与资源库：`res://data/maps/farm/`
- `farm_layout.json`：仅作为确定性迁移测试 fixture 保留，不参与运行时加载。

其他地图在逐张迁移完成前仍保持原有运行方式，不应建立 JSON 与场景双写。
