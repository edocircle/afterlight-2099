class_name UIRows
extends RefCounted
## Shared builders for modal rows/headings/buttons in the stone/wood style.

static func row(left: String, right: String = "", right_color: Color = Color.WHITE, right_control: Control = null) -> PanelContainer:
	var panel := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color("463f33")
	sb.set_corner_radius_all(12)
	sb.content_margin_left = 24
	sb.content_margin_right = 24
	sb.content_margin_top = 16
	sb.content_margin_bottom = 16
	panel.add_theme_stylebox_override("panel", sb)

	var stacked := right_control != null or right.length() > 16 or left.length() > 30
	var h: BoxContainer = VBoxContainer.new() if stacked else HBoxContainer.new()
	h.add_theme_constant_override("separation", 8 if stacked else 16)
	panel.add_child(h)

	var l := Label.new()
	l.text = left
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	l.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size.x = 120
	l.add_theme_font_size_override("font_size", 30)
	h.add_child(l)

	if right_control != null:
		right_control.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		h.add_child(right_control)
	elif right != "":
		var r := Label.new()
		r.text = right
		r.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		r.custom_minimum_size.x = 120
		r.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		r.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT if stacked else HORIZONTAL_ALIGNMENT_RIGHT
		r.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		r.add_theme_font_size_override("font_size", 28 if stacked else 30)
		r.add_theme_color_override("font_color", right_color)
		h.add_child(r)
	return panel


static func heading(text: String) -> Label:
	var l := Label.new()
	l.text = text
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.add_theme_font_size_override("font_size", 28)
	l.add_theme_color_override("font_color", Color("faecd8"))
	return l


static func action_button(text: String) -> Button:
	var b := Button.new()
	b.text = text
	b.focus_mode = Control.FOCUS_NONE
	b.custom_minimum_size = Vector2(260, 88)
	b.add_theme_font_size_override("font_size", 30)
	b.add_theme_color_override("font_color", Color.WHITE)
	for state in ["normal", "hover", "pressed"]:
		var sb := StyleBoxFlat.new()
		sb.bg_color = {"normal": Color("d97724"), "hover": Color("f59e0b"), "pressed": Color("9b4105")}[state]
		sb.set_border_width_all(4)
		sb.border_color = Color("542203")
		sb.set_corner_radius_all(12)
		sb.content_margin_left = 20
		sb.content_margin_right = 20
		b.add_theme_stylebox_override(state, sb)
	return b
