extends VBoxContainer
## Interface #2: Tactical Rig (Player Bag)
## 8-Slot Equipment Matrix:
## Top Row: 4 Crafted Field Equipment slots (Head, Chest, Legs, Feet)
## Bottom Row: 4 Generation Prestige Cyberware slots (Apron, Archive, Gloves, Weapon)

var _power_label: Label
var _glove_val_label: Label


func _ready() -> void:
	add_theme_constant_override("separation", 14)

	# Power Header
	_power_label = Label.new()
	_power_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_power_label.add_theme_font_size_override("font_size", 34)
	_power_label.add_theme_color_override("font_color", Color("f59e0b"))
	add_child(_power_label)

	# 1. Top Row: Standard Crafted Armor (Field Equipment)
	add_child(UIRows.heading("FIELD EQUIPMENT (CRAFTED)"))
	var top_grid := GridContainer.new()
	top_grid.columns = 4
	top_grid.add_theme_constant_override("h_separation", 10)
	top_grid.add_theme_constant_override("v_separation", 10)
	add_child(top_grid)

	for slot in GameState.loadout.get("equipment", []):
		var tile := _make_gear_tile(
			slot.get("label", "SLOT"),
			slot.get("name", "Crafted Gear"),
			"(Crafted)",
			Color("fff3e0"),
			slot.get("desc", "")
		)
		top_grid.add_child(tile)

	# 2. Bottom Row: Generation Prestige Cyberware (GP Shop Upgrades)
	add_child(UIRows.heading("GENERATION PRESTIGE CYBERWARE (GP SHOP UPGRADES)"))
	var bot_grid := GridContainer.new()
	bot_grid.columns = 4
	bot_grid.add_theme_constant_override("h_separation", 10)
	bot_grid.add_theme_constant_override("v_separation", 10)
	add_child(bot_grid)

	for slot in GameState.loadout.get("cyberware", []):
		var slot_key: String = slot.get("slot", "")
		var val_text: String = slot.get("value", "")

		if slot_key == "gloves":
			var mod_val := GameState.glove_modifier
			val_text = "+%.0f Skill" % mod_val if mod_val >= 0 else "%.0f Skill" % mod_val
			var tile := _make_cyber_tile(
				slot.get("label", "GLOVES"),
				val_text,
				Color("70ff8b"),
				"Tap to toggle: +30 Cyber-Glove / -15 Training Glove",
				true
			)
			bot_grid.add_child(tile)
		elif slot_key == "apron":
			var tile := _make_cyber_tile(
				slot.get("label", "APRON"),
				"+%.0f%% GP" % GameState.gp_boost_pct,
				Color("f59e0b"),
				slot.get("desc", ""),
				false
			)
			bot_grid.add_child(tile)
		elif slot_key == "archive":
			var tile := _make_cyber_tile(
				slot.get("label", "ARCHIVE"),
				"+%.1f XP" % GameState.archive_bonus,
				Color("f59e0b"),
				slot.get("desc", ""),
				false
			)
			bot_grid.add_child(tile)
		else:
			var tile := _make_cyber_tile(
				slot.get("label", "WEAPON"),
				val_text,
				Color("fff3e0"),
				slot.get("desc", ""),
				false
			)
			bot_grid.add_child(tile)

	_refresh_power()
	GameState.glove_modifier_changed.connect(func(_v: float) -> void: _refresh_gloves())

	# 3. Info / Inventory Status
	add_child(UIRows.heading("TACTICAL CARGO LINK"))
	add_child(UIRows.row("Active Inventory Link", "20/20 Standard Cargo Slots connected below", Color("70ff8b")))


func _refresh_power() -> void:
	var total_power: int = int(GameState.loadout.get("power", 420))
	_power_label.text = "TACTICAL RIG RATING // POWER: %d" % total_power


func _refresh_gloves() -> void:
	if _glove_val_label:
		var mod_val := GameState.glove_modifier
		var txt := "+%.0f Skill" % mod_val if mod_val >= 0 else "%.0f Skill" % mod_val
		_glove_val_label.text = txt
		_glove_val_label.add_theme_color_override("font_color", Color("e74c3c") if mod_val < 0 else Color("70ff8b"))


func _make_gear_tile(slot_name: String, item_name: String, sub_text: String, sub_color: Color, desc: String) -> PanelContainer:
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(220, 150)
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	var sb := StyleBoxFlat.new()
	sb.bg_color = Color("3d3429")
	sb.set_border_width_all(3)
	sb.border_color = Color("574b3d")
	sb.set_corner_radius_all(10)
	sb.content_margin_left = 8
	sb.content_margin_right = 8
	sb.content_margin_top = 10
	sb.content_margin_bottom = 10
	panel.add_theme_stylebox_override("panel", sb)

	var v := VBoxContainer.new()
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	panel.add_child(v)

	var title := Label.new()
	title.text = "[ %s ]" % slot_name
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 22)
	title.add_theme_color_override("font_color", Color("faecd8"))
	v.add_child(title)

	var item := Label.new()
	item.text = item_name
	item.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	item.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	item.add_theme_font_size_override("font_size", 18)
	item.add_theme_color_override("font_color", Color("bfb7aa"))
	v.add_child(item)

	var sub := Label.new()
	sub.text = sub_text
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sub.add_theme_font_size_override("font_size", 18)
	sub.add_theme_color_override("font_color", sub_color)
	v.add_child(sub)

	var btn := Button.new()
	btn.flat = true
	btn.focus_mode = Control.FOCUS_NONE
	btn.set_anchors_preset(Control.PRESET_FULL_RECT)
	btn.pressed.connect(func() -> void: GameState.toast_requested.emit("[%s] %s: %s" % [slot_name, item_name, desc]))
	panel.add_child(btn)

	return panel


func _make_cyber_tile(slot_name: String, val_text: String, val_color: Color, desc: String, is_gloves: bool) -> PanelContainer:
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(220, 150)
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	var sb := StyleBoxFlat.new()
	sb.bg_color = Color("442d17")
	sb.set_border_width_all(3)
	sb.border_color = Color("d97724")
	sb.set_corner_radius_all(10)
	sb.content_margin_left = 8
	sb.content_margin_right = 8
	sb.content_margin_top = 10
	sb.content_margin_bottom = 10
	panel.add_theme_stylebox_override("panel", sb)

	var v := VBoxContainer.new()
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	panel.add_child(v)

	var title := Label.new()
	title.text = "[ %s ]" % slot_name
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 22)
	title.add_theme_color_override("font_color", Color("f59e0b"))
	v.add_child(title)

	var val := Label.new()
	val.text = val_text
	val.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	val.add_theme_font_size_override("font_size", 26)
	val.add_theme_color_override("font_color", val_color)
	v.add_child(val)

	var sub := Label.new()
	sub.text = "(GP Upgraded)"
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sub.add_theme_font_size_override("font_size", 18)
	sub.add_theme_color_override("font_color", Color("bfb7aa"))
	v.add_child(sub)

	if is_gloves:
		_glove_val_label = val

	var btn := Button.new()
	btn.flat = true
	btn.focus_mode = Control.FOCUS_NONE
	btn.set_anchors_preset(Control.PRESET_FULL_RECT)
	if is_gloves:
		btn.pressed.connect(func() -> void:
			var new_glove := GameState.cycle_glove_modifier()
			var msg := "Equipped: +30 Cyber-Glove" if new_glove > 0 else ("Unequipped Gloves" if new_glove == 0 else "Equipped: -15 Training Glove (Fail-to-Learn)")
			GameState.toast_requested.emit(msg)
		)
	else:
		btn.pressed.connect(func() -> void: GameState.toast_requested.emit("[%s Cyberware] %s: %s" % [slot_name, val_text, desc]))
	panel.add_child(btn)

	return panel
