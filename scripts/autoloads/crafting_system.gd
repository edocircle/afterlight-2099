extends Node
## 3+1 crafting bench: 3 input slots + 1 tool slot, matched against data/recipes.json by item id.

signal bench_updated
signal message(text: String)
signal craft_success(result_id: String)

const RECIPES_PATH := "res://data/recipes.json"
const ENERGY_COST := 2.0
const INPUT_COUNT := 3

var bench_inputs: Array = [null, null, null]
var bench_tool: Variant = null
var recipes: Array = []
var active_match: Dictionary = {}


func _ready() -> void:
	_load_recipes()
	InventoryManager.slot_clicked.connect(_on_inventory_slot_clicked)


func _load_recipes() -> void:
	var f := FileAccess.open(RECIPES_PATH, FileAccess.READ)
	if f == null:
		push_error("Cannot open %s" % RECIPES_PATH)
		return
	var parsed: Variant = JSON.parse_string(f.get_as_text())
	if parsed is Array:
		recipes = parsed
	else:
		push_error("Invalid JSON in %s" % RECIPES_PATH)


func _on_inventory_slot_clicked(index: int) -> void:
	var item: Variant = InventoryManager.get_slot(index)
	if item == null:
		return
	var type: String = InventoryManager.get_def(item["id"]).get("type", "")
	if type == "container":
		return # containers open the drawer (Sprint 4), never go to the bench

	if type == "tool" and bench_tool == null:
		bench_tool = InventoryManager.take_one(index)
		evaluate_bench()
		return

	for i in INPUT_COUNT:
		if bench_inputs[i] == null:
			bench_inputs[i] = InventoryManager.take_one(index)
			evaluate_bench()
			return
	message.emit("Bench inputs are full.")


func return_input(slot_idx: int) -> void:
	var item: Variant = bench_inputs[slot_idx]
	if item == null:
		return
	if InventoryManager.add_item(item):
		bench_inputs[slot_idx] = null
		evaluate_bench()
	else:
		message.emit("Cargo full! No free slots.")


func return_tool() -> void:
	if bench_tool == null:
		return
	if InventoryManager.add_item(bench_tool):
		bench_tool = null
		evaluate_bench()
	else:
		message.emit("Cargo full! No free slots.")


func evaluate_bench() -> void:
	var ids: Array = []
	for item in bench_inputs:
		if item != null:
			ids.append(item["id"])
	ids.sort()
	var tool_id: String = bench_tool["id"] if bench_tool != null else ""

	active_match = {}
	for r in recipes:
		var recipe_inputs: Array = r["inputs"].duplicate()
		recipe_inputs.sort()
		if ids == recipe_inputs and String(r.get("tool", "")) == tool_id:
			active_match = r
			break
	bench_updated.emit()


func reset_bench() -> void:
	bench_inputs = [null, null, null]
	bench_tool = null
	evaluate_bench()


func can_craft() -> bool:
	return not active_match.is_empty()


func get_active_success_chance() -> float:
	if active_match.is_empty():
		return 0.0
	var disc: String = active_match.get("discipline", "")
	var req: float = float(active_match.get("level_req", 0))
	return GameState.get_recipe_success_chance(disc, req)


func craft_active_recipe() -> bool:
	if active_match.is_empty():
		return false

	var out_id: String = active_match["output_item"]
	var out_qty: int = int(active_match.get("output_qty", 1))
	var disc: String = active_match.get("discipline", "")
	var req: float = float(active_match.get("level_req", 0))

	if not InventoryManager.can_add(out_id, out_qty):
		message.emit("Cargo full! No free slots.")
		return false
	if not GameState.consume_energy("player", ENERGY_COST):
		message.emit("Energy low! Consume food rations.")
		return false

	# Tool loses exactly 1 durability; shatters at 0.
	if bench_tool != null:
		bench_tool["durability"] = int(bench_tool["durability"]) - 1
		if bench_tool["durability"] <= 0:
			var tool_name: String = InventoryManager.get_def(bench_tool["id"]).get("name", "Tool")
			message.emit("%s shattered!" % tool_name)
			bench_tool = null

	# 1 of each input is consumed (each bench slot holds exactly 1).
	for i in INPUT_COUNT:
		bench_inputs[i] = null

	var success_chance := GameState.get_recipe_success_chance(disc, req)
	var roll := randf()
	var out_name: String = InventoryManager.get_def(out_id).get("name", out_id)

	# Apply XP via progression formula (both on success and failure per Fail-to-Learn Paradox)
	var xp_res := GameState.apply_craft_skill_xp(disc, req)
	var xp_msg := ""
	if xp_res["diminished"]:
		xp_msg = " [0 XP: Diminished]"
	elif xp_res["gained"] > 0.0:
		xp_msg = " [+%.1f Skill!]" % xp_res["gained"]
	else:
		xp_msg = " [%d/%d crafts]" % [xp_res["count"], xp_res["req_crafts"]]

	if roll < success_chance:
		InventoryManager.add_item(InventoryManager.make_item(out_id, out_qty))
		message.emit("Crafted %s!%s" % [out_name, xp_msg])
		craft_success.emit(out_id)
	else:
		# The "Fail-to-Learn" Paradox
		message.emit("Synthesis Failed (%d%% Chance)!%s (Fail-to-Learn)" % [int(success_chance * 100.0), xp_msg])

	evaluate_bench()
	return true
