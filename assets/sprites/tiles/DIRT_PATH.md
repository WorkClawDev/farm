# 土路（玩家自铺）autotile 图集

文件：
- `dirt_path_atlas.png`：384×384，**6 列 × 6 行，每格 64×64，无间距**，RGBA，36 格全满。每格和源图 `assets/source_art/ai_samples/processed/x4/path_*.png` 逐像素一致（脚本里有校验）。
- `dirt_path_atlas_alpha.png`：同一网格，只把瓦片里的草像素（6 个草色）改成全透明，土和路沿像素不变。**农场推荐用这张**，理由见「接入注意 1」。
- `dirt_path_atlas.json`：格子坐标、mask4 表、对角细化规则（机器可读）。
- 预览：`playtest/screenshots/dirt_path_atlas_preview.png`（①AI 草底 ②标注瓦片名 ③游戏 Kenney 草底+不透明图集 ④Kenney 草底+透明版）。
- 重建脚本：`/workspace/farm_asset_candidates/dirt_path/build_atlas.py`（`python3 build_atlas.py`，加 `-v` 打印每格选了什么）。

## 命名含义（已按 tools/path_edges.py 和图核对过）
- `edge_X` / `outer_XY`：X、Y 是**长草的那一侧**。`edge_n` = 北边是草（路块的北沿）；`outer_nw` = 北和西是草（路块的西北角）。
- `inner_XY`：XY 那个**角上咬进一小块草**（四邻都是路，只有那个对角不是路）。
- `bend_AB`、`end_X`：A、B、X 是**路的出口方向**。`end_n` = 只往北通，东南西三面是草。
- `t_X`：X 是**茎的方向**，缺口在对面。`t_n` = 通北、东、西，南边是草。
- `h` / `v`：一字横路 / 竖路。`cross`：十字。`dirt_a/b/c`：纯土内部。

## 图集坐标 [列, 行]
| 行 | 列0 | 列1 | 列2 | 列3 | 列4 | 列5 |
|---|---|---|---|---|---|---|
| 0 | dirt_a | dirt_b | dirt_c | cross | h | h_b |
| 1 | v | v_b | end_n | end_e | end_s | end_w |
| 2 | bend_es | bend_sw | bend_wn | bend_ne | t_n | t_e |
| 3 | t_s | t_w | edge_n | edge_e | edge_s | edge_w |
| 4 | edge_n_b | edge_e_b | edge_s_b | edge_w_b | outer_nw | outer_ne |
| 5 | outer_se | outer_sw | inner_nw | inner_ne | inner_se | inner_sw |

（表里省略了前缀 `path_`。）region = `Rect2(col*64, row*64, 64, 64)`。

## 第一步：四邻掩码（N=1，E=2，S=4，W=8；y 向南增大）
| mask | 通向 | 瓦片 | 坐标 | 对角细化 |
|---|---|---|---|---|
| 0 | 孤立 | end_s（兜底） | [4,1] | 无 |
| 1 | N | end_n | [2,1] | 无 |
| 2 | E | end_e | [3,1] | 无 |
| 4 | S | end_s | [4,1] | 无 |
| 8 | W | end_w | [5,1] | 无 |
| 5 | N S | v / v_b | [0,1] / [1,1] | 无 |
| 10 | E W | h / h_b | [4,0] / [5,0] | 无 |
| 6 | E S | bend_es | [0,2] | SE 是路 → outer_nw [4,4] |
| 12 | S W | bend_sw | [1,2] | SW 是路 → outer_ne [5,4] |
| 9 | W N | bend_wn | [2,2] | NW 是路 → outer_se [0,5] |
| 3 | N E | bend_ne | [3,2] | NE 是路 → outer_sw [1,5] |
| 14 | E S W | t_s | [0,3] | SE 或 SW 是路 → edge_n / edge_n_b [2,3]/[0,4] |
| 13 | N S W | t_w | [1,3] | NW 或 SW 是路 → edge_e / edge_e_b [3,3]/[1,4] |
| 11 | N E W | t_n | [4,2] | NE 或 NW 是路 → edge_s / edge_s_b [4,3]/[2,4] |
| 7 | N E S | t_e | [5,2] | NE 或 SE 是路 → edge_w / edge_w_b [5,3]/[3,4] |
| 15 | 四向 | 看对角，见下 | | |

mask 15 按缺了几个对角（不是路的对角）来选：
| 缺几个 | 瓦片 |
|---|---|
| 0 | 内部 dirt_a/b/c [0,0]/[1,0]/[2,0] |
| 1 | inner_<缺的那个角>：nw [2,5]、ne [3,5]、se [4,5]、sw [5,5] |
| 2 | 内部 dirt（没有「双内角」瓦片） |
| 3、4 | cross [3,0] |

**孤立格兜底**：没有四面都是草的瓦片，用 `end_s`（北、东、西三面草，只有南边是平的）。看过预览，比 cross / 纯土好得多；南沿平口通常也会被站在格子上的角色脚下挡住。玩家再铺一格，它马上会变成正常端头/一字路。

**和需求描述不同的两处（按实图定的）**：
- 三邻 + 只有一个对角是路，用的是**直边**，不是 T。用 T 的话两格 T 的内角会在土里拼出一个草洞（预览里试过，很明显）；直边只是在交汇处留个方角，看起来自然。
- 四邻 + 缺两个对角（典型：一字路接进大土块的边），用内部纯土，不用单内角或十字：单内角左右不对称，十字会出两个草洞。

## 变体交替
- 两个变体（h/h_b、v/v_b、edge_X/edge_X_b）：`posmod(x + y, 2)`，0 取无 `_b`，1 取 `_b`。两套轮廓端点相同，随便相邻都接得上。
- 内部三变体：`["path_dirt_a","path_dirt_b","path_dirt_c"][posmod(x + 2*y, 3)]`，上下左右相邻永远不重样。
- 角、弯、T、十字、端头、内角只有一张。

## 选瓦片伪代码（GDScript 风格）
```gdscript
const N := 1; const E := 2; const S := 4; const W := 8
const DIRT3 := ["path_dirt_a", "path_dirt_b", "path_dirt_c"]

func pick_tile(c: Vector2i) -> String:
	var n := is_path(c + Vector2i(0, -1)); var e := is_path(c + Vector2i(1, 0))
	var s := is_path(c + Vector2i(0, 1));  var w := is_path(c + Vector2i(-1, 0))
	var nw := is_path(c + Vector2i(-1, -1)); var ne := is_path(c + Vector2i(1, -1))
	var sw := is_path(c + Vector2i(-1, 1));  var se := is_path(c + Vector2i(1, 1))
	var m := (N if n else 0) | (E if e else 0) | (S if s else 0) | (W if w else 0)
	var b := "_b" if posmod(c.x + c.y, 2) == 1 else ""
	match m:
		15:
			var miss: Array[String] = []
			for k in ["nw", "ne", "sw", "se"]:
				if not {"nw": nw, "ne": ne, "sw": sw, "se": se}[k]: miss.append(k)
			if miss.size() == 0 or miss.size() == 2: return DIRT3[posmod(c.x + 2 * c.y, 3)]
			if miss.size() == 1: return "path_inner_" + miss[0]
			return "path_cross"
		14: return ("path_edge_n" + b) if (se or sw) else "path_t_s"
		13: return ("path_edge_e" + b) if (nw or sw) else "path_t_w"
		11: return ("path_edge_s" + b) if (ne or nw) else "path_t_n"
		7:  return ("path_edge_w" + b) if (ne or se) else "path_t_e"
		6:  return "path_outer_nw" if se else "path_bend_es"
		12: return "path_outer_ne" if sw else "path_bend_sw"
		9:  return "path_outer_se" if nw else "path_bend_wn"
		3:  return "path_outer_sw" if ne else "path_bend_ne"
		5:  return "path_v" + b
		10: return "path_h" + b
		1:  return "path_end_n"
		2:  return "path_end_e"
		4:  return "path_end_s"
		8:  return "path_end_w"
	return "path_end_s"  # 0：孤立格兜底
```
名字转坐标直接读 `dirt_path_atlas.json` 的 `tiles`，或者把上面的坐标表抄成常量字典。

## 接入说明（给 Grok Build）
1. **草色不一致，农场用透明版。** 这套瓦片里的草是 AI 样张的深绿（约 RGB 70,140,33），农场地面现在是 Kenney `grass_64.png`（约 132,198,105，浅很多）。不透明版直接铺上去，每格路外圈会是一圈深绿方框（预览③）。`dirt_path_atlas_alpha.png` 把草像素抠成透明，下面露出地图自己的草，效果见预览④。两张网格完全一样，换图不用改坐标。
2. 用 `Texture2D` 加载图集，每格一个 `AtlasTexture`，`region = Rect2(col*64, row*64, 64, 64)`。也可以用 TileSet atlas source（texture_region_size 64×64，无 separation/margin）。
3. 过滤用 Nearest。项目已经是 `default_texture_filter=0`，单独的节点别再改成 Linear。新 PNG 第一次要让 Godot 导入生成 `.import`（编辑器打开一次或 `--headless --import`），`.import` 跟图一起提交。
4. 路画在地面层：在草地之上，低于田地/作物、玩家和所有道具，不参与 Y 排序，也不加碰撞（需求第 5 条）。
5. 铺一格或拆一格后，重新选**这一格和周围 8 格**里所有路格的瓦片（对角也算，因为 outer/edge/inner 要看对角）。
6. 格子坐标和农场的 64px 格对齐；`is_path()` 对地图外、房子、田地等一律返回 false。
7. 存档只存格子坐标列表，瓦片读档后重新算，不用存瓦片名。

## 已知限制（来自 ai_samples/README.md 和这次预览）
- 不是完整 47-blob：没有「双内角」瓦片，宽路上两个相邻内角会退回纯土；三邻只有一个对角时用直边，交汇处有一个方角。
- 没有孤立单格专用瓦片，用 end_s 兜底。
- 一字路只有两套轮廓，长直道仔细看有一点 2 格周期的起伏。
- 透明版边缘的草丛是透明的，路沿只剩深色潮边，没有不透明版那种草丛探进土里的细节。

## 来源和授权
自制素材：GenerateImage 生成的 AI 样张取纹理，加 `assets/source_art/ai_samples/tools/path_edges.py` 手绘 16px 像素后放大 ×4（最近邻）。不涉及第三方素材，没有外部授权，**不需要署名**，不用改 `assets/third_party/` 下的 ATTRIBUTION。
