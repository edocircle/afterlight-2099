extends Node

signal inventory_changed
signal slot_clicked(index: int)
signal container_opened(slot_index: int)
signal container_closed
signal container_changed

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


func make_item(id: String, qty: int = 1) -> Dictionary:
	var def := get_def(id)
	var item := {"id": id, "qty": qty}
	match def.get("type", "material"):
		"tool":
			item["qty"] = 1
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
	container["contents"][0] = make_item("crimson_berry", 15)
	container["contents"][1] = make_item("strut_fragment", 8)
	slots[0] = container
	slots[1] = make_item("raw_mineral", 22)
	var slag := make_item("heavy_slag")
	slag["durability"] = 5
	slots[2] = slag
	slots[3] = make_item("banana_pod", 14)
	slots[4] = make_item("carbon_strut", 32)
	slots[5] = make_item("polymer_tendon", 17)
	slots[6] = make_item("nano_strips", 20)
	slots[7] = make_item("azure_berry", 34)
	slots[8] = make_item("hard_chitin", 9)
	slots[9] = make_item("composite_log", 14)
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
	## One-tap extraction of a whole stack into the main inventory.
	var container: Variant = get_active_container()
	if container == null:
		return false
	var contents: Array = container["contents"]
	if content_index < 0 or content_index >= contents.size() or contents[content_index] == null:
		return false
	var item: Dictionary = contents[content_index]
	if not can_add(item["id"], int(item["qty"])):
		GameState.toast_requested.emit("Cargo full! No free slots.")
		return false
	add_item(item)
	contents[content_index] = null
	container_changed.emit()
	return true


func take_one(index: int) -> Variant:
	## Removes one unit (or the whole tool/container) from a slot and returns it, or null.
	var item: Variant = get_slot(index)
	if item == null:
		return null
	var max_stack := int(get_def(item["id"]).get("max_stack", 1))
	if max_stack > 1 and item["qty"] > 1:
		item["qty"] -= 1
		var single: Dictionary = item.duplicate(true)
		single["qty"] = 1
		inventory_changed.emit()
		return single
	slots[index] = null
	inventory_changed.emit()
	return item


func can_add(id: String, qty: int = 1) -> bool:
	var max_stack := int(get_def(id).get("max_stack", 1))
	var room := 0
	for s in slots:
		if s == null:
			room += max_stack
		elif s["id"] == id and max_stack > 1:
			room += max_stack - int(s["qty"])
	return room >= qty


func can_add_all(items: Dictionary) -> bool:
	## items: id -> qty. True if all fit together (free slots are shared between ids).
	var free_slots := 0
	for s in slots:
		if s == null:
			free_slots += 1
	var needed_slots := 0
	for id in items:
		var max_stack := int(get_def(id).get("max_stack", 1))
		var leftover: int = int(items[id])
		if max_stack > 1:
			for s in slots:
				if s != null and s["id"] == id:
					leftover -= max_stack - int(s["qty"])
		if leftover > 0:
			needed_slots += ceili(float(leftover) / float(max_stack))
	return needed_slots <= free_slots



func consume_food(target: String) -> bool:
	## Feeds `target` ("player" or "minion") with the first food item in the inventory.
	var current: float = GameState.protag_energy if target == "player" else GameState.minion_energy
	var maximum: float = GameState.max_protag_energy if target == "player" else GameState.max_minion_energy
	var who := "Operative" if target == "player" else "Drone"
	for i in SLOT_COUNT:
		var s: Variant = slots[i]
		if s == null:
			continue
		var def := get_def(s["id"])
		if def.get("type", "") != "food":
			continue
		if current >= maximum:
			GameState.toast_requested.emit("%s energy is already full." % who)
			return false
		var energy := float(def.get("energy_value", 0))
		GameState.replenish_energy(target, energy)
		s["qty"] -= 1
		if s["qty"] <= 0:
			slots[i] = null
		inventory_changed.emit()
		GameState.toast_requested.emit("%s fed +%d EN!" % [who, int(energy)])
		return true
	GameState.toast_requested.emit("No food items available in cargo!")
	return false


func feed_slot_to_target(slot_index: int, target: String) -> bool:
	## Feeds `target` ("player" or "minion") using the item at `slot_index`.
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
	var energy := float(def.get("energy_value", 0))
	GameState.replenish_energy(target, energy)
	s["qty"] = int(s["qty"]) - 1
	if s["qty"] <= 0:
		slots[slot_index] = null
	inventory_changed.emit()
	GameState.toast_requested.emit("%s fed %s (+%d EN)!" % [who, def.get("name", "Food"), int(energy)])
	return true


func add_item(item: Dictionary) -> bool:
	## Adds an item dict (from make_item). Returns false if the inventory is full.
	var def := get_def(item["id"])
	var max_stack := int(def.get("max_stack", 1))
	if max_stack > 1:
		for i in SLOT_COUNT:
			var s: Variant = slots[i]
			if s != null and s["id"] == item["id"] and s["qty"] < max_stack:
				var to_add: int = mini(max_stack - int(s["qty"]), int(item["qty"]))
				s["qty"] += to_add
				item["qty"] -= to_add
				if item["qty"] <= 0:
					inventory_changed.emit()
					return true
	for i in SLOT_COUNT:
		if slots[i] == null:
			slots[i] = item.duplicate(true)
			inventory_changed.emit()
			return true
	return false
