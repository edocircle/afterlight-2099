class_name ModalHost
extends Control
## Full-screen scrim + dialog hosting one modal content script at a time.

const MODALS := {
	"protag_skills": {"title": "PROTAGONIST SKILLS", "script": "res://scripts/ui/modals/modal_protag_skills.gd"},
	"protag_bag": {"title": "PLAYER BAG (EQUIPMENT)", "script": "res://scripts/ui/modals/modal_protag_bag.gd"},
	"city": {"title": "SECTOR BASTION (CITY)", "script": "res://scripts/ui/modals/modal_city.gd"},
	"minion_skills": {"title": "DRONE SUBSYSTEMS", "script": "res://scripts/ui/modals/modal_minion_skills.gd"},
	"minion_bag": {"title": "MINION BAG", "script": "res://scripts/ui/modals/modal_minion_bag.gd"},
	"fabricator_log": {"title": "MASTER FABRICATOR LOG", "script": "res://scripts/ui/modals/modal_fabricator_log.gd"},
	"recipe_ledger": {"title": "BLUEPRINT SUCCESS CALIBRATION", "script": "res://scripts/ui/modals/modal_recipe_ledger.gd"},
	"discovery_index": {"title": "MATERIAL DISCOVERY INDEX", "script": "res://scripts/ui/modals/modal_discovery_index.gd"},
	"identity_select": {"title": "OPERATIVE INITIALIZATION", "script": "res://scripts/ui/modals/modal_identity_select.gd"},
}

var _title: Label
var _dialog: PanelContainer
var _scroll: ScrollContainer
var _content: Control


func _ready() -> void:
	visible = false
	set_anchors_preset(Control.PRESET_FULL_RECT)

	var scrim := ColorRect.new()
	scrim.color = Color(0.06, 0.03, 0.012, 0.9)
	scrim.set_anchors_preset(Control.PRESET_FULL_RECT)
	scrim.mouse_filter = Control.MOUSE_FILTER_STOP
	scrim.gui_input.connect(func(e: InputEvent) -> void:
		if e is InputEventMouseButton and e.pressed:
			close())
	add_child(scrim)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(center)

	_dialog = PanelContainer.new()
	_dialog.custom_minimum_size = Vector2(1000, 0)
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color("051221")
	sb.set_border_width_all(4)
	sb.border_color = Color("00e5ff")
	sb.set_corner_radius_all(24)
	sb.set_content_margin_all(28)
	_dialog.add_theme_stylebox_override("panel", sb)
	center.add_child(_dialog)

	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 16)
	_dialog.add_child(col)

	var head := HBoxContainer.new()
	col.add_child(head)
	_title = Label.new()
	_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_title.add_theme_font_size_override("font_size", 40)
	_title.add_theme_color_override("font_color", Color("e0f7fa"))
	head.add_child(_title)

	var close_btn := Button.new()
	close_btn.text = "✕"
	close_btn.focus_mode = Control.FOCUS_NONE
	close_btn.custom_minimum_size = Vector2(96, 96)
	close_btn.add_theme_font_size_override("font_size", 44)
	close_btn.add_theme_color_override("font_color", Color("00e5ff"))
	close_btn.flat = true
	close_btn.pressed.connect(close)
	head.add_child(close_btn)

	_scroll = ScrollContainer.new()
	_scroll.custom_minimum_size = Vector2(888, 1200)
	_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	col.add_child(_scroll)

	ColonyManager.run_reset.connect(close)


func open(kind: String) -> void:
	if not MODALS.has(kind):
		return
	_clear_content()
	var def: Dictionary = MODALS[kind]
	_title.text = def["title"]

	if kind == "city":
		# Maximize modal height for phone screen viewport
		_dialog.custom_minimum_size = Vector2(1000, 2260)
		_scroll.custom_minimum_size = Vector2(944, 2100)
		_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	else:
		_dialog.custom_minimum_size = Vector2(1000, 0)
		_scroll.custom_minimum_size = Vector2(888, 1200)

	_content = VBoxContainer.new()
	_content.set_script(load(def["script"]))
	_content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_content.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_scroll.add_child(_content)
	visible = true



func close() -> void:
	visible = false
	_clear_content()


func _clear_content() -> void:
	if _content != null:
		_content.queue_free()
		_content = null
