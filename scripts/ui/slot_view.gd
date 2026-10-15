class_name SlotView
extends Button
## Reusable inventory slot: glyph/icon, quantity badge (top-right), durability bar (bottom).

const SLOT_SIZE := Vector2(160, 160)

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
	fill.bg_color = Color("27ae60")
	var back := StyleBoxFlat.new()
	back.bg_color = Color("252019")
	_dur_bar.add_theme_stylebox_override("fill", fill)
	_dur_bar.add_theme_stylebox_override("background", back)
	add_child(_dur_bar)

	set_item(null)


func set_item(item: Variant) -> void:
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
