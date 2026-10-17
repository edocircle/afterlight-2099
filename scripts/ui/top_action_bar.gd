class_name TopActionBar
extends HBoxContainer
## 5 stone buttons that request modals.

signal modal_requested(kind: String)

const BUTTONS := [
	["🧠", "SKILLS", "protag_skills"],
	["🎒", "P-BAG", "protag_bag"],
	["", "", ""],
	["⚙️", "M-SKILL", "minion_skills"],
	["💼", "M-BAG", "minion_bag"],
]


func _ready() -> void:
	add_theme_constant_override("separation", 16)
	alignment = BoxContainer.ALIGNMENT_CENTER
	resized.connect(queue_redraw)

	for def in BUTTONS:
		if def[1] == "":
			var spacer := Control.new()
			spacer.custom_minimum_size = Vector2(170, 170)
			spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
			add_child(spacer)
			continue

		var btn := Button.new()
		btn.focus_mode = Control.FOCUS_NONE
		btn.custom_minimum_size = Vector2(170, 170)
		btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		for state in ["normal", "hover", "pressed"]:
			btn.add_theme_stylebox_override(state, UiFrames.circle_button(state))
		btn.add_theme_stylebox_override("focus", StyleBoxEmpty.new())

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


func _draw() -> void:
	# Steel pipe behind the round buttons (children draw on top of this).
	var h := 36.0
	draw_style_box(UiFrames.pipe(), Rect2(30.0, size.y * 0.5 - h * 0.5, maxf(0.0, size.x - 60.0), h))


