class_name InventoryGrid
extends GridContainer
## 5x4 inventory grid. Renders InventoryManager.slots and reports clicks by index.

signal slot_pressed(index: int)

const ITEM_SLOT := preload("res://scenes/components/item_slot.tscn")

var _views: Array[SlotView] = []


func _ready() -> void:
	columns = 5
	add_theme_constant_override("h_separation", 14)
	add_theme_constant_override("v_separation", 14)
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for i in InventoryManager.SLOT_COUNT:
		var view: SlotView = ITEM_SLOT.instantiate()
		view.slot_index = i
		view.size_flags_horizontal = Control.SIZE_EXPAND_FILL
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
			var accent := UiFrames.GOLD if open else UiFrames.CYAN
			for state in ["normal", "hover", "pressed"]:
				_views[i].add_theme_stylebox_override(state, UiFrames.slot(state, accent))
		else:
			_views[i]._apply_default_style()



func _on_slot_pressed(index: int) -> void:
	print("Inventory slot pressed: ", index)
	slot_pressed.emit(index)
	InventoryManager.click_slot(index)
