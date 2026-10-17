class_name ModalRecipeLedger
extends VBoxContainer
## Sub-Menu: Blueprint Success Calibration (Recipe Ledger for selected discipline).

static var selected_discipline: String = "mealPrep"
static var selected_discipline_name: String = "Bio-Nutrient Synthesis"


func _ready() -> void:
	add_theme_constant_override("separation", 14)

	var back_btn := UIRows.action_button("← BACK TO SKILLS")
	back_btn.custom_minimum_size = Vector2(360, 72)
	back_btn.pressed.connect(func() -> void: GameState.modal_requested.emit("protag_skills"))
	add_child(back_btn)

	var eff := GameState.get_effective_skill(selected_discipline)
	var base: float = GameState.skills.get(selected_discipline, 0.0)
	var mod_str := "+%.1f" % GameState.glove_modifier if GameState.glove_modifier >= 0 else "%.1f" % GameState.glove_modifier

	add_child(UIRows.heading("BLUEPRINT SUCCESS CALIBRATION // %s" % selected_discipline_name.to_upper()))
	add_child(UIRows.row("Effective Skill Rating", "%.1f (Base %.1f, Glove %s)" % [eff, base, mod_str], Color("f59e0b")))
	add_child(UIRows.heading("CALIBRATION FORMULA: 50% + (Effective - Req) x 2%"))

	# Load recipes matching this discipline
	var f := FileAccess.open("res://data/recipes.json", FileAccess.READ)
	var found := 0
	if f != null:
		var parsed: Variant = JSON.parse_string(f.get_as_text())
		if parsed is Array:
			for r in parsed:
				if r.get("discipline", "") == selected_discipline:
					found += 1
					_add_recipe_row(r, eff)

	if found == 0:
		add_child(UIRows.row("Blueprint Archive", "No blueprints synthesized yet.", Color("bfb7aa")))

	add_child(UIRows.heading("THE FAIL-TO-LEARN PARADOX"))
	add_child(UIRows.row("Training Protocol", "Recipes below 100% success still grant full XP on failure! Use negative gloves to grind XP safely.", Color("70ff8b")))


func _add_recipe_row(recipe: Dictionary, eff_skill: float) -> void:
	var req: float = float(recipe.get("level_req", 0))
	var chance := clampf(0.50 + (eff_skill - req) * 0.02, 0.0, 1.0)
	var chance_pct := int(round(chance * 100.0))

	var color: Color
	var tag := ""
	if chance_pct >= 100:
		color = Color("70ff8b") # Green
		tag = "100% [OPTIMAL]"
	elif chance_pct >= 70:
		color = Color("f59e0b") # Amber
		tag = "%d%% [FAIL-TO-LEARN]" % chance_pct
	elif chance_pct > 0:
		color = Color("d97724") # Orange
		tag = "%d%% [HIGH RISK]" % chance_pct
	else:
		color = Color("e74c3c") # Red
		tag = "0% [INSUFFICIENT]"

	var r_name: String = recipe.get("name", recipe["id"])
	var inputs: Array = recipe.get("inputs", [])
	var input_costs: Dictionary = recipe.get("input_costs", {})
	var tool_id: String = recipe.get("tool", "")
	var out_qty: int = int(recipe.get("output_qty", 1))

	var mat_names: PackedStringArray = []
	for in_id in inputs:
		var cost: int = int(input_costs.get(in_id, 1))
		var in_name: String = InventoryManager.get_def(in_id).get("name", in_id)
		if cost > 1:
			mat_names.append("%dx %s" % [cost, in_name])
		else:
			mat_names.append(in_name)

	if tool_id != "":
		mat_names.append("Tool: %s" % InventoryManager.get_def(tool_id).get("name", tool_id))

	var yield_str := " (Yields %dx)" % out_qty if out_qty > 1 else ""
	var details := "Req: Lv %.0f | %s%s\nInputs: %s" % [req, tag, yield_str, ", ".join(mat_names)]
	var row := UIRows.row(r_name, details, color)
	add_child(row)
