# AFTERLIGHT 2099: GODOT 4.x IMPLEMENTATION SPECIFICATION
> **Target Engine:** Godot 4.3+ (GDScript / C# compatible, GDScript default)  
> **Orientation / Viewport:** Portrait Mobile (`440x956` or `1080x2340`, test scale stretch mode `canvas_items`)  
> **Architecture Pattern:** Event-Driven Autoload Architecture (Data-Driven via Resource / JSON files)

---

## 1. System Architecture & Directory Structure

```text
res://
├── assets/
│   ├── fonts/               # Impact/Trebuchet/Heavy font files
│   ├── sprites/
│   │   ├── icons/           # Item icons (64x64 PNG / SVG)
│   │   ├── ui/              # Stone slabs, rustic frames, durability bars
│   │   └── characters/      # Operative, Archon AI, Worker Drone portraits
│   └── sounds/              # Tap, craft success, failure, level up, breakdown
├── data/
│   ├── recipes.json         # Master 3+1 crafting definitions
│   ├── items.json           # All item metadata (stack, durability, food value)
│   ├── quests.json          # Linear Archon AI campaign quests
│   └── colony_buildings.json# Housing, farm generators, prestige values
├── scenes/
│   ├── main.tscn            # Master orchestrator scene
│   ├── hud/
│   │   ├── top_action_bar.tscn      # 5 stone buttons
│   │   ├── character_trio.tscn      # Protagonist, NPC Archon, Minion Drone
│   │   ├── container_drawer.tscn    # Upper dynamic container popup
│   │   ├── crafting_bench.tscn      # 3+1 Stone slab bench
│   │   └── inventory_grid.tscn      # 5x4 (20 slots) grid
│   ├── modals/
│   │   ├── modal_protag_skills.tscn # Skill sheet + success preview
│   │   ├── modal_protag_bag.tscn    # 4 gear + 4 GP cyberware slots
│   │   ├── modal_city.tscn          # Bastion settlement & Love Hut reset
│   │   ├── modal_minion_skills.tscn # Gathering silhouettes & comm level
│   │   └── modal_minion_bag.tscn    # Gather Type filter slot
│   └── components/
│       ├── item_slot.tscn           # Reusable inventory/bench slot UI
│       └── toast_notifier.tscn      # Floating action toasts
└── scripts/
    ├── autoloads/
    │   ├── game_state.gd            # Energy, player stats, minion stats
    │   ├── inventory_manager.gd     # 20-slot storage, bags, transfer logic
    │   ├── crafting_system.gd       # 3+1 matching, durability, skill XP
    │   ├── quest_manager.gd         # Archon AI quest chain tracker
    │   └── colony_manager.gd        # Passive generation, workers, prestige
    └── ui/
        ├── hud_controller.gd
        └── slot_view.gd
```

---

## 2. Core Autoload Singletons & Data Schemas

### A. Data Schema: `data/items.json`
```json
{
  "raw_mineral": {
    "name": "Raw Mineral",
    "icon": "res://assets/sprites/icons/raw_mineral.png",
    "type": "material",
    "max_stack": 100
  },
  "heavy_slag": {
    "name": "Heavy Slag",
    "icon": "res://assets/sprites/icons/heavy_slag.png",
    "type": "tool",
    "max_stack": 1,
    "max_durability": 15
  },
  "banana_pod": {
    "name": "Banana Pod",
    "icon": "res://assets/sprites/icons/banana_pod.png",
    "type": "food",
    "energy_value": 5,
    "max_stack": 100
  },
  "grandmas_container": {
    "name": "Grandma's Conta",
    "icon": "res://assets/sprites/icons/container_box.png",
    "type": "container",
    "max_stack": 1,
    "capacity": 8
  }
}
```

### B. Data Schema: `data/recipes.json` (Strict 3+1 Rule)
```json
[
  {
    "id": "recipe_mono_shard",
    "name": "Monomolecular Shard",
    "inputs": ["Raw Mineral"],
    "tool": "Heavy Slag",
    "discipline": "toolCraft",
    "level_req": 0,
    "output_item": "mono_shard",
    "output_qty": 1,
    "output_durability": 35
  },
  {
    "id": "recipe_peeled_banana",
    "name": "Peeled Banana",
    "inputs": ["Banana Pod"],
    "tool": null,
    "discipline": "mealPrep",
    "level_req": 0,
    "output_item": "peeled_banana",
    "output_qty": 1,
    "output_durability": 0
  },
  {
    "id": "recipe_diced_banana",
    "name": "Diced Banana Wafers",
    "inputs": ["Peeled Banana"],
    "tool": "Monomolecular Shard",
    "discipline": "mealPrep",
    "level_req": 0,
    "output_item": "banana_wafers",
    "output_qty": 1,
    "output_durability": 0
  }
]
```

---

## 3. Core Engine Scripts

### `scripts/autoloads/game_state.gd`
```gdscript
extends Node

signal energy_updated
signal skill_leveled(discipline: String, new_val: float)

var protag_energy: float = 114.0
var max_protag_energy: float = 114.0
var minion_energy: float = 137.0
var max_minion_energy: float = 137.0

# Base Skills
var skills = {
	"mealPrep": 37.2,
	"toolCraft": 23.6,
	"woodWork": 25.9,
	"skinning": 11.2,
	"cooking": 22.3,
	"tailoring": 1.1,
	"pottery": 6.7,
	"construction": 0.0
}

# Equipped Glove Bonus (+30.0 from GP shop)
var glove_modifier: float = 30.0

var minion_skills = {
	"scavenging": 55.2,
	"lumber": 29.6,
	"hunting": 20.7,
	"fishing": 4.6,
	"communication": 58.8
}

var minion_gather_target: String = "" # Empty = random scrap

func get_effective_skill(discipline: String) -> float:
	return skills.get(discipline, 0.0) + glove_modifier

func consume_energy(target: String, amount: float) -> bool:
	if target == "player":
		if protag_energy < amount: return false
		protag_energy -= amount
	else:
		if minion_energy < amount: return false
		minion_energy -= amount
	energy_updated.emit()
	return true

func replenish_energy(target: String, amount: float):
	if target == "player":
		protag_energy = min(max_protag_energy, protag_energy + amount)
	else:
		minion_energy = min(max_minion_energy, minion_energy + amount)
	energy_updated.emit()

func add_skill_xp(discipline: String):
	if skills.has(discipline):
		skills[discipline] = snappedf(skills[discipline] + 0.1, 0.1)
		skill_leveled.emit(discipline, skills[discipline])
```

---

### `scripts/autoloads/inventory_manager.gd`
```gdscript
extends Node

signal inventory_changed
signal container_opened(slot_index: int)

# Primary 20-slot inventory (5 columns x 4 rows)
var slots: Array = []
var active_container_index: int = -1

func _ready():
	slots.resize(20)
	for i in range(20):
		slots[i] = null
	_seed_starter_items()

func _seed_starter_items():
	# Seed matching Dawn of Crafting starter pack
	slots[0] = {
		"id": "grandmas_container",
		"name": "Grandma's Conta",
		"type": "container",
		"capacity": 8,
		"contents": [
			{"id": "banana_pod", "name": "Banana Pod", "qty": 8, "type": "food", "energy": 5},
			null, null, null, null, null, null, null
		]
	}
	slots[1] = {"id": "raw_mineral", "name": "Raw Mineral", "qty": 22, "type": "material"}
	slots[2] = {"id": "heavy_slag", "name": "Heavy Slag", "qty": 1, "type": "tool", "durability": 5, "max_durability": 15}
	slots[3] = {"id": "banana_pod", "name": "Banana Pod", "qty": 14, "type": "food", "energy": 5}
	slots[4] = {"id": "carbon_strut", "name": "Carbon Strut", "qty": 32, "type": "material"}
	slots[5] = {"id": "polymer_tendon", "name": "Polymer Tendon", "qty": 17, "type": "material"}
	inventory_changed.emit()

func add_item(item_data: Dictionary) -> bool:
	# Stacking pass (if not a tool or container)
	if item_data.get("type") != "tool" and item_data.get("type") != "container":
		for i in range(20):
			if slots[i] and slots[i]["name"] == item_data["name"] and slots[i]["qty"] < 100:
				var space = 100 - slots[i]["qty"]
				var to_add = min(space, item_data["qty"])
				slots[i]["qty"] += to_add
				item_data["qty"] -= to_add
				if item_data["qty"] <= 0:
					inventory_changed.emit()
					return true

	# Empty slot search pass
	for i in range(20):
		if slots[i] == null:
			slots[i] = item_data.duplicate(true)
			inventory_changed.emit()
			return true

	return false # Inventory is completely full
```

---

### `scripts/autoloads/crafting_system.gd`
```gdscript
extends Node

signal bench_updated(can_craft: bool, matched_recipe: Dictionary)
signal craft_success(result_name: String)

var bench_inputs: Array = [null, null, null]
var bench_tool: Dictionary = {}
var recipes: Array = []
var active_match: Dictionary = {}

func _ready():
	_load_recipes()

func _load_recipes():
	# Populated directly from recipes.json
	pass

func set_input(slot_idx: int, item: Dictionary):
	bench_inputs[slot_idx] = item
	evaluate_bench()

func set_tool(tool_item: Dictionary):
	bench_tool = tool_item
	evaluate_bench()

func clear_bench():
	bench_inputs = [null, null, null]
	bench_tool = {}
	evaluate_bench()

func evaluate_bench():
	var in_names = []
	for item in bench_inputs:
		if item != null:
			in_names.append(item["name"])
	in_names.sort()

	var tool_name = bench_tool.get("name", null)

	for r in recipes:
		var recipe_inputs = r["inputs"].duplicate()
		recipe_inputs.sort()
		if in_names == recipe_inputs and r["tool"] == tool_name:
			active_match = r
			bench_updated.emit(true, r)
			return

	active_match = {}
	bench_updated.emit(false, {})

func craft_active_recipe() -> bool:
	if active_match.is_empty():
		return false

	if not GameState.consume_energy("player", 2.0):
		return false

	# Deduct Tool Durability by exactly 1
	if not bench_tool.is_empty():
		bench_tool["durability"] -= 1
		if bench_tool["durability"] <= 0:
			bench_tool = {} # Tool shattered

	# Deduct 1 count from each bench input
	for i in range(3):
		bench_inputs[i] = null

	# Add Result item into Inventory
	var result_data = {
		"id": active_match["output_item"],
		"name": active_match["name"],
		"qty": active_match["output_qty"],
		"type": "tool" if active_match["output_durability"] > 0 else "material",
		"durability": active_match["output_durability"],
		"max_durability": active_match["output_durability"]
	}
	InventoryManager.add_item(result_data)

	# Grant Discipline XP (+0.1)
	GameState.add_skill_xp(active_match["discipline"])

	craft_success.emit(active_match["name"])
	evaluate_bench()
	return true
```

---

## 4. UI Layout Configuration (Godot Control Tree)

To avoid viewport clipping or zero-height collapses, configure the root UI nodes using **Containers with explicit minimum sizes**:

```text
Main (Control) [Anchor: Full Rect]
└── Background (TextureRect / ColorRect: #3a2211)
    └── AppContainer (VBoxContainer) [Custom Min Size: (420, 900), Anchor: Center]
        │
        ├── TopActionBar (GridContainer: 5 Columns)
        │   ├── BtnSkills (TextureButton / PanelContainer: Min Size 76x50)
        │   ├── BtnPlayerBag (TextureButton / PanelContainer: Min Size 76x50)
        │   ├── BtnCity (TextureButton / PanelContainer: Min Size 76x50)
        │   ├── BtnMinionSkills (TextureButton / PanelContainer: Min Size 76x50)
        │   └── BtnMinionBag (TextureButton / PanelContainer: Min Size 76x50)
        │
        ├── CharacterStage (HBoxContainer: Separation 10, Alignment Center)
        │   ├── ProtagonistPod (VBoxContainer)
        │   │   ├── Avatar (TextureRect: 60x60, Circular Mask)
        │   │   └── EnergyBar (ProgressBar: Min Size 80x16, Green StyleBox)
        │   ├── ArchonPod (VBoxContainer)
        │   │   ├── QuestBubble (PanelContainer: Floating / Bouncing)
        │   │   └── Avatar (TextureRect: 60x60)
        │   └── DronePod (VBoxContainer)
        │       ├── Avatar (TextureRect: 60x60)
        │       └── EnergyBar (ProgressBar: Min Size 80x16, Green StyleBox)
        │
        ├── UpperContainerDrawer (PanelContainer: Border Orange, Visible: False)
        │   └── DrawerGrid (GridContainer: 4 Columns, Min Height: 120px)
        │
        ├── CraftingSlab (PanelContainer: Stone Texture, Min Height: 68px)
        │   └── HBoxContainer
        │       ├── InputSlot0 (ItemSlot: 54x54)
        │       ├── InputSlot1 (ItemSlot: 54x54)
        │       ├── InputSlot2 (ItemSlot: 54x54)
        │       ├── ToolSlot (ItemSlot: 54x54, Orange Border)
        │       └── CraftButton (Button: Orange StyleBox, Expand Horizontal)
        │
        └── InventoryWrapper (PanelContainer: Dark Wood Inset)
            └── InventoryGrid (GridContainer: 5 Columns)
                └── 20x ItemSlot instances (Custom Min Size: 64x64 each)
```

---

## 5. Antigravity Prompt Directives & Sprint Roadmap

Feed these exact sequential prompts into **Antigravity / Cursor** to implement the Godot project without regressions:

### Sprint 1: Data Contracts & Inventory Grid
> **Prompt for Antigravity:**  
> "Create Godot 4.3 GDScript singletons `GameState` and `InventoryManager`. Setup a 5x4 GridContainer that renders 20 slots of size 64x64. Implement slot data rendering showing icon, quantity badge in the top right, and a green durability progress bar at the bottom for tools with remaining uses. Verify slot clicks return the index without errors."

### Sprint 2: 3+1 Crafting Terminal & Durability Mechanics
> **Prompt for Antigravity:**  
> "Create `CraftingSystem.gd` and the `crafting_slab.tscn` node containing 3 input slots, 1 tool slot (orange border), and a Craft button. When the user taps an inventory item, if it's a tool and tool slot is vacant, seat it in the tool slot; otherwise load it into the first empty input slot. Auto-evaluate against `recipes.json`. On pressing Craft: deduct 1 durability from the tool, remove 1 of each input, add the crafted item to inventory, consume 2 energy, and add +0.1 to the matching skill."

### Sprint 3: Character Trio, Energy, and Minion Loop
> **Prompt for Antigravity:**  
> "Implement the top character stage. Left is Operative with 114 EN, Center is Archon AI NPC with a quest speech bubble, Right is Worker Drone with 137 EN. Tapping food in inventory feeds the player or drone and restores energy. Tapping the drone initiates a scavenge action: roll accuracy based on `minion_skills.communication` ($P = \text{clamp}(\text{comm} \times 1.2\%, 10\%, 95\%)$), return targeted or random salvage, consume 2 EN, and add +0.1 to Scavenging and Communication."

### Sprint 4: Nested Container Storage (Upper Area Drawer)
> **Prompt for Antigravity:**  
> "Implement the `upper_container_drawer.tscn` popup directly above the crafting slab. When slot 0 (Grandma's Container) or any container in the 20 inventory slots is clicked, do not send it to crafting; instead, toggle open the upper drawer showing its 8 internal slots. Allow one-tap extraction of items from the container into empty slots in the main 20 inventory slots. Include a clear 'X' close button."

### Sprint 5: Modals, Quest Log, and Love Hut Prestige Reset
> **Prompt for Antigravity:**  
> "Connect the 5 top stone buttons to their respective popups: Protagonist Skills (showing base level + glove bonus), Player Bag (4 equipment + 4 GP cyberware slots), Sector Citadel / City (Housing worker limits and the Love Hut Recombination Pod reset), Minion Skills, and Minion Bag (with Gather Type slot). Implement the quest progress check verifying completed craft outputs."