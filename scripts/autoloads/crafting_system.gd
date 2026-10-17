extends Node
## 3+1 crafting bench: 3 input slots + 1 tool slot, matched against data/recipes.json by item id.

signal bench_updated
signal message(text: String)
signal craft_success(result_id: String)

const RECIPES_PATH := "res://data/recipes.json"
const ENERGY_COST := 2.0
const INPUT_COUNT := 3

const ITEM_ALIASES: Dictionary = {
	"raw_mineral": "raw_mineral_chunk",
	"heavy_slag": "heavy_slag_chunk",
	"nano_strips": "nano_grid_strips",
	"azure_berry": "azure_bio_berry",
	"crimson_berry": "crimson_bio_berry",
	"composite_log": "dense_composite_log",
	"hard_chitin": "hardened_bone_spike",
	"mono_shard": "monomolecular_shard",
	"peeled_banana": "peeled_banana_pod",
	"banana_wafers": "diced_banana_wafers",
	"pneu_hatchet": "pneumatic_hatchet",
	"field_container": "field_nanite_pod",
}

var bench_inputs: Array = [null, null, null]
var bench_tool: Variant = null
var recipes: Array = []
var active_match: Dictionary = {}


static func canonical_id(id: String) -> String:
	return ITEM_ALIASES.get(id, id)


static func ids_match(id_a: String, id_b: String) -> bool:
	return id_a == id_b or canonical_id(id_a) == canonical_id(id_b)


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

	var max_cap := int(InventoryManager.get_def(item["id"]).get("max_stack", 100))

	# If the item is already on the bench in an input slot, add 1 unit to that same slot
	for i in INPUT_COUNT:
		if bench_inputs[i] != null and ids_match(bench_inputs[i]["id"], item["id"]):
			var current_qty := int(bench_inputs[i]["qty"])
			if current_qty >= max_cap:
				message.emit("Crafting slot has reached maximum stack of %d." % max_cap)
				return
			var one: Variant = InventoryManager.take_one(index)
			if one != null:
				bench_inputs[i]["qty"] = current_qty + 1
				evaluate_bench()
			return

	# Otherwise put 1 unit into the first empty slot
	for i in INPUT_COUNT:
		if bench_inputs[i] == null:
			var one: Variant = InventoryManager.take_one(index)
			if one != null:
				bench_inputs[i] = one
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

	var max_cap := int(def.get("max_stack", 100))

	# If this slot has an item with matching id: stack into it up to 100
	if bench_inputs[slot_idx] != null:
		if ids_match(bench_inputs[slot_idx]["id"], item["id"]):
			var current_qty := int(bench_inputs[slot_idx]["qty"])
			var room := max_cap - current_qty
			if room <= 0:
				message.emit("Crafting slot has reached maximum stack of %d." % max_cap)
				return false
			var to_add := mini(room, int(item["qty"]))
			bench_inputs[slot_idx]["qty"] = current_qty + to_add
			item["qty"] = int(item["qty"]) - to_add
			if int(item["qty"]) <= 0:
				InventoryManager.slots[inv_index] = null
			InventoryManager.inventory_changed.emit()
			evaluate_bench()
			return true
		else:
			message.emit("Slot already occupied by %s." % InventoryManager.get_def(bench_inputs[slot_idx]["id"]).get("name", "item"))
			return false
	else:
		# If this item id already exists in another bench slot and has room, stack there first up to 100
		for i in INPUT_COUNT:
			if bench_inputs[i] != null and ids_match(bench_inputs[i]["id"], item["id"]):
				var cur_qty := int(bench_inputs[i]["qty"])
				var room := max_cap - cur_qty
				if room > 0:
					var to_add := mini(room, int(item["qty"]))
					bench_inputs[i]["qty"] = cur_qty + to_add
					item["qty"] = int(item["qty"]) - to_add
					if int(item["qty"]) <= 0:
						InventoryManager.slots[inv_index] = null
					InventoryManager.inventory_changed.emit()
					evaluate_bench()
					return true
		# Otherwise transfer the whole stack into this empty slot, capped at max_cap
		var to_put := mini(max_cap, int(item["qty"]))
		bench_inputs[slot_idx] = {
			"id": item["id"],
			"qty": to_put
		}
		item["qty"] = int(item["qty"]) - to_put
		if int(item["qty"]) <= 0:
			InventoryManager.slots[inv_index] = null
		InventoryManager.inventory_changed.emit()
		evaluate_bench()
		return true


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


func _refill_input_slot(slot_idx: int, item_id: String, target_qty: int) -> void:
	if item_id == "" or target_qty <= 0 or slot_idx < 0 or slot_idx >= INPUT_COUNT:
		return
	var max_cap := int(InventoryManager.get_def(item_id).get("max_stack", 100))
	var current_qty := int(bench_inputs[slot_idx]["qty"]) if bench_inputs[slot_idx] != null else 0
	var room := mini(target_qty, max_cap - current_qty)
	if room <= 0:
		return

	var total_avail := 0
	for j in InventoryManager.SLOT_COUNT:
		var inv_item: Variant = InventoryManager.slots[j]
		if inv_item != null and ids_match(inv_item["id"], item_id):
			total_avail += int(inv_item.get("qty", 1))
	if total_avail <= 0:
		return

	var to_take := mini(room, total_avail)
	var remaining_to_take := to_take
	for j in InventoryManager.SLOT_COUNT:
		if remaining_to_take <= 0:
			break
		var inv_item: Variant = InventoryManager.slots[j]
		if inv_item != null and ids_match(inv_item["id"], item_id):
			var take_amt: int = mini(remaining_to_take, int(inv_item["qty"]))
			if bench_inputs[slot_idx] == null:
				bench_inputs[slot_idx] = {
					"id": inv_item["id"],
					"qty": take_amt
				}
			else:
				bench_inputs[slot_idx]["qty"] = int(bench_inputs[slot_idx]["qty"]) + take_amt
			inv_item["qty"] = int(inv_item["qty"]) - take_amt
			remaining_to_take -= take_amt
			if int(inv_item["qty"]) <= 0:
				InventoryManager.slots[j] = null
			InventoryManager.inventory_changed.emit()


func _refill_tool(tool_id: String) -> void:
	if tool_id == "":
		return
	if bench_tool != null:
		return
	for j in InventoryManager.SLOT_COUNT:
		var inv_item: Variant = InventoryManager.slots[j]
		if inv_item != null and ids_match(inv_item["id"], tool_id):
			var dur: int = int(inv_item.get("durability", 1))
			if dur > 0:
				bench_tool = InventoryManager.take_one(j)
				InventoryManager.inventory_changed.emit()
				return


func evaluate_bench() -> void:
	var ids: Array = []
	for item in bench_inputs:
		if item != null:
			ids.append(canonical_id(item["id"]))
	ids.sort()
	var tool_id: String = canonical_id(bench_tool["id"]) if bench_tool != null else ""

	active_match = {}
	for r in recipes:
		var recipe_inputs: Array = []
		for rin in r.get("inputs", []):
			recipe_inputs.append(canonical_id(rin))
		recipe_inputs.sort()
		var r_tool: String = canonical_id(String(r.get("tool", "")))
		if ids == recipe_inputs and r_tool == tool_id:
			active_match = r
			break
	bench_updated.emit()


func reset_bench() -> void:
	bench_inputs = [null, null, null]
	bench_tool = null
	evaluate_bench()


func can_craft() -> bool:
	if active_match.is_empty():
		return false
	var input_costs: Dictionary = active_match.get("input_costs", {})
	for i in INPUT_COUNT:
		if bench_inputs[i] != null:
			var in_id: String = bench_inputs[i]["id"]
			var cost: int = int(input_costs.get(in_id, input_costs.get(canonical_id(in_id), 1)))
			if int(bench_inputs[i].get("qty", 1)) < cost:
				return false
	return true


func get_active_success_chance() -> float:
	if active_match.is_empty():
		return 0.0
	var disc: String = active_match.get("discipline", "")
	var req: float = float(active_match.get("level_req", 0))
	return GameState.get_recipe_success_chance(disc, req)


func craft_active_recipe() -> bool:
	if active_match.is_empty():
		return false

	var prev_recipe: Dictionary = active_match.duplicate(true)
	var prev_inputs: Array = []
	for i in INPUT_COUNT:
		if bench_inputs[i] != null:
			prev_inputs.append(bench_inputs[i]["id"])
		else:
			prev_inputs.append("")
	var prev_tool_id: String = bench_tool["id"] if bench_tool != null else ""

	var out_id: String = active_match["output_item"]
	var single_out_qty: int = int(active_match.get("output_qty", 1))
	var disc: String = active_match.get("discipline", "")
	var req: float = float(active_match.get("level_req", 0))
	var input_costs: Dictionary = active_match.get("input_costs", {})

	# Determine max batches based on available input stack sizes
	var max_batches: int = 999999
	for i in INPUT_COUNT:
		if bench_inputs[i] != null:
			var in_id: String = bench_inputs[i]["id"]
			var cost: int = int(input_costs.get(in_id, input_costs.get(canonical_id(in_id), 1)))
			if cost <= 0:
				cost = 1
			max_batches = mini(max_batches, int(float(bench_inputs[i].get("qty", 1)) / float(cost)))
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
	var consumed_qtys: Array = [0, 0, 0]
	var input_ids: Array = ["", "", ""]
	for i in INPUT_COUNT:
		if bench_inputs[i] != null:
			input_ids[i] = String(bench_inputs[i]["id"])
			var cost: int = int(input_costs.get(input_ids[i], input_costs.get(canonical_id(input_ids[i]), 1)))
			if cost <= 0:
				cost = 1
			var amt_consumed: int = max_batches * cost
			consumed_qtys[i] = amt_consumed
			bench_inputs[i]["qty"] = int(bench_inputs[i]["qty"]) - amt_consumed
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

	# Auto-refill input slots with the same quantity if available in inventory
	for i in INPUT_COUNT:
		if input_ids[i] != "" and int(consumed_qtys[i]) > 0:
			_refill_input_slot(i, input_ids[i], int(consumed_qtys[i]))

	# Auto-refill tool if shattered and matching replacement is available in inventory
	var needed_tool: String = String(prev_recipe.get("tool", ""))
	if needed_tool == "" and prev_tool_id != "":
		needed_tool = prev_tool_id
	if needed_tool != "" and bench_tool == null:
		_refill_tool(needed_tool)

	evaluate_bench()
	return true
