class_name CharacterTrio
extends PanelContainer
## Operative Fabricator (left), Master Fabricator NPC (center), Worker Drone (right).
## Operative features dedicated floating access icons: Neural Skills Core (🧠) and Tactical Rig (🎒).

const PORTRAIT_SIZE := 210
const PORTRAIT_RADIUS := 40
const BOT_RUN_DISTANCE := 50.0
const PETE_TEX := "res://assets/sprites/characters/pete.jpg"
const MAYOR_TEX := "res://assets/sprites/characters/mayor_thomas.jpg"
const BOT_TEX := "res://assets/sprites/characters/helper_bot.jpg"
const BUBBLE_HEIGHT := 70
const HOLD_SECONDS := 0.5
const BEAM_INTERVAL := 0.6
const CHARACTER_DROP_TARGET := preload("res://scripts/ui/character_drop_target.gd")


var _bars: Dictionary = {} # target -> ProgressBar
var _texts: Dictionary = {} # target -> Label
var _bubble: Button
var _hold: Timer
var _beam: Timer
var _beaming := false
var _drone_status: Label
var _bot_mover: Control
var _bot_tween: Tween

var _operative_portrait: Button
var _operative_label: Label


func _ready() -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 24)
	add_child(row)

	# 1. Operative (Fabricator / Crafter)
	_operative_portrait = _make_pod(row, GameState.get_avatar_glyph(), GameState.operative_callsign, UiFrames.CYAN_SOFT, "player", "THE BOY PROTAGONIST", PETE_TEX)
	_operative_portrait.pressed.connect(InventoryManager.consume_food.bind("player"))

	# 2. Master Fabricator (AI Hologram NPC)
	var archon := _make_pod(row, "🧙‍♂️", "MAYOR THOMAS", UiFrames.CYAN_SOFT, "", "THE MAYOR", MAYOR_TEX)
	archon.pressed.connect(_open_log)
	_make_bubble(_pod_of(archon))

	# 3. Worker Drone (Scavenger Minion)
	var drone := _make_pod(row, "🛸", "HELPER BOT", UiFrames.GOLD, "minion", "SCAVENGER", BOT_TEX)

	_bot_mover = drone.get_meta("mover", null)
	MinionSystem.scavenge_started.connect(_on_scavenge_started)
	MinionSystem.scavenge_finished.connect(_on_scavenge_finished)

	_hold = Timer.new()
	_hold.one_shot = true
	_hold.wait_time = HOLD_SECONDS
	_hold.timeout.connect(_on_drone_held)
	add_child(_hold)
	_beam = Timer.new()
	_beam.wait_time = BEAM_INTERVAL
	_beam.timeout.connect(_on_beam_tick)
	add_child(_beam)
	drone.button_down.connect(func() -> void:
		_beaming = false
		_hold.start())
	drone.button_up.connect(func() -> void:
		_hold.stop()
		_beam.stop())
	drone.pressed.connect(_on_drone_pressed)

	add_theme_stylebox_override("panel", UiFrames.panel(26))




	GameState.energy_updated.connect(_on_energy_updated)
	GameState.identity_updated.connect(_refresh_operative_identity)
	QuestManager.quest_changed.connect(_refresh_bubble)
	MinionSystem.run_state_changed.connect(_refresh_status)
	_on_energy_updated("player", GameState.protag_energy, GameState.max_protag_energy)
	_on_energy_updated("minion", GameState.minion_energy, GameState.max_minion_energy)
	_refresh_bubble()
	_refresh_status()

	var tick := Timer.new() # keeps the run countdown fresh
	tick.wait_time = 1.0
	tick.autostart = true
	tick.timeout.connect(_refresh_status)
	add_child(tick)


func _pod_of(portrait: Button) -> Control:
	# portrait -> mover -> frame -> pod
	return portrait.get_parent().get_parent().get_parent()


func _on_scavenge_started(_duration: float, is_depleted: bool) -> void:
	## Helper Bot dashes down and right, exiting its frame to scout the city!
	if _bot_mover == null:
		return
	if _bot_tween != null and _bot_tween.is_running():
		_bot_tween.kill()
	_bot_tween = create_tween()
	var t := _bot_tween
	var exit_time := 0.20 if not is_depleted else 0.75
	t.tween_property(_bot_mover, "position:y", 220.0, exit_time).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	t.parallel().tween_property(_bot_mover, "position:x", 80.0, exit_time).set_trans(Tween.TRANS_SINE)
	t.parallel().tween_property(_bot_mover, "scale", Vector2(0.3, 0.3), exit_time)
	t.parallel().tween_property(_bot_mover, "modulate:a", 0.0, exit_time)


func _on_scavenge_finished(_item_id: String) -> void:
	## Helper Bot returns from the city, swooping back up into its frame with a happy wiggle!
	if _bot_mover == null:
		return
	if _bot_tween != null and _bot_tween.is_running():
		_bot_tween.kill()
	_bot_mover.position = Vector2(0, 180)
	_bot_mover.scale = Vector2(0.4, 0.4)
	_bot_mover.modulate.a = 0.0
	_bot_tween = create_tween()
	var t := _bot_tween
	t.tween_property(_bot_mover, "position:y", 0.0, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	t.parallel().tween_property(_bot_mover, "position:x", 0.0, 0.25)
	t.parallel().tween_property(_bot_mover, "scale", Vector2.ONE, 0.25)
	t.parallel().tween_property(_bot_mover, "modulate:a", 1.0, 0.15)
	# Happy wiggle
	t.tween_property(_bot_mover, "rotation", 0.12, 0.08).set_trans(Tween.TRANS_SINE)
	t.tween_property(_bot_mover, "rotation", -0.12, 0.08).set_trans(Tween.TRANS_SINE)
	t.tween_property(_bot_mover, "rotation", 0.0, 0.06).set_trans(Tween.TRANS_SINE)


func _refresh_operative_identity() -> void:
	if _operative_portrait:
		var pic: TextureRect = _operative_portrait.get_meta("tex_rect", null)
		if GameState.operative_chassis == "female":
			if pic:
				pic.texture = null
			_operative_portrait.text = GameState.get_avatar_glyph()
		else:
			_operative_portrait.text = ""
			if pic:
				pic.texture = load(PETE_TEX)
	if _operative_label:
		_operative_label.text = GameState.operative_callsign


func _make_pod(parent: Control, glyph: String, label: String, border: Color, target: String, subtitle: String = "", tex_path: String = "") -> Button:
	var pod := VBoxContainer.new()
	pod.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	pod.alignment = BoxContainer.ALIGNMENT_END
	pod.add_theme_constant_override("separation", 8)
	parent.add_child(pod)

	var spacer := Control.new() # keeps portraits aligned with the NPC's bubble row
	spacer.custom_minimum_size = Vector2(0, BUBBLE_HEIGHT)
	spacer.name = "BubbleRow"
	pod.add_child(spacer)

	# Frame -> Mover (animatable) -> [rounded clip panel with picture] + [border/press button on top]
	var frame := Control.new()
	frame.custom_minimum_size = Vector2(PORTRAIT_SIZE, PORTRAIT_SIZE)
	frame.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	pod.add_child(frame)

	var mover := Control.new()
	mover.set_anchors_preset(Control.PRESET_FULL_RECT)
	mover.mouse_filter = Control.MOUSE_FILTER_IGNORE
	mover.pivot_offset = Vector2(PORTRAIT_SIZE, PORTRAIT_SIZE) / 2.0
	frame.add_child(mover)

	var base_panel := Panel.new()
	base_panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	base_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# Ivory backing with a coloured glow that sits BEHIND the picture (no tint on the art)
	base_panel.add_theme_stylebox_override("panel", UiFrames.portrait_backing(border, Color("fffdfa"), PORTRAIT_RADIUS))
	mover.add_child(base_panel)

	var clip := Panel.new()
	clip.set_anchors_preset(Control.PRESET_FULL_RECT)
	clip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	clip.clip_children = CanvasItem.CLIP_CHILDREN_ONLY
	var bg := StyleBoxFlat.new()
	bg.bg_color = Color("ffffff")
	bg.set_corner_radius_all(PORTRAIT_RADIUS)
	clip.add_theme_stylebox_override("panel", bg)
	mover.add_child(clip)

	var pic := TextureRect.new()
	pic.set_anchors_preset(Control.PRESET_FULL_RECT)
	pic.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	pic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	clip.add_child(pic)


	var portrait: Button = CHARACTER_DROP_TARGET.new()
	portrait.set_anchors_preset(Control.PRESET_FULL_RECT)
	portrait.set("drop_target_id", target)

	portrait.text = glyph
	portrait.focus_mode = Control.FOCUS_NONE
	portrait.add_theme_font_size_override("font_size", 96)
	if tex_path != "" and ResourceLoader.exists(tex_path):
		portrait.text = ""
		pic.texture = load(tex_path)
	portrait.set_meta("tex_rect", pic)
	for state in ["normal", "hover", "pressed", "focus"]:
		portrait.add_theme_stylebox_override(state, UiFrames.portrait(border, state == "pressed", PORTRAIT_RADIUS))
	mover.add_child(portrait)
	portrait.set_meta("mover", mover)



	if target != "":
		var bar := ProgressBar.new()
		bar.show_percentage = false
		bar.custom_minimum_size = Vector2(0, 48)
		bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		bar.add_theme_stylebox_override("fill", UiFrames.bar_fill())
		bar.add_theme_stylebox_override("background", UiFrames.bar_back())
		var txt := Label.new()
		txt.set_anchors_preset(Control.PRESET_FULL_RECT)
		txt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		txt.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		txt.add_theme_font_size_override("font_size", 28)
		txt.add_theme_color_override("font_outline_color", Color.BLACK)
		txt.add_theme_constant_override("outline_size", 6)
		txt.mouse_filter = Control.MOUSE_FILTER_IGNORE
		bar.add_child(txt)
		pod.add_child(bar)
		_bars[target] = bar
		_texts[target] = txt


	var name_label := Label.new()
	name_label.text = label
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.add_theme_font_size_override("font_size", 26)
	name_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	pod.add_child(name_label)

	if target == "player":
		_operative_label = name_label

	if subtitle != "":
		var sub_label := Label.new()
		sub_label.text = subtitle
		sub_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		sub_label.add_theme_font_size_override("font_size", 18)
		sub_label.add_theme_color_override("font_color", Color("bfb7aa"))
		pod.add_child(sub_label)
		if target == "minion":
			_drone_status = sub_label

	return portrait


func _make_bubble(pod: Control) -> void:
	var row: Control = pod.get_node("BubbleRow")
	_bubble = Button.new()
	_bubble.focus_mode = Control.FOCUS_NONE
	_bubble.custom_minimum_size = Vector2(0, BUBBLE_HEIGHT)
	_bubble.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_bubble.add_theme_font_size_override("font_size", 28)
	for c in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
		_bubble.add_theme_color_override(c, Color("fde68a"))
	for state in ["normal", "hover", "pressed", "focus"]:
		_bubble.add_theme_stylebox_override(state, UiFrames.quest_bubble())
	_bubble.pressed.connect(_open_log)
	pod.add_child(_bubble)
	pod.move_child(_bubble, row.get_index())
	row.queue_free()

	_bubble.resized.connect(func() -> void: _bubble.pivot_offset = _bubble.size / 2.0)
	var tween := create_tween().set_loops()
	tween.tween_property(_bubble, "scale", Vector2(1.06, 1.06), 0.9).set_trans(Tween.TRANS_SINE)
	tween.tween_property(_bubble, "scale", Vector2.ONE, 0.9).set_trans(Tween.TRANS_SINE)




func _refresh_bubble() -> void:
	if _bubble:
		_bubble.text = "📜 " + QuestManager.bubble_text()


func _on_energy_updated(target: String, value: float, max_value: float) -> void:
	if not _bars.has(target):
		return
	var bar: ProgressBar = _bars[target]
	bar.max_value = max_value
	bar.value = value
	_texts[target].text = "%d / %d" % [int(value), int(max_value)]


func _refresh_status() -> void:
	if _drone_status:
		var st := MinionSystem.status_text()
		if st != "":
			_drone_status.text = st
			_drone_status.add_theme_color_override("font_color", Color("f59e0b"))
		else:
			_drone_status.text = "SCAVENGER"
			_drone_status.add_theme_color_override("font_color", Color("bfb7aa"))


func _open_log() -> void:
	GameState.modal_requested.emit("fabricator_log")


func _on_drone_held() -> void:
	if MinionSystem.cargo_pod != null or MinionSystem.is_scavenging:
		return
	_beaming = true
	if MinionSystem.scavenge():
		_beam.start()


func _on_beam_tick() -> void:
	if not MinionSystem.is_scavenging:
		if not MinionSystem.scavenge():
			_beam.stop()


func _on_drone_pressed() -> void:
	if _beaming:
		_beaming = false
		return
	MinionSystem.interact()


