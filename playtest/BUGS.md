# 《田园物语》试玩 Bug 记录

## 2026-10-17 验证提交 502fee5（作物缩放 / HUD 透明度 / 耕地层级）
截图目录：`playtest/screenshots/`，运行日志：`playtest/run.log`
开局：主菜单 → 创建农场 → 空槽 农场 3 → 创建新农场

### BUG-1 角色走上土路会被路面盖住【高】
- 步骤：新开局，按 S 约 0.6 秒走到出生点下方的土路。
- 期望：角色画在路面之上。
- 实际：脚踩路边时只露出头发；完全踩在路上时角色消失。草地上正常。
- 截图：02_after_move_player_tiny.png、03b_player_head_only_zoom.png、08_near_barn.png、15_player_hidden_on_path.png；正常对照 12_player_visible_grass.png

### BUG-2 锄地有提示但看不到耕地格；空草地锄地无效【高】
- 步骤：走到围栏田地上方中间的门口，按 E/Space（默认装备锄头）。
- 期望：出现耕好的土格和格子描边。
- 实际：弹出“土地已翻好”，但看不到任何耕地格或描边；角色站在田地里也会被遮住。在空草地上锄地完全没反应，也没有提示。
- 截图：06_tilled.png、16_tilled_toast_but_invisible.png、05_player_in_field_hidden.png、11_hoe_on_grass_no_effect.png
- 怀疑和本次 `TilledArea`/`_ground` 设置 `z_index = -1` 有关。

### BUG-3 作物画成了不透明白色方块【中】
- 步骤：接 BUG-2，按 1 选芜菁种子，按 Space 播种（提示“已播种”，种子从 15 变成 14）。
- 期望：作物精灵大约占格子 85%，背景透明，下面有耕地。
- 实际：大小正常（约一格），但画成了带白/米色底的芜菁图标，看起来像背包图标，而且压在围栏门上，下面没有耕地。
- 截图：17_plant_attempt.png
- 备注：开局背包里没有番茄/玉米种子，后续生长阶段没测。

### BUG-4 Toast 提示挡住右上角日期面板【低】
- 步骤：锄地或播种时触发提示。
- 实际：“土地已翻好”/“已播种”盖在日期和时间上。
- 截图：06_tilled.png、17_plant_attempt.png

### BUG-5 进不了围栏田地【中】
- 在田地门口按 E 会锄地，不会开门，角色也走不进去。

### BUG-6 “[E]钓鱼”提示被角色压住，且按键不一致【低】
- 屏幕上写“[E]钓鱼”，日志写 “Press F to fish here”；提示还被画在角色下面。
- 截图：13_on_path.png

### BUG-7 选农场 3 但存档写进了槽位 2【中，待复现】
- 选空槽 农场 3 新建，日志显示 `[SaveManager] Saved slot 2`，可能覆盖农场 2。

### 文档不一致（README 操作说明）
- 1–6 选的是物品栏里的物品，不是工具；工具用 Q/R 切换。
- README 里 E 同时写了“交互”和“下一个工具”，游戏里 E 是使用工具。
- I 打开的是农场手册的制作页，不是背包；底栏写的是 J 打开手册。

### 本次通过的部分
- HUD 面板已经半透明，能透出后面的建筑和池塘（01_farm_start.png）。
- 没有崩溃，日志里没有脚本错误（只有 ALSA 音频驱动的报错）。

## 2026-10-17 复测本地提交 e8c0a9e（键盘实玩，1280×720）
日志：`playtest/run_retest.log`，截图前缀 `retest_`
- BUG-1 通过：角色在土路上、栅栏边都完整显示（retest_01b_path_down.png、retest_01d_by_fence.png）。
- BUG-2 通过：耕地格颜色较深、有描边，角色站在上面（retest_02_e_hoed.png、retest_03_b_three.png）。耕地和田地底色差别不大，主要靠描边看出来。
- BUG-3 通过：芜菁背景透明、约一格大、在田里；睡到第 5 天，各生长阶段都没有白边（retest_11_growth.png、retest_13_in_field_grown.png）。没浇水的长得慢。
- BUG-5 通过：能从上方中间的门进田；左、右、下三边围栏没测。
- BUG-4 未修：Toast 仍叠在右上角日期/金币面板上（retest_03_a_plant.png、retest_03_d_water.png）。

### BUG-8 床边自动弹出休息框，默认选取消【低，UX】
- 步骤：走进床的触发区。
- 实际：一走进去就自动弹出休息框，默认焦点在“取消”，按键容易误取消（日志里有 Sleep canceled）；在床边按 Space/E 没反应。
- 期望：按 Space/E 才弹出，或者默认选“确认”。
- 截图：retest_07_sleep_dialog.png

### BUG-9 在田外锄地没有任何反馈【低，UX】
- 在草地或土路上锄地什么都不发生，也不提示（retest_04_c_hoe_grass.png）。建议提示“这里不能耕地”。

### 观察（未定性）
- 左上角的任务面板会盖住田地左上一角（retest_13_in_field_grown.png）。
- 水壶用 2 次就空了，提示“无法浇水或水壶已空”，没测怎么加水。
- 收获流程没测，任务“收获1个芜菁”仍是 0/1。

## 2026-10-18 复测 BUG-4（UIManager.gd 的改动还没提交）
日志：`playtest/run_bug4.log`，截图前缀 `bug4_`，用的是测试存档槽 3
- BUG-4 通过：1–4 条 Toast 在屏幕上方居中，不挡日期/金币、任务面板、工具面板、物品栏和角色（bug4_01_hoe_toast.png、bug4_02_plant_toast.png、bug4_07_empty_can_stack.png）。

### BUG-10 Toast 叠加没有上限，会盖住角色和物品栏【中】
- 步骤：进田后按 Q 切到鱼竿，3.5 秒内连按 Space 约 14 次。
- 实际：11 条“选择种子或合适的工具”从上往下排，6 条以上就压到角色，第 11 条压到物品栏。
- 期望：最多显示 3–4 条，或者把重复的提示合并成一条。
- 截图：bug4_04_water_stack.png

### BUG-11 HUD 每帧报脚本错误：体力函数名不对【中】
- 日志：`SCRIPT ERROR: Invalid call. Nonexistent function 'get_stamina_percentage' in base 'Node (StaminaManager.gd)'`，位置 HUD.gd:30 `_process`，本局出现 2501 次。
- 原因：`src/ui/hud/HUD.gd:30` 调用的是 `get_stamina_percentage()`，但 `src/core/systems/StaminaManager.gd:58` 里的函数叫 `get_stamina_percent()`。体力条可能因此没有更新。
- 备注：这行代码从最初的快照就有，前两次的日志里没出现过，可能只有某些情况下才会走到。

### 备注
- 按 Q 会切到鱼竿而不是水壶，要按两次 R 才能切到水壶。工具的切换顺序可能需要确认一下。

## 2026-10-18 复测 BUG-10 / BUG-11（本地提交 fb969c8、7700558）
日志：`playtest/run_bug10_11.log`，截图前缀 `bug10_` / `bug11_`，用的是测试存档槽 3
- BUG-10 通过：拿鱼竿连按 14 次只显示 1 条“选择种子或合适的工具 ×14”（bug10_burst_mid.png、bug10_burst_end.png）。混着触发不同提示时，同屏最多 4 条，重复的会原地累加计数，顺序不变（bug10_cap_a.png、bug10_cap_b.png）。大约 4 秒内全部淡出。不挡任务面板、日期面板、物品栏、工具面板和角色。
- BUG-11 通过：日志里 `get_stamina_percentage` 出现 0 次，也没有 SCRIPT ERROR。左下角的“体力 N/100”会随着干活下降（66→58→34→10），见 bug10_cap_b.png、bug11_mid_hoe.png、bug11_after_hoeing2.png。

### BUG-12 水壶永远倒不空，重复浇同一格也会成功【中，待确认设计】
- 步骤：装备水壶，对着同一株作物按 Space 20 次以上。
- 实际：每次都显示“浇水完成”（×14），水壶不会空，已经浇过的格子再浇也照样扣体力。
- 期望：水壶有容量，用完提示“无法浇水或水壶已空”；已经浇过的格子不该再扣体力，或者给个提示。
- 备注：10-17 那次复测时浇 2 次就出现过“无法浇水或水壶已空”，两次表现不一致。
- 截图：bug10_mix_water.png

### BUG-13 体力满或一段时间没变化时，体力条会隐藏【低，待确认设计】
- 开局体力 100 时看不到体力条；连续用不耗体力的镐子大约 30 秒后，体力条也会消失（bug11_after_hoeing.png）。如果设计上应该一直显示，就算 bug。

### BUG-14 选中种子时，拿锄头对着耕地按 Space 会播种【低，UX】
- 物品栏 1 号格选着种子时，拿锄头对着已经耕好的地按 Space，直接播种了，种子从 15 掉到 6，期间没有再按 1。容易误把种子用掉。
- 备注：用 R 切换工具的顺序是锄头 → 水壶 → 斧头 → 镐子 → 鱼竿。

## 2026-10-18 复测 BUG-12 / BUG-14（本地提交 8998dc9、c363e5b）
日志：`playtest/run_bug12_14.log`，截图前缀 `bug12_` / `bug14_`，只用了存档槽 3（农场 1、2 的存档时间没变）
- BUG-14 全部通过：
  - 拿锄头对耕地按 Space，提示“这里已经翻过了（按数字键选种子播种）”，种子数不变（bug14_hoe_on_tilled.png）。
  - 拿着种子对没翻的地按 Space，提示“先用锄头翻地再播种”（这一步没截到图）。
  - 拿着种子对耕好的空地按 Space，播种成功，种子 15→14（bug14_plant.png）。
  - 对已经种了作物的格子按 Space，提示“这里已经种了作物”（bug14_plant_occupied.png）。
  - 拿着种子时按 Q/R，切回上次用的工具（bug14_q_back.png）。
- BUG-12 全部通过：
  - 容量 20 次，每浇一次扣 1 次水、2 点体力。
  - 浇已经浇过的格子，提示“这块地今天已经浇过水了”；浇没翻的地，提示“这里不能浇水，先用锄头翻地”；水壶空了，提示“水壶空了，去池塘边按空格装水”。这三种情况都不扣水、不扣体力。
  - 在钓鱼点按空格装满（20/20），睡觉起来也会装满。
  - 进出房子后水量不变，存档再读档后水量和体力都不变。
  - 截图：bug12_water_again.png、bug12_empty_can.png、bug12_pond_refill.png、bug12_after_sleep_water.png、bug12_after_house_still_empty.png、bug12_after_load_water.png

### BUG-15 切换场景后，手上的工具被重置成锄头【低】
- 步骤：拿着水壶离开农场，进屋再出来。
- 实际：工具面板显示锄头。期望：保留原来拿着的工具。截图：bug12_house_tool_reset.png

### BUG-16 切换场景时日志报物理错误【中】
- 日志：`ERROR: Removing a CollisionObject node during a physics callback is not allowed ... Remove with call_deferred() instead.`，本局出现 4 次，都在切换场景前后（run_bug12_14.log 第 150、181、279、317 行）。

### BUG-17 暂停菜单的按钮要点两下才生效【低】
- 第一次点“保存”或“退出游戏”只是高亮按钮，第二次点才执行。

### 观察
- 体力条只在体力变化后显示几秒，平时是隐藏的（同 BUG-13）。
- 只有池塘右侧一小块闪光的钓鱼点能装水，岸边其他地方按空格没反应。可以考虑把装水的范围扩大到整个岸边。
- 第 1 天种下并浇水的芜菁，第 2 天看起来就成熟了，需要确认生长速度是不是设计如此。
- 水壶有两套计数：日志写 100/100，存档里的 watering_can_water 是 95/100，是游戏里 20 次计数的 5 倍。游戏表现正常，只是存在两种刻度。

## 2026-10-18 复测 BUG-15/16/17、Toast 报错、存档界面 Esc（本地提交 ec723c1、85b8eb8、ebb7b5f）
日志：`playtest/run_bug15_17.log`。只用了存档槽 3（save_2.json），save_0/1 的时间戳没变。
- BUG-15 通过：拿着水壶或种子进出房子，手上的东西保持不变；拿种子时按 Q 能回到水壶；存档读档后，水壶和种子也都还在手上（bug15_02 至 bug15_20）。
- BUG-16 通过：进出门 7 次，`Removing a CollisionObject` 出现 0 次（bug16_inside_1、bug16_after5）。
- Toast 报错通过：连按约 30 次，加上混着浇水、锄地，`Cannot convert argument 1 from Object to Object` 出现 0 次；提示能合并、同屏最多 4 条、旧的会被挤掉（toast_11 至 toast_18）。
- BUG-17 关闭（复现不了）：先悬停再点、直接快速点都试了，保存、读取、设置、继续、退出游戏每个按钮都是点一下就生效（bug17_*）。
- 日志里没有 SCRIPT ERROR，只有 ALSA 音频驱动的报错。

### BUG-18 存档界面按 Esc，暂停菜单关了但存档界面还开着【中】
- 步骤：Esc 打开暂停菜单 → 保存（打开选存档位界面）→ 按 Esc。
- 期望：关掉存档界面，回到暂停菜单，游戏保持暂停。
- 实际：暂停菜单关掉、游戏继续运行，时钟在走（7:47→7:56），存档界面却还开着，而且还能操作。
- 截图：saveesc_03_3s_later.png

### 待确认
- 用“返回”关掉存档界面后，有两次紧接着按 Esc 没有打开暂停菜单，之后单独再按一次就正常了。还没稳定复现。
- 在普通草地上用工具，既没有提示也没有日志（同 BUG-9）。
- 用 R 切换工具的顺序实际是：锄头 → 水壶 → 斧头 → 镐子 → 镰刀 → 鱼竿。
- playtest/ 文件夹在 Godot 项目里面，截图可能会被 Godot 生成 .import 文件。建议在 playtest/ 下放一个 .gdignore，或者把它加进 .gitignore。
