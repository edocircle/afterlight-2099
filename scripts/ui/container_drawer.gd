class_name ContainerDrawer
extends PanelContainer
## Upper drawer showing the contents of the open container. Tap an item to move it to the inventory.

const ITEM_SLOT := preload("res://scenes/components/item_slot.tscn")
const COLUMNS := 5

var _title: Label
var _grid: GridContainer
var _views: Array[SlotView] = []


func _ready() -> void:
	visible = false
	# Position as overlay starting below TopActionBar (approx 174px down), covering Character Trio and Mini Map
	offset_top = 174
	offset_bottom = 1200
	size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	mouse_filter = Control.MOUSE_FILTER_STOP

	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 14)
	add_child(col)

	var head := HBoxContainer.new()
	col.add_child(head)

	_title = Label.new()
	_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_title.add_theme_font_size_override("font_size", 36)
	_title.add_theme_color_override("font_color", Color("e0f7fa"))
	head.add_child(_title)

	var close := Button.new()
	close.text = "✕ CLOSE"
	close.focus_mode = Control.FOCUS_NONE
	close.custom_minimum_size = Vector2(220, 96)
	close.add_theme_font_size_override("font_size", 36)
	close.add_theme_color_override("font_color", Color("00e5ff"))
	close.add_theme_stylebox_override("normal", _box(Color("09233b"), Color("00e5ff"), 16))
	close.add_theme_stylebox_override("hover", _box(Color("10365c"), Color("40c4ff"), 16))
	close.add_theme_stylebox_override("pressed", _box(Color("051221"), Color("00b0ff"), 16))
	close.pressed.connect(InventoryManager.close_container)
	head.add_child(close)

	_grid = GridContainer.new()
	_grid.columns = COLUMNS
	_grid.add_theme_constant_override("h_separation", 12)
	_grid.add_theme_constant_override("v_separation", 12)
	col.add_child(_grid)

	var panel := _box(Color("051221"), Color("00e5ff"), 24)
	panel.set_border_width_all(4)
	panel.set_content_margin_all(20)
	add_theme_stylebox_override("panel", panel)



	InventoryManager.container_opened.connect(_on_opened)
	InventoryManager.container_closed.connect(func() -> void: visible = false)
	InventoryManager.container_changed.connect(refresh)


func _on_opened(_slot_index: int) -> void:
	var container: Variant = InventoryManager.get_active_container()
	if container == null:
		return
	for v in _views:
		v.queue_free()
	_views.clear()
	for i in container["contents"].size():
		var view: SlotView = ITEM_SLOT.instantiate()
		view.pressed.connect(InventoryManager.extract_from_container.bind(i))
		_grid.add_child(view)
		_views.append(view)
	visible = true
	refresh()


func refresh() -> void:
	var container: Variant = InventoryManager.get_active_container()
	if container == null:
		return
	var def: Dictionary = InventoryManager.get_def(container["id"])
	var contents: Array = container["contents"]
	_title.text = "%s (%d SLOTS)" % [String(def.get("name", "Container")).to_upper(), contents.size()]
	for i in _views.size():
		_views[i].set_item(contents[i])


func _box(fill: Color, border: Color, radius: int) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = fill
	sb.set_border_width_all(4)
	sb.border_color = border
	sb.set_corner_radius_all(radius)
	return sb
