extends VBoxContainer
## Sector Bastion: housing limits, buildings, and the Love Hut Recombination Pod reset (tap twice to confirm).

const CONFIRM_SECONDS := 3.0

var _reset_btn: Button
var _armed := false


func _ready() -> void:
	add_theme_constant_override("separation", 12)
	for b in ColonyManager.buildings:
		match b["id"]:
			"love_hut":
				_reset_btn = UIRows.action_button("RESET")
				_reset_btn.pressed.connect(_on_reset_pressed)
				add_child(UIRows.row(b["name"], "", Color.WHITE, _reset_btn))
			"habitats":
				add_child(UIRows.row(b["name"], "Pop: %d / %d Operatives" % [ColonyManager.population, ColonyManager.housing_capacity]))
			_:
				add_child(UIRows.row(b["name"], b["status"], Color("f59e0b")))


func _on_reset_pressed() -> void:
	if not _armed:
		_armed = true
		_reset_btn.text = "TAP AGAIN"
		get_tree().create_timer(CONFIRM_SECONDS).timeout.connect(_disarm)
		return
	_armed = false
	ColonyManager.reset_run()


func _disarm() -> void:
	if is_instance_valid(_reset_btn):
		_armed = false
		_reset_btn.text = "RESET"
