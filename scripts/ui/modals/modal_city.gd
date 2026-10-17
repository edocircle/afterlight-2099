extends VBoxContainer
## Full Interactive Colony City Map with Pan & Zoom and Building Construction.
## Features:
## - 30x30 procedural sector with contiguous connected desert dunes
## - Multi-touch pinch-to-zoom (0.6x to 2.8x) & mouse wheel zoom
## - Smooth finger drag and mouse drag panning with view centering
## - Building placement mode on surveyed terrain
## - Colony housing, population, and recombination reset options

const TILE_BASE_SIZE := 48 # 30 * 48 = 1440px full grid at 100% zoom

const TILES := {
	"grass": {
		"name": "Lush Grassland",
		"tex": "res://assets/sprites/tiles/grass.png",
		"color": Color("58a62c"),
		"buildable": true
	},
	"forest": {
		"name": "Canopy Forest",
		"tex": "res://assets/sprites/tiles/forest.png",
		"color": Color("2e6b18"),
		"buildable": true
	},
	"mountain": {
		"name": "Granite Mountain",
		"tex": "res://assets/sprites/tiles/mountain.png",
		"color": Color("7c7c84"),
		"buildable": false
	},
	"desert": {
		"name": "Connected Sand Dunes",
		"tex": "res://assets/sprites/tiles/desert.png",
		"color": Color("d6a845"),
		"buildable": true
	},
	"shallow_water": {
		"name": "Coastal Shallows",
		"tex": "res://assets/sprites/tiles/shallow_water.png",
		"color": Color("38bdf8"),
		"buildable": true
	},
	"deep_water": {
		"name": "Deep Ocean Trench",
		"tex": "res://assets/sprites/tiles/deep_water.png",
		"color": Color("033c73"),
		"buildable": false
	}
}

const BUILD_OPTIONS := [
	{"id": "solar_array", "name": "Solar Array", "icon": "⚡", "cost": "2x Nano-Grid"},
	{"id": "hydro_dome", "name": "Hydroponic Dome", "icon": "🌿", "cost": "1x Composite Log"},
	{"id": "habitat_pod", "name": "Habitat Pod", "icon": "🏠", "cost": "2x Carbon Strut"},
	{"id": "radar_dish", "name": "Comms Array", "icon": "📡", "cost": "1x Mono-Shard"}
]

var _selected_build_idx: int = -1
var _zoom_level: float = 1.0
var _viewport_scroll: ScrollContainer
var _map_grid: Control
var _textures: Dictionary = {}
var _status_lbl: Label
var _inspect_lbl: Label
var _reset_btn: Button
var _armed := false

# Drag & Pinch state
var _is_mouse_dragging := false
var _has_dragged := false
var _drag_distance := 0.0
var _touch_points: Dictionary = {} # index (int) -> Vector2 (global_position)
var _initial_touch_distance: float = 0.0
var _initial_zoom_level: float = 1.0


func _ready() -> void:
	add_theme_constant_override("separation", 14)
	size_flags_vertical = Control.SIZE_EXPAND_FILL
	_load_textures()
	_build_ui()
	ColonyManager.map_updated.connect(_redraw_map)
	ColonyManager.run_reset.connect(_redraw_map)


func _load_textures() -> void:
	for k in TILES:
		var p: String = TILES[k]["tex"]
		if ResourceLoader.exists(p):
			_textures[k] = load(p)


func _build_ui() -> void:
	# 1. Header & Overview
	add_child(UIRows.heading("NEW AMSTERDAM CITADEL // 30x30 SECTOR"))
	add_child(UIRows.row("Colony Status", "Population: %d / %d Operatives" % [ColonyManager.population, ColonyManager.housing_capacity], Color("d4af37")))

	# 2. Zoom controls
	var controls_row := HBoxContainer.new()
	controls_row.add_theme_constant_override("separation", 10)
	add_child(controls_row)

	var zoom_out_btn := Button.new()
	zoom_out_btn.text = "➖ ZOOM OUT"
	zoom_out_btn.focus_mode = Control.FOCUS_NONE
	zoom_out_btn.custom_minimum_size = Vector2(180, 52)
	zoom_out_btn.add_theme_font_size_override("font_size", 20)
	zoom_out_btn.pressed.connect(func() -> void: _adjust_zoom(-0.25))
	controls_row.add_child(zoom_out_btn)

	_status_lbl = Label.new()
	_status_lbl.text = "Zoom: 100% (Pinch / Drag)"
	_status_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_status_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_status_lbl.add_theme_font_size_override("font_size", 22)
	_status_lbl.add_theme_color_override("font_color", Color("38bdf8"))
	controls_row.add_child(_status_lbl)

	var zoom_in_btn := Button.new()
	zoom_in_btn.text = "➕ ZOOM IN"
	zoom_in_btn.focus_mode = Control.FOCUS_NONE
	zoom_in_btn.custom_minimum_size = Vector2(180, 52)
	zoom_in_btn.add_theme_font_size_override("font_size", 20)
	zoom_in_btn.pressed.connect(func() -> void: _adjust_zoom(0.25))
	controls_row.add_child(zoom_in_btn)

	# 3. Interactive Zoomable Map Viewport (Maximized height for phone screen)
	var view_frame := PanelContainer.new()
	view_frame.custom_minimum_size = Vector2(0, 1420)
	view_frame.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	view_frame.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var v_sb := StyleBoxFlat.new()
	v_sb.bg_color = Color("081f33")
	v_sb.set_border_width_all(4)
	v_sb.border_color = Color("22d3ee")
	v_sb.set_corner_radius_all(20)
	v_sb.set_content_margin_all(6)
	view_frame.add_theme_stylebox_override("panel", v_sb)
	add_child(view_frame)

	_viewport_scroll = ScrollContainer.new()
	_viewport_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_viewport_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_viewport_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_SHOW_NEVER
	_viewport_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_SHOW_NEVER
	view_frame.add_child(_viewport_scroll)

	_map_grid = Control.new()
	var total_px: float = 30.0 * TILE_BASE_SIZE * _zoom_level
	_map_grid.custom_minimum_size = Vector2(total_px, total_px)
	_map_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_map_grid.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_map_grid.mouse_filter = Control.MOUSE_FILTER_STOP
	_map_grid.draw.connect(_on_map_draw)
	_map_grid.gui_input.connect(_on_map_gui_input)
	_viewport_scroll.add_child(_map_grid)

	# 4. Building Blueprint Palette & Inspector
	add_child(UIRows.heading("CONSTRUCTION BLUEPRINTS // TAP BLUEPRINT THEN TAP MAP"))
	var build_row := HBoxContainer.new()
	build_row.add_theme_constant_override("separation", 10)
	add_child(build_row)

	for i in BUILD_OPTIONS.size():
		var b_def: Dictionary = BUILD_OPTIONS[i]
		var b_btn := Button.new()
		b_btn.text = "%s %s" % [b_def["icon"], b_def["name"]]
		b_btn.focus_mode = Control.FOCUS_NONE
		b_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b_btn.custom_minimum_size = Vector2(0, 60)
		b_btn.add_theme_font_size_override("font_size", 20)
		b_btn.pressed.connect(_select_blueprint.bind(i))
		build_row.add_child(b_btn)

	_inspect_lbl = Label.new()
	_inspect_lbl.text = "Survey Status: Drag finger/mouse to pan. Pinch or buttons to zoom. Tap to inspect or build."
	_inspect_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_inspect_lbl.add_theme_font_size_override("font_size", 22)
	_inspect_lbl.add_theme_color_override("font_color", Color("70ff8b"))
	add_child(_inspect_lbl)

	# 5. Existing Colony Buildings and Reset Button
	add_child(UIRows.heading("MUNICIPAL BUILDINGS // RECOMBINATION"))
	for b in ColonyManager.buildings:
		match b["id"]:
			"love_hut":
				_reset_btn = UIRows.action_button("RESET")
				_reset_btn.pressed.connect(_on_reset_pressed)
				add_child(UIRows.row(b["name"], "", Color.WHITE, _reset_btn))
			_:
				add_child(UIRows.row(b["name"], b.get("status", ""), Color("f59e0b")))


func _adjust_zoom(delta: float) -> void:
	_set_zoom(_zoom_level + delta)


func _set_zoom(new_val: float) -> void:
	var old_zoom := _zoom_level
	_zoom_level = clampf(new_val, 0.6, 2.8)
	var total_px: float = 30.0 * TILE_BASE_SIZE * _zoom_level
	_map_grid.custom_minimum_size = Vector2(total_px, total_px)
	_status_lbl.text = "Zoom: %d%%" % int(_zoom_level * 100.0)

	if _viewport_scroll != null and old_zoom > 0:
		var ratio := _zoom_level / old_zoom
		var view_w: float = _viewport_scroll.size.x
		var view_h: float = _viewport_scroll.size.y
		if view_w <= 0.0:
			view_w = 900.0
		if view_h <= 0.0:
			view_h = 1400.0
		var center_x: float = _viewport_scroll.scroll_horizontal + view_w * 0.5
		var center_y: float = _viewport_scroll.scroll_vertical + view_h * 0.5
		_viewport_scroll.scroll_horizontal = int(center_x * ratio - view_w * 0.5)
		_viewport_scroll.scroll_vertical = int(center_y * ratio - view_h * 0.5)

	_redraw_map()


func _select_blueprint(idx: int) -> void:
	if _selected_build_idx == idx:
		_selected_build_idx = -1
		_inspect_lbl.text = "Building selection cleared. Mode: Inspect & Pan."
		_inspect_lbl.add_theme_color_override("font_color", Color("bfb7aa"))
	else:
		_selected_build_idx = idx
		var b_def: Dictionary = BUILD_OPTIONS[idx]
		_inspect_lbl.text = "Ready to place: %s %s (%s). Tap an eligible map cell." % [b_def["icon"], b_def["name"], b_def["cost"]]
		_inspect_lbl.add_theme_color_override("font_color", Color("f59e0b"))


func _redraw_map() -> void:
	if _map_grid != null:
		_map_grid.queue_redraw()


func _on_map_draw() -> void:
	var map_dim := ColonyManager.city_map_size
	if map_dim <= 0 or ColonyManager.city_map_data.is_empty():
		return

	var cell_size: float = TILE_BASE_SIZE * _zoom_level

	for y in map_dim:
		for x in map_dim:
			var idx := y * map_dim + x
			var t_key: String = ColonyManager.city_map_data[idx]
			var rect := Rect2(x * cell_size, y * cell_size, cell_size, cell_size)

			if _textures.has(t_key):
				_map_grid.draw_texture_rect(_textures[t_key], rect, false)
			else:
				var col: Color = TILES.get(t_key, {}).get("color", Color.GRAY)
				_map_grid.draw_rect(rect, col)

			# Subtle grid border
			_map_grid.draw_rect(rect, Color(0, 0, 0, 0.25), false, 1.0)

	# Draw placed buildings
	for key in ColonyManager.city_buildings.keys():
		var b: Dictionary = ColonyManager.city_buildings[key]
		var bx: int = int(b.get("x", 0))
		var by: int = int(b.get("y", 0))
		var b_rect := Rect2(bx * cell_size, by * cell_size, cell_size, cell_size)
		_map_grid.draw_rect(b_rect, Color(0.9, 0.6, 0.1, 0.4))
		_map_grid.draw_rect(b_rect, Color("f59e0b"), false, 2.0)
		# Draw building icon glyph
		var icon_str: String = b.get("icon", "🏛️")
		var font: Font = ThemeDB.fallback_font
		_map_grid.draw_string(font, Vector2(bx * cell_size + cell_size * 0.2, by * cell_size + cell_size * 0.75), icon_str, HORIZONTAL_ALIGNMENT_CENTER, -1, int(cell_size * 0.6))


func _on_map_gui_input(event: InputEvent) -> void:
	# 1. Touch screen events (multi-touch pinch & single finger drag)
	if event is InputEventScreenTouch:
		if event.pressed:
			_touch_points[event.index] = global_position
			if _touch_points.size() == 1:
				_has_dragged = false
				_drag_distance = 0.0
			elif _touch_points.size() >= 2:
				_has_dragged = true
				var pts: Array = _touch_points.values()
				_initial_touch_distance = (pts[0] - pts[1]).length()
				_initial_zoom_level = _zoom_level
		else:
			var released_pos: Vector2 = global_position
			_touch_points.erase(event.index)
			if _touch_points.is_empty():
				if not _has_dragged:
					_handle_click_at(released_pos)
		accept_event()
		return

	if event is InputEventScreenDrag:
		_touch_points[event.index] = global_position
		if _touch_points.size() >= 2:
			var pts: Array = _touch_points.values()
			var current_dist: float = (pts[0] - pts[1]).length()
			if _initial_touch_distance > 10.0:
				var scale_factor: float = current_dist / _initial_touch_distance
				_set_zoom(_initial_zoom_level * scale_factor)
			_has_dragged = true
		elif _touch_points.size() == 1:
			_viewport_scroll.scroll_horizontal -= int(event.relative.x)
			_viewport_scroll.scroll_vertical -= int(event.relative.y)
			_drag_distance += event.relative.length()
			if _drag_distance > 10.0:
				_has_dragged = true
		accept_event()
		return

	# 2. Mouse events (mouse drag to move & wheel to zoom)
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP and event.pressed:
			_adjust_zoom(0.15)
			accept_event()
			return
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN and event.pressed:
			_adjust_zoom(-0.15)
			accept_event()
			return
		elif event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				_is_mouse_dragging = true
				_has_dragged = false
				_drag_distance = 0.0
			else:
				_is_mouse_dragging = false
				if not _has_dragged:
					_handle_click_at(event.global_position)
			accept_event()
			return

	if event is InputEventMouseMotion and _is_mouse_dragging:
		_viewport_scroll.scroll_horizontal -= int(event.relative.x)
		_viewport_scroll.scroll_vertical -= int(event.relative.y)
		_drag_distance += event.relative.length()
		if _drag_distance > 8.0:
			_has_dragged = true
		accept_event()


func _handle_click_at(global_pos: Vector2) -> void:
	var local_pos := global_pos - _map_grid.global_position
	var cell_size: float = TILE_BASE_SIZE * _zoom_level
	var tx: int = int(local_pos.x / cell_size)
	var ty: int = int(local_pos.y / cell_size)
	var map_dim := ColonyManager.city_map_size

	if tx >= 0 and tx < map_dim and ty >= 0 and ty < map_dim:
		_handle_tile_action(tx, ty)


func _handle_tile_action(x: int, y: int) -> void:
	var t_key := ColonyManager.get_tile(x, y)
	var t_info: Dictionary = TILES.get(t_key, {})
	var t_name: String = t_info.get("name", t_key.capitalize())
	var existing_building: Variant = ColonyManager.get_building_at(x, y)

	if _selected_build_idx >= 0:
		var b_def: Dictionary = BUILD_OPTIONS[_selected_build_idx]

		if not t_info.get("buildable", true):
			_inspect_lbl.text = "Cannot construct on %s! Choose grass, forest, shallow water, or desert dunes." % t_name
			_inspect_lbl.add_theme_color_override("font_color", Color("e74c3c"))
			return

		ColonyManager.place_building(x, y, b_def["id"], b_def["name"], b_def["icon"])
		_inspect_lbl.text = "Constructed %s %s on Sector [%d, %d] (%s)!" % [b_def["icon"], b_def["name"], x + 1, y + 1, t_name]
		_inspect_lbl.add_theme_color_override("font_color", Color("70ff8b"))
		_redraw_map()
	else:
		if existing_building != null:
			_inspect_lbl.text = "Sector [%d, %d]: %s %s on %s terrain." % [x + 1, y + 1, existing_building.get("icon", ""), existing_building.get("name", "Structure"), t_name]
		else:
			_inspect_lbl.text = "Sector [%d, %d]: %s — Available for construction." % [x + 1, y + 1, t_name]
		_inspect_lbl.add_theme_color_override("font_color", t_info.get("color", Color("f59e0b")))


func _on_reset_pressed() -> void:
	if not _armed:
		_armed = true
		_reset_btn.text = "TAP AGAIN"
		get_tree().create_timer(3.0).timeout.connect(_disarm)
		return
	_armed = false
	ColonyManager.reset_run()


func _disarm() -> void:
	if is_instance_valid(_reset_btn):
		_armed = false
		_reset_btn.text = "RESET"
