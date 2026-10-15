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
		slot.pressed.connect(CraftingSystem.return_input.bind(i))
		row.add_child(slot)
		_inputs.append(slot)

	_tool = ITEM_SLOT.instantiate()
	_tool.add_theme_stylebox_override("normal", _box(Color("47321e"), Color("d97724")))
	_tool.add_theme_stylebox_override("hover", _box(Color("47321e"), Color("f59e0b")))
	_tool.add_theme_stylebox_override("pressed", _box(Color("5a4026"), Color("f59e0b")))
	_tool.pressed.connect(CraftingSystem.return_tool)
	row.add_child(_tool)

	_craft_btn = Button.new()
	_craft_btn.text = "Craft"
	_craft_btn.custom_minimum_size = Vector2(0, 160)
	_craft_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_craft_btn.focus_mode = Control.FOCUS_NONE
	_craft_btn.add_theme_font_size_override("font_size", 48)
	_craft_btn.add_theme_stylebox_override("normal", _box(Color("d97724"), Color("542203")))
	_craft_btn.add_theme_stylebox_override("hover", _box(Color("f59e0b"), Color("542203")))
	_craft_btn.add_theme_stylebox_override("pressed", _box(Color("9b4105"), Color("542203")))
	_craft_btn.add_theme_stylebox_override("disabled", _box(Color("625c52"), Color("38332c")))
	_craft_btn.pressed.connect(CraftingSystem.craft_active_recipe)
	row.add_child(_craft_btn)

	add_child(row)

	var slab := _box(Color("7d7568"), Color("363127"))
	slab.set_content_margin_all(20)
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
		var chance := CraftingSystem.get_active_success_chance()
		if chance < 1.0:
			_craft_btn.text = "Craft (%d%%)" % int(chance * 100.0)
		else:
			_craft_btn.text = "Craft"
	else:
		_craft_btn.text = "Craft"


func _box(fill: Color, border: Color) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = fill
	sb.set_border_width_all(6)
	sb.border_color = border
	sb.set_corner_radius_all(16)
	return sb
