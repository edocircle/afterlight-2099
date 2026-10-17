extends Node
## Worker Drone loop.
## Early phase: manual tether - tap/hold the drone to scavenge one item at a time into the inventory.
## With a Cargo Pod equipped: tap sends the drone on a timed autonomous run; it returns with a full pod.

signal scavenge_completed(item_id: String)
signal run_state_changed
signal scavenge_started(duration: float, is_depleted: bool)
signal scavenge_finished(item_id: String)

const POOL_PATH := "res://data/scavenge_pool.json"
const DISCOVERY_PATH := "res://data/minion_discovery_index.json"
const ENERGY_COST := 2.0 # per scavenged item (manual and pod runs)
const MIN_ACCURACY := 0.10
const MAX_ACCURACY := 0.95
const ACCURACY_PER_COMM := 0.012 # 1.2% per communication point
const RUN_SECONDS := 60.0 # placeholder run duration
const POD_SLOT := "cargo_pod"
const NORMAL_SCAVENGE_TIME := 1.0
const BASE_DEPLETED_SCAVENGE_TIME := 6.0 # Drastically slower speed when depleted, scales exponentially

var pool: Array = []
var discovery_index: Dictionary = {}
var cargo_pod: Variant = null # equipped pod item dict or null
var run_end_unix: float = 0.0 # 0 = no run in progress; otherwise unix time the run finishes
var is_scavenging: bool = false
var scavenge_end_unix: float = 0.0
var scavenge_duration: float = 0.0
var scavenge_depleted: bool = false
var depleted_streak: int = 0
var _scavenge_timer: Timer


func _ready() -> void:
	_scavenge_timer = Timer.new()
	_scavenge_timer.one_shot = true
	_scavenge_timer.timeout.connect(_on_manual_scavenge_complete)
	add_child(_scavenge_timer)
	GameState.energy_updated.connect(_on_energy_updated)

	var f := FileAccess.open(POOL_PATH, FileAccess.READ)
	if f != null:
		var parsed: Variant = JSON.parse_string(f.get_as_text())
		if parsed is Dictionary:
			pool = parsed.get("scavenging", [])
	var df := FileAccess.open(DISCOVERY_PATH, FileAccess.READ)
	if df != null:
		var d_parsed: Variant = JSON.parse_string(df.get_as_text())
		if d_parsed is Dictionary:
			discovery_index = d_parsed


func _on_energy_updated(target: String, val: float, _max_val: float) -> void:
	if target == "minion" and val >= ENERGY_COST:
		depleted_streak = 0


func get_accuracy() -> float:
	var comm: float = GameState.minion_skills.get("communication", 0.0)
	return clampf(comm * ACCURACY_PER_COMM, MIN_ACCURACY, MAX_ACCURACY)


func get_signal_tier() -> Dictionary:
	var comm: float = GameState.minion_skills.get("communication", 0.0)
	if comm <= 20.0:
		return {
			"tier": "Signal Noise",
			"code": "LOW",
			"desc": "Frequent telemetry dropouts. Drone frequently returns random junk instead of target.",
			"color": Color("e74c3c"),
			"range": "10% - 24%"
		}
	elif comm <= 50.0:
		return {
			"tier": "Calibrated Uplink",
			"code": "MID",
			"desc": "Calibrated telemetry link. Prioritizes designated gather target with minor scrap.",
			"color": Color("f59e0b"),
			"range": "25% - 60%"
		}
	else:
		return {
			"tier": "Deep Synapse Lock",
			"code": "HIGH",
			"desc": "Quantum neural lock. Drone acts as a precision harvester returning targeted hauls.",
			"color": Color("70ff8b"),
			"range": "65% - 95%"
		}


func get_discipline_for_item(item_id: String) -> String:
	for disc in ["scavenging", "lumber", "hunting", "fishing"]:
		var items: Array = discovery_index.get(disc, [])
		for entry in items:
			if entry.get("id", "") == item_id:
				return disc
	return "scavenging"


func get_unlocked_targets() -> Array:
	var targets: Array = []
	for disc in ["scavenging", "lumber", "hunting", "fishing"]:
		var current_skill: float = GameState.minion_skills.get(disc, 0.0)
		var entries: Array = discovery_index.get(disc, [])
		for entry in entries:
			var req: float = float(entry.get("req_skill", 0.0))
			if current_skill >= req:
				targets.append(entry.get("id", ""))
	return targets


func cycle_gather_target() -> void:
	## Gather Type slot: cycles Any -> each unlocked target -> Any.
	var unlocked := get_unlocked_targets()
	if unlocked.is_empty():
		unlocked = pool.duplicate()
	var options: Array = [""] + unlocked
	var idx := options.find(GameState.minion_gather_target)
	if idx == -1:
		idx = 0
	GameState.minion_gather_target = options[(idx + 1) % options.size()]


func set_gather_target(item_id: String) -> void:
	GameState.minion_gather_target = item_id
	run_state_changed.emit()


func reset_run() -> void:
	cargo_pod = null
	run_end_unix = 0.0
	run_state_changed.emit()


func _roll_item() -> Dictionary:
	# Success returns the targeted item (if a Gather Type is set); otherwise random salvage.
	var target: String = GameState.minion_gather_target
	if target != "" and randf() < get_accuracy():
		return {
			"id": target,
			"discipline": get_discipline_for_item(target),
			"is_target": true
		}
	var junk: String = pool.pick_random() if not pool.is_empty() else "raw_mineral"
	return {
		"id": junk,
		"discipline": get_discipline_for_item(junk),
		"is_target": false
	}


func _grant_xp(discipline: String) -> void:
	GameState.add_minion_skill_xp(discipline)
	GameState.add_minion_skill_xp("communication")


## --- Interaction entry point (drone tap) ---

func interact() -> void:
	if cargo_pod == null:
		scavenge()
		return
	match run_state():
		"idle":
			start_run()
		"running":
			GameState.toast_requested.emit("Drone is out scavenging... %s left." % _fmt(run_seconds_left()))
		"ready":
			collect_run()


## --- Manual tether (early phase) ---

func scavenge() -> bool:
	if is_scavenging:
		var left := maxi(1, int(ceil(scavenge_end_unix - Time.get_unix_time_from_system())))
		GameState.toast_requested.emit("Drone is scavenging in Citadel... %ds remaining" % left)
		return false

	if pool.is_empty():
		return false

	if not InventoryManager.can_add("raw_mineral_chunk"):
		GameState.toast_requested.emit("Cargo full! No free slots.")
		return false

	var has_energy := GameState.minion_energy >= ENERGY_COST
	if has_energy:
		GameState.consume_energy("minion", ENERGY_COST)
		depleted_streak = 0
		scavenge_depleted = false
		scavenge_duration = NORMAL_SCAVENGE_TIME
		GameState.toast_requested.emit("Drone scouting Citadel (%.1fs)..." % scavenge_duration)
	else:
		# Energy depleted: still able to search, but drastically slower exponentially!
		depleted_streak += 1
		scavenge_depleted = true
		scavenge_duration = minf(40.0, BASE_DEPLETED_SCAVENGE_TIME * pow(1.5, depleted_streak - 1))
		GameState.toast_requested.emit("Drone depleted! Searching exponentially slower (%.1fs)..." % scavenge_duration)

	is_scavenging = true
	scavenge_end_unix = Time.get_unix_time_from_system() + scavenge_duration
	_scavenge_timer.start(scavenge_duration)
	scavenge_started.emit(scavenge_duration, scavenge_depleted)
	run_state_changed.emit()
	return true


func _on_manual_scavenge_complete() -> void:
	is_scavenging = false
	var roll := _roll_item()
	var item_id: String = roll["id"]
	var disc: String = roll["discipline"]

	if InventoryManager.can_add(item_id):
		InventoryManager.add_item(InventoryManager.make_item(item_id))
		_grant_xp(disc)
		var item_name: String = InventoryManager.get_def(item_id).get("name", item_id)
		if scavenge_depleted:
			GameState.toast_requested.emit("Drone returned from slow search with: %s!" % item_name)
		else:
			GameState.toast_requested.emit("Drone scavenged: %s!" % item_name)
		scavenge_completed.emit(item_id)
		scavenge_finished.emit(item_id)
	else:
		GameState.toast_requested.emit("Cargo full! Item lost.")
		scavenge_finished.emit("")
	run_state_changed.emit()


## --- Cargo pod ---

func pod_capacity() -> int:
	if cargo_pod == null:
		return 0
	return int(InventoryManager.get_def(cargo_pod["id"]).get("capacity", 0))


func toggle_cargo_pod() -> void:
	## Equips the first cargo pod found in the inventory, or returns the equipped one.
	if run_state() != "idle":
		GameState.toast_requested.emit("Drone is on a run. Collect first.")
		return
	if cargo_pod != null:
		if InventoryManager.add_item(cargo_pod):
			cargo_pod = null
			run_state_changed.emit()
		else:
			GameState.toast_requested.emit("Cargo full! No free slots.")
		return
	for i in InventoryManager.SLOT_COUNT:
		var s: Variant = InventoryManager.get_slot(i)
		if s != null and InventoryManager.get_def(s["id"]).get("equip_slot", "") == POD_SLOT:
			cargo_pod = InventoryManager.take_one(i)
			run_state_changed.emit()
			return
	GameState.toast_requested.emit("No Cargo Pod in inventory. Craft one first.")


## --- Autonomous runs ---

func run_state() -> String:
	if run_end_unix <= 0.0:
		return "idle"
	return "running" if Time.get_unix_time_from_system() < run_end_unix else "ready"


func run_seconds_left() -> int:
	return maxi(0, int(ceil(run_end_unix - Time.get_unix_time_from_system())))


func status_text() -> String:
	if is_scavenging:
		var left := maxi(1, int(ceil(scavenge_end_unix - Time.get_unix_time_from_system())))
		if scavenge_depleted:
			return "LOW PWR (%ds)" % left
		return "SCOUT (%ds)" % left
	if cargo_pod == null:
		if GameState.minion_energy < ENERGY_COST:
			return "LOW ENERGY (SLOW)"
		return "SCAVENGER"
	match run_state():
		"running":
			return "RUN %s" % _fmt(run_seconds_left())
		"ready":
			return "READY!"
	return "TAP TO SEND"


func start_run() -> bool:
	if pool.is_empty() or cargo_pod == null or run_state() != "idle":
		return false
	var cost := ENERGY_COST * pod_capacity()
	if not GameState.consume_energy("minion", cost):
		GameState.toast_requested.emit("Drone needs %d EN for this run. Feed food." % int(cost))
		return false
	run_end_unix = Time.get_unix_time_from_system() + RUN_SECONDS
	run_state_changed.emit()
	GameState.toast_requested.emit("Drone dispatched! Back in %s." % _fmt(int(RUN_SECONDS)))
	return true


func collect_run() -> bool:
	if run_state() != "ready":
		return false
	var haul: Dictionary = {}
	var haul_discs: Dictionary = {}
	for i in pod_capacity():
		var roll := _roll_item()
		var id: String = roll["id"]
		haul[id] = int(haul.get(id, 0)) + 1
		haul_discs[id] = roll["discipline"]
	if not InventoryManager.can_add_all(haul):
		GameState.toast_requested.emit("Cargo full! Make room for the haul.")
		return false

	var names: PackedStringArray = []
	var first_id := ""
	for id in haul:
		if first_id == "":
			first_id = id
		InventoryManager.add_item(InventoryManager.make_item(id, haul[id]))
		var item_name: String = InventoryManager.get_def(id).get("name", id)
		names.append("%dx %s" % [haul[id], item_name])
		var disc: String = haul_discs.get(id, "scavenging")
		for n in haul[id]:
			_grant_xp(disc)
	run_end_unix = 0.0
	run_state_changed.emit()
	GameState.toast_requested.emit("Drone returned: %s" % ", ".join(names))
	scavenge_completed.emit(first_id)
	return true


func _fmt(seconds: int) -> String:
	return "%d:%02d" % [int(seconds / 60.0), seconds % 60]
