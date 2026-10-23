extends Node

signal inventory_changed
signal slot_clicked(index: int)
signal container_opened(slot_index: int)
signal container_closed
signal container_changed
signal food_consumed(target: String, amount: float)

const SLOT_COUNT := 20
const ITEMS_PATH := "res://data/items.json"

# Each slot is null or {"id": String, "qty": int, "durability": int, "contents": Array (containers only)}
var slots: Array = []
var active_container_index: int = -1
var _defs: Dictionary = {}


func _ready() -> void:
	_load_defs()
	slots.resize(SLOT_COUNT)
	slots.fill(null)
	_seed_starter_items()


func _load_defs() -> void:
	var f := FileAccess.open(ITEMS_PATH, FileAccess.READ)
	if f == null:
		push_error("Cannot open %s" % ITEMS_PATH)
		return
	var parsed: Variant = JSON.parse_string(f.get_as_text())
	if parsed is Dictionary:
		_defs = parsed
	else:
		push_error("Invalid JSON in %s" % ITEMS_PATH)


func get_def(id: String) -> Dictionary:
	return _defs.get(id, {})


func get_max_stack(item_or_id: Variant) -> int:
	var id: String = item_or_id["id"] if item_or_id is Dictionary else String(item_or_id)
	var def := get_def(id)
	var type: String = def.get("type", "")
	if type == "container":
		return 1
	if type == "tool":
		return 100 # Tools with matching durability stack up to 100 like other items
	return int(def.get("max_stack", 100))


func can_items_stack(a: Dictionary, b: Dictionary) -> bool:
	if a.get("id", "") != b.get("id", ""):
		return false
	var def := get_def(a.get("id", ""))
	var type: String = def.get("type", "")
	if type == "container":
		return false
	if type == "tool":
		return int(a.get("durability", 1)) == int(b.get("durability", 1))
	return true


func make_item(id: String, qty: int = 1) -> Dictionary:
	var def := get_def(id)
	var item := {"id": id, "qty": qty}
	match def.get("type", "material"):
		"tool":
			item["qty"] = qty
			item["durability"] = int(def.get("max_durability", 1))
		"container":
			item["qty"] = 1
			var contents: Array = []
			contents.resize(int(def.get("capacity", 8)))
			contents.fill(null)
			item["contents"] = contents
	return item


func _seed_starter_items() -> void:
	# Temporary starter pack matching the prototype
	var container := make_item("grandmas_container")
	container["contents"][0] = make_item("crimson_bio_berry", 15)
	container["contents"][1] = make_item("strut_fragment", 8)
	slots[0] = container
	slots[1] = make_item("raw_mineral_chunk", 22)
	var slag := make_item("heavy_slag_chunk")
	slag["durability"] = 5
	slots[2] = slag
	slots[3] = make_item("banana_pod", 14)
	slots[4] = make_item("carbon_strut", 32)
	slots[5] = make_item("polymer_tendon", 17)
	slots[6] = make_item("nano_grid_strips", 20)
	slots[7] = make_item("azure_bio_berry", 34)
	slots[8] = make_item("hardened_bone_spike", 9)
	slots[9] = make_item("dense_composite_log", 14)
	inventory_changed.emit()


func reset_run() -> void:
	close_container()
	slots.fill(null)
	_seed_starter_items()


func get_slot(index: int) -> Variant:
	if index < 0 or index >= SLOT_COUNT:
		return null
	return slots[index]


func is_container(index: int) -> bool:
	var item: Variant = get_slot(index)
	return item != null and get_def(item["id"]).get("type", "") == "container"


func click_slot(index: int) -> void:
	# If a container (Grandma's box / bag) is currently open:
	if active_container_index != -1:
		if index == active_container_index:
			# Clicking the active container itself closes it
			close_container()
			return
		elif is_container(index):
			# Clicking another container switches to it
			toggle_container(index)
			return
		else:
			# Clicking any inventory item moves it into the open container!
			put_into_container(index)
			return

	# Containers open the drawer instead of going to the crafting bench.
	if is_container(index):
		toggle_container(index)
		return
	slot_clicked.emit(index)


func toggle_container(index: int) -> void:
	if active_container_index == index:
		close_container()
	elif is_container(index):
		active_container_index = index
		container_opened.emit(index)


func close_container() -> void:
	if active_container_index == -1:
		return
	active_container_index = -1
	container_closed.emit()


func get_active_container() -> Variant:
	return get_slot(active_container_index) if active_container_index != -1 else null


func extract_from_container(content_index: int) -> bool:
	## 1-by-1 extraction from container into the main inventory on tap/click.
	var container: Variant = get_active_container()
	if container == null:
		return false
	var contents: Array = container["contents"]
	if content_index < 0 or content_index >= contents.size() or contents[content_index] == null:
		return false
	var item: Dictionary = contents[content_index]
	if not can_add(item["id"], 1):
		GameState.toast_requested.emit("Cargo full! No free slots.")
		return false

	var one: Dictionary = item.duplicate(true)
	one["qty"] = 1
	if not add_item(one):
		GameState.toast_requested.emit("Cargo full! No free slots.")
		return false

	var max_stack := get_max_stack(item)
	if max_stack > 1 and int(item.get("qty", 1)) > 1:
		item["qty"] = int(item["qty"]) - 1
	else:
		contents[content_index] = null

	container_changed.emit()
	return true


func drop_container_item_to_inventory_slot(inv_index: int, content_index: int) -> bool:
	## Drag-and-drop from container to a specific inventory slot (moves whole quantity).
	var container: Variant = get_active_container()
	if container == null:
		return false
	var contents: Array = container["contents"]
	if content_index < 0 or content_index >= contents.size() or contents[content_index] == null:
		return false
	if inv_index < 0 or inv_index >= SLOT_COUNT:
		return false

	var item: Dictionary = contents[content_index]
	var max_stack := get_max_stack(item)
	var target_slot: Variant = slots[inv_index]

	if target_slot == null:
		slots[inv_index] = item.duplicate(true)
		contents[content_index] = null
		inventory_changed.emit()
		container_changed.emit()
		return true
	elif can_items_stack(target_slot, item):
		var to_add: int = mini(max_stack - int(target_slot["qty"]), int(item["qty"]))
		if to_add > 0:
			target_slot["qty"] = int(target_slot["qty"]) + to_add
			item["qty"] = int(item["qty"]) - to_add
			if int(item["qty"]) <= 0:
				contents[content_index] = null
			inventory_changed.emit()
			container_changed.emit()
			return true
		else:
			GameState.toast_requested.emit("Inventory slot is at maximum stack.")
			return false
	else:
		# Swap items between inventory slot and container slot if types differ
		if get_def(target_slot["id"]).get("type", "") == "container":
			GameState.toast_requested.emit("Cannot put a container inside another container!")
			return false
		var temp: Dictionary = target_slot.duplicate(true)
		slots[inv_index] = item.duplicate(true)
		contents[content_index] = temp
		inventory_changed.emit()
		container_changed.emit()
		return true


func put_into_container(inv_index: int) -> bool:
	## Transfers exactly 1 unit of item from inventory slot into active container (1-by-1 on click).
	## Matches crafting slot behavior. Stacks into existing slot first, or enters first empty slot.
	var container: Variant = get_active_container()
	if container == null:
		return false
	var item: Variant = get_slot(inv_index)
	if item == null:
		return false
	if is_container(inv_index):
		GameState.toast_requested.emit("Cannot put a container inside another container!")
		return false

	var contents: Array = container["contents"]
	var max_stack := get_max_stack(item)

	# 1. Try adding 1 unit into an existing stack of the same item
	if max_stack > 1:
		for i in contents.size():
			var c: Variant = contents[i]
			if c != null and can_items_stack(c, item):
				var current_qty := int(c["qty"])
				if current_qty < max_stack:
					var one: Variant = take_one(inv_index)
					if one != null:
						c["qty"] = current_qty + 1
						container_changed.emit()
						return true
				else:
					GameState.toast_requested.emit("Container slot has reached maximum stack of %d." % max_stack)
					return false

	# 2. Otherwise place 1 unit into the first empty slot
	for i in contents.size():
		if contents[i] == null:
			var one: Variant = take_one(inv_index)
			if one != null:
				contents[i] = one
				container_changed.emit()
				return true

	GameState.toast_requested.emit("Container is full! No free slots.")
	return false


func drop_into_container_slot(content_index: int, inv_index: int) -> bool:
	## Drag-and-drop targeting a specific slot inside the container.
	var container: Variant = get_active_container()
	if container == null:
		return false
	var item: Variant = get_slot(inv_index)
	if item == null:
		return false
	if is_container(inv_index):
		GameState.toast_requested.emit("Cannot put a container inside another container!")
		return false

	var contents: Array = container["contents"]
	if content_index < 0 or content_index >= contents.size():
		return false

	var max_stack := get_max_stack(item)
	var target_slot: Variant = contents[content_index]

	if target_slot == null:
		contents[content_index] = item.duplicate(true)
		slots[inv_index] = null
		inventory_changed.emit()
		container_changed.emit()
		return true
	elif can_items_stack(target_slot, item):
		var to_add: int = mini(max_stack - int(target_slot["qty"]), int(item["qty"]))
		if to_add > 0:
			target_slot["qty"] = int(target_slot["qty"]) + to_add
			item["qty"] = int(item["qty"]) - to_add
			if int(item["qty"]) <= 0:
				slots[inv_index] = null
			inventory_changed.emit()
			container_changed.emit()
			return true
		else:
			GameState.toast_requested.emit("Container slot is at maximum stack.")
			return false
	else:
		# Swap items between inventory slot and container slot if types differ
		var temp: Dictionary = target_slot.duplicate(true)
		contents[content_index] = item.duplicate(true)
		slots[inv_index] = temp
		inventory_changed.emit()
		container_changed.emit()
		return true


func take_one(index: int) -> Variant:
	## Removes one unit (or the whole container) from a slot and returns it, or null.
	var item: Variant = get_slot(index)
	if item == null:
		return null
	var max_stack := get_max_stack(item)
	if max_stack > 1 and int(item.get("qty", 1)) > 1:
		item["qty"] = int(item["qty"]) - 1
		var single: Dictionary = item.duplicate(true)
		single["qty"] = 1
		inventory_changed.emit()
		return single
	slots[index] = null
	inventory_changed.emit()
	return item


func take_slot(index: int) -> Variant:
	## Takes the entire item stack from inventory slot index and returns it, clearing the slot.
	var item: Variant = get_slot(index)
	if item == null:
		return null
	slots[index] = null
	inventory_changed.emit()
	return item



func can_add(id: String, qty: int = 1, durability: int = -1) -> bool:
	var def := get_def(id)
	var type: String = def.get("type", "")
	var max_stack := get_max_stack(id)
	var target_dur := durability
	if target_dur == -1 and type == "tool":
		target_dur = int(def.get("max_durability", 1))

	var room := 0
	for s in slots:
		if s == null:
			room += max_stack
		elif s["id"] == id and max_stack > 1:
			if type == "tool":
				if int(s.get("durability", 1)) == target_dur:
					room += max_stack - int(s.get("qty", 1))
			else:
				room += max_stack - int(s.get("qty", 1))
	return room >= qty


func can_add_all(items: Dictionary) -> bool:
	## items: id -> qty. True if all fit together (free slots are shared between ids).
	var free_slots := 0
	for s in slots:
		if s == null:
			free_slots += 1
	var needed_slots := 0
	for id in items:
		var def := get_def(id)
		var type: String = def.get("type", "")
		var max_stack := get_max_stack(id)
		var leftover: int = int(items[id])
		if max_stack > 1:
			for s in slots:
				if s != null and s["id"] == id:
					if type == "tool":
						var default_dur := int(def.get("max_durability", 1))
						if int(s.get("durability", 1)) == default_dur:
							leftover -= max_stack - int(s.get("qty", 1))
					else:
						leftover -= max_stack - int(s.get("qty", 1))
		if leftover > 0:
			needed_slots += ceili(float(leftover) / float(max_stack))
	return needed_slots <= free_slots



func consume_food(target: String) -> bool:
	## Feeds `target` ("player" or "minion") with food from inventory, stopping when full.
	var current: float = GameState.protag_energy if target == "player" else GameState.minion_energy
	var maximum: float = GameState.max_protag_energy if target == "player" else GameState.max_minion_energy
	var who := "Pete" if target == "player" else "Helper Bot"
	if current >= maximum:
		GameState.toast_requested.emit("%s energy is already full." % who)
		return false

	for i in SLOT_COUNT:
		var s: Variant = slots[i]
		if s == null:
			continue
		var def := get_def(s["id"])
		if def.get("type", "") != "food":
			continue
		var energy_per_item := float(def.get("energy_value", 0))
		if energy_per_item <= 0.0:
			continue

		var needed_energy: float = maximum - current
		var available_qty: int = int(s.get("qty", 1))
		var consumed: int = 0
		var sim_energy: float = current
		while sim_energy < maximum and consumed < available_qty:
			sim_energy += energy_per_item
			consumed += 1

		if (float(consumed) * energy_per_item) > needed_energy:
			consumed -= 1

		if consumed > 0:
			var total_energy: float = float(consumed) * energy_per_item
			GameState.replenish_energy(target, total_energy)
			food_consumed.emit(target, total_energy)
			s["qty"] = int(s["qty"]) - consumed
			if int(s["qty"]) <= 0:
				slots[i] = null
			inventory_changed.emit()
			var food_name: String = def.get("name", "Food")
			if consumed == 1:
				GameState.toast_requested.emit("%s fed 1x %s (+%d EN)!" % [who, food_name, int(total_energy)])
			else:
				GameState.toast_requested.emit("%s fed %dx %s (+%d EN)!" % [who, consumed, food_name, int(total_energy)])
			return true

	GameState.toast_requested.emit("No food items can be fed without exceeding max capacity!")
	return false


func feed_slot_to_target(slot_index: int, target: String) -> bool:
	## Feeds `target` ("player" or "minion") using the item at `slot_index`.
	## Consumes up to the needed energy. If quantity * energy > needed energy, quantity is -1.
	var s: Variant = get_slot(slot_index)
	if s == null:
		return false
	var def := get_def(s["id"])
	if def.get("type", "") != "food":
		GameState.toast_requested.emit("Not edible! Only food can be consumed.")
		return false
	var current: float = GameState.protag_energy if target == "player" else GameState.minion_energy
	var maximum: float = GameState.max_protag_energy if target == "player" else GameState.max_minion_energy
	var who := "Pete" if target == "player" else "Helper Bot"
	if current >= maximum:
		GameState.toast_requested.emit("%s is already full on energy." % who)
		return false

	var energy_per_item := float(def.get("energy_value", 0))
	if energy_per_item <= 0.0:
		GameState.toast_requested.emit("%s has no nutritional energy value!" % def.get("name", "Food"))
		return false

	var needed_energy: float = maximum - current
	var available_qty: int = int(s.get("qty", 1))
	var consumed: int = 0
	var sim_energy: float = current
	while sim_energy < maximum and consumed < available_qty:
		sim_energy += energy_per_item
		consumed += 1

	if (float(consumed) * energy_per_item) > needed_energy:
		consumed -= 1

	if consumed <= 0:
		GameState.toast_requested.emit("%s energy is nearly full (%d/%d EN). Feeding would exceed max energy!" % [who, int(current), int(maximum)])
		return false

	var total_energy: float = float(consumed) * energy_per_item
	GameState.replenish_energy(target, total_energy)
	food_consumed.emit(target, total_energy)
	s["qty"] = int(s["qty"]) - consumed
	if int(s["qty"]) <= 0:
		slots[slot_index] = null
	inventory_changed.emit()

	var food_name: String = def.get("name", "Food")
	if consumed == 1:
		GameState.toast_requested.emit("%s fed 1x %s (+%d EN)!" % [who, food_name, int(total_energy)])
	else:
		GameState.toast_requested.emit("%s fed %dx %s (+%d EN)!" % [who, consumed, food_name, int(total_energy)])
	return true


func add_item(item: Dictionary) -> bool:
	## Adds an item dict (from make_item). Returns false if the inventory is full.
	var max_stack := get_max_stack(item)
	if max_stack > 1:
		for i in SLOT_COUNT:
			var s: Variant = slots[i]
			if s != null and can_items_stack(s, item) and int(s["qty"]) < max_stack:
				var to_add: int = mini(max_stack - int(s["qty"]), int(item["qty"]))
				s["qty"] = int(s["qty"]) + to_add
				item["qty"] = int(item["qty"]) - to_add
				if int(item["qty"]) <= 0:
					inventory_changed.emit()
					return true
	for i in SLOT_COUNT:
		if slots[i] == null:
			slots[i] = item.duplicate(true)
			inventory_changed.emit()
			return true
	return false
