class_name CityMap
extends PanelContainer
## 15x15 pixel/tile city map view styled like the Dawn of Crafting settlement ledger.
## Displays procedural/randomized terrain elements:
## 1. shallow water, 2. deep water, 3. grass, 4. forest, 5. desert, 6. mountain

signal tile_clicked(x: int, y: int, terrain_type: String)

const MAP_SIZE := 15
const TILE_PIXEL_SIZE := 20 # 15 * 20 = 300px miniature grid, fits snugly in the middle

const TILES := {
	"grass": {
		"name": "Lush Grassland",
		"tex": "res://assets/sprites/tiles/grass.png",
		"color": Color("58a62c")
	},
	"forest": {
		"name": "Dense Canopy Forest",
		"tex": "res://assets/sprites/tiles/forest.png",
		"color": Color("2e6b18")
	},
	"mountain": {
		"name": "Core Granite Mountain",
		"tex": "res://assets/sprites/tiles/mountain.png",
		"color": Color("7c7c84")
	},
	"desert": {
		"name": "Arid Sand Dunes",
		"tex": "res://assets/sprites/tiles/desert.png",
		"color": Color("d6a845")
	},
	"shallow_water": {
		"name": "Coastal Shallows",
		"tex": "res://assets/sprites/tiles/shallow_water.png",
		"color": Color("38bdf8")
	},
	"deep_water": {
		"name": "Abyssal Deep Water",
		"tex": "res://assets/sprites/tiles/deep_water.png",
		"color": Color("033c73")
	}
}

var _grid_container: GridContainer
var _title_label: Label
var _stats_label: Label
var _inspect_label: Label
var _buttons: Array = [] # 15x15 Array of TextureButtons
var _textures: Dictionary = {}


func _ready() -> void:
	_load_textures()
	_build_ui()
	generate_random_map()
	ColonyManager.run_reset.connect(generate_random_map)


func _load_textures() -> void:
	for k in TILES.keys():
		var path: String = TILES[k]["tex"]
		if ResourceLoader.exists(path):
			_textures[k] = load(path)


func _build_ui() -> void:
	# Panel container styling - clean, compact timber stone frame
	var panel_sb := StyleBoxFlat.new()
	panel_sb.bg_color = Color("2e2419")
	panel_sb.set_border_width_all(4)
	panel_sb.border_color = Color("4f3c27")
	panel_sb.set_corner_radius_all(14)
	panel_sb.content_margin_left = 14
	panel_sb.content_margin_right = 14
	panel_sb.content_margin_top = 10
	panel_sb.content_margin_bottom = 10
	add_theme_stylebox_override("panel", panel_sb)

	var root_col := VBoxContainer.new()
	root_col.add_theme_constant_override("separation", 6)
	add_child(root_col)

	# Header bar with city name, eye icon, randomize button
	var head_row := HBoxContainer.new()
	head_row.add_theme_constant_override("separation", 8)
	root_col.add_child(head_row)

	var eye_lbl := Label.new()
	eye_lbl.text = "🗺️"
	eye_lbl.add_theme_font_size_override("font_size", 22)
	head_row.add_child(eye_lbl)

	_title_label = Label.new()
	_title_label.text = "NEW AMSTERDAM (15x15 SECTOR)"
	_title_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_title_label.add_theme_font_size_override("font_size", 20)
	_title_label.add_theme_color_override("font_color", Color("fdf6e2"))
	head_row.add_child(_title_label)

	_stats_label = Label.new()
	_stats_label.text = "POP: %d/%d" % [ColonyManager.population, ColonyManager.housing_capacity]
	_stats_label.add_theme_font_size_override("font_size", 18)
	_stats_label.add_theme_color_override("font_color", Color("d4af37"))
	head_row.add_child(_stats_label)

	var regen_btn := Button.new()
	regen_btn.text = "🎲 RE-SEED"
	regen_btn.focus_mode = Control.FOCUS_NONE
	regen_btn.custom_minimum_size = Vector2(110, 32)
	regen_btn.add_theme_font_size_override("font_size", 16)
	var btn_sb := StyleBoxFlat.new()
	btn_sb.bg_color = Color("573c22")
	btn_sb.set_border_width_all(2)
	btn_sb.border_color = Color("d97724")
	btn_sb.set_corner_radius_all(6)
	regen_btn.add_theme_stylebox_override("normal", btn_sb)
	var btn_hover := btn_sb.duplicate()
	btn_hover.bg_color = Color("734e2c")
	regen_btn.add_theme_stylebox_override("hover", btn_hover)
	regen_btn.pressed.connect(func() -> void:
		generate_random_map()
		GameState.toast_requested.emit("Sector terrain re-randomized!")
	)
	head_row.add_child(regen_btn)

	# Content row: Left Miniature Grid (300x300) + Right Survey Inspector Panel
	var content_row := HBoxContainer.new()
	content_row.add_theme_constant_override("separation", 16)
	root_col.add_child(content_row)

	# Miniature Map frame wrapper
	var map_frame := PanelContainer.new()
	var mf_sb := StyleBoxFlat.new()
	mf_sb.bg_color = Color("15100b")
	mf_sb.set_border_width_all(3)
	mf_sb.border_color = Color("3d2e1e")
	mf_sb.set_corner_radius_all(8)
	mf_sb.set_content_margin_all(4)
	map_frame.add_theme_stylebox_override("panel", mf_sb)
	content_row.add_child(map_frame)

	_grid_container = GridContainer.new()
	_grid_container.columns = MAP_SIZE
	_grid_container.add_theme_constant_override("h_separation", 1)
	_grid_container.add_theme_constant_override("v_separation", 1)
	map_frame.add_child(_grid_container)

	# Build 15x15 miniature button grid
	_buttons.resize(MAP_SIZE * MAP_SIZE)
	for y in MAP_SIZE:
		for x in MAP_SIZE:
			var idx := y * MAP_SIZE + x
			var btn := TextureButton.new()
			btn.custom_minimum_size = Vector2(TILE_PIXEL_SIZE, TILE_PIXEL_SIZE)
			btn.ignore_texture_size = false
			btn.stretch_mode = TextureButton.STRETCH_SCALE
			btn.focus_mode = Control.FOCUS_NONE
			btn.pressed.connect(_on_tile_pressed.bind(x, y))
			_grid_container.add_child(btn)
			_buttons[idx] = btn

	# Right Column: Survey Inspector & Biome Legend
	var info_col := VBoxContainer.new()
	info_col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info_col.add_theme_constant_override("separation", 6)
	content_row.add_child(info_col)

	_inspect_label = Label.new()
	_inspect_label.text = "Survey Status: Tap any sector tile on the left to inspect terrain biome properties."
	_inspect_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_inspect_label.add_theme_font_size_override("font_size", 20)
	_inspect_label.add_theme_color_override("font_color", Color("f59e0b"))
	info_col.add_child(_inspect_label)

	# Biome Legend indicators
	var legend_grid := GridContainer.new()
	legend_grid.columns = 2
	legend_grid.add_theme_constant_override("h_separation", 8)
	legend_grid.add_theme_constant_override("v_separation", 4)
	info_col.add_child(legend_grid)

	for k in ["grass", "forest", "mountain", "desert", "shallow_water", "deep_water"]:
		var leg_lbl := Label.new()
		leg_lbl.text = "• %s" % TILES[k]["name"]
		leg_lbl.add_theme_font_size_override("font_size", 16)
		leg_lbl.add_theme_color_override("font_color", TILES[k]["color"])
		legend_grid.add_child(leg_lbl)


func generate_random_map() -> void:
	if not ColonyManager.is_inside_tree() and ColonyManager.city_map_data.is_empty():
		ColonyManager.generate_city_map(MAP_SIZE)
	else:
		ColonyManager.generate_city_map(MAP_SIZE)

	_render_map()


func _render_map() -> void:
	var data: Array = ColonyManager.city_map_data
	if data.size() != MAP_SIZE * MAP_SIZE:
		return

	for y in MAP_SIZE:
		for x in MAP_SIZE:
			var idx := y * MAP_SIZE + x
			var t_key: String = data[idx]
			var btn: TextureButton = _buttons[idx]
			if _textures.has(t_key):
				btn.texture_normal = _textures[t_key]
			btn.tooltip_text = "%s (%d, %d)" % [TILES.get(t_key, {}).get("name", t_key), x, y]


func _on_tile_pressed(x: int, y: int) -> void:
	var t_key: String = ColonyManager.get_tile(x, y)
	var t_info: Dictionary = TILES.get(t_key, {})
	var t_name: String = t_info.get("name", t_key.capitalize())

	_inspect_label.text = "Survey Sector [%02d, %02d]: %s — Ready for foundation planning." % [x + 1, y + 1, t_name.to_upper()]
	_inspect_label.add_theme_color_override("font_color", t_info.get("color", Color("f59e0b")))

	tile_clicked.emit(x, y, t_key)
