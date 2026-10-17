extends VBoxContainer
## Master Fabricator Console: Mission logs, undiscovered blueprint hints, and discipline tree teaching.
## Optimized for mobile: uses on-demand tab rendering to ensure instant 0ms pop-up with no lag.

var _tab_container: VBoxContainer
var _tab_buttons: Dictionary = {}
var _current_tab: String = "directives"
var _recipe_category: String = "mealPrep"
var _item_type_filter: String = "all"


func _ready() -> void:
	add_theme_constant_override("separation", 14)

	add_child(UIRows.heading("AI HOLOGRAM CONSOLE // SENIOR ENGINEER"))
	add_child(UIRows.row("Operational Status", "Online / Synchronized", Color("70ff8b")))

	# Top Navigation Tab Bar
	var nav_bar := HBoxContainer.new()
	nav_bar.add_theme_constant_override("separation", 8)
	add_child(nav_bar)

	var tabs := [
		["directives", "📜 DIRECTIVES"],
		["disciplines", "🧠 DISCIPLINES"],
		["blueprints", "📋 BLUEPRINTS"],
		["items", "📦 ITEM INDEX"]
	]

	for tab in tabs:
		var btn := Button.new()
		btn.text = tab[1]
		btn.focus_mode = Control.FOCUS_NONE
		btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		btn.custom_minimum_size = Vector2(0, 52)
		btn.add_theme_font_size_override("font_size", 20)
		btn.pressed.connect(_switch_tab.bind(tab[0]))
		nav_bar.add_child(btn)
		_tab_buttons[tab[0]] = btn

	_tab_container = VBoxContainer.new()
	_tab_container.add_theme_constant_override("separation", 12)
	add_child(_tab_container)

	_switch_tab("directives")


func _switch_tab(tab_name: String) -> void:
	_current_tab = tab_name
	_update_tab_buttons()
	_render_tab_content()


func _update_tab_buttons() -> void:
	for k: String in _tab_buttons:
		var btn: Button = _tab_buttons[k]
		var is_active: bool = (k == _current_tab)
		var sb := StyleBoxFlat.new()
		sb.set_corner_radius_all(10)
		sb.set_border_width_all(2)
		if is_active:
			sb.bg_color = Color("0284c7")
			sb.border_color = Color("38bdf8")
			btn.add_theme_color_override("font_color", Color.WHITE)
		else:
			sb.bg_color = Color("0f3b57", 0.6)
			sb.border_color = Color("164e63")
			btn.add_theme_color_override("font_color", Color("94a3b8"))
		btn.add_theme_stylebox_override("normal", sb)
		var h_sb := sb.duplicate()
		h_sb.bg_color = Color("0369a1")
		btn.add_theme_stylebox_override("hover", h_sb)


func _render_tab_content() -> void:
	for child in _tab_container.get_children():
		child.queue_free()

	match _current_tab:
		"directives":
			_render_directives()
		"disciplines":
			_render_disciplines()
		"blueprints":
			_render_blueprints()
		"items":
			_render_items()


# -------------------------------------------------------------
# TAB 1: MISSION DIRECTIVES & QUESTS
# -------------------------------------------------------------
func _render_directives() -> void:
	_tab_container.add_child(UIRows.heading("MISSION LOGS // CURRENT DIRECTIVE"))
	if QuestManager.is_finished():
		_tab_container.add_child(UIRows.row("Directives Complete", "Citadel Colony operational", Color("70ff8b")))
	else:
		var q := QuestManager.current()
		var right := ""
		if q["type"] == "scavenge":
			right = "%d / %d" % [QuestManager.progress, int(q["target"])]
		_tab_container.add_child(UIRows.row("%s: %s" % [q["title"], q["task"]], right, Color("f59e0b")))
		_tab_container.add_child(UIRows.heading("BLUEPRINT SYNTHESIS HINT"))
		_tab_container.add_child(UIRows.row("Data Decryption", String(q.get("hint", "No blueprint hint available.")), Color("fff3e0")))

	if QuestManager.current_index > 0:
		_tab_container.add_child(UIRows.heading("HISTORICAL ARCHIVE // CLEARED"))
		for i in QuestManager.current_index:
			_tab_container.add_child(UIRows.row(String(QuestManager.quests[i]["title"]), "VERIFIED", Color("70ff8b")))


# -------------------------------------------------------------
# TAB 2: DISCIPLINE ADVANCEMENT & MASTERY
# -------------------------------------------------------------
func _render_disciplines() -> void:
	var total_lvl := GameState.get_total_level()
	_tab_container.add_child(UIRows.heading("DISCIPLINE TREE ADVANCEMENT (TEACHING)"))
	_tab_container.add_child(UIRows.row("Overall Fabricator Level", "Rank %d (Total Disciplines)" % total_lvl, Color("f59e0b")))

	for tree in GameState.skills_def.get("protag", []):
		var req: int = int(tree.get("unlock_level", 0))
		var tree_name: String = tree["name"]
		var current_pts: float = GameState.skills.get(tree["key"], 0.0)
		var current_lvl := GameState.get_level(current_pts)
		if total_lvl >= req:
			_tab_container.add_child(UIRows.row(tree_name, "UNLOCKED (Lv %d)" % current_lvl, Color("70ff8b")))
		else:
			_tab_container.add_child(UIRows.row(tree_name, "LOCKED (Requires Overall Lv %d)" % req, Color("bfb7aa")))


# -------------------------------------------------------------
# TAB 3: BLUEPRINTS (Categorized per discipline for high performance)
# -------------------------------------------------------------
func _render_blueprints() -> void:
	_tab_container.add_child(UIRows.heading("BLUEPRINT ARCHIVES // CATEGORY FILTER"))

	var cat_scroll := ScrollContainer.new()
	cat_scroll.custom_minimum_size = Vector2(0, 56)
	cat_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	cat_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_tab_container.add_child(cat_scroll)

	var cat_row := HBoxContainer.new()
	cat_row.add_theme_constant_override("separation", 8)
	cat_scroll.add_child(cat_row)

	var categories := [
		["mealPrep", "Bio-Nutrient"],
		["toolCraft", "Kinetic"],
		["woodWork", "Structural"],
		["cooking", "Thermal Food"],
		["tailoring", "Textiles"],
		["pottery", "Sintering"],
		["construction", "Construction"],
		["engraving", "Engraving"]
	]

	for c in categories:
		var c_btn := Button.new()
		c_btn.text = c[1]
		c_btn.focus_mode = Control.FOCUS_NONE
		c_btn.custom_minimum_size = Vector2(130, 44)
		c_btn.add_theme_font_size_override("font_size", 18)
		var is_active: bool = (_recipe_category == c[0])
		var csb := StyleBoxFlat.new()
		csb.set_corner_radius_all(8)
		csb.bg_color = Color("0284c7") if is_active else Color("1e293b")
		csb.border_color = Color("38bdf8") if is_active else Color("334155")
		csb.set_border_width_all(2)
		c_btn.add_theme_stylebox_override("normal", csb)
		c_btn.pressed.connect(func() -> void:
			_recipe_category = c[0]
			_render_tab_content()
		)
		cat_row.add_child(c_btn)

	var found := 0
	for r in CraftingSystem.recipes:
		if r.get("discipline", "") == _recipe_category:
			found += 1
			_tab_container.add_child(_build_recipe_row(r))

	if found == 0:
		_tab_container.add_child(UIRows.row("Category Empty", "No blueprints recorded in this branch.", Color("bfb7aa")))


func _build_recipe_row(recipe: Dictionary) -> PanelContainer:
	var panel := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color("082e46", 0.85)
	sb.set_border_width_all(2)
	sb.border_color = Color("22d3ee")
	sb.set_corner_radius_all(12)
	sb.content_margin_left = 18
	sb.content_margin_right = 18
	sb.content_margin_top = 12
	sb.content_margin_bottom = 12
	panel.add_theme_stylebox_override("panel", sb)

	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 6)
	panel.add_child(v)

	var title_lbl := Label.new()
	var out_id: String = recipe.get("output_item", "")
	var out_def: Dictionary = InventoryManager.get_def(out_id)
	var out_name: String = out_def.get("name", recipe.get("name", out_id))
	var out_glyph: String = out_def.get("glyph", "📦")
	var out_qty: int = int(recipe.get("output_qty", 1))
	var level_req: int = int(recipe.get("level_req", 0))

	title_lbl.text = "%s %s (Yield: %dx)" % [out_glyph, out_name, out_qty]
	title_lbl.add_theme_font_size_override("font_size", 26)
	title_lbl.add_theme_color_override("font_color", Color("f59e0b"))
	v.add_child(title_lbl)

	var inputs_list: Array = []
	var input_costs: Dictionary = recipe.get("input_costs", {})
	for in_id in recipe.get("inputs", []):
		var in_def: Dictionary = InventoryManager.get_def(in_id)
		var glyph: String = in_def.get("glyph", "•")
		var name: String = in_def.get("name", in_id)
		var cost: int = int(input_costs.get(in_id, 1))
		if cost > 1:
			inputs_list.append("%s %dx %s" % [glyph, cost, name])
		else:
			inputs_list.append("%s %s" % [glyph, name])

	var tool_id: String = recipe.get("tool", "")
	var tool_str := ""
	if tool_id != "":
		var tool_def: Dictionary = InventoryManager.get_def(tool_id)
		tool_str = "  |  Tool: %s %s" % [tool_def.get("glyph", "🔧"), tool_def.get("name", tool_id)]

	var inputs_lbl := Label.new()
	inputs_lbl.text = "Inputs: %s%s" % [", ".join(inputs_list), tool_str]
	inputs_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	inputs_lbl.add_theme_font_size_override("font_size", 22)
	inputs_lbl.add_theme_color_override("font_color", Color("e0f2fe"))
	v.add_child(inputs_lbl)

	var disc_lbl := Label.new()
	disc_lbl.text = "Discipline Req: Level %d" % level_req
	disc_lbl.add_theme_font_size_override("font_size", 20)
	disc_lbl.add_theme_color_override("font_color", Color("38bdf8"))
	v.add_child(disc_lbl)

	return panel


# -------------------------------------------------------------
# TAB 4: ITEM INDEX (Filterable by Type for high performance)
# -------------------------------------------------------------
func _render_items() -> void:
	_tab_container.add_child(UIRows.heading("COLONY MATERIEL DIRECTORY // ITEM CATALOG"))

	var filter_row := HBoxContainer.new()
	filter_row.add_theme_constant_override("separation", 8)
	_tab_container.add_child(filter_row)

	var types := [
		["all", "All"],
		["food", "🍱 Food"],
		["tool", "🔧 Tools"],
		["material", "🪨 Materials"],
		["container", "📦 Bags"],
		["equipment", "🥋 Gear"]
	]

	for t in types:
		var t_btn := Button.new()
		t_btn.text = t[1]
		t_btn.focus_mode = Control.FOCUS_NONE
		t_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		t_btn.custom_minimum_size = Vector2(0, 44)
		t_btn.add_theme_font_size_override("font_size", 18)
		var is_active: bool = (_item_type_filter == t[0])
		var tsb := StyleBoxFlat.new()
		tsb.set_corner_radius_all(8)
		tsb.bg_color = Color("0284c7") if is_active else Color("1e293b")
		tsb.border_color = Color("38bdf8") if is_active else Color("334155")
		tsb.set_border_width_all(2)
		t_btn.add_theme_stylebox_override("normal", tsb)
		t_btn.pressed.connect(func() -> void:
			_item_type_filter = t[0]
			_render_tab_content()
		)
		filter_row.add_child(t_btn)

	var items_def: Dictionary = InventoryManager._defs
	var count := 0
	for item_id in items_def:
		var def: Dictionary = items_def[item_id]
		var item_type: String = def.get("type", "material")
		if _item_type_filter == "all" or item_type == _item_type_filter:
			_tab_container.add_child(_build_item_row(item_id, def))
			count += 1
			# Limit initial display in 'all' to avoid frame stutter
			if _item_type_filter == "all" and count >= 35:
				var more_lbl := Label.new()
				more_lbl.text = "... Use filter buttons above to browse all %d items." % items_def.size()
				more_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
				more_lbl.add_theme_font_size_override("font_size", 20)
				more_lbl.add_theme_color_override("font_color", Color("38bdf8"))
				_tab_container.add_child(more_lbl)
				break


func _build_item_row(item_id: String, def: Dictionary) -> PanelContainer:
	var panel := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color("082e46", 0.75)
	sb.set_border_width_all(2)
	sb.border_color = Color("1e4a68")
	sb.set_corner_radius_all(10)
	sb.content_margin_left = 16
	sb.content_margin_right = 16
	sb.content_margin_top = 10
	sb.content_margin_bottom = 10
	panel.add_theme_stylebox_override("panel", sb)

	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 14)
	panel.add_child(h)

	var glyph_box := PanelContainer.new()
	var gsb := StyleBoxFlat.new()
	gsb.bg_color = Color("041d2e")
	gsb.set_corner_radius_all(8)
	gsb.content_margin_left = 10
	gsb.content_margin_right = 10
	gsb.content_margin_top = 6
	gsb.content_margin_bottom = 6
	glyph_box.add_theme_stylebox_override("panel", gsb)
	var glyph_lbl := Label.new()
	glyph_lbl.text = def.get("glyph", "📦")
	glyph_lbl.add_theme_font_size_override("font_size", 38)
	glyph_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	glyph_box.add_child(glyph_lbl)
	h.add_child(glyph_box)

	var v := VBoxContainer.new()
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	v.add_theme_constant_override("separation", 4)
	h.add_child(v)

	var name_lbl := Label.new()
	name_lbl.text = def.get("name", item_id)
	name_lbl.add_theme_font_size_override("font_size", 24)
	name_lbl.add_theme_color_override("font_color", Color("e0f2fe"))
	v.add_child(name_lbl)

	var sub_parts: Array = []
	var type: String = def.get("type", "material").capitalize()
	sub_parts.append("Type: %s" % type)
	if def.has("energy_value"):
		sub_parts.append("Restores: +%d EN (Food)" % int(def["energy_value"]))
	if def.has("max_durability"):
		sub_parts.append("Durability: %d DP" % int(def["max_durability"]))
	if def.has("capacity"):
		sub_parts.append("Capacity: %d Slots" % int(def["capacity"]))

	var desc_lbl := Label.new()
	desc_lbl.text = " • ".join(sub_parts)
	desc_lbl.add_theme_font_size_override("font_size", 20)
	desc_lbl.add_theme_color_override("font_color", Color("70ff8b") if def.has("energy_value") else Color("38bdf8"))
	v.add_child(desc_lbl)

	return panel
