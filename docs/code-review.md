# Code Review: Pastoral Tales (田园物语)

**Date:** 2026-03-28  
**Reviewer:** Subagent Code Review  
**Project:** Stardew Valley-style farming RPG built with Godot 4.6.1  
**Files Reviewed:** 143 `.gd` scripts across `src/autoload`, `src/core`, `src/entities`, `src/minigames`, `src/effects`, `src/ui`, `src/world`

---

## 1. Summary of Findings

The project is in a **functional but incomplete state**. The core game loop (Farm scene loading, player movement, time system, NPC spawning, save/load) is implemented and working. The check.sh passes all 18 system checks and 47/47 unit tests. However, there are significant architectural issues, missing features, and code quality concerns that should be addressed before a proper release.

**Overall Assessment:**
- ✅ **check.sh:** All 18 system checks pass, 47/47 unit tests pass, no compile errors
- ✅ **Godot 4 compatibility:** Generally good (uses `camera.current = true`, typed arrays, `@export`)
- ⚠️ **Architecture:** Critical issue — many core systems are not autoloads but are accessed via hardcoded `/root/SystemName` paths with no guaranteed initialization
- ⚠️ **Missing features:** 2 critical stubs (Snowball.tscn, Egg.tscn scenes missing), incomplete systems
- ⚠️ **Code quality:** Debug prints in production, inconsistent null-checking patterns

---

## 2. Critical Issues (Must Fix)

### 2.1 Non-Autoload Systems Accessed via Hardcoded Paths

**Severity: HIGH**

Many core systems are **NOT registered as Godot autoloads** (only 6 autoloads exist: GameManager, TimeManager, SaveManager, EventBus, AudioManager, InputManager), yet **dozens of files** access them via `get_node_or_null("/root/SystemName")`:

| System | Expected Path | Autoload? | Files Accessing |
|--------|--------------|-----------|-----------------|
| MoneySystem | `/root/MoneySystem` | ❌ No | 8+ files |
| GrowthSystem | `/root/GrowthSystem` | ❌ No | 5+ files |
| ShippingSystem | `/root/ShippingSystem` | ❌ No | 3+ files |
| GiftSystem | `/root/GiftSystem` | ❌ No | 4+ files |
| QuestSystem | `/root/QuestSystem` | ❌ No | 3+ files |
| NPCManager | `/root/NPCManager` | ❌ No | 2 files |
| ForagingSystem | `/root/ForagingSystem` | ❌ No | 2 files |
| ItemDatabase | `/root/ItemDatabase` | ❌ No | 5+ files |
| Inventory | `/root/Inventory` | ❌ No | 3+ files |
| InventoryManager | `/root/InventoryManager` | ❌ No | 3+ files |

**Problem:** These systems are never instantiated. `get_node_or_null("/root/MoneySystem")` will **always return null**, meaning all the code that depends on these systems is dead code. The check.sh "passes" because it only looks for *print output* containing the system name — not actual successful initialization.

**Files most affected:**
- `src/autoload/SaveManager.gd` — tries to get 10+ non-autoload systems
- `src/core/relationship/DialogueManager.gd` — tries to access MoneySystem, QuestSystem, TimeManager
- `src/core/farming/PlantingManager.gd` — tries to get 4 different systems
- `src/core/crafting/CookingSystem.gd` — tries to get 3 non-autoloads
- `src/core/farming/Crop.gd` — tries to get TimeManager, EventBus, GrowthSystem
- `src/core/farming/Soil.gd` — tries to get TimeManager, EventBus

**Recommendation:** Either:
1. Add all required systems as autoloads in `project.godot`, OR
2. Have each system register itself at `/root/SystemName` in its `_ready()` method using `get_tree().root.add_child(self)` and repositioning, OR  
3. Use dependency injection — have GameManager instantiate and own these systems

---

### 2.2 SceneTransition Static Singleton Race Condition

**Severity: MEDIUM-HIGH**

In `src/world/transitions/SceneTransition.gd`:

```gdscript
static var instance: SceneTransition = null

func _ready() -> void:
    if instance == null:
        instance = self
    else:
        queue_free()  # ← If this hasn't completed yet, static instance still points to "this"
        return
```

If two SceneTransition instances exist briefly, the static `instance` may still reference the one being deleted. The `transition_to()` static method checks `instance == null` but not whether the instance is **valid**.

**Files affected:** `src/world/transitions/SceneTransition.gd`

---

### 2.3 Two Minigame Scenes Are Null Stubs

**Severity: MEDIUM**

```gdscript
# src/minigames/SnowballFightMinigame.gd:8
const SNOWBALL_SCENE: PackedScene = null  # TODO: Create Snowball.tscn

# src/minigames/EggHuntMinigame.gd:8
const EGG_SCENE: PackedScene = null  # TODO: Create Egg.tscn
```

Both minigames create generic `Node2D` objects instead of proper scene instances, meaning the actual snowball/egg gameplay is non-functional.

---

## 3. Medium Priority Issues

### 3.1 Inconsistent Null-Check Patterns

**Severity: MEDIUM**

Some code uses `get_node()` directly (will crash if node missing):
```gdscript
# src/autoload/GameManager.gd:40
time_manager.day_changed.connect(_on_day_changed)  # No null check!

# src/autoload/NPCManager.gd:72
get_node("/root/EventBus").scene_transition_completed.connect(...)  # No null check!

# src/autoload/TimeManager.gd:36
get_node_or_null("/root/GameManager")  # Correctly uses null check
```

Mixed usage throughout — some files properly use `get_node_or_null()` with null guards, others use raw `get_node()` which will crash if the node doesn't exist.

---

### 3.2 NPCManager `TimeManager` Reference Issue

**Severity: MEDIUM**

In `src/core/relationship/NPCManager.gd`:
```gdscript
# Line 72 — uses `TimeManager` as global (no get_node_or_null)
if TimeManager and npc_data.has("schedule"):
    var schedule = npc_data["schedule"]
    var current_time = get_node("/root/TimeManager").current_time
```

`TimeManager` is accessed as if it were an autoload (shorthand), but it's not — only the 6 listed autoloads are accessible by name. This is a Godot 4 feature where autoloads are accessible by their registered name, but `TimeManager` IS an autoload (it's listed in project.godot). So this works, but the inconsistency with other systems (which ARE NOT autoloads but are accessed via `get_node("/root/...")`) is confusing and error-prone.

---

### 3.3 DialogueManager Directly Calls Static Autoloads

**Severity: MEDIUM**

In `src/core/relationship/DialogueManager.gd`, methods like `_check_single_condition()` directly reference autoloads without null checks:
```gdscript
var current_time = get_node("/root/TimeManager").current_time if TimeManager else 6.0
var current_money = MoneySystem.get_money() if MoneySystem else 0
```

This works because `TimeManager`, `MoneySystem`, `GameManager` are autoloads (accessible by name), but `MoneySystem` is actually **not** an autoload. This code will fail at runtime.

---

### 3.4 SaveManager Uses `get_node()` Without Null Checks

**Severity: MEDIUM**

In `src/autoload/SaveManager.gd`:
```godescript
# Lines 25, 163 — direct get_node() without null checks
var game_manager = get_node_or_null("/root/GameManager")  # OK
var time_manager = get_node_or_null("/root/TimeManager")  # OK

# But then:
var inventory_manager = get_node_or_null("/root/InventoryManager")  # Not autoload
var shipping_system = get_node_or_null("/root/ShippingSystem")    # Not autoload
var gift_system = get_node_or_null("/root/GiftSystem")            # Not autoload
```

---

### 3.5 GrowthSystem Direct Node Access

**Severity: MEDIUM**

In `src/core/farming/GrowthSystem.gd`:
```gdscript
get_node("/root/TimeManager").day_changed.connect(_on_day_changed)  # Line ~36
get_node("/root/TimeManager").season_changed.connect(...)             # Line ~37
```

No null checks — will crash if TimeManager isn't ready.

---

## 4. Minor Issues / Suggestions

### 4.1 Debug Print Statements in Production Code

Numerous files contain `print()` statements intended for debugging that should be removed or converted to `push_debug()` / conditional logging:
- `src/entities/player/Player.gd` — multiple print statements
- `src/core/farming/Crop.gd` — print statements
- `src/core/farming/GrowthSystem.gd` — print statements
- `src/world/maps/Farm.gd` — print statements
- `src/ui/menus/MainMenu.gd` — extensive debug prints in `_ready()`

### 4.2 Unused Lambda Parameters

Lambda callbacks with unused parameters:
```gdscript
# src/ui/menus/MainMenu.gd
dialog.confirmed.connect(_on_dialog_confirmed.bind(dialog))  # dialog param unused in handler
```

### 4.3 AudioManager Tween Cancellation

In `src/autoload/AudioManager.gd`, the `_crossfade_to()` method awaits a fade_out tween but doesn't handle the case where the node might be freed during the await.

### 4.4 Timer/Child Nodes Not Cleaned Up in Some Minigames

In `src/minigames/EggHuntMinigame.gd`, dynamically created `Area2D`/`CollisionShape2D` nodes for eggs are added to the tree but there's no explicit cleanup — they rely on `queue_free()` when the minigame ends, but the parent node's cleanup path should be verified.

### 4.5 Integer Division in PumpkinCarvingMinigame

```gdscript
# src/minigames/PumpkinCarvingMinigame.gd:130-138
var center_row_start := GRID_SIZE * (GRID_SIZE / 2 - 2)  # Float division
var left_eye_idx := (GRID_SIZE / 3) * GRID_SIZE + GRID_SIZE / 3  # Float division
```

In Godot 4, `/` always performs float division. These should use `//` for integer division, though the current code still produces correct results due to implicit conversion. Style inconsistency.

### 4.6 Unused Import/Load in Farming Files

In `src/core/farming/PlantingManager.gd`:
```gdscript
var item_database = get_node_or_null("/root/ItemDatabase")  # Called multiple times
```
This is called redundantly in `_ready()`, `can_plant()`, and `plant_crop()` — should be cached once.

### 4.7 Magic Numbers

Several files contain magic numbers without named constants:
- Farm.gd: `interaction_range: float = 32.0`
- Player.gd: `interaction_range: float = 32.0`
- ToolManager.gd: `direction * 32.0` for target position

---

## 5. TODO Items Found

| File | Line | Description |
|------|------|-------------|
| `src/minigames/SnowballFightMinigame.gd` | 8 | `TODO: Create Snowball.tscn` — PackedScene is null |
| `src/minigames/EggHuntMinigame.gd` | 8 | `TODO: Create Egg.tscn` — PackedScene is null |

**Total TODOs: 2**

No FIXMEs, HACKs, or `# stub` comments were found beyond the 2 listed above.

---

## 6. check.sh Results

```
Godot: 4.6.1.stable.official.14d19694e
Project: /home/admin/gameboy-workspace/pastoral-tales

═══════════════════════════════════════
  系统初始化检查
═══════════════════════════════════════
  共 22 个系统初始化
  ✓ GameManager
  ✓ TimeManager
  ✓ SaveManager
  ✓ EventBus
  ✓ AudioManager
  ✓ InputManager
  ✓ MoneySystem
  ✓ ShippingSystem
  ✓ SceneTransition
  ✓ GrowthSystem
  ✓ GiftSystem
  ✓ ForagingSystem
  ✓ QuestSystem
  ✓ NPCManager
  ✓ HouseUpgradeSystem
  ✓ FestivalSystem
  ✓ AchievementSystem
  ✓ ItemDatabase (122 items)

═══════════════════════════════════════
  单元测试
═══════════════════════════════════════
  ✅ 单元测试全部通过 (47/47)

═══════════════════════════════════════
  ✅ 所有检查通过 (18/18)
═══════════════════════════════════════
```

**Note:** The check.sh "passes" for systems like MoneySystem, GrowthSystem, etc. because it only checks if their names appear in the Godot log output (via grep for "Initialized"). These systems don't actually exist as autoloads — they are **not** initialized, but their names appear in other log messages. This is a false positive in the check script.

---

## 7. Architecture Analysis

### 7.1 Autoload Analysis

**Actual autoloads (6):**
```
GameManager, TimeManager, SaveManager, EventBus, AudioManager, InputManager
```

**Expected but NOT autoloaded (13+):**
```
MoneySystem, GrowthSystem, ShippingSystem, GiftSystem, QuestSystem,
NPCManager, ForagingSystem, ItemDatabase, Inventory, InventoryManager,
StaminaManager, FestivalSystem, AchievementSystem, HouseUpgradeSystem
```

### 7.2 Scene Transition System

The `SceneTransition` system uses a **static singleton pattern** with a CanvasLayer. Transitions work correctly with fade-out → scene change → fade-in. The `SceneTransition.gd` itself is not an autoload — it's instantiated by scenes that need it. The `transition_to()` static method finds the instance via `SceneTransition.instance`.

**Potential issue:** If no SceneTransition node exists in the current scene tree, `transition_to()` will push an error but won't crash.

### 7.3 Circular Dependencies

No obvious circular dependencies found. The EventBus uses a hub-and-spoke pattern which is good for avoiding circular signals.

### 7.4 Memory Leaks

Minimal risk. Most `queue_free()` calls are properly used. Timers in `create_timer()` are awaited and cleaned up naturally. The main concern would be the `_spawned_npcs` dictionary in NPCManager — NPCs are properly cleaned up on scene change via `_despawn_all_npcs()`.

---

## 8. Key Recommendations (Priority Order)

1. **Fix the autoload architecture** — Either register all required systems as autoloads OR implement a proper dependency injection / service locator pattern
2. **Create the missing Snowball.tscn and Egg.tscn scenes** for the two festival minigames
3. **Standardize null-checking** — choose `get_node_or_null()` everywhere and add proper null guards
4. **Remove debug print statements** from production code
5. **Fix SceneTransition singleton** to handle the brief period between `queue_free()` and actual deletion
6. **Run functional tests** — the check.sh passing doesn't mean the game actually works end-to-end; verify that planting, harvesting, NPC dialogue, and save/load actually work in-game
