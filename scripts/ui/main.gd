extends Control
## Root wiring: top bar / NPC -> modal host, and Android back button handling.

@onready var _bar: TopActionBar = $Margin/AppContainer/TopActionBar
@onready var _host: ModalHost = $ModalHost


func _ready() -> void:
	_bar.modal_requested.connect(_host.open)
	GameState.modal_requested.connect(_host.open)


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_GO_BACK_REQUEST:
		if _host.visible:
			_host.close()
		elif InventoryManager.active_container_index != -1:
			InventoryManager.close_container()
		else:
			get_tree().quit()
