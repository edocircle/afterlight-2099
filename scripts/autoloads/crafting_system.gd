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

	if type == "tool":
		if bench_tool == null:
			bench_tool = InventoryManager.take_one(index)
			evaluate_bench()
		return

	# If the item is already on the bench in an input slot, stack it into that same slot
	for i in INPUT_COUNT:
		if bench_inputs[i] != null and bench_inputs[i]["id"] == item["id"]:
			var one: Variant = InventoryManager.take_one(index)
			if one != null:
				bench_inputs[i]["qty"] = int(bench_inputs[i]["qty"]) + 1
				evaluate_bench()
			return

	# Otherwise put into the first empty slot
	for i in INPUT_COUNT:
		if bench_inputs[i] == null:
			bench_inputs[i] = InventoryManager.take_one(index)
			evaluate_bench()
			return
	message.emit("Bench inputs are full.")


func drop_item_to_input_slot(slot_idx: int, inv_index: int) -> bool:
	var item: Variant = InventoryManager.get_slot(inv_index)
	if item == null:
		return false
	var def := InventoryManager.get_def(item["id"])
	var type: String = def.get("type", "")
	if type == "container":
		message.emit("Containers cannot be used as crafting inputs.")
		return false
	if type == "tool":
		message.emit("Tools must be placed in the dedicated tool slot.")
		return false

	# If this slot has an item: if same id, stack it. If empty, take one. If different id, notify.
	if bench_inputs[slot_idx] != null:
		if bench_inputs[slot_idx]["id"] == item["id"]:
			var one: Variant = InventoryManager.take_one(inv_index)
			if one != null:
				bench_inputs[slot_idx]["qty"] = int(bench_inputs[slot_idx]["qty"]) + 1
				evaluate_bench()
				return true
		else:
			message.emit("Slot already occupied by %s." % InventoryManager.get_def(bench_inputs[slot_idx]["id"]).get("name", "item"))
			return false
	else:
		# Check if this item is already in another bench slot: stack into that slot instead
		for i in INPUT_COUNT:
			if bench_inputs[i] != null and bench_inputs[i]["id"] == item["id"]:
				var one: Variant = InventoryManager.take_one(inv_index)
				if one != null:
					bench_inputs[i]["qty"] = int(bench_inputs[i]["qty"]) + 1
					evaluate_bench()
					return true
		bench_inputs[slot_idx] = InventoryManager.take_one(inv_index)
		evaluate_bench()
		return true
	return false


func drop_item_to_tool_slot(inv_index: int) -> bool:
	var item: Variant = InventoryManager.get_slot(inv_index)
	if item == null:
		return false
	var def := InventoryManager.get_def(item["id"])
	var type: String = def.get("type", "")
	if type != "tool":
		message.emit("Only tools can be placed in the tool slot.")
		return false
	if bench_tool != null:
		message.emit("Tool slot is already occupied.")
		return false
	bench_tool = InventoryManager.take_one(inv_index)
	evaluate_bench()
	return true



func return_input(slot_idx: int) -> void:
	var item: Variant = bench_inputs[slot_idx]
	if item == null:
		return
	# Return the item stack to inventory
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
	var single_out_qty: int = int(active_match.get("output_qty", 1))
	var disc: String = active_match.get("discipline", "")
	var req: float = float(active_match.get("level_req", 0))

	# Determine max batches based on available input stack sizes
	var max_batches: int = 999999
	for i in INPUT_COUNT:
		if bench_inputs[i] != null:
			max_batches = mini(max_batches, int(bench_inputs[i].get("qty", 1)))
	if max_batches <= 0 or max_batches == 999999:
		return false

	# Cap by tool durability if a tool is required
	if bench_tool != null:
		var tool_dur: int = int(bench_tool.get("durability", 1))
		max_batches = mini(max_batches, tool_dur)

	# Cap by player energy
	var max_by_energy: int = int(GameState.protag_energy / ENERGY_COST)
	if max_by_energy < 1:
		message.emit("Energy low! Consume food rations.")
		return false
	max_batches = mini(max_batches, max_by_energy)

	# Cap by inventory capacity for output
	while max_batches > 0 and not InventoryManager.can_add(out_id, max_batches * single_out_qty):
		max_batches -= 1

	if max_batches <= 0:
		message.emit("Cargo full! No free slots.")
		return false

	# Deduct energy for batches
	GameState.consume_energy("player", ENERGY_COST * max_batches)

	# Deduct tool durability
	if bench_tool != null:
		bench_tool["durability"] = int(bench_tool["durability"]) - max_batches
		if bench_tool["durability"] <= 0:
			var tool_name: String = InventoryManager.get_def(bench_tool["id"]).get("name", "Tool")
			message.emit("%s shattered!" % tool_name)
			bench_tool = null

	# Consume inputs
	for i in INPUT_COUNT:
		if bench_inputs[i] != null:
			bench_inputs[i]["qty"] = int(bench_inputs[i]["qty"]) - max_batches
			if int(bench_inputs[i]["qty"]) <= 0:
				bench_inputs[i] = null

	var success_chance := GameState.get_recipe_success_chance(disc, req)
	var out_name: String = InventoryManager.get_def(out_id).get("name", out_id)

	var successes := 0
	var failures := 0
	var total_xp_gained := 0.0

	for b in max_batches:
		var roll := randf()
		var xp_res := GameState.apply_craft_skill_xp(disc, req)
		total_xp_gained += float(xp_res.get("gained", 0.0))
		if roll < success_chance:
			successes += 1
		else:
			failures += 1

	if successes > 0:
		InventoryManager.add_item(InventoryManager.make_item(out_id, successes * single_out_qty))
		craft_success.emit(out_id)

	var xp_msg := ""
	if total_xp_gained > 0.0:
		xp_msg = " [+%.1f Skill!]" % total_xp_gained

	if max_batches == 1:
		if successes > 0:
			message.emit("Crafted %s!%s" % [out_name, xp_msg])
		else:
			message.emit("Synthesis Failed (%d%% Chance)!%s (Fail-to-Learn)" % [int(success_chance * 100.0), xp_msg])
	else:
		if failures == 0:
			message.emit("Crafted %dx %s!%s" % [successes * single_out_qty, out_name, xp_msg])
		else:
			message.emit("Batch: %dx %s created (%d failed)!%s" % [successes * single_out_qty, out_name, failures, xp_msg])

	evaluate_bench()
	return true

