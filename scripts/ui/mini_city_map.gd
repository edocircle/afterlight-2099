class_name MiniCityMap
extends PanelContainer
## Miniature Overview of the 30x30 Colony City Map.
## Displays between the Character Trio and Crafting Slab.
## Renders cleanly on a lightweight canvas without zooming issues.
## Tapping opens the full interactive City Menu.

const TILES := {
	"grass": Color("58a62c"),
	"forest": Color("2e6b18"),
	"mountain": Color("7c7c84"),
	"desert": Color("d6a845"),
	"shallow_water": Color("38bdf8"),
	"deep_water": Color("033c73")
}

var _canvas: Control
var _header_lbl: Label
var _inspect_lbl: Label
var _textures: Dictionary = {}


func _ready() -> void:
	_load_textures()
	_build_ui()
	ColonyManager.run_reset.connect(queue_redraw_map)


func _load_textures() -> void:
	var paths := {
		"grass": "res://assets/sprites/tiles/grass.png",
		"forest": "res://assets/sprites/tiles/forest.png",
		"mountain": "res://assets/sprites/tiles/mountain.png",
		"desert": "res://assets/sprites/tiles/desert.png",
		"shallow_water": "res://assets/sprites/tiles/shallow_water.png",
		"deep_water": "res://assets/sprites/tiles/deep_water.png"
	}
	for k in paths:
		if ResourceLoader.exists(paths[k]):
			_textures[k] = load(paths[k])


func _build_ui() -> void:
	custom_minimum_size = Vector2(0, 320)
	size_flags_horizontal = Control.SIZE_EXPAND_FILL

	var panel_sb := StyleBoxFlat.new()
	panel_sb.bg_color = Color("2e2419")
	panel_sb.set_border_width_all(4)
	panel_sb.border_color = Color("4f3c27")
	panel_sb.set_corner_radius_all(16)
	panel_sb.content_margin_left = 16
	panel_sb.content_margin_right = 16
	panel_sb.content_margin_top = 10
	panel_sb.content_margin_bottom = 10
	add_theme_stylebox_override("panel", panel_sb)

	var root_col := VBoxContainer.new()
	root_col.add_theme_constant_override("separation", 8)
	add_child(root_col)

	# Header row
	var head_row := HBoxContainer.new()
	head_row.add_theme_constant_override("separation", 10)
	root_col.add_child(head_row)

	var icon_lbl := Label.new()
	icon_lbl.text = "🗺️"
	icon_lbl.add_theme_font_size_override("font_size", 24)
	head_row.add_child(icon_lbl)

	_header_lbl = Label.new()
	_header_lbl.text = "NEW AMSTERDAM COLONY (30x30 MINI-MAP)"
	_header_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_header_lbl.add_theme_font_size_override("font_size", 22)
	_header_lbl.add_theme_color_override("font_color", Color("fdf6e2"))
	head_row.add_child(_header_lbl)

	var open_btn := Button.new()
	open_btn.text = "🔍 OPEN CITY"
	open_btn.focus_mode = Control.FOCUS_NONE
	open_btn.custom_minimum_size = Vector2(160, 44)
	open_btn.add_theme_font_size_override("font_size", 20)
	var btn_sb := StyleBoxFlat.new()
	btn_sb.bg_color = Color("573c22")
	btn_sb.set_border_width_all(2)
	btn_sb.border_color = Color("d97724")
	btn_sb.set_corner_radius_all(8)
	open_btn.add_theme_stylebox_override("normal", btn_sb)
	var btn_h := btn_sb.duplicate()
	btn_h.bg_color = Color("734e2c")
	open_btn.add_theme_stylebox_override("hover", btn_h)
	open_btn.pressed.connect(func() -> void:
		GameState.modal_requested.emit("city")
	)
	head_row.add_child(open_btn)

	# Content row: Map View + Stats & Info
	var content_row := HBoxContainer.new()
	content_row.add_theme_constant_override("separation", 20)
	content_row.alignment = BoxContainer.ALIGNMENT_CENTER
	root_col.add_child(content_row)

	# Map frame
	var frame := PanelContainer.new()
	frame.custom_minimum_size = Vector2(250, 250)
	var frame_sb := StyleBoxFlat.new()
	frame_sb.bg_color = Color("15100b")
	frame_sb.set_border_width_all(3)
	frame_sb.border_color = Color("3d2e1e")
	frame_sb.set_corner_radius_all(10)
	frame_sb.set_content_margin_all(5)
	frame.add_theme_stylebox_override("panel", frame_sb)
	content_row.add_child(frame)

	_canvas = Control.new()
	_canvas.custom_minimum_size = Vector2(240, 240)
	_canvas.draw.connect(_on_canvas_draw)
	frame.add_child(_canvas)

	# Right Info column
	var info_col := VBoxContainer.new()
	info_col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info_col.add_theme_constant_override("separation", 8)
	content_row.add_child(info_col)

	var pop_lbl := Label.new()
	pop_lbl.text = "🏛️ Population: %d / %d Operatives" % [ColonyManager.population, ColonyManager.housing_capacity]
	pop_lbl.add_theme_font_size_override("font_size", 22)
	pop_lbl.add_theme_color_override("font_color", Color("d4af37"))
	info_col.add_child(pop_lbl)

	_inspect_lbl = Label.new()
	var b_count := ColonyManager.city_buildings.size()
	_inspect_lbl.text = "Constructed Buildings: %d\nContiguous Desert: Connected Dunes Region\nTap 'OPEN CITY' to zoom & construct foundations." % b_count
	_inspect_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_inspect_lbl.add_theme_font_size_override("font_size", 20)
	_inspect_lbl.add_theme_color_override("font_color", Color("bfb7aa"))
	info_col.add_child(_inspect_lbl)

	# Biome color legend
	var leg_grid := GridContainer.new()
	leg_grid.columns = 3
	leg_grid.add_theme_constant_override("h_separation", 10)
	leg_grid.add_theme_constant_override("v_separation", 4)
	info_col.add_child(leg_grid)

	var biome_names := {
		"grass": "Grass",
		"forest": "Forest",
		"desert": "Desert",
		"mountain": "Mountain",
		"shallow_water": "Shallow",
		"deep_water": "Deep Sea"
	}
	for k in ["grass", "forest", "desert", "mountain", "shallow_water", "deep_water"]:
		var leg := Label.new()
		leg.text = "■ %s" % biome_names[k]
		leg.add_theme_font_size_override("font_size", 16)
		leg.add_theme_color_override("font_color", TILES[k])
		leg_grid.add_child(leg)


func queue_redraw_map() -> void:
	if _canvas != null:
		_canvas.queue_redraw()
	if _inspect_lbl != null:
		var b_count := ColonyManager.city_buildings.size()
		_inspect_lbl.text = "Constructed Buildings: %d\nContiguous Desert: Connected Dunes Region\nTap 'OPEN CITY' to zoom & construct foundations." % b_count


func _on_canvas_draw() -> void:
	var map_dim := ColonyManager.city_map_size
	if map_dim <= 0 or ColonyManager.city_map_data.is_empty():
		return
	var cell_size := 240.0 / float(map_dim)

	for y in map_dim:
		for x in map_dim:
			var idx := y * map_dim + x
			var t_key: String = ColonyManager.city_map_data[idx]
			var rect := Rect2(x * cell_size, y * cell_size, cell_size, cell_size)
			if _textures.has(t_key):
				_canvas.draw_texture_rect(_textures[t_key], rect, false)
			else:
				var col: Color = TILES.get(t_key, Color.GRAY)
				_canvas.draw_rect(rect, col)


	# Draw placed building markers
	for key in ColonyManager.city_buildings.keys():
		var b: Dictionary = ColonyManager.city_buildings[key]
		var bx: int = int(b.get("x", 0))
		var by: int = int(b.get("y", 0))
		var b_rect := Rect2(bx * cell_size - 1, by * cell_size - 1, cell_size + 2, cell_size + 2)
		_canvas.draw_rect(b_rect, Color("f59e0b"))
