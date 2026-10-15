extends Node
## Colony data (housing, buildings) and the Love Hut run reset.
## Passive generation and GP rewards are NOT implemented yet; reset is a placeholder until rules are defined.

signal run_reset

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

	generate_city_map(15)


## 15x15 City Map Grid State
var city_map_size: int = 15
var city_map_data: Array = [] # 225 strings representing terrain elements


func generate_city_map(size: int = 15) -> void:
	city_map_size = size
	city_map_data.clear()
	city_map_data.resize(size * size)

	# 1. Base terrain: fill mostly with lush grass
	for i in size * size:
		city_map_data[i] = "grass"

	# 2. Clustered Water Bodies (shallow water coasts and deep water interior)
	var num_water_sources := randi_range(2, 3)
	for s in num_water_sources:
		var center_x := randi_range(0, size - 1)
		var center_y := randi_range(0, size - 1)
		var radius := randi_range(2, 4)
		for y in range(maxi(0, center_y - radius), mini(size, center_y + radius + 1)):
			for x in range(maxi(0, center_x - radius), mini(size, center_x + radius + 1)):
				var dist := Vector2(x - center_x, y - center_y).length()
				if dist <= radius * 0.5:
					city_map_data[y * size + x] = "deep_water"
				elif dist <= radius + 0.3 and city_map_data[y * size + x] != "deep_water":
					city_map_data[y * size + x] = "shallow_water"

	# 3. Mountain ridges / rock clusters
	var num_mountain_clusters := randi_range(2, 4)
	for m in num_mountain_clusters:
		var mx := randi_range(1, size - 2)
		var my := randi_range(1, size - 2)
		var count := randi_range(3, 6)
		for c in count:
			var px: int = clampi(mx + randi_range(-1, 1), 0, size - 1)
			var py: int = clampi(my + randi_range(-1, 1), 0, size - 1)
			var current: String = city_map_data[py * size + px]
			if current != "deep_water" and current != "shallow_water":
				city_map_data[py * size + px] = "mountain"

	# 4. Forest groves
	var num_groves := randi_range(3, 5)
	for g in num_groves:
		var gx := randi_range(0, size - 1)
		var gy := randi_range(0, size - 1)
		var count := randi_range(4, 8)
		for c in count:
			var px: int = clampi(gx + randi_range(-2, 2), 0, size - 1)
			var py: int = clampi(gy + randi_range(-2, 2), 0, size - 1)
			var current: String = city_map_data[py * size + px]
			if current == "grass":
				city_map_data[py * size + px] = "forest"

	# 5. Desert / Sand dunes patches
	var num_deserts := randi_range(1, 3)
	for d in num_deserts:
		var dx := randi_range(0, size - 1)
		var dy := randi_range(0, size - 1)
		var count := randi_range(3, 7)
		for c in count:
			var px: int = clampi(dx + randi_range(-1, 1), 0, size - 1)
			var py: int = clampi(dy + randi_range(-1, 1), 0, size - 1)
			var current: String = city_map_data[py * size + px]
			if current == "grass":
				city_map_data[py * size + px] = "desert"


func get_tile(x: int, y: int) -> String:
	if x < 0 or x >= city_map_size or y < 0 or y >= city_map_size:
		return "grass"
	return city_map_data[y * city_map_size + x]


func reset_run() -> void:
	## Recombination Pod: restore the starting state (inventory, bench, energy, skills, quests).
	InventoryManager.reset_run()
	CraftingSystem.reset_bench()
	GameState.reset_run()
	QuestManager.reset_run()
	run_reset.emit()
	GameState.toast_requested.emit("Recombination complete. Run reset.")
