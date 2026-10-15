extends VBoxContainer
## Interface #1: Neural Skills Core (The Skills Window)
## Modeled on the Koo Skills interface:
## [Code] Discipline Name : Base Skill (Glove Mod -> Effective Skill)
## Tapping any skill row opens that discipline's Blueprint Success Calibration sub-menu.


func _ready() -> void:
	add_theme_constant_override("separation", 12)

	# Operative Callsign Header
	var head_row := HBoxContainer.new()
	add_child(head_row)

	var id_lbl := Label.new()
	id_lbl.text = "%s // CALLSIGN: %s" % [GameState.get_avatar_glyph(), GameState.operative_callsign.to_upper()]
	id_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	id_lbl.add_theme_font_size_override("font_size", 26)
	id_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	id_lbl.custom_minimum_size.x = 120
	id_lbl.add_theme_color_override("font_color", Color("f59e0b"))
	head_row.add_child(id_lbl)

	var edit_btn := Button.new()
	edit_btn.text = "EDIT ID"
	edit_btn.focus_mode = Control.FOCUS_NONE
	edit_btn.custom_minimum_size = Vector2(140, 52)
	edit_btn.add_theme_font_size_override("font_size", 22)
	edit_btn.pressed.connect(func() -> void: GameState.modal_requested.emit("identity_select"))
	head_row.add_child(edit_btn)

	var glove_str := "+%.1f" % GameState.glove_modifier if GameState.glove_modifier >= 0 else "%.1f" % GameState.glove_modifier
	add_child(UIRows.heading("BASE SKILL (GLOVE MODIFIER -> EFFECTIVE SKILL)"))

	var total_lvl := GameState.get_total_level()

	for def in GameState.skills_def.get("protag", []):
		var key: String = def["key"]
		var code: String = def.get("code", "?")
		var d_name: String = def["name"]
		var req_lvl: int = int(def.get("unlock_level", 0))

		if total_lvl < req_lvl:
			# Locked Discipline Row
			var row := UIRows.row("[?] [LOCKED DISCIPLINE]", "??? (Unlocks at Rank %d)" % req_lvl, Color("bfb7aa"))
			add_child(row)
			continue

		var base_pts: float = float(GameState.skills.get(key, 0.0))
		var eff_pts := GameState.get_effective_skill(key)

		# Format: [F] Bio-Nutrient Synthesis : 37.2 (+30.0 -> 67.2)
		var left_txt := "[%s] %s" % [code, d_name]
		var right_txt := "%.1f (%s -> %.1f)" % [base_pts, glove_str, eff_pts]

		var btn := _make_skill_row_button(left_txt, right_txt, key, d_name)
		add_child(btn)

	add_child(UIRows.heading("BLUEPRINT SUCCESS CALIBRATION"))
	add_child(UIRows.row("Ledger Protocol", "Tap any discipline row above to review blueprints, success rates, and fail-to-learn calibration.", Color("70ff8b")))


func _make_skill_row_button(left: String, right: String, discipline_key: String, discipline_name: String) -> PanelContainer:
	var panel := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color("463f33")
	sb.set_corner_radius_all(12)
	sb.content_margin_left = 20
	sb.content_margin_right = 20
	sb.content_margin_top = 16
	sb.content_margin_bottom = 16
	panel.add_theme_stylebox_override("panel", sb)

	var btn := Button.new()
	btn.focus_mode = Control.FOCUS_NONE
	btn.set_anchors_preset(Control.PRESET_FULL_RECT)
	btn.flat = true
	btn.mouse_filter = Control.MOUSE_FILTER_PASS
	btn.pressed.connect(func() -> void:
		ModalRecipeLedger.selected_discipline = discipline_key
		ModalRecipeLedger.selected_discipline_name = discipline_name
		GameState.modal_requested.emit("recipe_ledger")
	)
	panel.add_child(btn)

	var h := HBoxContainer.new()
	h.mouse_filter = Control.MOUSE_FILTER_IGNORE
	h.add_theme_constant_override("separation", 16)
	panel.add_child(h)

	var l := Label.new()
	l.text = left
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size.x = 120
	l.add_theme_font_size_override("font_size", 28)
	l.add_theme_color_override("font_color", Color("fff3e0"))
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	h.add_child(l)

	var r := Label.new()
	r.text = right
	r.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	r.add_theme_font_size_override("font_size", 26)
	r.add_theme_color_override("font_color", Color("f59e0b"))
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	h.add_child(r)

	return panel
