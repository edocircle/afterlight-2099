class_name ModalMinionBag
extends VBoxContainer
## Minion Bag: Equipment & Directive Setup.
## 8-Slot Matrix:
## Top Row (Chassis Wearables): [HEAD] Sensor Visor, [NECK] Chitin Core, [BODY] Solar Weave, [FEET] Treads
## Bottom Row (Directives & Upgrades): [???] Aux Expansion, [???] Aux Expansion, [GATHER TYPE], [MINION FIST]
## Power: 2, Neural Sync accuracy formula: clamp(Comm * 1.2%, 10%, 95%)

var _power_label: Label
var _telemetry_label: Label
var _gather_btn: Button
var _pod_btn: Button
var _gather_tile_sub: Label
var _fist_tile_sub: Label
var _detail_label: Label


func _ready() -> void:
	add_theme_constant_override("separation", 14)

	# Power & Title Header
	var pwr_row := HBoxContainer.new()
	add_child(pwr_row)

	_power_label = Label.new()
	_power_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_power_label.add_theme_font_size_override("font_size", 28)
	_power_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_power_label.custom_minimum_size.x = 120
	_power_label.add_theme_color_override("font_color", Color("f59e0b"))
	pwr_row.add_child(_power_label)

	var en_lbl := Label.new()
	en_lbl.text = "ENERGY: %d / %d EN" % [int(GameState.minion_energy), int(GameState.max_minion_energy)]
	en_lbl.add_theme_font_size_override("font_size", 26)
	en_lbl.add_theme_color_override("font_color", Color("70ff8b"))
	pwr_row.add_child(en_lbl)

	# Telemetry & Accuracy Banner
	_telemetry_label = Label.new()
	_telemetry_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_telemetry_label.add_theme_font_size_override("font_size", 24)
	_telemetry_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_telemetry_label.custom_minimum_size.x = 120
	add_child(_telemetry_label)

	# 1. 8-Slot Modular Gear Matrix
	add_child(UIRows.heading("CHASSIS WEARABLES & DIRECTIVE MATRIX (8-SLOT)"))

	var matrix_grid := GridContainer.new()
	matrix_grid.columns = 4
	matrix_grid.add_theme_constant_override("h_separation", 10)
	matrix_grid.add_theme_constant_override("v_separation", 10)
	add_child(matrix_grid)

	# Top Row (Chassis Wearables)
	for slot in GameState.loadout.get("minion_chassis", []):
		var tile := _make_slot_tile(
			slot.get("label", "SLOT"),
			slot.get("name", "Wearable"),
			"Power: +%d" % int(slot.get("power", 0)),
			Color("70ff8b") if int(slot.get("power", 0)) > 0 else Color("bfb7aa"),
			slot.get("desc", ""),
			false
		)
		matrix_grid.add_child(tile)

	# Bottom Row (Directives & Upgrades)
	for slot in GameState.loadout.get("minion_directives", []):
		var slot_key: String = slot.get("slot", "")
		var is_locked: bool = bool(slot.get("locked", false))

		if is_locked:
			var tile := _make_slot_tile(
				slot.get("label", "???"),
				slot.get("name", "Aux Expansion"),
				"[ LOCKED ]",
				Color("e74c3c"),
				slot.get("desc", ""),
				false
			)
			matrix_grid.add_child(tile)
		elif slot_key == "gather_type":
			var tile := _make_gather_type_tile(slot)
			matrix_grid.add_child(tile)
		elif slot_key == "fist":
			var tile := _make_fist_tile(slot)
			matrix_grid.add_child(tile)

	# Detail inspector row
	_detail_label = Label.new()
	_detail_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_detail_label.add_theme_font_size_override("font_size", 22)
	_detail_label.add_theme_color_override("font_color", Color("faecd8"))
	_detail_label.text = "Tap any slot above to view telemetry specs. Gather Type slot directs target scavenging."
	add_child(UIRows.row("Telemetry Inspector", "", Color.WHITE, _detail_label))

	# 2. Interactive Directives & Quick Controls
	add_child(UIRows.heading("DIRECTIVE FILTERS & EXPEDITION SETUP"))

	_gather_btn = UIRows.action_button("")
	_gather_btn.custom_minimum_size = Vector2(400, 60)
	_gather_btn.pressed.connect(_on_gather_cycle_pressed)
	add_child(UIRows.row("Gather Type Filter", "", Color.WHITE, _gather_btn))

	var browse_btn := UIRows.action_button("BROWSE INDEX")
	browse_btn.custom_minimum_size = Vector2(400, 60)
	browse_btn.pressed.connect(func() -> void:
		ModalDiscoveryIndex.selected_discipline = "scavenging"
		ModalDiscoveryIndex.selected_discipline_name = "Surface Scavenging"
		ModalDiscoveryIndex.selected_code = "B"
		GameState.modal_requested.emit("discovery_index")
	)
	add_child(UIRows.row("Discovery Silhouette Ledger", "", Color.WHITE, browse_btn))

	_pod_btn = UIRows.action_button("")
	_pod_btn.custom_minimum_size = Vector2(400, 60)
	_pod_btn.pressed.connect(_on_pod_pressed)
	add_child(UIRows.row("Modular Cargo Pod Chassis", "", Color.WHITE, _pod_btn))

	var feed_btn := UIRows.action_button("FEED RATIONS")
	feed_btn.custom_minimum_size = Vector2(400, 60)
	feed_btn.pressed.connect(InventoryManager.consume_food.bind("minion"))
	add_child(UIRows.row("Refuel Drone (Food Rations)", "", Color.WHITE, feed_btn))

	# 3. Inventory Grid Below Marker
	add_child(UIRows.heading("============== INVENTORY GRID BELOW =============="))
	add_child(UIRows.row(
		"Cargo Tether Link",
		"20/20 Field Inventory slots active below. Scavenged hauls and manual drag-gathers deposit directly into cargo slots.",
		Color("70ff8b")
	))

	_refresh()
	MinionSystem.run_state_changed.connect(_refresh)


func _refresh() -> void:
	# Power calculation
	var pwr: int = int(GameState.loadout.get("minion_power", 2))
	_power_label.text = "MINION CHASSIS // POWER: %d" % pwr

	# Neural Sync Telemetry
	var comm: float = float(GameState.minion_skills.get("communication", 0.0))
	var acc: float = MinionSystem.get_accuracy() * 100.0
	var rnd: float = 100.0 - acc
	var tier := MinionSystem.get_signal_tier()

	_telemetry_label.text = "[ %s ] Target Harvest: %.1f%%  |  Random Scavenge: %.1f%%" % [
		tier["tier"].to_upper(),
		acc,
		rnd
	]
	_telemetry_label.add_theme_color_override("font_color", tier["color"])

	# Gather Type button & tile
	var target_id: String = GameState.minion_gather_target
	if target_id == "":
		_gather_btn.text = "[ ANY FIELD SCRAP ]"
		if _gather_tile_sub:
			_gather_tile_sub.text = "[ ANY SCRAP ]"
			_gather_tile_sub.add_theme_color_override("font_color", Color("bfb7aa"))
	else:
		var def := InventoryManager.get_def(target_id)
		var t_name: String = def.get("name", target_id).to_upper()
		var glyph: String = def.get("glyph", "")
		_gather_btn.text = "[ %s %s ]" % [glyph, t_name]
		if _gather_tile_sub:
			_gather_tile_sub.text = "%s %s" % [glyph, t_name]
			_gather_tile_sub.add_theme_color_override("font_color", Color("f59e0b"))

	# Cargo Pod button & tile
	if MinionSystem.cargo_pod == null:
		_pod_btn.text = "[ EMPTY ] TAP TO EQUIP"
		if _fist_tile_sub:
			_fist_tile_sub.text = "Unarmed Harvester"
			_fist_tile_sub.add_theme_color_override("font_color", Color("bfb7aa"))
	else:
		var pod_def := InventoryManager.get_def(MinionSystem.cargo_pod["id"])
		var pod_name: String = pod_def.get("name", "Cargo Pod").to_upper()
		var cap := MinionSystem.pod_capacity()
		_pod_btn.text = "[ %s x%d ]" % [pod_name, cap]
		if _fist_tile_sub:
			_fist_tile_sub.text = "Pod Cap: %d" % cap
			_fist_tile_sub.add_theme_color_override("font_color", Color("70ff8b"))


func _on_gather_cycle_pressed() -> void:
	MinionSystem.cycle_gather_target()
	_refresh()
	var tid: String = GameState.minion_gather_target
	var tname: String = "Any Field Scrap" if tid == "" else InventoryManager.get_def(tid).get("name", tid)
	_detail_label.text = "Gather Directive updated: Targeting '%s'. Hit chance: %.1f%%." % [
		tname,
		MinionSystem.get_accuracy() * 100.0
	]


func _on_pod_pressed() -> void:
	MinionSystem.toggle_cargo_pod()
	_refresh()


func _make_slot_tile(slot_name: String, item_name: String, sub_text: String, sub_color: Color, desc: String, is_action: bool) -> PanelContainer:
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(190, 150)
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	var sb := StyleBoxFlat.new()
	sb.bg_color = Color("3d3429") if not is_action else Color("4d3e2d")
	sb.set_border_width_all(3)
	sb.border_color = Color("574b3d")
	sb.set_corner_radius_all(10)
	sb.content_margin_left = 8
	sb.content_margin_right = 8
	sb.content_margin_top = 10
	sb.content_margin_bottom = 10
	panel.add_theme_stylebox_override("panel", sb)

	var btn := Button.new()
	btn.focus_mode = Control.FOCUS_NONE
	btn.set_anchors_preset(Control.PRESET_FULL_RECT)
	btn.flat = true
	btn.mouse_filter = Control.MOUSE_FILTER_PASS
	btn.pressed.connect(func() -> void:
		_detail_label.text = "[ %s ] %s: %s" % [slot_name, item_name, desc]
	)
	panel.add_child(btn)

	var v := VBoxContainer.new()
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
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

	return panel


func _make_gather_type_tile(slot: Dictionary) -> PanelContainer:
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(190, 150)
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	var sb := StyleBoxFlat.new()
	sb.bg_color = Color("453422")
	sb.set_border_width_all(3)
	sb.border_color = Color("d97724")
	sb.set_corner_radius_all(10)
	sb.content_margin_left = 8
	sb.content_margin_right = 8
	sb.content_margin_top = 10
	sb.content_margin_bottom = 10
	panel.add_theme_stylebox_override("panel", sb)

	var btn := Button.new()
	btn.focus_mode = Control.FOCUS_NONE
	btn.set_anchors_preset(Control.PRESET_FULL_RECT)
	btn.flat = true
	btn.mouse_filter = Control.MOUSE_FILTER_PASS
	btn.pressed.connect(_on_gather_cycle_pressed)
	panel.add_child(btn)

	var v := VBoxContainer.new()
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(v)

	var title := Label.new()
	title.text = "[ GATHER TYPE ]"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 20)
	title.add_theme_color_override("font_color", Color("f59e0b"))
	v.add_child(title)

	var item := Label.new()
	item.text = "Directive Filter"
	item.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	item.add_theme_font_size_override("font_size", 18)
	item.add_theme_color_override("font_color", Color("faecd8"))
	v.add_child(item)

	_gather_tile_sub = Label.new()
	_gather_tile_sub.text = "[ ANY SCRAP ]"
	_gather_tile_sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_gather_tile_sub.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_gather_tile_sub.add_theme_font_size_override("font_size", 18)
	_gather_tile_sub.add_theme_color_override("font_color", Color("bfb7aa"))
	v.add_child(_gather_tile_sub)

	return panel


func _make_fist_tile(slot: Dictionary) -> PanelContainer:
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(190, 150)
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	var sb := StyleBoxFlat.new()
	sb.bg_color = Color("383228")
	sb.set_border_width_all(3)
	sb.border_color = Color("574b3d")
	sb.set_corner_radius_all(10)
	sb.content_margin_left = 8
	sb.content_margin_right = 8
	sb.content_margin_top = 10
	sb.content_margin_bottom = 10
	panel.add_theme_stylebox_override("panel", sb)

	var btn := Button.new()
	btn.focus_mode = Control.FOCUS_NONE
	btn.set_anchors_preset(Control.PRESET_FULL_RECT)
	btn.flat = true
	btn.mouse_filter = Control.MOUSE_FILTER_PASS
	btn.pressed.connect(func() -> void:
		_detail_label.text = "[ MINION FIST ] Unarmed harvest mount / Tool hardpoint. When Cargo Pod is equipped, drone can be dispatched on autonomous runs."
	)
	panel.add_child(btn)

	var v := VBoxContainer.new()
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(v)

	var title := Label.new()
	title.text = "[ MINION FIST ]"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 20)
	title.add_theme_color_override("font_color", Color("faecd8"))
	v.add_child(title)

	var item := Label.new()
	item.text = "Harvester Mount"
	item.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	item.add_theme_font_size_override("font_size", 18)
	item.add_theme_color_override("font_color", Color("bfb7aa"))
	v.add_child(item)

	_fist_tile_sub = Label.new()
	_fist_tile_sub.text = "Unarmed"
	_fist_tile_sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_fist_tile_sub.add_theme_font_size_override("font_size", 18)
	_fist_tile_sub.add_theme_color_override("font_color", Color("bfb7aa"))
	v.add_child(_fist_tile_sub)

	return panel
