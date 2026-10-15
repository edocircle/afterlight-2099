extends Control
## Root wiring: top bar / NPC -> modal host, and Android back button handling.

@onready var _bar: TopActionBar = $Margin/AppContainer/TopActionBar
@onready var _host: ModalHost = $ModalHost
@onready var _water_backdrop: TextureRect = $WaterBackdrop


func _ready() -> void:
	_load_backdrop()
	_bar.modal_requested.connect(_host.open)
	GameState.modal_requested.connect(_host.open)


func _load_backdrop() -> void:
	var path := "res://assets/sprites/underwater_bg.png"
	var global_p := ProjectSettings.globalize_path(path)
	if FileAccess.file_exists(global_p):
		var img := Image.new()
		var err := img.load(global_p)
		if err == OK:
			_water_backdrop.texture = ImageTexture.create_from_image(img)



func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_GO_BACK_REQUEST:
		if _host.visible:
			_host.close()
		elif InventoryManager.active_container_index != -1:
			InventoryManager.close_container()
		else:
			get_tree().quit()
