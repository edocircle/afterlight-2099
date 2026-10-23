class_name MiniCityMap
extends PanelContainer
## Miniature Overview of the 30x30 Colony City Map.
## Displays between Character Trio and Crafting Slab.
## Provides a clean, simplified 1:1 view aligned with the City Menu map.
## Tapping opens the maximized interactive City Menu.

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
var _pop_lbl: Label
var _textures: Dictionary = {}


func _ready() -> void:
	_load_textures()
	_build_ui()
	ColonyManager.map_updated.connect(queue_redraw_map)
	ColonyManager.run_reset.connect(queue_redraw_map)
	MinionSystem.scavenge_started.connect(func(_d: float, _dep: bool) -> void: queue_redraw_map())
	MinionSystem.scavenge_finished.connect(func(_id: String) -> void: queue_redraw_map())


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
	custom_minimum_size = Vector2(0, 390)
	size_flags_horizontal = Control.SIZE_EXPAND_FILL

	var panel_sb := UiFrames.panel(20)
	panel_sb.content_margin_top = 16
	panel_sb.content_margin_bottom = 18
	add_theme_stylebox_override("panel", panel_sb)

	var root_col := VBoxContainer.new()
	root_col.add_theme_constant_override("separation", 8)
	add_child(root_col)

	# Clean header
	var head_row := HBoxContainer.new()
	head_row.add_theme_constant_override("separation", 10)
	root_col.add_child(head_row)

	var icon_lbl := Label.new()
	icon_lbl.text = "🏛️"
	icon_lbl.add_theme_font_size_override("font_size", 24)
	head_row.add_child(icon_lbl)

	_header_lbl = Label.new()
	_header_lbl.text = "COLONY CITADEL (30x30)"
	_header_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_header_lbl.add_theme_font_size_override("font_size", 22)
	_header_lbl.add_theme_color_override("font_color", Color("fef08a")) # Warm high-contrast amber
	_header_lbl.add_theme_color_override("font_outline_color", Color(0.02, 0.08, 0.14, 0.95))
	_header_lbl.add_theme_constant_override("outline_size", 6)
	head_row.add_child(_header_lbl)

	_pop_lbl = Label.new()
	_pop_lbl.text = "Pop: %d/%d" % [ColonyManager.population, ColonyManager.housing_capacity]
	_pop_lbl.add_theme_font_size_override("font_size", 20)
	_pop_lbl.add_theme_color_override("font_color", Color("67e8f9")) # Bright cyan
	_pop_lbl.add_theme_color_override("font_outline_color", Color(0.02, 0.08, 0.14, 0.95))
	_pop_lbl.add_theme_constant_override("outline_size", 6)
	head_row.add_child(_pop_lbl)

	var open_btn := Button.new()
	open_btn.text = "🔍 EXPAND"
	open_btn.focus_mode = Control.FOCUS_NONE
	open_btn.custom_minimum_size = Vector2(140, 44)
	open_btn.add_theme_font_size_override("font_size", 18)
	for state in ["normal", "hover", "pressed"]:
		open_btn.add_theme_stylebox_override(state, UiFrames.small_button(state))
	open_btn.pressed.connect(func() -> void:
		GameState.modal_requested.emit("city")
	)
	head_row.add_child(open_btn)

	# Content: Centered framed map aligned with city modal
	var center_box := CenterContainer.new()
	center_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	root_col.add_child(center_box)

	var frame := PanelContainer.new()
	frame.custom_minimum_size = Vector2(306, 306)
	var frame_sb := StyleBoxFlat.new()
	frame_sb.bg_color = Color("081f33")
	frame_sb.set_border_width_all(3)
	frame_sb.border_color = Color("22d3ee")
	frame_sb.set_corner_radius_all(14)
	frame_sb.set_content_margin_all(3)
	frame.add_theme_stylebox_override("panel", frame_sb)
	center_box.add_child(frame)

	_canvas = Control.new()
	_canvas.custom_minimum_size = Vector2(300, 300)
	_canvas.draw.connect(_on_canvas_draw)
	_canvas.mouse_filter = Control.MOUSE_FILTER_PASS
	_canvas.gui_input.connect(func(e: InputEvent) -> void:
		if e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT:
			GameState.modal_requested.emit("city")
	)
	frame.add_child(_canvas)


func queue_redraw_map() -> void:
	if _canvas != null:
		_canvas.queue_redraw()
	if _pop_lbl != null:
		_pop_lbl.text = "Pop: %d/%d" % [ColonyManager.population, ColonyManager.housing_capacity]


func _on_canvas_draw() -> void:
	var map_dim := ColonyManager.city_map_size
	if map_dim <= 0 or ColonyManager.city_map_data.is_empty():
		return
	var cell_size := 300.0 / float(map_dim)

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

	# Subtle grid lines
	for i in range(1, map_dim):
		var p: float = i * cell_size
		_canvas.draw_line(Vector2(p, 0), Vector2(p, 300.0), Color(0, 0, 0, 0.18), 1.0)
		_canvas.draw_line(Vector2(0, p), Vector2(300.0, p), Color(0, 0, 0, 0.18), 1.0)

	# Draw placed building markers
	for key in ColonyManager.city_buildings.keys():
		var b: Dictionary = ColonyManager.city_buildings[key]
		var bx: int = int(b.get("x", 0))
		var by: int = int(b.get("y", 0))
		var b_rect := Rect2(bx * cell_size, by * cell_size, cell_size, cell_size)
		_canvas.draw_rect(b_rect, Color(0.9, 0.6, 0.1, 0.6))
		_canvas.draw_rect(b_rect, Color("f59e0b"), false, 1.5)

	# Cute scavenging bot animation on the city map
	if MinionSystem.is_scavenging:
		_draw_scavenging_bot()


const WAYPOINTS: Array[Vector2] = [
	Vector2(265.0, 20.0), # Flies in from top right
	Vector2(220.0, 85.0), # North-East sector
	Vector2(110.0, 65.0), # North ruins
	Vector2(65.0, 190.0), # West ruins
	Vector2(185.0, 230.0), # South ruins
	Vector2(150.0, 140.0), # Central Citadel
	Vector2(275.0, 15.0), # Swoops back out
]


func _draw_scavenging_bot() -> void:
	var total_dur := maxf(0.1, MinionSystem.scavenge_duration)
	var time_left := maxf(0.0, MinionSystem.scavenge_end_unix - Time.get_unix_time_from_system())
	var elapsed_ratio := clampf(1.0 - (time_left / total_dur), 0.0, 1.0)

	var seg_count := float(WAYPOINTS.size() - 1)
	var seg_idx := clampi(int(elapsed_ratio * seg_count), 0, WAYPOINTS.size() - 2)
	var seg_t := fposmod(elapsed_ratio * seg_count, 1.0)
	seg_t = smoothstep(0.0, 1.0, seg_t)

	var bot_pos: Vector2 = WAYPOINTS[seg_idx].lerp(WAYPOINTS[seg_idx + 1], seg_t)

	# Hover bobbing animation
	var is_dep := MinionSystem.scavenge_depleted
	var bob_freq := 4.0 if is_dep else 10.0
	var bob_amt := 2.0 if is_dep else 4.0
	var hover_y := sin(Time.get_ticks_msec() * 0.001 * bob_freq) * bob_amt
	var drone_center := bot_pos + Vector2(0, hover_y)

	# 1. Ground shadow
	_canvas.draw_circle(bot_pos + Vector2(0, 14), 7.0, Color(0, 0, 0, 0.3))

	# 2. Scanning light beam / cone pointing down to ground
	var beam_col: Color
	if is_dep:
		var pulse := 0.25 + 0.15 * sin(Time.get_ticks_msec() * 0.015)
		beam_col = Color(0.96, 0.62, 0.07, pulse)
	else:
		var pulse := 0.35 + 0.15 * sin(Time.get_ticks_msec() * 0.02)
		beam_col = Color(0.13, 0.83, 0.93, pulse)

	var pt_top := drone_center + Vector2(0, 4)
	var pt_bl := bot_pos + Vector2(-15, 14)
	var pt_br := bot_pos + Vector2(15, 14)
	_canvas.draw_colored_polygon(PackedVector2Array([pt_top, pt_bl, pt_br]), beam_col)

	# 3. Expanding radar pulse ring on ground
	var speed_mult := 0.008 if is_dep else 0.02
	var ring_r := 6.0 + fposmod(Time.get_ticks_msec() * speed_mult, 10.0)
	var ring_alpha := 1.0 - (ring_r - 6.0) / 10.0
	var ring_col := Color(beam_col.r, beam_col.g, beam_col.b, ring_alpha * 0.7)
	_canvas.draw_arc(bot_pos + Vector2(0, 14), ring_r, 0, TAU, 16, ring_col, 1.5)

	# 4. Cute Saucer Drone
	var body_col := Color("d97706") if is_dep else Color("0284c7")
	var rim_col := Color("f59e0b") if is_dep else Color("38bdf8")
	var dome_col := Color("fcd34d") if is_dep else Color("7dd3fc")

	# Outer saucer
	_canvas.draw_circle(drone_center, 8.0, Color("082e46"))
	_canvas.draw_circle(drone_center, 7.0, body_col)
	_canvas.draw_arc(drone_center, 7.5, 0, TAU, 16, rim_col, 1.5)

	# Glass dome
	_canvas.draw_circle(drone_center + Vector2(0, -2), 4.0, dome_col)

	# Center sensor eye
	var eye_col := Color("ef4444") if is_dep else Color.WHITE
	_canvas.draw_circle(drone_center + Vector2(0, -1), 1.8, eye_col)


func _process(_delta: float) -> void:
	if MinionSystem.is_scavenging:
		if _canvas != null:
			_canvas.queue_redraw()
		var left := maxi(1, int(ceil(MinionSystem.scavenge_end_unix - Time.get_unix_time_from_system())))
		if _header_lbl != null:
			if MinionSystem.scavenge_depleted:
				_header_lbl.text = "COLONY CITADEL 🛸 Scouting (%ds - Slow)" % left
				_header_lbl.add_theme_color_override("font_color", Color("f59e0b"))
			else:
				_header_lbl.text = "COLONY CITADEL 🛸 Scouting (%ds)" % left
				_header_lbl.add_theme_color_override("font_color", Color("38bdf8"))
	else:
		if _header_lbl != null and _header_lbl.text != "COLONY CITADEL (30x30)":
			_header_lbl.text = "COLONY CITADEL (30x30)"
			_header_lbl.add_theme_color_override("font_color", Color("e0f2fe"))
			if _canvas != null:
				_canvas.queue_redraw()
