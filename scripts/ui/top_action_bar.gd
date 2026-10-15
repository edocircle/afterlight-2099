class_name TopActionBar
extends HBoxContainer
## 5 stone buttons that request modals.

signal modal_requested(kind: String)

const BUTTONS := [
	["🧠", "SKILLS", "protag_skills"],
	["🎒", "P-BAG", "protag_bag"],
	["🏛️", "CITY", "city"],
	["⚙️", "M-SKILL", "minion_skills"],
	["💼", "M-BAG", "minion_bag"],
]


func _ready() -> void:
	add_theme_constant_override("separation", 16)
	alignment = BoxContainer.ALIGNMENT_CENTER

	for def in BUTTONS:
		var btn := Button.new()
		btn.focus_mode = Control.FOCUS_NONE
		btn.custom_minimum_size = Vector2(170, 170)
		btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		btn.add_theme_stylebox_override("normal", _circle_box(Color("164e63", 0.85), Color("38bdf8")))
		btn.add_theme_stylebox_override("hover", _circle_box(Color("0e7490", 0.95), Color("7dd3fc")))
		btn.add_theme_stylebox_override("pressed", _circle_box(Color("155e75", 1.0), Color("0284c7")))

		var v := VBoxContainer.new()
		v.set_anchors_preset(Control.PRESET_FULL_RECT)
		v.alignment = BoxContainer.ALIGNMENT_CENTER
		v.mouse_filter = Control.MOUSE_FILTER_IGNORE
		v.add_theme_constant_override("separation", 2)
		btn.add_child(v)

		var icon := Label.new()
		icon.text = def[0]
		icon.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		icon.add_theme_font_size_override("font_size", 60)
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		v.add_child(icon)

		var text := Label.new()
		text.text = def[1]
		text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		text.add_theme_font_size_override("font_size", 22)
		text.add_theme_color_override("font_color", Color("e0f2fe"))
		text.add_theme_color_override("font_outline_color", Color("0369a1"))
		text.add_theme_constant_override("outline_size", 4)
		text.mouse_filter = Control.MOUSE_FILTER_IGNORE
		v.add_child(text)

		btn.pressed.connect(modal_requested.emit.bind(def[2]))
		add_child(btn)


func _circle_box(fill: Color, border: Color) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = fill
	sb.set_border_width_all(5)
	sb.border_color = border
	sb.set_corner_radius_all(85)
	sb.shadow_color = Color("0284c7", 0.45)
	sb.shadow_size = 8
	return sb


