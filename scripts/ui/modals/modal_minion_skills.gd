class_name ModalMinionSkills
extends VBoxContainer
## Drone Subsystems Window:
## Displays the 5+1 subsystems with exact discipline codes:
## [B] Surface Scavenging   : 55.2
## [A] Core Pylon Salvage   : 29.6
## [H] Bio-Specimen Extraction: 20.7
## [F] Aquatic Harvesting   : 4.6
## [C] Neural Sync (Comm.)  : 58.8
## [?] [LOCKED SUBSYSTEM]   : ???
## Tapping any category opens the Material Discovery Index / Silhouette Ledger.

func _ready() -> void:
	add_theme_constant_override("separation", 12)

	# Telemetry Header Banner
	var head_row := HBoxContainer.new()
	add_child(head_row)

	var id_lbl := Label.new()
	id_lbl.text = "🤖 HELPER BOT // SCAVENGER-01"
	id_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	id_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	id_lbl.custom_minimum_size.x = 120
	id_lbl.add_theme_font_size_override("font_size", 26)
	id_lbl.add_theme_color_override("font_color", Color("f59e0b"))
	head_row.add_child(id_lbl)

	var pwr_lbl := Label.new()
	pwr_lbl.text = "CHASSIS POWER: 2"
	pwr_lbl.add_theme_font_size_override("font_size", 24)
	pwr_lbl.add_theme_color_override("font_color", Color("70ff8b"))
	head_row.add_child(pwr_lbl)

	add_child(UIRows.heading("DRONE GATHERING SUBSYSTEMS"))

	# Render the 5+1 subsystems table
	for def in GameState.skills_def.get("minion", []):
		var key: String = def["key"]
		var code: String = def.get("code", "?")
		var s_name: String = def["name"]
		var req_lvl: int = int(def.get("unlock_level", 0))

		if req_lvl > 0 and GameState.get_total_level() < req_lvl:
			# Locked Subsystem
			var locked_row := UIRows.row(
				"[%s] [LOCKED SUBSYSTEM]" % code,
				"??? (Unlocks at Colony Rank %d)" % req_lvl,
				Color("bfb7aa")
			)
			add_child(locked_row)
			continue

		var pts: float = float(GameState.minion_skills.get(key, 0.0))
		var left_txt := "[%s] %s" % [code, s_name]
		var right_txt := "%.1f" % pts

		var btn := _make_subsystem_row(left_txt, right_txt, key, s_name, code)
		add_child(btn)

	# Neural Sync & Targeting Mechanic Section
	add_child(UIRows.heading("NEURAL SYNC (COMMUNICATION) & TARGETING ACCURACY"))

	var comm_pts: float = float(GameState.minion_skills.get("communication", 0.0))
	var acc := MinionSystem.get_accuracy()
	var acc_pct := acc * 100.0
	var random_pct := 100.0 - acc_pct
	var tier_info := MinionSystem.get_signal_tier()

	var formula_row := UIRows.row(
		"Telemetry Uplink Status",
		"[%s] %s" % [tier_info["tier"].to_upper(), tier_info["range"]],
		tier_info["color"]
	)
	add_child(formula_row)

	var odds_str := "Target Lock: %.1f%%  |  Random Scrap: %.1f%%" % [acc_pct, random_pct]
	add_child(UIRows.row("Harvest Accuracy Odds", odds_str, Color("fff3e0")))

	add_child(UIRows.heading("MATERIAL DISCOVERY INDEX & SILHOUETTE LEDGER"))
	add_child(UIRows.row(
		"Silhouette Protocol",
		"Tap any gathering category above to review recognized material blueprints, minimum skill tiers, and dark silhouettes.",
		Color("70ff8b")
	))


func _make_subsystem_row(left: String, right: String, key: String, d_name: String, code: String) -> PanelContainer:
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
		ModalDiscoveryIndex.selected_discipline = key
		ModalDiscoveryIndex.selected_discipline_name = d_name
		ModalDiscoveryIndex.selected_code = code
		GameState.modal_requested.emit("discovery_index")
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
	r.add_theme_font_size_override("font_size", 30)
	r.add_theme_color_override("font_color", Color("f59e0b"))
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	h.add_child(r)

	return panel
