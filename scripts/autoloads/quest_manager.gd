extends Node
## Archon AI quest chain. Advances when a matching craft output is produced or the drone scavenges.

signal quest_changed

const QUESTS_PATH := "res://data/quests.json"

var quests: Array = []
var current_index: int = 0
var progress: int = 0 # for count-based (scavenge) quests


func _ready() -> void:
	var f := FileAccess.open(QUESTS_PATH, FileAccess.READ)
	if f == null:
		push_error("Cannot open %s" % QUESTS_PATH)
	else:
		var parsed: Variant = JSON.parse_string(f.get_as_text())
		if parsed is Array:
			quests = parsed
		else:
			push_error("Invalid JSON in %s" % QUESTS_PATH)
	CraftingSystem.craft_success.connect(_on_craft_success)
	MinionSystem.scavenge_completed.connect(_on_scavenge_completed)


func is_finished() -> bool:
	return current_index >= quests.size()


func current() -> Dictionary:
	return {} if is_finished() else quests[current_index]


func bubble_text() -> String:
	return "DONE" if is_finished() else String(current()["title"])


func announce() -> void:
	if is_finished():
		GameState.toast_requested.emit("[MASTER FABRICATOR] All directives cleared!")
		return
	var q := current()
	var text := "[MASTER FABRICATOR] %s: %s" % [q["title"], q["task"]]
	if q["type"] == "scavenge":
		text += " (%d/%d)" % [progress, int(q["target"])]
	GameState.toast_requested.emit(text)


func reset_run() -> void:
	current_index = 0
	progress = 0
	quest_changed.emit()


func _on_craft_success(result_id: String) -> void:
	if is_finished():
		return
	var q := current()
	if q["type"] == "craft":
		var tgt: String = String(q["target"])
		if tgt == result_id:
			_advance()
		elif (tgt == "peeled_banana" or tgt == "peeled_banana_pod") and (result_id == "peeled_banana" or result_id == "peeled_banana_pod"):
			_advance()
		elif (tgt == "mono_shard" or tgt == "monomolecular_shard") and (result_id == "mono_shard" or result_id == "monomolecular_shard"):
			_advance()
		elif (tgt == "banana_wafers" or tgt == "diced_banana_wafers") and (result_id == "banana_wafers" or result_id == "diced_banana_wafers"):
			_advance()
		elif (tgt == "field_container" or tgt == "field_nanite_pod") and (result_id == "field_container" or result_id == "field_nanite_pod"):
			_advance()


func _on_scavenge_completed(_item_id: String) -> void:
	if is_finished():
		return
	var q := current()
	if q["type"] == "scavenge":
		progress += 1
		if progress >= int(q["target"]):
			_advance()


func _advance() -> void:
	GameState.toast_requested.emit("Directive Cleared: %s!" % current()["title"])
	current_index += 1
	progress = 0
	quest_changed.emit()
