extends VBoxContainer
## Master Fabricator Console: Mission logs, undiscovered blueprint hints, and discipline tree teaching.


func _ready() -> void:
	add_theme_constant_override("separation", 14)

	add_child(UIRows.heading("AI HOLOGRAM CONSOLE // SENIOR ENGINEER"))
	add_child(UIRows.row("Operational Status", "Online / Synchronized", Color("70ff8b")))

	# 1. Mission Logs & Current Directive
	add_child(UIRows.heading("MISSION LOGS // CURRENT DIRECTIVE"))
	if QuestManager.is_finished():
		add_child(UIRows.row("Directives Complete", "Citadel Colony operational", Color("70ff8b")))
	else:
		var q := QuestManager.current()
		var right := ""
		if q["type"] == "scavenge":
			right = "%d / %d" % [QuestManager.progress, int(q["target"])]
		add_child(UIRows.row("%s: %s" % [q["title"], q["task"]], right, Color("f59e0b")))
		add_child(UIRows.heading("BLUEPRINT SYNTHESIS HINT"))
		add_child(UIRows.row("Data Decryption", String(q.get("hint", "No blueprint hint available.")), Color("fff3e0")))

	# 2. Discipline Tree Teaching & Progression
	var total_lvl := GameState.get_total_level()
	add_child(UIRows.heading("DISCIPLINE TREE ADVANCEMENT (TEACHING)"))
	add_child(UIRows.row("Overall Fabricator Level", "Rank %d (Total Disciplines)" % total_lvl, Color("f59e0b")))

	for tree in GameState.skills_def.get("protag", []):
		var req: int = int(tree.get("unlock_level", 0))
		var tree_name: String = tree["name"]
		var current_pts: float = GameState.skills.get(tree["key"], 0.0)
		var current_lvl := GameState.get_level(current_pts)
		if total_lvl >= req:
			add_child(UIRows.row(tree_name, "UNLOCKED (Lv %d)" % current_lvl, Color("70ff8b")))
		else:
			add_child(UIRows.row(tree_name, "LOCKED (Requires Overall Lv %d)" % req, Color("bfb7aa")))

	# 3. Completed Mission Log History
	if QuestManager.current_index > 0:
		add_child(UIRows.heading("HISTORICAL ARCHIVE // CLEARED"))
		for i in QuestManager.current_index:
			add_child(UIRows.row(String(QuestManager.quests[i]["title"]), "VERIFIED", Color("70ff8b")))

	# 4. Blueprint Archives & Recipe Guide
	add_child(UIRows.heading("BLUEPRINT ARCHIVES // CRAFTING RECIPES"))
	var recipes: Array = CraftingSystem.recipes
	for r in recipes:
		var recipe_panel := _build_recipe_row(r)
		add_child(recipe_panel)

	# 5. Item Encyclopedia & Materiel Directory
	add_child(UIRows.heading("COLONY MATERIEL DIRECTORY // ITEM CATALOG"))
	var items_def: Dictionary = InventoryManager._defs
	for item_id in items_def:
		var item_panel := _build_item_row(item_id, items_def[item_id])
		add_child(item_panel)


func _build_recipe_row(recipe: Dictionary) -> PanelContainer:
	var panel := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color("463f33")
	sb.set_corner_radius_all(12)
	sb.content_margin_left = 20
	sb.content_margin_right = 20
	sb.content_margin_top = 16
	sb.content_margin_bottom = 16
	panel.add_theme_stylebox_override("panel", sb)

	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 8)
	panel.add_child(v)

	var title_lbl := Label.new()
	var out_id: String = recipe.get("output_item", "")
	var out_def: Dictionary = InventoryManager.get_def(out_id)
	var out_name: String = out_def.get("name", recipe.get("name", out_id))
	var out_glyph: String = out_def.get("glyph", "📦")
	var out_qty: int = int(recipe.get("output_qty", 1))
	var discipline: String = recipe.get("discipline", "")
	var level_req: int = int(recipe.get("level_req", 0))

	title_lbl.text = "%s %s (Yield: %dx)" % [out_glyph, out_name, out_qty]
	title_lbl.add_theme_font_size_override("font_size", 30)
	title_lbl.add_theme_color_override("font_color", Color("f59e0b"))
	v.add_child(title_lbl)

	# Inputs row with glyphs and names
	var inputs_list: Array = []
	for in_id in recipe.get("inputs", []):
		var in_def: Dictionary = InventoryManager.get_def(in_id)
		var glyph: String = in_def.get("glyph", "•")
		var name: String = in_def.get("name", in_id)
		inputs_list.append("%s %s" % [glyph, name])

	var tool_id: String = recipe.get("tool", "")
	var tool_str := ""
	if tool_id != "":
		var tool_def: Dictionary = InventoryManager.get_def(tool_id)
		tool_str = "  |  Tool: %s %s" % [tool_def.get("glyph", "🔧"), tool_def.get("name", tool_id)]

	var inputs_lbl := Label.new()
	inputs_lbl.text = "Inputs: %s%s" % [", ".join(inputs_list), tool_str]
	inputs_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	inputs_lbl.add_theme_font_size_override("font_size", 24)
	inputs_lbl.add_theme_color_override("font_color", Color("f8ecd8"))
	v.add_child(inputs_lbl)

	var disc_lbl := Label.new()
	disc_lbl.text = "Req: %s (Lv %d)" % [discipline, level_req]
	disc_lbl.add_theme_font_size_override("font_size", 22)
	disc_lbl.add_theme_color_override("font_color", Color("bfb7aa"))
	v.add_child(disc_lbl)

	return panel


func _build_item_row(item_id: String, def: Dictionary) -> PanelContainer:
	var panel := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color("383228")
	sb.set_corner_radius_all(12)
	sb.content_margin_left = 20
	sb.content_margin_right = 20
	sb.content_margin_top = 14
	sb.content_margin_bottom = 14
	panel.add_theme_stylebox_override("panel", sb)

	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 16)
	panel.add_child(h)

	var glyph_box := PanelContainer.new()
	var gsb := StyleBoxFlat.new()
	gsb.bg_color = Color("2b251d")
	gsb.set_corner_radius_all(10)
	gsb.content_margin_left = 12
	gsb.content_margin_right = 12
	gsb.content_margin_top = 8
	gsb.content_margin_bottom = 8
	glyph_box.add_theme_stylebox_override("panel", gsb)
	var glyph_lbl := Label.new()
	glyph_lbl.text = def.get("glyph", "📦")
	glyph_lbl.add_theme_font_size_override("font_size", 44)
	glyph_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	glyph_box.add_child(glyph_lbl)
	h.add_child(glyph_box)

	var v := VBoxContainer.new()
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	v.add_theme_constant_override("separation", 4)
	h.add_child(v)

	var name_lbl := Label.new()
	name_lbl.text = def.get("name", item_id)
	name_lbl.add_theme_font_size_override("font_size", 28)
	name_lbl.add_theme_color_override("font_color", Color("faecd8"))
	v.add_child(name_lbl)

	var sub_parts: Array = []
	var type: String = def.get("type", "material").capitalize()
	sub_parts.append("Type: %s" % type)
	if def.has("energy_value"):
		sub_parts.append("Restores: +%d EN (Food)" % int(def["energy_value"]))
	if def.has("max_durability"):
		sub_parts.append("Durability: %d" % int(def["max_durability"]))
	if def.has("capacity"):
		sub_parts.append("Capacity: %d Slots" % int(def["capacity"]))

	var desc_lbl := Label.new()
	desc_lbl.text = " • ".join(sub_parts)
	desc_lbl.add_theme_font_size_override("font_size", 22)
	desc_lbl.add_theme_color_override("font_color", Color("70ff8b") if def.has("energy_value") else Color("bfb7aa"))
	v.add_child(desc_lbl)

	return panel

