extends VBoxContainer
## Character Initialization: Operative callsign registration and aesthetic chassis model selector.

var _line_edit: LineEdit
var _selected_chassis: String = "male"
var _male_btn: Button
var _female_btn: Button


func _ready() -> void:
	add_theme_constant_override("separation", 16)

	add_child(UIRows.heading("OPERATIVE IDENTITY INITIALIZATION"))
	add_child(UIRows.row("Direct Link", "Neural Synchronization Link Established", Color("70ff8b")))

	# 1. Model / Chassis Selector
	add_child(UIRows.heading("SELECT AESTHETIC CHASSIS MODEL"))
	var chassis_row := HBoxContainer.new()
	chassis_row.add_theme_constant_override("separation", 16)
	add_child(chassis_row)

	_male_btn = Button.new()
	_male_btn.text = "🧑‍🚀 MODEL ALPHA (MALE)"
	_male_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_male_btn.custom_minimum_size = Vector2(0, 96)
	_male_btn.focus_mode = Control.FOCUS_NONE
	_male_btn.add_theme_font_size_override("font_size", 30)
	_male_btn.pressed.connect(func() -> void: _set_chassis("male"))
	chassis_row.add_child(_male_btn)

	_female_btn = Button.new()
	_female_btn.text = "👩‍🚀 MODEL BETA (FEMALE)"
	_female_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_female_btn.custom_minimum_size = Vector2(0, 96)
	_female_btn.focus_mode = Control.FOCUS_NONE
	_female_btn.add_theme_font_size_override("font_size", 30)
	_female_btn.pressed.connect(func() -> void: _set_chassis("female"))
	chassis_row.add_child(_female_btn)

	_selected_chassis = GameState.operative_chassis
	_update_chassis_buttons()

	# 2. Callsign / Codename Registration
	add_child(UIRows.heading("REGISTER CALLSIGN / CODENAME"))

	var callsign_box := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color("463f33")
	sb.set_corner_radius_all(12)
	sb.content_margin_left = 24
	sb.content_margin_right = 24
	sb.content_margin_top = 16
	sb.content_margin_bottom = 16
	callsign_box.add_theme_stylebox_override("panel", sb)
	add_child(callsign_box)

	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 16)
	callsign_box.add_child(hbox)

	var lbl := Label.new()
	lbl.text = "Callsign:"
	lbl.add_theme_font_size_override("font_size", 32)
	lbl.add_theme_color_override("font_color", Color("faecd8"))
	hbox.add_child(lbl)

	_line_edit = LineEdit.new()
	_line_edit.text = GameState.operative_callsign
	_line_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_line_edit.add_theme_font_size_override("font_size", 32)
	hbox.add_child(_line_edit)

	# Preset callsign quick buttons
	add_child(UIRows.heading("TACTICAL PRESETS"))
	var preset_row := HBoxContainer.new()
	preset_row.add_theme_constant_override("separation", 12)
	add_child(preset_row)

	for callsign in ["Unit KOO", "Operator VEX", "Fabricator ZERO", "Vanguard NYX"]:
		var pb := Button.new()
		pb.text = callsign
		pb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		pb.custom_minimum_size = Vector2(0, 72)
		pb.focus_mode = Control.FOCUS_NONE
		pb.add_theme_font_size_override("font_size", 24)
		pb.pressed.connect(func() -> void: _line_edit.text = callsign)
		preset_row.add_child(pb)

	# 3. Confirmation Button
	var confirm_btn := UIRows.action_button("CONFIRM OPERATIVE IDENTITY")
	confirm_btn.custom_minimum_size = Vector2(0, 100)
	confirm_btn.pressed.connect(_on_confirm)
	add_child(confirm_btn)


func _set_chassis(chassis: String) -> void:
	_selected_chassis = chassis
	_update_chassis_buttons()


func _update_chassis_buttons() -> void:
	var active_box := StyleBoxFlat.new()
	active_box.bg_color = Color("d97724")
	active_box.set_border_width_all(4)
	active_box.border_color = Color("f59e0b")
	active_box.set_corner_radius_all(12)

	var normal_box := StyleBoxFlat.new()
	normal_box.bg_color = Color("3d3830")
	normal_box.set_corner_radius_all(12)

	if _selected_chassis == "male":
		_male_btn.add_theme_stylebox_override("normal", active_box)
		_female_btn.add_theme_stylebox_override("normal", normal_box)
	else:
		_female_btn.add_theme_stylebox_override("normal", active_box)
		_male_btn.add_theme_stylebox_override("normal", normal_box)


func _on_confirm() -> void:
	var name_txt := _line_edit.text.strip_edges()
	if name_txt == "":
		name_txt = "Operator KOO"
	GameState.set_identity(name_txt, _selected_chassis)
	GameState.toast_requested.emit("Operative Synchronized: %s" % name_txt)
	GameState.modal_requested.emit("protag_skills")
