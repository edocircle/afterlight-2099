extends Node
## Colony data (housing, buildings) and the Love Hut run reset.
## Passive generation and GP rewards are NOT implemented yet; reset is a placeholder until rules are defined.

signal run_reset
signal map_updated

const BUILDINGS_PATH := "res://data/colony_buildings.json"

var population: int = 0
var housing_capacity: int = 0
var buildings: Array = []


func _ready() -> void:
	var f := FileAccess.open(BUILDINGS_PATH, FileAccess.READ)
	if f == null:
		push_error("Cannot open %s" % BUILDINGS_PATH)
		return
	var parsed: Variant = JSON.parse_string(f.get_as_text())
	if parsed is Dictionary:
		population = int(parsed.get("population", 0))
		housing_capacity = int(parsed.get("housing_capacity", 0))
		buildings = parsed.get("buildings", [])
	else:
		push_error("Invalid JSON in %s" % BUILDINGS_PATH)

	generate_city_map(30)


## 30x30 City Map Grid State
var city_map_size: int = 30
var city_map_data: Array = [] # 900 strings representing terrain elements
var city_buildings: Dictionary = {} # "x,y" -> Dictionary of placed building data


func generate_city_map(size: int = 30) -> void:
	city_map_size = size
	city_map_data.clear()
	city_map_data.resize(size * size)
	city_buildings.clear()

	# 1. Base terrain: fill with lush grass
	for i in size * size:
		city_map_data[i] = "grass"

	# 2. Clustered Water Bodies (shallow water coasts and deep water interior)
	var num_water_sources := randi_range(3, 5)
	for s in num_water_sources:
		var center_x := randi_range(3, size - 4)
		var center_y := randi_range(3, size - 4)
		var radius := randi_range(3, 6)
		for y in range(maxi(0, center_y - radius), mini(size, center_y + radius + 1)):
			for x in range(maxi(0, center_x - radius), mini(size, center_x + radius + 1)):
				var dist := Vector2(x - center_x, y - center_y).length()
				if dist <= radius * 0.55:
					city_map_data[y * size + x] = "deep_water"
				elif dist <= radius + 0.4 and city_map_data[y * size + x] != "deep_water":
					city_map_data[y * size + x] = "shallow_water"

	# 3. Contiguous Connected Desert Region
	# Instead of scattered random spots, create one connected contiguous desert biome with organic spread
	var desert_cells: Dictionary = {}
	var desert_origin_x := randi_range(4, size - 5)
	var desert_origin_y := randi_range(4, size - 5)
	# Find a start position not already deep water if possible
	var frontier: Array[Vector2i] = [Vector2i(desert_origin_x, desert_origin_y)]
	desert_cells[Vector2i(desert_origin_x, desert_origin_y)] = true

	var target_desert_count := randi_range(90, 140) # contiguous region covering ~10-15% of the 900 tiles
	var dirs := [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]

	while desert_cells.size() < target_desert_count and not frontier.is_empty():
		var current_cell: Vector2i = frontier.pick_random()
		# Expand in directions to form contiguous dunes
		var step_dir: Vector2i = dirs.pick_random()
		var next_cell := current_cell + step_dir
		if next_cell.x >= 0 and next_cell.x < size and next_cell.y >= 0 and next_cell.y < size:
			if not desert_cells.has(next_cell):
				desert_cells[next_cell] = true
				frontier.append(next_cell)
		# Prune frontier occasionally to keep it localized and contiguous
		if frontier.size() > 25:
			frontier.remove_at(randi_range(0, frontier.size() - 1))

	for pos in desert_cells.keys():
		var idx: int = pos.y * size + pos.x
		if city_map_data[idx] != "deep_water":
			city_map_data[idx] = "desert"

	# 4. Forest groves (clustered near grasslands, away from desert)
	var num_groves := randi_range(5, 8)
	for g in num_groves:
		var gx := randi_range(1, size - 2)
		var gy := randi_range(1, size - 2)
		var count := randi_range(8, 16)
		for c in count:
			var px: int = clampi(gx + randi_range(-3, 3), 0, size - 1)
			var py: int = clampi(gy + randi_range(-3, 3), 0, size - 1)
			var current: String = city_map_data[py * size + px]
			if current == "grass":
				city_map_data[py * size + px] = "forest"

	# 5. Mountain ridges / rock clusters
	var num_mountain_clusters := randi_range(4, 7)
	for m in num_mountain_clusters:
		var mx := randi_range(2, size - 3)
		var my := randi_range(2, size - 3)
		var count := randi_range(6, 12)
		for c in count:
			var px: int = clampi(mx + randi_range(-2, 2), 0, size - 1)
			var py: int = clampi(my + randi_range(-2, 2), 0, size - 1)
			var current: String = city_map_data[py * size + px]
			if current != "deep_water" and current != "shallow_water":
				city_map_data[py * size + px] = "mountain"

	map_updated.emit()


func get_tile(x: int, y: int) -> String:
	if x < 0 or x >= city_map_size or y < 0 or y >= city_map_size:
		return "grass"
	return city_map_data[y * city_map_size + x]


func get_building_at(x: int, y: int) -> Variant:
	var key := "%d,%d" % [x, y]
	return city_buildings.get(key, null)


func place_building(x: int, y: int, building_id: String, building_name: String, icon: String) -> bool:
	if x < 0 or x >= city_map_size or y < 0 or y >= city_map_size:
		return false
	var tile_type := get_tile(x, y)
	if tile_type == "deep_water":
		GameState.toast_requested.emit("Cannot build on deep water!")
		return false
	var key := "%d,%d" % [x, y]
	city_buildings[key] = {
		"id": building_id,
		"name": building_name,
		"icon": icon,
		"x": x,
		"y": y
	}
	map_updated.emit()
	return true



func reset_run() -> void:
	## Recombination Pod: restore the starting state (inventory, bench, energy, skills, quests).
	InventoryManager.reset_run()
	CraftingSystem.reset_bench()
	GameState.reset_run()
	QuestManager.reset_run()
	run_reset.emit()
	GameState.toast_requested.emit("Recombination complete. Run reset.")
