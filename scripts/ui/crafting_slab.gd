class_name CraftingSlab
extends PanelContainer
## 3 input slots + orange-bordered tool slot + Craft button. Pure view over CraftingSystem.

const ITEM_SLOT := preload("res://scenes/components/item_slot.tscn")

var _inputs: Array[SlotView] = []
var _tool: SlotView
var _craft_btn: Button


func _ready() -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)

	for i in CraftingSystem.INPUT_COUNT:
		var slot: SlotView = ITEM_SLOT.instantiate()
		slot.bench_input_slot_index = i
		slot.pressed.connect(CraftingSystem.return_input.bind(i))
		# Matching prototype: orange-bordered rounded slots for bench inputs
		slot.add_theme_stylebox_override("normal", _box(Color("0c344d", 0.8), Color("f97316"), 4, 18))
		slot.add_theme_stylebox_override("hover", _box(Color("134e6f", 0.9), Color("fb923c"), 4, 18))
		slot.add_theme_stylebox_override("pressed", _box(Color("082538", 1.0), Color("ea580c"), 4, 18))
		row.add_child(slot)
		_inputs.append(slot)

	_tool = ITEM_SLOT.instantiate()
	_tool.is_bench_tool_slot = true
	# Tool slot with gear/tool icon theme & cyan border
	_tool.add_theme_stylebox_override("normal", _box(Color("082e46", 0.85), Color("38bdf8"), 4, 18))
	_tool.add_theme_stylebox_override("hover", _box(Color("0c4467", 0.95), Color("7dd3fc"), 4, 18))
	_tool.add_theme_stylebox_override("pressed", _box(Color("062031", 1.0), Color("0284c7"), 4, 18))
	_tool.pressed.connect(CraftingSystem.return_tool)
	row.add_child(_tool)

	_craft_btn = Button.new()
	_craft_btn.text = "Construct"
	_craft_btn.custom_minimum_size = Vector2(0, 160)
	_craft_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_craft_btn.focus_mode = Control.FOCUS_NONE
	_craft_btn.add_theme_font_size_override("font_size", 44)
	# Matching prototype: vibrant teal/cyan Construct button
	_craft_btn.add_theme_stylebox_override("normal", _box(Color("0284c7"), Color("38bdf8"), 4, 20))
	_craft_btn.add_theme_stylebox_override("hover", _box(Color("0369a1"), Color("7dd3fc"), 4, 20))
	_craft_btn.add_theme_stylebox_override("pressed", _box(Color("075985"), Color("0284c7"), 4, 20))
	_craft_btn.add_theme_stylebox_override("disabled", _box(Color("0c2738"), Color("1e4a68"), 3, 20))
	_craft_btn.pressed.connect(CraftingSystem.craft_active_recipe)
	row.add_child(_craft_btn)

	add_child(row)

	# Main slab panel matching prototype: rounded teal metallic enclosure with orange highlight accent
	var slab := _box(Color("164e63", 0.94), Color("38bdf8"), 5, 28)
	slab.set_content_margin_all(22)
	slab.shadow_color = Color("0284c7", 0.6)
	slab.shadow_size = 12
	add_theme_stylebox_override("panel", slab)




	CraftingSystem.bench_updated.connect(refresh)
	refresh()


func refresh() -> void:
	for i in _inputs.size():
		_inputs[i].set_item(CraftingSystem.bench_inputs[i])
	_tool.set_item(CraftingSystem.bench_tool)
	var can := CraftingSystem.can_craft()
	_craft_btn.disabled = not can
	if can:
		var max_batches: int = 999999
		for i in CraftingSystem.INPUT_COUNT:
			if CraftingSystem.bench_inputs[i] != null:
				max_batches = mini(max_batches, int(CraftingSystem.bench_inputs[i].get("qty", 1)))
		if CraftingSystem.bench_tool != null:
			max_batches = mini(max_batches, int(CraftingSystem.bench_tool.get("durability", 1)))
		var max_by_energy: int = int(GameState.protag_energy / CraftingSystem.ENERGY_COST)
		max_batches = mini(max_batches, max_by_energy)

		var single_out_qty: int = int(CraftingSystem.active_match.get("output_qty", 1))
		var chance := CraftingSystem.get_active_success_chance()
		var count_str := ""
		if max_batches > 1:
			count_str = " (x%d)" % (max_batches * single_out_qty)

		if chance < 1.0:
			_craft_btn.text = "Construct%s (%d%%)" % [count_str, int(chance * 100.0)]
		else:
			_craft_btn.text = "Construct%s" % count_str
	else:
		_craft_btn.text = "Construct"


func _box(fill: Color, border: Color, border_w: int = 4, radius: int = 16) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = fill
	sb.set_border_width_all(border_w)
	sb.border_color = border
	sb.set_corner_radius_all(radius)
	return sb

