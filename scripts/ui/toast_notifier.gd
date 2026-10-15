class_name ToastNotifier
extends CenterContainer
## Floating toast. Listens to GameState.toast_requested and CraftingSystem.message.

const SHOW_SECONDS := 1.9
const FADE_SECONDS := 0.3

var _panel: PanelContainer
var _label: Label
var _tween: Tween


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE

	_panel = PanelContainer.new()
	_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_panel.modulate.a = 0.0
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.07, 0.04, 0.016, 0.95)
	sb.set_border_width_all(3)
	sb.border_color = Color("f59e0b")
	sb.set_corner_radius_all(40)
	sb.content_margin_left = 40
	sb.content_margin_right = 40
	sb.content_margin_top = 20
	sb.content_margin_bottom = 20
	_panel.add_theme_stylebox_override("panel", sb)
	add_child(_panel)

	_label = Label.new()
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_label.add_theme_font_size_override("font_size", 36)
	_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_panel.add_child(_label)

	GameState.toast_requested.connect(show_toast)
	CraftingSystem.message.connect(show_toast)


func show_toast(text: String) -> void:
	_label.text = text
	_label.custom_minimum_size.x = 760 if text.length() > 28 else 520
	_panel.reset_size()
	_panel.modulate.a = 1.0
	if _tween:
		_tween.kill()
	_tween = create_tween()
	_tween.tween_interval(SHOW_SECONDS)
	_tween.tween_property(_panel, "modulate:a", 0.0, FADE_SECONDS)
