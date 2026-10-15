class_name CharacterDropTarget
extends Button

var drop_target_id: String = ""


func _can_drop_data(_at_position: Vector2, data: Variant) -> bool:
	if not (data is Dictionary):
		return false
	if data.get("source") != "inventory":
		return false
	var item: Variant = data.get("item")
	if item == null or not (item is Dictionary):
		return false
	var def := InventoryManager.get_def(item.get("id", ""))
	return def.get("type", "") == "food"


func _drop_data(_at_position: Vector2, data: Variant) -> void:
	if not _can_drop_data(_at_position, data):
		return
	var slot_idx: int = int(data.get("slot_index", -1))
	if slot_idx >= 0 and drop_target_id != "":
		InventoryManager.feed_slot_to_target(slot_idx, drop_target_id)
