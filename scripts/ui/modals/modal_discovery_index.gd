class_name ModalDiscoveryIndex
extends VBoxContainer
## Material Discovery Index / Silhouette Ledger for Drone Subsystems.
## Unlocked Items: Displays recognized icon, min skill needed, required catalyst/bait.
## Locked Tiers: Unmet requirements display a dark black silhouette with ??? under Skill Needed.
## Skill Growth: Incremental harvesting increases skill, turning silhouettes into recognized blueprints.

static var selected_discipline: String = "scavenging"
static var selected_discipline_name: String = "Surface Scavenging"
static var selected_code: String = "B"

const INDEX_PATH := "res://data/minion_discovery_index.json"


func _ready() -> void:
	add_theme_constant_override("separation", 14)

	# Back button to Drone Subsystems
	var back_btn := UIRows.action_button("← BACK TO DRONE SUBSYSTEMS")
	back_btn.custom_minimum_size = Vector2(400, 72)
	back_btn.pressed.connect(func() -> void: GameState.modal_requested.emit("minion_skills"))
	add_child(back_btn)

	var current_skill: float = float(GameState.minion_skills.get(selected_discipline, 0.0))

	# Header Banner
	var head_panel := PanelContainer.new()
	var h_sb := StyleBoxFlat.new()
	h_sb.bg_color = Color("463f33")
	h_sb.set_corner_radius_all(12)
	h_sb.content_margin_left = 20
	h_sb.content_margin_right = 20
	h_sb.content_margin_top = 16
	h_sb.content_margin_bottom = 16
	head_panel.add_theme_stylebox_override("panel", h_sb)
	add_child(head_panel)

	var h_box := HBoxContainer.new()
	h_box.add_theme_constant_override("separation", 16)
	head_panel.add_child(h_box)

	var h_title := Label.new()
	h_title.text = "[%s] %s" % [selected_code, selected_discipline_name.to_upper()]
	h_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h_title.add_theme_font_size_override("font_size", 30)
	h_title.add_theme_color_override("font_color", Color("fff3e0"))
	h_box.add_child(h_title)

	var h_pts := Label.new()
	h_pts.text = "SKILL: %.1f" % current_skill
	h_pts.add_theme_font_size_override("font_size", 30)
	h_pts.add_theme_color_override("font_color", Color("f59e0b"))
	h_box.add_child(h_pts)

	# Category Description Note
	var desc_str := _get_discipline_description(selected_discipline)
	if desc_str != "":
		add_child(UIRows.row("Discipline Protocol", desc_str, Color("bfb7aa")))

	add_child(UIRows.heading("MATERIAL DISCOVERY INDEX (SILHOUETTE LEDGER)"))

	# Load discovery items from JSON
	var f := FileAccess.open(INDEX_PATH, FileAccess.READ)
	var items: Array = []
	if f != null:
		var parsed: Variant = JSON.parse_string(f.get_as_text())
		if parsed is Dictionary and parsed.has(selected_discipline):
			items = parsed[selected_discipline]

	if items.is_empty():
		add_child(UIRows.row("Archive Status", "No discovery blueprints indexed for this subsystem.", Color("bfb7aa")))
	else:
		for entry in items:
			var req: float = float(entry.get("req_skill", 0.0))
			var unlocked: bool = current_skill >= req
			_render_entry_card(entry, unlocked)

	add_child(UIRows.heading("SKILL GROWTH & BLUEPRINT RECOGNITION"))
	add_child(UIRows.row(
		"Progression Protocol",
		"As the drone completes harvesting actions in this category, its skill increases incrementally (+0.1), turning dark silhouettes into recognized blueprints.",
		Color("70ff8b")
	))


func _render_entry_card(entry: Dictionary, unlocked: bool) -> void:
	var panel := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.set_corner_radius_all(14)
	sb.content_margin_left = 20
	sb.content_margin_right = 20
	sb.content_margin_top = 16
	sb.content_margin_bottom = 16

	if unlocked:
		sb.bg_color = Color("463f33")
		sb.set_border_width_all(2)
		sb.border_color = Color("8c8275")
	else:
		# Dark black silhouette styling
		sb.bg_color = Color("1a1714")
		sb.set_border_width_all(2)
		sb.border_color = Color("2e2720")

	panel.add_theme_stylebox_override("panel", sb)
	add_child(panel)

	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 20)
	panel.add_child(h)

	# Icon / Silhouette Glyph
	var icon_lbl := Label.new()
	icon_lbl.custom_minimum_size = Vector2(90, 90)
	icon_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	icon_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	icon_lbl.add_theme_font_size_override("font_size", 48)

	if unlocked:
		icon_lbl.text = entry.get("glyph", "📦")
	else:
		# Dark black silhouette
		icon_lbl.text = "⬛"
		icon_lbl.add_theme_color_override("font_color", Color("000000"))

	h.add_child(icon_lbl)

	# Info column
	var info_col := VBoxContainer.new()
	info_col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info_col.add_theme_constant_override("separation", 4)
	h.add_child(info_col)

	var title_row := HBoxContainer.new()
	info_col.add_child(title_row)

	var title := Label.new()
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.add_theme_font_size_override("font_size", 28)

	var tag := Label.new()
	tag.add_theme_font_size_override("font_size", 22)

	if unlocked:
		title.text = entry.get("name", "Unknown Material")
		title.add_theme_color_override("font_color", Color("fff3e0"))
		tag.text = "[RECOGNIZED]"
		tag.add_theme_color_override("font_color", Color("70ff8b"))
	else:
		title.text = "??? [LOCKED SILHOUETTE]"
		title.add_theme_color_override("font_color", Color("bfb7aa"))
		tag.text = "[LOCKED TIER]"
		tag.add_theme_color_override("font_color", Color("e74c3c"))

	title_row.add_child(title)
	title_row.add_child(tag)

	# Subtitle / Requirements
	var req_lbl := Label.new()
	req_lbl.add_theme_font_size_override("font_size", 22)

	var desc_lbl := Label.new()
	desc_lbl.add_theme_font_size_override("font_size", 20)
	desc_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART

	if unlocked:
		var req_val: float = float(entry.get("req_skill", 0.0))
		var catalyst: String = entry.get("catalyst", "None")
		req_lbl.text = "Skill Needed: %.1f | Catalyst/Bait: %s" % [req_val, catalyst]
		req_lbl.add_theme_color_override("font_color", Color("f59e0b"))
		desc_lbl.text = entry.get("desc", "")
		desc_lbl.add_theme_color_override("font_color", Color("bfb7aa"))
	else:
		req_lbl.text = "Skill Needed: ??? | Catalyst/Bait: ???"
		req_lbl.add_theme_color_override("font_color", Color("5a5245"))
		desc_lbl.text = "Telemetry signal encrypted. Requires higher %s skill to decode silhouette." % selected_discipline_name
		desc_lbl.add_theme_color_override("font_color", Color("5a5245"))

	info_col.add_child(req_lbl)
	info_col.add_child(desc_lbl)

	# If unlocked and it's a gatherable material, provide button to set gather target!
	var item_id: String = entry.get("id", "")
	if unlocked and item_id != "" and selected_discipline != "communication":
		var act_btn := Button.new()
		act_btn.focus_mode = Control.FOCUS_NONE
		act_btn.custom_minimum_size = Vector2(180, 52)
		act_btn.add_theme_font_size_override("font_size", 20)

		var is_target := GameState.minion_gather_target == item_id
		if is_target:
			act_btn.text = "TARGET LOCK"
			act_btn.add_theme_color_override("font_color", Color("f59e0b"))
		else:
			act_btn.text = "SET TARGET"
			act_btn.pressed.connect(func() -> void:
				MinionSystem.set_gather_target(item_id)
				GameState.toast_requested.emit("Target directive set: %s" % entry.get("name", item_id))
				GameState.modal_requested.emit("discovery_index")
			)
		h.add_child(act_btn)


func _get_discipline_description(disc: String) -> String:
	match disc:
		"scavenging":
			return "Surface Scavenging yields baseline materials: Flora, Raw Minerals, Poly-Berries, and Resonant Crystals."
		"lumber":
			return "Core Pylon Salvage dismantles pylons, structural pillars, and composite logs."
		"hunting":
			return "Bio-Specimen Extraction traps and salvages cyber-fauna for pelts, chitin spikes, and polymer tendons."
		"fishing":
			return "Aquatic Harvesting extracts deep-water biomass, requiring bait inputs and energy."
		"communication":
			return "Neural Sync dictates directive adherence and targeting accuracy across all operations."
	return ""
