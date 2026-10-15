class_name InventoryGrid
extends GridContainer
## 5x4 inventory grid. Renders InventoryManager.slots and reports clicks by index.

signal slot_pressed(index: int)

const ITEM_SLOT := preload("res://scenes/components/item_slot.tscn")

var _views: Array[SlotView] = []


func _ready() -> void:
	columns = 5
	add_theme_constant_override("h_separation", 12)
	add_theme_constant_override("v_separation", 12)
	for i in InventoryManager.SLOT_COUNT:
		var view: SlotView = ITEM_SLOT.instantiate()
		view.slot_index = i
		view.pressed.connect(_on_slot_pressed.bind(i))
		add_child(view)
		_views.append(view)
	InventoryManager.inventory_changed.connect(refresh)
	InventoryManager.container_opened.connect(func(_i: int) -> void: refresh())
	InventoryManager.container_closed.connect(refresh)
	refresh()


func refresh() -> void:
	for i in _views.size():
		_views[i].set_item(InventoryManager.get_slot(i))
		if InventoryManager.is_container(i):
			var open := i == InventoryManager.active_container_index
			_views[i].add_theme_stylebox_override("normal", _container_box(open))
		else:
			_views[i].remove_theme_stylebox_override("normal")


func _container_box(open: bool) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color("8f4813") if open else Color("5f3a1c")
	sb.set_border_width_all(6)
	sb.border_color = Color("f59e0b")
	sb.set_corner_radius_all(12)
	return sb


func _on_slot_pressed(index: int) -> void:
	print("Inventory slot pressed: ", index)
	slot_pressed.emit(index)
	InventoryManager.click_slot(index)
