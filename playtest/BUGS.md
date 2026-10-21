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

## 2026-10-19 复测 BUG-18（本地提交 73e5b15）
日志：`playtest/run_bug18.log`、`playtest/run_bug18b.log`，只用了存档槽 3，日志里没有 SCRIPT ERROR。
- BUG-18 通过：在保存、读取、设置界面按 Esc，都只关掉当前界面，暂停菜单还在，时钟停在 6:08 不动（bug18_01_pause_after_save_esc.png）。
- 从存档界面点“返回”或 × 关掉后，按一次 Esc 就能继续游戏，再按一次 Esc 就能打开暂停菜单，不再需要按两次。
- 在“退出游戏”和“返回主菜单”的确认框上按 Esc 会取消，游戏不退出（bug18_02_quit_dialog_esc.png）。
- 正常游戏时按 Esc 能正常打开和关闭暂停菜单，保存到农场 3 正常。

### BUG-19 覆盖存档的确认框上按 Esc，关掉的是下面的存档界面【低】
- 步骤：Esc → 保存 → 在农场 3 上点“保存到这里”，弹出“覆盖现有农场？” → 按一次 Esc。
- 期望：只取消覆盖确认框，存档界面保持打开。
- 实际：存档界面先被关掉，确认框还浮在暂停菜单上面；再按一次 Esc 才关掉。和 BUG-18 是同一类问题。
- 截图：bug18_03_overwrite_dialog_open.png、bug18_04_overwrite_after_esc.png

## 2026-10-19 复测 BUG-19（基于 HEAD 2940d7a，加上还没提交的工作区改动）
日志：`playtest/run_bug19.log`，没有 SCRIPT ERROR。只用了存档槽 3；save_0 和 save_1 的时间戳仍是 10-17 12:40，没有变；槽 3 只做了允许的“重新开始”，没有确认过覆盖或删除。
- BUG-19 通过（测了 2 轮）：在覆盖确认框上按一次 Esc，只关掉确认框，存档界面还在，时钟停在 6:06；再按一次 Esc，回到暂停菜单（bug19_03 至 bug19_07）。
- 删除确认框通过：按一次 Esc 只关掉确认框，槽 3 还在；再按一次 Esc 回到暂停菜单（bug19_08 至 bug19_10）。
- 设置里“恢复默认”的确认框通过：按一次 Esc 只关掉确认框，设置值不变（100/80/100）；再按一次 Esc 回到暂停菜单（bug19_13 至 bug19_16）。
- BUG-18 回归通过：在读取、保存、设置界面按 Esc，都只关掉当前界面；在“返回主菜单”和“退出游戏”的确认框上按 Esc 会取消；游戏中按一次 Esc 就能打开或关闭暂停菜单（bug19_11、bug19_12、bug19_17 至 bug19_22）。

## 2026-10-19 复测人物打磨第 1 轮（工作区改动未提交：Player.gd、Player.tscn、ToolManager.gd、角色精灵图）
日志：`playtest/run_polish_r1.log`。只用了存档槽 3，没花钱。截图在 `playtest/screenshots/polish_r1_test_*`，共 194 张。
- 工具位置和朝向：通过。锄头画在手边，会跟着朝向翻转；朝上时画在身后。地图左上角不再出现工具（polish_r1_test_face_sheet.png）。备注：锄头目前是橙色的“Γ”形占位图，水壶是一团蓝色，不是正式的精灵图。
- 锄地和浇水动作：通过。四个方向都有抬手、挥下、收回的动作，锄地和浇水的结果都正常（polish_r1_test_hoe_left_sheet.png、polish_r1_test_can_left_after.png）。
- 走路：通过。上下走两条腿轮流迈步，左右走没有滑步（polish_r1_test_walk_down_zoomsheet.png、polish_r1_test_walk_right_sheet.png）。
- 白色毛边：通过。草地上和土路上都没有白边，只有头发和左臂边缘有几个灰色的抗锯齿像素（polish_r1_test_edge_grass_zoom8.png）。
- 对话和商店里站立不动：通过。对话时按住 D 或 W，连拍 6 帧都一样，没有原地踏步（polish_r1_test_dialog_npc_holdD_zs.png）。开商店时角色被面板挡住了，只能确认位置没动。

### BUG-20 和喷泉旁的 NPC 对话会无限递归，之后 Esc 和 J 都失灵【高】
- 步骤：进村，走到喷泉旁的 NPC 身边，按 E 或 Space 对话。
- 日志：
  - DialogueManager.start_dialogue（第 119、136、143 行）和 _on_event_dialogue_started / _on_event_dialogue_ended（第 459、461 行）互相调用，报了 16 次以上 Stack overflow。
  - 之后 DialogueBox.gd 第 136 行报 `Nonexistent 'float' constructor`，第 109、199 行也有报错。
  - 最后引擎报了约 1000 次 Stack underflow。
- 实际：
  - 对话翻页时出现空白页，最后一句结束后又重新打开了商店（polish_r1_test_dialog_closed.png）。
  - 之后 Esc 打不开暂停菜单，J 也打不开手册，只能点窗口的 X 关游戏（polish_r1_test_pause3.png）。
- 期望：对话正常结束，没有报错，暂停菜单能正常打开。
- 备注：这两个对话脚本不在本轮改动的文件里，看起来是原来就有的问题，跟人物打磨没有关系。

### BUG-21 角色在喷泉旁被 NPC 围住，动不了【中】
- 步骤：进村，走到喷泉附近，等 NPC 走过来。
- 实际：NPC 把角色挤在中间，按 WASD 好几秒都没反应，角色还被画在 NPC 下面（polish_r1_test_postshop_holdD_zoomsheet.png、polish_r1_test_nav9.png）。
- 期望：NPC 不该把角色堵住，也不该盖住角色。

### 待确认
- 锄地朝向：朝下、左、右、上各锄一次，只出了 3 格耕地，朝右那次好像和朝下锄到了同一格。可能是因为角色正好站在两格的交界处，需要再测一次。

## 2026-10-19 复测 UI 第 2 轮（工作区改动未提交：GameTheme.tres、UIThemeBridge.gd、背包、HUD）
日志：`playtest/run_polish_r2.log`，没有 SCRIPT ERROR。只用了存档槽 3，save_0 和 save_1 没有变化。这次没和 NPC 对话，也没买东西；高对比模式测完已经关掉（ui_settings.json 里 high_contrast 为 false）。截图在 `playtest/screenshots/polish_r2_test_*`。
- HUD：通过。各面板互不重叠，金钱是金色，字号一致（polish_r2_test_03_hud_stamina.png、polish_r2_test_03_crop_money.png）。
  - 体力条只在体力低于 78% 时才出现，每次变化后显示约 2.6 秒。
  - 提示“…（按数字键选种子播种）”里的“种)”会单独换到下一行，和已知的“品。”是同一个问题。
- 背包：通过，有两处小问题。图标居中，左上角有快捷键号，右下角有 ×N；悬停是绿框，选中是橙框；选中的页签能看出来（polish_r2_test_06_crop_slots_zoom_v2.png）。
  - 小问题：“×15”压到了种子图标的底部。
  - 小问题：同样是空格子，悬停提示有时显示“空”，有时显示“[3] 空”。
- 暂停菜单、存档界面、设置：大部分不通过。
  - 通过的部分：暂停菜单的按钮有悬停和按下的样式，“保存”按钮不再是绿色，存档卡的标题大小正常（polish_r2_test_10_pause_hover_save.png、polish_r2_test_11_pause_pressed_settings.png）。
  - 商店：没测。商店只能通过和 NPC 对话打开，而对话会触发 BUG-20。

### BUG-22 还有很多按钮是绿色【中】
- 存档界面的“保存到这里”全是绿色。
- 制作页签里每个配方都是绿色，“可制作 0”的配方也是，看起来像能做（polish_r2_test_08_craft_tab_hover.png）。
- 设置里的“应用”是绿色，鼠标悬停时变化很小。

### BUG-23 选中的配方和设置分类没有选中样式【低】
- 选中的配方，以及当前所在的设置分类（声音、辅助功能），只有鼠标悬停时才看得出来，移开就没了（polish_r2_test_08、polish_r2_test_14_settings_hover.png）。

### BUG-24 音量滑条的颜色让人看不懂【低】
- 音乐音量在 80% 时，右边没填满的部分是深色；而 100% 的滑条看起来是灰色（polish_r2_test_14_crop_sliders.png）。

### BUG-25 高对比模式下有多处显示问题【高】
- 获得焦点的按钮看不清文字：打开设置 → 辅助功能 → 打开高对比模式 → 按 Esc 回到暂停菜单，获得焦点的“设置”按钮是黑底深色字，看不清。存档界面、手册、设置里的 × 关闭按钮也一样（polish_r2_test_19_crop_focus_text_invisible.png）。
- HUD：
  - 日期和金钱面板超出了窗口右边，时间显示成“10:01 AI”，“500 金”也被截掉（polish_r2_test_22_crop_hc_date_clipped.png）。
  - 体力面板盖住了提示面板，提示面板还超出了底边，被物品栏压住（polish_r2_test_22_hc_hud.png）。
  - 只有日期、体力、提示这三个面板换了主题，任务面板、物品栏和工具面板还是普通主题。
- 背包：悬停和选中都是一样的纯黄色，分不出来；图标很小，还偏到了左上（polish_r2_test_23_crop_hc_slots.png）。
- 设置：
  - 鼠标悬停在已勾选的“高对比模式”这一行时，底色和边框都消失了（polish_r2_test_16_hc_settings.png）。
  - 打开高对比模式会马上保存，不用点“应用”；关掉时却要点“应用”才会保存，两边不一致。
- 其他：
  - “删除”和“退出游戏”按钮没有了红色的危险提示。
  - 存档卡上“第1年·春季第1天”这一行的字比上下几行小。

### 待确认
- 关掉手册后马上按 Esc，有时没反应，要按第二次才能打开暂停菜单。

## 2026-10-19 复测第 3 轮（工作区未提交改动，槽 3）
日志：playtest/run_r3.log；截图前缀：screenshots/r3_test_*
日志统计：Stack overflow 0 次，Stack underflow 0 次，SCRIPT ERROR 0 次。

- **BUG-20 对话递归：部分通过。** 不再栈溢出。镇长、铁匠、农场主用 E 和 Space 各聊过多次，没有空白页，商店不会自己打开，聊完 Esc 和 J 都是按一次就生效。截图：r3_test_dlg_ejcheck_all.png
- **商店 UI：正常。** 商人直接打开种子商店（没有招呼对话，可能就是这么设计的）。购买和出售两个页签、悬停高亮都正常，Esc 或 × 可以关闭。截图：r3_test_shop_buy_hover.png、r3_test_shop_sell_tab.png
- **BUG-21 被 NPC 围住：通过。** 往上顶商人约 0.6 秒挤过去，往右顶两个村民最多约 2.5 秒挤过去。前后遮挡按上下位置正确。截图：r3_test_squeezeUp_montage.png、r3_test_squeeze_montage.png、r3_test_draworder_above_zoom.png、r3_test_draworder_below_zoom.png
- **锄地四个方向：通过。** 在格子中心锄出 4 个相邻格，靠近格子右边缘也是 4 个相邻格，贴着右侧围栏只出 3 格（往外那一下出了田地，属正常）。截图：r3_test_hoe_setA.png、r3_test_hoe_setB.png、r3_test_hoe_setC.png
- **挥工具时锁定移动：通过。** 挥动的约 0.26 秒内原地不动，挥完不用再按，按住的方向会直接接着走。截图：r3_test_swing2_zoom.png，逐帧 r3_test_swing2_00..41.png

### BUG-26（新，中）结束对话的那次按键会重新开始对话
- 步骤：在村子里面朝 NPC，按 E 或 Space，之后大约每秒按一次。
- 预期：第 1 句，第 2 句，然后关闭。
- 实际：第 1 句、第 2 句反复循环 2 到 7 遍才关闭（约翰 14 页，铁匠 8 页，镇长 8 页）。E 和 Space 都会出现，不是每次都有。日志里每循环一次都有新的 `[Player] Interacting with …` 和 `Started dialogue`，这一轮共 48 次。看起来是关闭对话的那次按键又被 Player 当成了一次交互。
- 截图：r3_test_dlg_E_trace.png、r3_test_dlg_space_trace.png、r3_test_dlg_npcD_E1_montage.png

### BUG-27（新，低）日志里的 NPC 名字和对话框不一致
- 日志写的是 镇长·威廉、农夫·乔、铁匠·汤姆、店主·莉莉，对话框显示的是 镇长托马斯、农场主约翰、铁匠布鲁斯。

### 备注（UI 风格，不算 bug）
- 对话框里的正文是浅色字配米色底，很难看清。截图：r3_test_dlg_E_trace.png

## 2026-10-19 复测第 4 轮（工作区未提交，槽 3）+ Sand 加测
日志：playtest/run_r4.log；截图：screenshots/r4_test_*（66 张）。Started dialogue 39 次，对应开始的 39 次对话；Stack overflow 0 次。

- **BUG-26：通过。** 和铁匠·汤姆、农夫·乔、医生·玛丽、镇长·威廉对话，E 和 Space 快按、慢按各 2 次以上，都不再从第一句重开，每次只有 1 条 Started dialogue。截图：r4_test_dlg_mayor_line1.png
- **BUG-27：通过。** 对话框和日志里的名字一致，正文是深色字，看得清。截图：r4_test_dlg_blacksmith1.png、r4_test_dlg_farmer1.png、r4_test_dlg_doctor1.png
- **BUG-22~25：基本通过，只有“完成”一项失败（见 BUG-28）。** 存档卡和配方行是普通样式；可制作 0 的配方变灰；选中项是金色；滑条清楚；删除、退出、恢复默认是红色；设置即改即存。高对比下焦点是青色外框，HUD 跟随主题且不越界不重叠，背包悬停和选中能分清，图标居中。高对比下没法判断“可制作 0 变灰”，因为所有配方都是 0、没有对照。高对比已关闭。截图：r4_test_normal_crafting.png、r4_test_hc_focus.png、r4_test_hc_hud.png、r4_test_hc_inv_selected_hover.png、r4_test_hc_off_settings.png
- **小问题：通过。** ×N 不压图标；格子提示格式统一（“芜菁种子 × 15”，空格子显示“空”）；文字没有单字折行；关手册后按一次 Esc 就开暂停，5/5。截图：r4_test_normal_inv_hover_tooltip.png、r4_test_esc_after_handbook_1..5.png
- **各场景 Esc/J：部分通过。** 玩家小屋里 Esc 和 J 都是按一次就生效。截图：r4_test_house_esc_first_press.png、r4_test_house_j_first_press.png。Forest、Beach、Mine 没测到，因为找不到入口（见 BUG-32）。
- **存档卡时间：通过。** 显示 2026-10-19 12:20，与当时的 `date`（12:20:51 HKT）一致。截图：r4_test_slot3_card_time.png
- **待机呼吸：大部分通过。** 站着不动时有呼吸；开暂停菜单或手册时不动；开“减少动态效果”后不播放，关掉后恢复。走路、挥工具和对话时有没有停，没能单独确认。截图：r4_test_breath_idle_*、r4_test_breath_pause_*、r4_test_breath_reduced_motion_*
- **NPC 0.8 倍：通过。** 比例协调，脚踩在影子上；相邻格能对话，隔 2 到 3 格按 E 没反应；头上没有残留的 E 标签。截图：r4_test_far_from_npcs_E_no_talk.png

### BUG-28（低）设置里的“完成”按钮不是绿色
- 步骤：Esc → 设置。预期“完成”是绿色主按钮，实际和普通按钮一样是米色。普通主题和高对比都这样。截图：r4_test_normal_settings.png、r4_test_hc_settings_a11y.png

### BUG-29（高）进入玩家小屋时 Kitchen.gd 解析错误
- run_r4.log 第 746、750 行：`Identifier "InteractPrompt" not declared`（res://src/world/objects/Kitchen.gd:18）；第 754 行：`Failed to load script Kitchen.gd`。可能是 UI 正在改到一半。

### BUG-30（高）往返村庄时崩溃（signal 11）
- 步骤：农场 → 村庄 → 农场 → 村庄，第二次刚到村庄时崩溃。日志第 268 行：`Program crashed with signal 11`，崩在 `NPCManager._despawn_all_npcs`（对已经释放的 NPC 调用 queue_free）。只出现了一次。

### BUG-31（中）早上 6:00 到 7:15 左右 NPC 不能对话
- 这段时间所有 NPC 都站在喷泉旁（日程上应该在家）。按 E 时日志有 Interacting，但不弹对话，商人也不开商店。

### BUG-32（中）村庄找不到去 Forest、Beach、Mine 的出口
- 沿北、东边缘和右下角走都没有触发。Village.tscn 里 Forest 出口在 (640,60)，落在东北建筑的碰撞框内（x 520–790，y 5–190），可能走不到。Mine 出口 (180,820) 在西南角建筑旁，没走到。待确认。

### BUG-33（低）可以走到西北房子屋顶的下沿上

### BUG-34（低）对话提示写成“Space 继续 · Space 显示全文”，同一个键写了两遍

### 备注
- 中午 NPC 聚在喷泉旁时还是可能把人短暂围住（BUG-21 的残留，低）。
- 第一次启动时，存档卡时间比第二次早约 8 小时（槽 1：03:16 对 11:16），之后都正确。可能和时区修复前后有关，先观察。

## 2026-10-19 复测第 5 轮（工作区未提交，槽 3）
日志：playtest/run_r5.log（Scene loaded 20 次；没有 SCRIPT ERROR、signal 11、InteractPrompt 报错）。截图：screenshots/r5_test_*（91 张）

- **BUG-29 厨房：通过。** 进小屋后站在灶台正下方按 E，打开了烹饪界面，日志没有 Kitchen 报错。截图：r5_test_kitchen_e.png
- **BUG-30 来回切换：通过。** 农场和村庄来回 6 趟，其中 2 趟穿插了小屋，另外还去了森林和海滩，都没有崩溃。
- **BUG-31 早上和村民对话：通过。** 6:20 左右找商人莉莉，提示“暂未营业”并写出营业时间 8:00-20:00；铁匠能正常对话。截图：r5_test_npc_talk.png、r5_test_npc2_talk.png
- **BUG-32 出口：失败。**
  - 海滩：通过。进得去，回来落在“海滩 →”路牌旁，在海滩里 Esc 和 J 都是按一次就生效。截图：r5_test_beach_esc.png、r5_test_beach_j.png、r5_test_beach_back.png
  - 森林：进得去，Esc 和 J 按一次就生效，但出不来（见 BUG-35）。
  - 矿洞：去不了（见 BUG-36）。
  - 农场：从村庄回农场时落在“前往村庄”出口旁，正常；从农场去村庄时的落点不对（见 BUG-37）。
- **BUG-28：通过**，“完成”是绿色。**BUG-33：通过**，走不到西北房子的屋顶上（截图：r5_test_nw_roof2.png）。**BUG-34：通过**，打字时提示“Space 显示全文”，打完后提示“Space 继续”（截图：r5_test_dialogue_hint.png）。
- **交互气泡：**
  - 通过：NPC、出货箱、工作台、厨房、牛棚、鸡舍。截图：r5_test_npc_near.png、r5_test_bin_near.png、r5_test_workbench_near2.png、r5_test_kitchen_near3.png、r5_test_barn_bubble.png、r5_test_coop_near.png
  - 失败：钓鱼点、可采集物（见 BUG-38、BUG-39）。
  - 另外：厨房气泡只在灶台正下方出现；鸡舍的气泡被任务面板挡住一部分。
- **呼吸动作：通过。** 走路、挥工具和对话时都停止。

### BUG-35（高）森林出不去，只能读档
- 步骤：从村庄沿中路往上进入森林，然后试着从下边、上边、左边和东边的路出去。
- 预期：有一个能走到的出口回村庄。实际：哪个方向都不触发切换，只能回主菜单重新读槽 3。
- 截图：r5_test_forest_exit2.png、r5_test_forest_exit3.png、r5_test_forest_exit4.png、r5_test_forest_east.png、r5_test_forest_bottom.png

### BUG-36（中）走不到矿洞出口
- 步骤：从下方道路沿蓝顶房子右侧往下走，再沿最下沿从左走到右，经过“↓ 矿洞”路牌。
- 实际：镜头停在最下沿，没有切换场景。代码里出口在 (180,900)，看起来在能走、能看见的范围之外。所以矿洞里的 Esc 和 J 没测到。
- 截图：r5_test_mine_route3.png 到 r5_test_mine_route6.png

### BUG-37（低）从农场进村庄的落点不对
- 预期落在“← 农场”路牌旁（from_farm 设为 (150,300)），实际落在喷泉广场，往东偏了约 270。截图：r5_test_v_arrive3.png

### BUG-38（中）钓鱼点不显示 E 气泡
- 日志有“[FishingSpot] Player at fishing spot”，但画面上没有气泡。截图：r5_test_fish_near3.png、r5_test_fish_near4.png

### BUG-39（中）森林里的可采集物不能互动
- 站在蘑菇或浆果丛上没有气泡，按 E 没反应，日志也没有任何记录。截图：r5_test_forage_near.png、r5_test_forage_e2.png、r5_test_forage_berry2.png

### BUG-40（低）从村庄进小屋，出来后总是回到农场

### BUG-41（中）厨房食谱窗口排版错乱
- 标题栏过高，× 按钮被拉得很长，面板底部超出窗口。可能跟正在改的 UI 有关。截图：r5_test_kitchen_open.png

### BUG-42（低）森林里树的碰撞不一致，有些树可以直接穿过去

### 待确认：BUG-26 可能部分复发
- 在最后一句按 Space 结束对话，会马上又开始同一段对话（Space 也是交互键）。BUG-26 那一轮说的就是这个问题，需要单独再测。

### 备注
- 海滩里“→ 村庄”路牌的箭头指向右边，但实际回村庄要往上走。

## 2026-10-19 复测第 6 轮（工作区未提交，槽 3）
日志：playtest/run_r6.log（没有 SCRIPT ERROR、signal 11 和 Stack overflow）。截图：screenshots/r6_test_*（43 张）。这一轮游戏非常卡，输入和画面落后 5~15 秒，每一步都对照日志确认过。

- **BUG-35 森林出口：通过。** 西出口和南出口都回到村庄中路顶端（“↑ 森林”路牌下面）。截图：r6_test_forest_south_exit_village.png
- **BUG-42 树碰撞：通过。** 试了 5 棵树，都穿不过去。
- **BUG-39 采集：通过。** 蘑菇和浆果都有 E 气泡，按 E 能采到（快捷栏显示浆果 ×2、蘑菇 ×2）。重新进森林后采集物会刷新。
- **BUG-36 矿洞：通过。**
  - 从村庄往南走到底就进入矿洞。截图：r6_test_mine_entered.png
  - 矿洞里 Esc 和 J 都是按一次就生效。截图：r6_test_mine_esc.png、r6_test_mine_j_handbook.png
  - 梯子能下到第 2 层，再上回第 1 层。截图：r6_test_mine_floor2.png
  - 从西出口回到村庄“↓ 矿洞”路牌旁。截图：r6_test_mine_exit_village.png
  - 站在 Tom 家门口不会误进矿洞。截图：r6_test_tom_door_no_mine_0840.png
- **BUG-41 厨房：通过。**
  - 食谱窗口排版正常。截图：r6_test_kitchen_window.png
  - 站在灶台左、右、下方都有气泡（r6_test_kitchen_bubble_left/right/below.png）。气泡触发范围偏大，站在灶台左上方斜一格也会出现。
- **BUG-38 钓鱼点：部分通过。** 拿着水壶时显示“装水”；拿其他工具时显示“钓鱼”这一项没测到。
- **BUG-37：通过。** 从农场进村庄落在“← 农场”路牌旁。
- **BUG-40：通过。** 从村庄进小屋，出来回到村庄“⌂ 小屋”旁。截图：r6_test_house_exit_village_npcs_0626.png
- **海滩路牌：通过。** 显示“↑ 村庄”。截图：r6_test_beach_sign.png
- **鸡舍气泡：失败（BUG-43）。**
- **NPC 作息：部分。**
  - 20:00~21:00 回家淡出没看到，21:19 到村庄时已经全部在休息。
  - 早上 6:26 村民都已经在路上，6:00 在门口出现没看到。
  - 白天看到 NPC 站在房顶上、两个 NPC 重叠（BUG-44）。
- **BUG-26 再确认：通过（测了 4 个 NPC）。** 在最后一句只轻按一次 Space，都没有重开，日志里 Started dialogue 正好 4 条，对上 4 次对话。商人直接开商店，渔夫没有对话（BUG-46），所以没凑齐第 5 个 NPC。

### BUG-43（低）鸡舍的 E 气泡位置不对
- 在鸡舍旁按 E 能进（日志：[Coop] 按 E 键进入鸡舍），但鸡舍上方没有气泡，气泡出现在池塘那边。

### BUG-44（中）每次进村庄 NPC 都生成两份
- 日志里每次进村庄，同一个 NPC 都会初始化两次。例如铁匠·汤姆在第 303 和 318 行、第 392 和 407 行都各初始化了一次，医生·玛丽也一样。看起来场景里放了一份，NPCManager 又生成了一份。
- 表现：两个紫衣 NPC 叠在喷泉上方；8:40 和 9:27 有个橙衣 NPC 站在东北红顶房子的屋顶上。截图：r6_test_village_npcs_0927.png、r6_test_tom_door_no_mine_0840.png
- 还有个 NPC 站在“← 农场”路牌附近，被任务面板挡住一部分。

### BUG-45（中）矿洞换层时出现物理报错
- 用梯子换层时出现 64 条 `Can't change this state while flushing queries`。调用链：`_on_ladder_down_entered`（Mine.gd:206）→ `_generate_floor_ores`（Mine.gd:129）。矿石应该延后（deferred）生成，不要在 area_entered 回调里直接生成。

### BUG-46（低）海滩的老渔夫·杰克不能对话
- 有 E 气泡，但按 E 没反应。日志第 1068 行：`No dialogue data for NPC: fisherman_old_jack`。截图：r6_test_beach_fisherman_no_dialogue.png

### 备注
- 测试代理最后跑了一次只读的 `git status --short`，没有改动任何东西。

## 2026-10-19 复测第 7 轮（工作区未提交，槽 3，窗口 1280×720）
日志：playtest/run_r7.log；截图：screenshots/r7_test_*（36 张）。没有崩溃，flushing queries 0 条，Stack overflow 0 条。
输入延迟：按 J 开手册 0.08~0.11 秒，Esc 关闭 0.05~0.07 秒，开始走路 0.09~0.28 秒，整体比第 6 轮好很多。

- **BUG-44 NPC 重复生成：通过。** 从农场、小屋、森林、矿洞、海滩进村庄共 5 次，每次 5 个村民各初始化一次，广场上每人只出现一次，没有人在屋顶上或房子里。截图：r7_test_1_entry1_from_farm.png ~ r7_test_1_entry5_from_beach_plaza.png
  - 小问题：镇长和莉莉的出生点都是 (500,400)，乔和汤姆都是 (600,350)，有时会叠在一起。
- **BUG-45 矿洞换层：通过。** 碰梯子 4 次，每次只换一层（1→2→3→4→3），flushing queries 0 条。截图：r7_test_2_mine_f2.png、r7_test_2_mine_f3.png
  - 不一致：左边梯子标着“← 村庄”，走进去是上一层，但在第 3 层站在上面按 E 会直接回村庄。
- **BUG-43 鸡舍气泡：通过。** 气泡贴在鸡舍下方。截图：r7_test_3_coop_bubble.png
- **BUG-46 老渔夫·杰克：通过。** 能对话。截图：r7_test_3_fisherman_dialogue.png
  - 在最后一句按 Space 结束后，对话立刻又开了一次；重开的那次按 Space 没反应，只有 Enter 能关。日志里还写着杰克“arrived at tavern”，但他人在海滩。
- **厨房气泡范围：通过。** 灶台左、右、下方有气泡，左上斜一格没有。截图：r7_test_3_kitchen_left.png、r7_test_3_kitchen_right.png、r7_test_3_kitchen_below2.png、r7_test_3_kitchen_diag_ul.png
- **钓鱼点文字：通过。** 拿锄头或斧头显示“钓鱼”，拿水壶显示“装水”。截图：r7_test_4a_hoe_fish.png、r7_test_4a_can_water.png
- **晚上回家：失败（BUG-47）。**
- **早上出门：没看到。** 02:00 自动跳到第二天 06:00，人还在村庄；但 06:27 才第一次看清，那时 5 个村民已经在广场和水井附近，没看到“在门口出现”那一刻。截图：r7_test_4c_night_9.png、r7_test_4c_night_10.png

### BUG-47（中）晚上村民不走回家门，直接消失
- 步骤：19:50 站在村庄广场，每 15 分钟截一张图。
- 预期：20:00/21:00 村民走到自家门口后淡出。
- 实际：乔、汤姆、玛丽在 20:00~20:15 之间直接消失；镇长和莉莉在水井旁叠着站到 20:59，21:14 前消失。始终没看到有人走路回家。日志里“is going home”后面马上就是“is resting”（第 787~792 行），像是直接删掉了。
- 截图：r7_test_4b_eve_1950.png、r7_test_4b_eve_1.png ~ r7_test_4b_eve_6.png

### BUG-48（中）NPCSchedule.gd:168 访问空对象
- 留在村庄过夜，所有村民进入 resting 之后、02:00 换日之前，报了两次 `Invalid access to property or key 'activity' on a base object of type 'Nil'`（日志第 797、804 行）。调用链：NPCSchedule.update ← NPC._on_time_changed:579 ← TimeManager。

### BUG-26 残留（低）：Space 结束对话后又被当成交互
- 在老渔夫·杰克的最后一句按 Space，对话会立刻重开一次。

### 备注
- 村庄半夜也是全亮的，没有夜晚色调。
- 测试工具注意：按键要按住约 120 毫秒、两次按键间隔约 0.4 秒，太短的点按有时会被吞掉。

## 2026-10-19 复测第 8 轮（工作区未提交，槽 3，窗口 1280×720）
日志：playtest/run_r8.log；截图：screenshots/r8_test_*（162 张）。中途被打断，后半段是接续完成的。没有 SCRIPT ERROR、signal 11、NPCSchedule 报错，flushing queries 0 条。

- **BUG-47 晚上走回家：通过。** 5 个村民都走出“reached the door … after 15~30 s”，然后进入 resting，完整走了两轮（共 10 条）。晚上约 8:00 还聚在水井边，8:16 已有人走西边路，8:44 散开。回家路上能跟镇长说话（对话时停下）。截图：r8_test_eve_walk_01.png ~ _25.png、r8_test_eve_talk_*.png
- **早上在门口出现：通过。** 1:48 AM 广场空着且是暗的；6:24~7:02 AM 天亮，村民站在家门口附近，不是在路中间；第二天 6:17 也看到有人站在红顶房子门口。截图：r8_test_rollover_01.png、r8_test_rollover_25/40/50.png、r8_test_now2.png、r8_test_morning_doors.png
- **BUG-48：通过。** 留在村庄过午夜到 2:00 换日，日志里没有 NPCSchedule 报错。
- **夜晚色调：室外通过，室内未测。** 村庄、农场、森林、海滩晚上都变暗，白天恢复；HUD 和对话框不变暗（对话框仍是米色）。小屋和矿洞的夜间亮度没测到（接续时已经是早上）。截图：r8_test_day_* 对比 r8_test_night_*、r8_test_eve_talk_2.png
- **BUG-26 残留：通过。** 老渔夫最后一句按 Space 后对话框关掉，只剩 E 提示，不会立刻重开；过一会儿再按可以重新从第一句开始。医生对话也是按一次 Space 就结束。截图：r8_test_fish_d1_l3.png → l4、r8_test_fish_cycle_1.png → cycle_2.png
- **矿洞梯子牌子：通过。** 第 2 层有“↑ 第1层”和“↓ 第3层”，第 1 层有“↑ 村庄”；能正常上下和回村庄。同一把梯子上还写着“← 村庄”，和上行牌子并排，略奇怪但不影响使用。截图：r8_test_mine_f2.png、r8_test_mine_up_to1.png、r8_test_mine_up_to_village.png
- **广场村民重叠：通过。** 多次进村，水井旁 4~5 人分开站着，没有叠成一个。截图：r8_test_plaza_entry3/4/5.png

### 备注
- 第 1 层梯子上“← 村庄”和“↑ 村庄”同时存在，建议整理一下文案。
- 夜晚小屋和矿洞内部亮度还没测，下一轮可以补。

## 2026-10-19 美术验收（HEAD Stage A–D，槽 3，1280×720）
日志：`playtest/run_art_accept.log`；截图：`screenshots/art_accept_*`（约 83 张）。读档农场 3（save_2）。无时约到第 1 年春季第 5 天中午，金币 500。无 SCRIPT ERROR / signal 11 / 崩溃。

### 清单结果
1. **玩家（Villager3 绿袍）：通过。** 黑发褐肤绿袍，四向走路/待机正常；锄头、水壶手持可见且能锄地浇水（「土地已翻好」「浇水完成」）。截图：art_accept_player_walk_*.png、art_accept_player_tool_*.png、art_accept_hoe_action.png、art_accept_water_action.png
2. **村民：部分通过。** 精灵与角色对应，能对话，E 气泡正常。谈过汤姆、玛丽、杰克；莉莉商店能开。**失败：站位**——镇长卡进水井里（下半身被井挡住）；广场/午餐时段多人重叠。Day4/Day5 多次复现。截图：art_accept_plaza_npcs.png、art_accept_talk_*.png
3. **地块：部分通过。** 农场/村庄/森林是 Kenney 像素风（草地、土路、树、篱、井、拼装房）。**海滩失败观感**：能进，但几乎看不见沙和海，像草地。小屋内部空米色房、矿洞偏旧图——按清单只记录不算失败。截图：art_accept_farm/village/forest/beach/house_interior/mine.png
4. **道具图标：通过。** 热键栏/背包/商店是统一像素图标族（番茄等替代图标按已知不算新 bug）。截图：art_accept_hotbar.png、art_accept_inventory.png、art_accept_shop.png
5. **已知未换：已确认。** 本存档田间几乎没作物；谷仓外观仍是旧插画风；对话无肖像（只有名字+正文）。不算回归失败。截图：art_accept_crops.png、art_accept_farm_buildings.png、art_accept_portrait.png
6. **顺手回归：通过。** Esc/J 正常；对话 Space 结束不立刻重开；村庄↔农场、小屋、矿洞、海滩、森林出口都能走。

### 新问题
- **BUG-49（中）NPC 站位：镇长卡进水井 + 广场重叠。** 步骤：白天进村看水井/广场。预期：站在路上/门口不穿模。实际：镇长下半身埋进井；多人叠在一起。截图：art_accept_plaza_npcs.png
- **BUG-50（低）手持锄头/水壶精灵过大，挡住大半身。** 截图：art_accept_player_tool_hoe.png、art_accept_player_tool_can.png
- **BUG-51（中）海滩地图几乎无沙无海，像草地。** 截图：art_accept_beach.png
- **BUG-52（低）BGM 时段错配。** 日志：白天海滩报 `No BGM for time slot: beach_night`；中午森林切到 forest_night。

### 备注
- 退出时有 ObjectDB leak 警告（非崩溃）。
- 浇水有 toast，泥块仍偏深褐，未见明显蓝色湿润层（未单独开 bug）。

## 2026-10-19 复测 BUG-49～52（工作区未提交，槽 3，1280×720）
日志：`playtest/run_art_retest.log`；截图：`screenshots/art_retest_*`。读档农场 3。无 SCRIPT ERROR / signal 11。日志中 **0** 条 `No BGM for time slot`。

- **BUG-49：通过。** 白天多次进村（至少 4 次）。水井始终空着，镇长不在井里；村民分开站，不叠成一团。中午广场坐标分散。截图：art_retest_plaza_noon.png、art_retest_plaza.png、art_retest_well.png
- **BUG-50：通过。** 锄头/水壶手持明显缩小，贴在身侧/头旁，不再挡住大半身（对比 art_accept_player_tool_*）。截图：art_retest_hoe.png、art_retest_can.png
- **BUG-51：通过（沙+海可见）。** 海滩有棕沙、内陆草、底部蓝水带，不再是一片草。备注：岸边南走时精灵会浅浅叠进绘制水面（碰撞约 y=155、岸线约 y=80），未掉出地图。截图：art_retest_beach.png、art_retest_beach_morning.png、art_retest_beach_shore.png、art_retest_beach_hud.png
- **BUG-52：主缺陷通过。** 白天无 `beach_night` 错配；夜晚海滩才切 `beach_night`；换日时海滩切 `beach_morning`。村庄白天 `village_day`、夜晚 `village_night`。矿洞/小屋未单独切 location BGM（仍播上一场景日曲，可接受）。农场/森林本轮因卡住未进。

### 新问题（非本轮必过项）
- **BUG-53（低）矿洞回村出生点卡建筑。** `from_mine` 出生点 (240,880) 落在南侧建筑碰撞盒内，进村后几乎只能先往南回矿洞再往东绕出。
- **BUG-54（低）北广场卡住。** Day6 约 9:13～10:58 在北井/↑森林/←农场路牌附近 WASD 无位移。
- 海滩岸线浅穿模：见 BUG-51 备注，暂不单开高优先级。

## 2026-10-19 复测 BUG-53/54（补测，部分完成）
日志：run_b53_54.log；截图在 screenshots/。槽3 不存档。中途有人跑 `scripts/check.sh`（里面的 `pkill -f 'godot --path'`），把测试进程杀掉 2 次，每次都重新启动。
- **BUG-53 通过**：从矿洞回村，出生在西南建筑东侧的南路上，不在建筑里。按 A/D/W 各等 3 秒，都能正常移动。截图：art_retest53_spawn3 / west / east / north。
- **BUG-54 通过（测过的位置）**：
  - 水井 S/N/E/W 四个方向撞上去再走开，都没卡住。
  - ↑森林 路牌四个方向都能走，出口进得了森林。
  - ←农场 路牌和 near_farm 路口没有隐形墙；出口进得了农场，农场的 → 前往村庄 也能回到村子。
  - 截图：art_retest54_well_s/n/e/w、forest_sign、exit_forest、farm_sign、exit_farm。
  - 小问题：水井碰撞圆半径 28，比画出来的石圈小，玩家会和石圈重叠一点，但会被推出去，不算阻塞。
- **未完成**：
  - Tree08：碰撞体在世界坐标约 (80,-80)，只走到附近，没测碰撞（art_retest54_tree08 只是附近的截图）。
  - Tree10：没测。碰撞体还在地图局部坐标 (620,820)，也就是世界坐标 (500,700)，在广场南边 ⌂小屋 路旁，不是北广场东侧。和描述的修改不一致，待确认。
  - 海滩复查：本轮跳过。
- **小屋门**：上一轮怀疑出门又被传回屋里。这轮误入小屋后按一次 S 就出来了，没有复现。

## 2026-10-20 Phase 1 素材验收（工作区未提交版本，部分完成）
槽3，1280×720，不存档。日志：run_p1_art.log。截图前缀：art_p1_*。
- **阻塞（BUG-55）**：槽3 的存档里没有任何鸡、猪、牛、羊、马，游戏里也没有能得到动物的途径。`add_animal` 只在 Barn.gd、Coop.gd、AnimalBuilding.gd 里有定义，没有任何地方调用。日志里只有鸡舍和牛棚的 initialized，没有动物生成。所以动物动画、y-sort、体型比例、羊马是否未变这几项都没法验收。
  - 期望：有一个调试方法能生成动物，或者有一份带动物的测试存档。
- 第 1 项（动物动画）：未测，原因同上。
- 第 2 项（建筑）：部分通过。
  - 谷仓：新外观（蓝顶红仓）已显示。正面碰撞会挡住（art_p1_barn_collide_front）。遮挡顺序正确：玩家在南侧时在谷仓前面（art_p1_barn_front），在北侧时被谷仓挡住（art_p1_barn_behind）。谷仓只有「E 收集」，没有室内，但日志写着「按 E 键进入牛棚」，文字和实际行为对不上。
  - 农舍：新外观（蓝顶带藤蔓）已显示。能进门也能出来（art_p1_house_front、art_p1_house_entered）。北侧遮挡还没截图。
  - 鸡舍：只在远处看到（art_p1_farm_1 左上），收集点、碰撞、遮挡都没测。
- 第 3 项（比例）：建筑和玩家放在一起不刺眼。代码里图片显示尺寸和原图长宽比不一致，农舍 504×576 被拉成 220×168，鸡舍 144×240 被拉成 176×136，会被压扁。Grok Build 正在改成等比缩放，改完再验。动物比例未测。
- 第 4 项：存档里没有羊和马。其他村屋还是旧美术（art_p1_village_1），通过。
- 小问题：
  - 农舍门前有一个蓝顶小物件（可能是邮箱），会挡住往北进门，玩家和它有重叠（art_p1_house_front）。
  - 农舍室内只有空地板，「E 烹饪」提示显示在空白处（art_p1_house_interior_invisible_stove）。之前的 art_accept_house_interior 也是这样，不是这次引入的问题。
- 日志：无缺失贴图；有 1 条 ERR_CANT_OPEN（第 13 行），以及 V-Sync、音频驱动、ObjectDB 泄漏几条常见警告。
- 运行环境：这轮游戏输入延迟 10～30 秒，截图前要先动一下鼠标才会重绘，测试效率很低。

## 2026-10-20 Phase 1 补测（树/海滩/F9 动物/建筑）
槽3，不存档。日志：run_p1_retest.log、run_p1_retest_b.log。截图前缀：p1r_*。输入延迟约 1～3 秒，比上一轮好很多。开测前机器上没有残留的 godot 进程，负载 0.31。
- BUG-53/54：
  - 从矿洞回村往北走，没有被挡（p1r_spawn_from_mine、p1r_village_north1/2）。
  - Tree10 在路东边的草地上，走过去会被挡住（p1r_tree10_blocked）。
  - Tree08 上方空地能走，树干处会被挡（p1r_tree08_above/trunk）。
  - 判定**通过**。注：这三条依据测试员的记录，截图没有逐张复核。
- 海滩：白天是沙滩加海，日志里没有 No BGM 和 beach_night（p1r_beach_day），**通过**。BUG-51/52 可以结案。
- BUG-55（动物生成）：在农场按 F9，鸡、猪、牛、羊、马各生成 1 只（p1r_animals_spawn、p1r_ysort_2_north_pig），**通过**。
  - 动画：从截图看，鸡、猪、牛在不同帧里朝向和姿势不同，没有看到空帧或模糊（p1r_animals_burst1～8）。闪烁和走路时是否转成 idle 只看静态截图没法判断，**待补**。
- **BUG-56（新）羊和马的贴图带着不透明的淡蓝色方形背景**。复现：按 F9，看羊和马。期望：透明背景的旧单帧图。实际：两只动物都显示在一块淡蓝色方块上（p1r_ysort_2_north_pig、p1r_animals_burst4）。
- 遮挡顺序：动物会画在玩家上面，玩家站在猪北侧时会被猪挡住（p1r_ysort_2_north_pig）。这和 Grok Build 说的现有设计一致，是否要改成按 y 排序由项目决定。
- 比例（目测，没有用像素测量）：猪比玩家宽，而且差不多一样高，偏大；牛和玩家差不多高；鸡大约是玩家的 2/3。建议：猪和牛缩小约 20%，鸡保持不变。
- 农舍门：蓝色尖角已经去掉，往北能直接进门，往南能出来（p1r_house_*），**通过**。小问题（BUG-59）：沿着农舍门前的路往西走，会被传回屋里。
- 谷仓和鸡舍提示：**失败（BUG-57）**。画面上只显示「E 收集」。完整的「收集产品 / 喂养 / 查看」只在日志里出现（p1r_barn_2_prompt、p1r_barn_9_prompt）。
- 鸡舍：
  - 南侧遮挡正确（p1r_coop_3_south）。
  - **BUG-58（待复核）**：从鸡舍东南侧一直按 W，玩家会走进鸡舍东墙和屋顶的范围，没有在墙脚被挡住（p1r_coop_4_pushnorth）。
- 0.5 等比缩放：农舍、谷仓、鸡舍都没有被压扁，比例合理，**通过**（p1r_coop_2、p1r_farm_1）。
- 日志：没有 SCRIPT ERROR，也没有缺失贴图。启动时有 1 条 ERR_CANT_OPEN，和之前一样。

## 2026-10-20 复测 BUG-58/59/57 + 体型 + 动画连拍
槽3，不存档。日志：run_b58_59.log。截图前缀：r58_*、r59_*。笔记：r59_notes.txt。
- **BUG-59 通过**：沿着农舍门前的路往西走、往东走都不会进屋（日志里进屋记录前后都是 7 次，没有增加）。站在台阶上往北能进门，往南能出门（r59_path_west/east、r59_enter、r59_exit）。go-home 没测，因为只有睡觉能触发，而睡觉会存档。
- **BUG-58 部分通过，没有发现失败**：
  - 农舍左右两侧都在墙角被挡住（r58_house_e/w）。
  - 谷仓西侧不会穿模（r58_barn_w），正门会挡住（r58_barn_front）。
  - 谷仓东侧被一块石头先挡住，这次测试无效。
  - 鸡舍东西两侧**未测**。
- **体型**（手工裁剪量像素，误差约 ±5%，因为前后两次截图的朝向不同）：
  - 猪：高度和玩家的比例从 1.07 变成 0.85，约为原来的 0.80，**通过**。
  - 牛：从 1.32 变成 1.06，约为原来的 0.80，**通过**。
  - 鸡：从 0.97 变成 0.81，约为原来的 0.84。但 Chicken.gd 没有设置 private_sprite_scale，用的还是默认值 1.0，判断是姿势或朝向导致的测量误差，不算 bug。
- **动画连拍通过**：r59_burst_01～20 没有空帧，没有闪烁；牛往右走时朝右，猪往左走时朝左，鸡会在正面和背面之间切换。停下后是否转成 idle 没法判断，因为动物一直在走（r59_still_*）。
- **BUG-57**：谷仓画面提示是「E 收集/喂养」（r58_barn_front），**通过**。鸡舍的提示**未看**。
- 已知未修：羊和马的方块底图（BUG-56，r59_f9）；农舍室内只画了空地板（以前就这样）。
- 另外：槽3 读档后玩家出生在村子 (410,-20)，在屏幕上方，一开始镜头看不到人物。
- 日志：1 条 ERR_CANT_OPEN，来自 audio_driver_alsa（这台机器没有声卡），没有 SCRIPT ERROR，也没有缺失贴图。

- 待补测：动物停下后转 idle（项目决定这次不算验收条件）。
- 补测（run_b57.log）：
  - 鸡舍东西两侧在墙脚被挡住，不会走进墙里或屋顶（r58_coop_e/w），**通过**。BUG-58 中鸡舍的部分可以结案。
  - 鸡舍画面提示是「E 收集/喂养」（r57_coop），**通过**。BUG-57 可以结案。
  - 谷仓东侧**未测**：东边那块石头会先把玩家挡住，从东侧走不到墙边。可以只作为记录，不阻塞验收。

## 2026-10-20 复测动物 y-sort（Actors 层，未提交）
槽3，不存档。日志：run_ysort.log。截图前缀：ys_*。这轮画面延迟 15～45 秒，证据不完整。
- **BUG-60 玩家站在动物南侧时仍被动物盖住**：
  - 复现：按 F9 刷出动物后，让玩家走到鸡或猪的正南方。
  - 期望：玩家画在动物前面。
  - 实际：鸡、猪仍画在玩家上面（ys_chicken_s、ys_pig_s）。
  - 玩家在北侧时正常（ys_pig_n、ys_chicken_n）。
  - 怀疑排序原点和脚底对不上，或者玩家不在同一个 Actors 层。另外，一个绿发村民的脚在马的北边，却画在马上面（ys_cow_n）。
- **BUG-61 栅栏永远在下层**：
  - 玩家站在栅栏北侧时，画在栅栏上面（ys_fence_1）。
  - 代码注释写的是栅栏在 TerrainOverlay 层（z -2），比 Actors 层低，所以栅栏永远挡不住人和动物。
  - 这次没观察到动物经过栅栏。
- **建筑**（证据不足）：
  - 谷仓南侧：屋檐可能压到玩家头发几个像素（ys_barn_s），没法下结论。谷仓北侧的截图是旧画面。
  - 鸡舍和农舍北侧都没测到。
  - 注释写 FarmMap/Objects 在 z 7。如果属实，建筑会永远盖住角色，需要 Grok Build 确认。
  - 没看到动物走进建筑或画在屋顶上。
- 动物进出鸡舍和谷仓：在谷仓边观察约 20 秒，没有动物进出。**未测完**。
- **F9 通过**：5 只都生成了（日志："DEBUG F9 spawned 5 animals"）。羊和马还是方块底图，就是已知的 BUG-56。
- **BUG-62 新 UI：当前选中按钮的文字看不清**。主菜单和暂停菜单的第一个按钮是白字配米色底（ys_ui、ys_ui_pause）。另外，任务面板会挡住左上角的动物，只是布局备注。右上角日期被截是已知问题，没报。
- 日志：没有 SCRIPT ERROR，也没有缺失贴图。只有 1 条音频驱动的 ERR_CANT_OPEN。
- 其他：
  - 村子的镜头一开始没跟着玩家。
  - 测试中途 src/autoload/UIManager.gd 变成已修改状态，不是测试改的，可能是 Grok Build 同时在改。

- 2026-10-21：BUG-61（栅栏）和建筑层级按 Sand 的 C 方案，记为已知问题，等 Phase 2 改地图时一起重构，这一轮不测。

## 2026-10-21 BUG-60 复测 + focus_first（槽3，未存档，日志 run_b60.log / run_b60b.log）
- BUG-60 鸡、猪、牛：通过。玩家在南边时盖住动物，在北边时被动物盖住，6 个方向都正确（b60_pig_s/n、b60_chicken_s/n、b60_cow_s/n）。其中 pig_n 和 chicken_s 两张重叠区域很小，判定偏弱。
- 动物进出鸡舍/牛棚：未观察到。在牛棚和疑似鸡舍处各看了约 25 秒，没有动物靠近或进出，无法判定（b60_barn、b60_coop）。
- 快速反复开关界面（Esc、J 各约 10 次，再交替切换），村子和农场各做一轮：通过。游戏一直正常响应，日志里没有 focus_first 报错，也没有 SCRIPT ERROR（b60_ui_spam、b60_ui_spam_farm）。J 键打开的界面没有确认真的显示出来。
- UI v2：选中按钮的文字清楚可读，BUG-62 在 v2 下不再出现（b60_ui_menu、b60_ui_pause）。
- 日志：唯一的 ERROR 是本机没有声卡导致的 ALSA 报错（ERR_CANT_OPEN），属于环境问题。
- 环境：第一轮时另一个 godot 进程（不是我启动的）占用约 200% CPU，人物几乎走不动；第二轮该进程已退出，正常完成。
- 补充：动物进出鸡舍、牛棚这一项不适用。据 Grok Build 说明（Animal.gd:306），动物只在换天时直接传送回窝点，不会走进门，所以没有进出过程可测。如果要测"过一天后动物是否出现在外面"，就需要在游戏里睡觉，这违反测试规则，本轮不测。

## 2026-10-21 BUG-56 复测受阻（槽3，未存档，日志 run_b56.log）
- 目标：F9 羊/马底色透明 + 脚底遮挡；鸡猪牛不变。
- 阻塞：**进农场失败**。从村子走 ←农场 后，日志里 `[Farm] Scene loaded` 出现约 15 次，每次淡出未完成就立刻 `[Village] Scene loaded` 弹回村子。中间有 `[ShippingBin] Player entered/left interaction range`。全程 `DEBUG F9` = 0，羊马相关截图未拍。
- 日志无 SCRIPT ERROR；仅有本机无声卡的 ALSA ERROR（环境问题）。
- 误点开过「删除农场 3」确认框，已取消，存档未删。
- 进出鸡舍：按约定标为不适用。

## 2026-10-21 进农场弹回修复 + BUG-56 重测（槽3，未存档，日志 run_b56b.log）
- 村子→农场：通过。淡出后停在农场，日志 Village/Farm 各加载 1 次后 Transition completed，无交替弹回（b56b_farm_enter.png）。
- BUG-56 羊/马底色：通过。无白/淡蓝不透明方块；马蹄下仅有正常接触阴影（b56_sheep_bg、b56_horse_bg）。
- 羊/马脚底遮挡：北边通过；南边通过但重叠很弱（b56_sheep_s/n、b56_horse_s/n）。
- 鸡/猪/牛：通过，外观正常，无底板回退。
- 日志：无 SCRIPT ERROR（仅本机 ALSA/V-Sync 环境警告）。
- 开局视野：day1_farm_overview.png — 农舍、南侧田、土路、门南箱子与工作台同框（夜间 21:52）。
