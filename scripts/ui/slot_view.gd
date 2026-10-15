class_name SlotView
extends Button
## Reusable inventory slot: glyph/icon, quantity badge (top-right), durability bar (bottom).

const SLOT_SIZE := Vector2(188, 188)

var slot_index: int = -1
var current_item: Variant = null


var _icon_label: Label
var _icon_tex: TextureRect
var _qty_label: Label
var _dur_label: Label
var _dur_bar: ProgressBar


func _init() -> void:
	custom_minimum_size = SLOT_SIZE
	focus_mode = Control.FOCUS_NONE

	_icon_label = Label.new()
	_icon_label.set_anchors_preset(Control.PRESET_FULL_RECT)
	_icon_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_icon_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_icon_label.add_theme_font_size_override("font_size", 64)
	_icon_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_icon_label)

	_icon_tex = TextureRect.new()
	_icon_tex.set_anchors_preset(Control.PRESET_FULL_RECT)
	_icon_tex.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_icon_tex.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_icon_tex.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_icon_tex)

	_qty_label = Label.new()
	_qty_label.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	_qty_label.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	_qty_label.offset_top = 4
	_qty_label.offset_right = -10
	_qty_label.add_theme_font_size_override("font_size", 28)
	_qty_label.add_theme_color_override("font_outline_color", Color.BLACK)
	_qty_label.add_theme_constant_override("outline_size", 6)
	_qty_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_qty_label)

	_dur_label = Label.new()
	_dur_label.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	_dur_label.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_dur_label.offset_left = 10
	_dur_label.offset_bottom = -20
	_dur_label.add_theme_font_size_override("font_size", 24)
	_dur_label.add_theme_color_override("font_color", Color("70ff8b"))
	_dur_label.add_theme_color_override("font_outline_color", Color.BLACK)
	_dur_label.add_theme_constant_override("outline_size", 5)
	_dur_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_dur_label)

	_dur_bar = ProgressBar.new()
	_dur_bar.show_percentage = false
	_dur_bar.anchor_left = 0.0
	_dur_bar.anchor_right = 1.0
	_dur_bar.anchor_top = 1.0
	_dur_bar.anchor_bottom = 1.0
	_dur_bar.offset_left = 10
	_dur_bar.offset_right = -10
	_dur_bar.offset_top = -16
	_dur_bar.offset_bottom = -6
	_dur_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var fill := StyleBoxFlat.new()
	fill.bg_color = Color("00e5ff")
	fill.set_corner_radius_all(4)
	var back := StyleBoxFlat.new()
	back.bg_color = Color("0a1626")
	_dur_bar.add_theme_stylebox_override("fill", fill)
	_dur_bar.add_theme_stylebox_override("background", back)
	add_child(_dur_bar)

	# Futuristic rounded module slot styling
	_apply_default_style()
	set_item(null)


func _apply_default_style() -> void:
	for state in ["normal", "hover", "pressed"]:
		var sb := StyleBoxFlat.new()
		# Translucent dark teal/slate module interior matching prototype
		sb.bg_color = Color("0d354d", 0.88) if state == "normal" else (Color("124c6e", 0.95) if state == "hover" else Color("082436", 1.0))
		sb.set_border_width_all(4)
		# Vivid glowing cyan border matching prototype
		sb.border_color = Color("22d3ee") if state != "pressed" else Color("38bdf8")
		sb.set_corner_radius_all(16)
		sb.shadow_color = Color("0284c7", 0.4)
		sb.shadow_size = 4
		add_theme_stylebox_override(state, sb)




var bench_input_slot_index: int = -1
var is_bench_tool_slot: bool = false


func _can_drop_data(_at_position: Vector2, data: Variant) -> bool:
	if not (data is Dictionary) or data.get("source") != "inventory":
		return false
	var item: Variant = data.get("item")
	if item == null or not (item is Dictionary):
		return false
	var def := InventoryManager.get_def(item.get("id", ""))
	var type: String = def.get("type", "")

	if is_bench_tool_slot:
		return type == "tool"
	elif bench_input_slot_index >= 0:
		return type != "tool" and type != "container"
	return false


func _drop_data(_at_position: Vector2, data: Variant) -> void:
	if not _can_drop_data(_at_position, data):
		return
	var inv_idx: int = int(data.get("slot_index", -1))
	if inv_idx < 0:
		return

	if is_bench_tool_slot:
		CraftingSystem.drop_item_to_tool_slot(inv_idx)
	elif bench_input_slot_index >= 0:
		CraftingSystem.drop_item_to_input_slot(bench_input_slot_index, inv_idx)



func set_item(item: Variant) -> void:
	current_item = item
	if item == null:
		_icon_label.text = ""
		_icon_tex.texture = null
		_qty_label.text = ""
		_dur_label.text = ""
		_dur_bar.visible = false
		return

	var def: Dictionary = InventoryManager.get_def(item["id"])
	var icon_path: String = def.get("icon", "")
	if icon_path != "" and ResourceLoader.exists(icon_path):
		_icon_tex.texture = load(icon_path)
		_icon_label.text = ""
	else:
		_icon_tex.texture = null
		_icon_label.text = def.get("glyph", "?")

	if def.get("type", "") == "tool":
		_qty_label.text = ""
		_dur_bar.visible = true
		_dur_bar.max_value = float(def.get("max_durability", 1))
		_dur_bar.value = float(item.get("durability", 0))
		_dur_label.text = str(int(item.get("durability", 0)))
	else:
		_dur_bar.visible = false
		_dur_label.text = ""
		_qty_label.text = str(int(item["qty"]))


func _get_drag_data(_at_position: Vector2) -> Variant:
	if current_item == null or slot_index < 0:
		return null

	var preview := Control.new()
	var bg := Panel.new()
	bg.custom_minimum_size = Vector2(100, 100)
	bg.position = -Vector2(50, 50)
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.2, 0.15, 0.1, 0.85)
	sb.border_color = Color("f59e0b")
	sb.set_border_width_all(3)
	sb.set_corner_radius_all(12)
	bg.add_theme_stylebox_override("panel", sb)
	preview.add_child(bg)

	var def := InventoryManager.get_def(current_item["id"])
	var icon_path: String = def.get("icon", "")
	if icon_path != "" and ResourceLoader.exists(icon_path):
		var tex_rect := TextureRect.new()
		tex_rect.texture = load(icon_path)
		tex_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
		tex_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		tex_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		bg.add_child(tex_rect)
	else:

		var lbl := Label.new()
		lbl.text = def.get("glyph", "?")
		lbl.set_anchors_preset(Control.PRESET_FULL_RECT)
		lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		lbl.add_theme_font_size_override("font_size", 42)
		bg.add_child(lbl)

	set_drag_preview(preview)
	return {
		"source": "inventory",
		"slot_index": slot_index,
		"item": current_item
	}

