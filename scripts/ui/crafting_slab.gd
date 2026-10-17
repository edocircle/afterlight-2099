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
		# Matching prototype: orange-framed slots for bench inputs
		for state in ["normal", "hover", "pressed"]:
			slot.add_theme_stylebox_override(state, UiFrames.bench_slot(state))
		row.add_child(slot)
		_inputs.append(slot)

	_tool = ITEM_SLOT.instantiate()
	_tool.is_bench_tool_slot = true
	# Tool slot: same orange frame as the prototype's gear slot
	for state in ["normal", "hover", "pressed"]:
		_tool.add_theme_stylebox_override(state, UiFrames.bench_slot(state))
	_tool.pressed.connect(CraftingSystem.return_tool)
	row.add_child(_tool)

	_craft_btn = Button.new()
	_craft_btn.text = "Construct"
	_craft_btn.custom_minimum_size = Vector2(200, 160)
	_craft_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_craft_btn.focus_mode = Control.FOCUS_NONE
	_craft_btn.add_theme_font_size_override("font_size", 40)

	# Matching prototype: dark teal Construct button with glowing cyan frame
	for state in ["normal", "hover", "pressed", "disabled"]:
		_craft_btn.add_theme_stylebox_override(state, UiFrames.action_button(state))
	_craft_btn.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	_craft_btn.add_theme_color_override("font_color", Color("e6fbff"))
	_craft_btn.add_theme_color_override("font_hover_color", Color.WHITE)
	_craft_btn.add_theme_color_override("font_pressed_color", Color("b9f4fc"))
	_craft_btn.add_theme_color_override("font_disabled_color", Color("4a7a90"))
	_craft_btn.add_theme_color_override("font_outline_color", Color("0369a1"))
	_craft_btn.add_theme_constant_override("outline_size", 6)
	_craft_btn.pressed.connect(CraftingSystem.craft_active_recipe)
	row.add_child(_craft_btn)

	add_child(row)

	# Main slab panel matching prototype: steel enclosure with orange-lined inner recess
	add_theme_stylebox_override("panel", UiFrames.slab(28))




	CraftingSystem.bench_updated.connect(refresh)
	refresh()


func refresh() -> void:
	for i in _inputs.size():
		_inputs[i].set_item(CraftingSystem.bench_inputs[i])
	_tool.set_item(CraftingSystem.bench_tool)
	var can := CraftingSystem.can_craft()
	_craft_btn.disabled = not can
	_craft_btn.text = "Construct"



func _box(fill: Color, border: Color, border_w: int = 4, radius: int = 16) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = fill
	sb.set_border_width_all(border_w)
	sb.border_color = border
	sb.set_corner_radius_all(radius)
	return sb

