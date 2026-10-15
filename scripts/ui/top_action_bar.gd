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
	add_theme_constant_override("separation", 12)
	for def in BUTTONS:
		var btn := Button.new()
		btn.focus_mode = Control.FOCUS_NONE
		btn.custom_minimum_size = Vector2(0, 150)
		btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		btn.add_theme_stylebox_override("normal", _box(Color("8c857b")))
		btn.add_theme_stylebox_override("hover", _box(Color("a09a8f")))
		btn.add_theme_stylebox_override("pressed", _box(Color("6a645a")))

		var v := VBoxContainer.new()
		v.set_anchors_preset(Control.PRESET_FULL_RECT)
		v.alignment = BoxContainer.ALIGNMENT_CENTER
		v.mouse_filter = Control.MOUSE_FILTER_IGNORE
		btn.add_child(v)

		var icon := Label.new()
		icon.text = def[0]
		icon.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		icon.add_theme_font_size_override("font_size", 56)
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		v.add_child(icon)

		var text := Label.new()
		text.text = def[1]
		text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		text.add_theme_font_size_override("font_size", 24)
		text.add_theme_color_override("font_color", Color("24201a"))
		text.mouse_filter = Control.MOUSE_FILTER_IGNORE
		v.add_child(text)

		btn.pressed.connect(modal_requested.emit.bind(def[2]))
		add_child(btn)


func _box(fill: Color) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = fill
	sb.set_border_width_all(4)
	sb.border_color = Color("3d3830")
	sb.set_corner_radius_all(16)
	return sb
