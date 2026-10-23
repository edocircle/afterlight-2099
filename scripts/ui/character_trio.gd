class_name CharacterTrio
extends PanelContainer
## Operative Fabricator (left), Master Fabricator NPC (center), Worker Drone (right).
## Operative features dedicated floating access icons: Neural Skills Core (🧠) and Tactical Rig (🎒).

const PORTRAIT_SIZE := 252
const PORTRAIT_RADIUS := 40
const BOT_RUN_DISTANCE := 50.0
const PETE_TEX := "res://assets/sprites/characters/pete.png"
const MAYOR_TEX := "res://assets/sprites/characters/mayor_thomas.png"
const BOT_TEX := "res://assets/sprites/characters/helper_bot.png"

# Pete animated action sprites (extracted from pete_animation.jfif)
const PETE_CLOSING_EYES := "res://assets/sprites/characters/pete_closing_eyes.png"
const PETE_THINKING := "res://assets/sprites/characters/pete_thinking.png"
const PETE_CURIOUS := "res://assets/sprites/characters/pete_curious.png"
const PETE_JOYFUL := "res://assets/sprites/characters/pete_joyful_crafter.png"
const PETE_MASTER_CRAFTING := "res://assets/sprites/characters/pete_master_crafting.png"
const PETE_STARTING_TIRED := "res://assets/sprites/characters/pete_starting_tired.png"
const PETE_EXHAUSTED := "res://assets/sprites/characters/pete_exhausted.png"
const PETE_EATING_HAPPILY := "res://assets/sprites/characters/pete_eating_happily.png"

# Bot animated action sprites (extracted from robot_animation.jfif)
const BOT_IDLING_HAPPY := "res://assets/sprites/characters/bot_idling_happy.png"
const BOT_OFF_REST := "res://assets/sprites/characters/bot_off_rest.png"
const BOT_ANALYZING := "res://assets/sprites/characters/bot_analyzing.png"
const BOT_SEARCHING := "res://assets/sprites/characters/bot_searching.png"
const BOT_BUFFERING := "res://assets/sprites/characters/bot_buffering.png"
const BOT_ERROR_SHOCK := "res://assets/sprites/characters/bot_error_shock.png"
const BOT_EXCITED := "res://assets/sprites/characters/bot_excited.png"
const BOT_BATTERY_LOW := "res://assets/sprites/characters/bot_battery_low.png"

const BUBBLE_HEIGHT := 70
const HOLD_SECONDS := 0.5
const BEAM_INTERVAL := 0.6
const CHARACTER_DROP_TARGET := preload("res://scripts/ui/character_drop_target.gd")
const CHARACTER_ANIMATED_FACE := preload("res://scripts/ui/character_animated_face.gd")


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

# Pete animation controller
var _pete_pic_primary: TextureRect
var _pete_pic_secondary: TextureRect
var _pete_fade_tween: Tween
var _pete_action_timer: Timer
var _pete_idle_timer: Timer
var _pete_idle_index: int = 0
var _pete_is_action: bool = false
var _pete_is_low_energy: bool = false
var _pete_idle_sequence: Array[String] = [
	PETE_CLOSING_EYES,
	PETE_THINKING,
	PETE_CURIOUS,
	PETE_JOYFUL
]

# Bot animation controller
var _bot_portrait: Button
var _bot_pic_primary: TextureRect
var _bot_pic_secondary: TextureRect
var _bot_fade_tween: Tween
var _bot_action_timer: Timer
var _bot_idle_timer: Timer
var _bot_idle_index: int = 0
var _bot_is_action: bool = false
var _bot_is_low_energy: bool = false
var _bot_is_depleted: bool = false
var _bot_idle_sequence: Array[String] = [
	BOT_IDLING_HAPPY,
	BOT_OFF_REST,
	BOT_IDLING_HAPPY,
	BOT_ANALYZING
]


func _ready() -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 24)
	add_child(row)

	# 1. Operative (Fabricator / Crafter) - 30% bigger (328x328)
	_operative_portrait = _make_pod(row, GameState.get_avatar_glyph(), GameState.operative_callsign, UiFrames.CYAN_SOFT, "player", "THE BOY PROTAGONIST", PETE_CLOSING_EYES, CHARACTER_ANIMATED_FACE.CharacterType.PETE, 328)
	_operative_portrait.pressed.connect(InventoryManager.consume_food.bind("player"))
	_setup_pete_animation()

	# 2. Master Fabricator (AI Hologram NPC) - 30% bigger (328x328)
	var archon := _make_pod(row, "🧙‍♂️", "MAYOR THOMAS", UiFrames.CYAN_SOFT, "", "THE MAYOR", MAYOR_TEX, CHARACTER_ANIMATED_FACE.CharacterType.MAYOR, 328)
	archon.pressed.connect(_open_log)
	_make_bubble(_pod_of(archon))

	# 3. Worker Drone (Scavenger Minion)
	_bot_portrait = _make_pod(row, "🛸", "HELPER BOT", UiFrames.GOLD, "minion", "SCAVENGER", BOT_IDLING_HAPPY, CHARACTER_ANIMATED_FACE.CharacterType.BOT, PORTRAIT_SIZE)
	var drone := _bot_portrait

	_bot_mover = drone.get_meta("mover", null)
	_setup_bot_animation()
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

	# Remove outer HUD frame so characters sit directly on top of the background
	add_theme_stylebox_override("panel", StyleBoxEmpty.new())




	GameState.energy_updated.connect(_on_energy_updated)
	GameState.identity_updated.connect(_refresh_operative_identity)
	QuestManager.quest_changed.connect(_refresh_bubble)
	MinionSystem.run_state_changed.connect(_refresh_status)
	CraftingSystem.craft_attempted.connect(_on_craft_attempted)
	InventoryManager.food_consumed.connect(_on_food_consumed)
	_on_energy_updated("player", GameState.protag_energy, GameState.max_protag_energy)
	_on_energy_updated("minion", GameState.minion_energy, GameState.max_minion_energy)
	_refresh_bubble()
	_refresh_status()

	var tick := Timer.new() # keeps the run countdown fresh
	tick.wait_time = 1.0
	tick.autostart = true
	tick.timeout.connect(_refresh_status)
	add_child(tick)


func _setup_pete_animation() -> void:
	if _operative_portrait == null:
		return
	_pete_pic_primary = _operative_portrait.get_meta("tex_rect", null)
	if _pete_pic_primary == null:
		return
	var mover: Control = _pete_pic_primary.get_parent()
	_pete_pic_secondary = TextureRect.new()
	_pete_pic_secondary.set_anchors_preset(Control.PRESET_FULL_RECT)
	_pete_pic_secondary.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_pete_pic_secondary.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_pete_pic_secondary.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_pete_pic_secondary.modulate.a = 0.0
	mover.add_child(_pete_pic_secondary)
	# Ensure the button stays on top of the images
	mover.move_child(_operative_portrait, mover.get_child_count() - 1)

	# Action timer to restore idle/tired after temporary reaction (e.g. crafting, eating)
	_pete_action_timer = Timer.new()
	_pete_action_timer.one_shot = true
	_pete_action_timer.timeout.connect(_on_pete_action_finished)
	add_child(_pete_action_timer)

	# Idle animation timer to smoothly cycle through idle sequence
	_pete_idle_timer = Timer.new()
	_pete_idle_timer.wait_time = 2.8
	_pete_idle_timer.autostart = true
	_pete_idle_timer.timeout.connect(_on_pete_idle_tick)
	add_child(_pete_idle_timer)


func _transition_pete_texture(tex_path: String, duration: float = 0.45) -> void:
	if not ResourceLoader.exists(tex_path) or _pete_pic_primary == null or _pete_pic_secondary == null:
		return
	var new_tex := load(tex_path) as Texture2D
	if _pete_pic_primary.texture == new_tex and _pete_pic_primary.modulate.a >= 0.99:
		return

	if _pete_fade_tween != null and _pete_fade_tween.is_running():
		_pete_fade_tween.kill()

	# Prepare secondary with new texture
	_pete_pic_secondary.texture = new_tex
	_pete_pic_secondary.modulate.a = 0.0

	_pete_fade_tween = create_tween()
	# Cross-fade: secondary fades in smoothly
	_pete_fade_tween.tween_property(_pete_pic_secondary, "modulate:a", 1.0, duration).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_pete_fade_tween.tween_callback(func() -> void:
		_pete_pic_primary.texture = new_tex
		_pete_pic_primary.modulate.a = 1.0
		_pete_pic_secondary.modulate.a = 0.0
	)


func _on_pete_idle_tick() -> void:
	if _pete_is_action:
		return
	if _pete_is_low_energy:
		# Stay in "Starting to be Tired" pose
		_transition_pete_texture(PETE_STARTING_TIRED, 0.6)
		return

	# Smoothly advance through the 4 cheerful idle poses:
	# Closing Eyes -> Thinking -> Curious -> Joyful Crafter
	_pete_idle_index = (_pete_idle_index + 1) % _pete_idle_sequence.size()
	_transition_pete_texture(_pete_idle_sequence[_pete_idle_index], 0.5)


func _on_craft_attempted() -> void:
	## When Construct button hit:
	## - if energy < 30%: "Very Tired/Exhausted"
	## - else: "Master Crafting"
	_pete_is_action = true
	var target_tex := PETE_EXHAUSTED if _pete_is_low_energy else PETE_MASTER_CRAFTING
	_transition_pete_texture(target_tex, 0.25)
	_pete_action_timer.start(1.8)


func _on_food_consumed(target: String, _amount: float) -> void:
	if target == "player":
		## When food is given to the boy: "Eating Happily"
		_pete_is_action = true
		_transition_pete_texture(PETE_EATING_HAPPILY, 0.25)
		_pete_action_timer.start(2.0)
	elif target == "minion":
		## When food is given to the bot: "Excited"
		_bot_is_action = true
		_transition_bot_texture(BOT_EXCITED, 0.25)
		_bot_action_timer.start(2.0)


func _on_pete_action_finished() -> void:
	_pete_is_action = false
	if _pete_is_low_energy:
		_transition_pete_texture(PETE_STARTING_TIRED, 0.4)
	else:
		_transition_pete_texture(_pete_idle_sequence[_pete_idle_index], 0.4)


func _setup_bot_animation() -> void:
	if _bot_portrait == null:
		return
	_bot_pic_primary = _bot_portrait.get_meta("tex_rect", null)
	if _bot_pic_primary == null:
		return
	var mover: Control = _bot_pic_primary.get_parent()
	_bot_pic_secondary = TextureRect.new()
	_bot_pic_secondary.set_anchors_preset(Control.PRESET_FULL_RECT)
	_bot_pic_secondary.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_bot_pic_secondary.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_bot_pic_secondary.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_bot_pic_secondary.modulate.a = 0.0
	mover.add_child(_bot_pic_secondary)
	mover.move_child(_bot_portrait, mover.get_child_count() - 1)

	_bot_action_timer = Timer.new()
	_bot_action_timer.one_shot = true
	_bot_action_timer.timeout.connect(_on_bot_action_finished)
	add_child(_bot_action_timer)

	_bot_idle_timer = Timer.new()
	_bot_idle_timer.wait_time = 3.0
	_bot_idle_timer.autostart = true
	_bot_idle_timer.timeout.connect(_on_bot_idle_tick)
	add_child(_bot_idle_timer)


func _transition_bot_texture(tex_path: String, duration: float = 0.45) -> void:
	if not ResourceLoader.exists(tex_path) or _bot_pic_primary == null or _bot_pic_secondary == null:
		return
	var new_tex := load(tex_path) as Texture2D
	if _bot_pic_primary.texture == new_tex and _bot_pic_primary.modulate.a >= 0.99:
		return

	if _bot_fade_tween != null and _bot_fade_tween.is_running():
		_bot_fade_tween.kill()

	_bot_pic_secondary.texture = new_tex
	_bot_pic_secondary.modulate.a = 0.0

	_bot_fade_tween = create_tween()
	_bot_fade_tween.tween_property(_bot_pic_secondary, "modulate:a", 1.0, duration).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_bot_fade_tween.tween_callback(func() -> void:
		_bot_pic_primary.texture = new_tex
		_bot_pic_primary.modulate.a = 1.0
		_bot_pic_secondary.modulate.a = 0.0
	)


func _on_bot_idle_tick() -> void:
	if _bot_is_action:
		return
	if _bot_is_depleted:
		_transition_bot_texture(BOT_BUFFERING, 0.6)
		return
	if _bot_is_low_energy:
		_transition_bot_texture(BOT_BATTERY_LOW, 0.6)
		return

	# Idle cycling: Idling / Happy -> Off / Rest -> Idling / Happy -> Analyzing
	_bot_idle_index = (_bot_idle_index + 1) % _bot_idle_sequence.size()
	_transition_bot_texture(_bot_idle_sequence[_bot_idle_index], 0.5)


func _on_bot_action_finished() -> void:
	_bot_is_action = false
	if _bot_is_depleted:
		_transition_bot_texture(BOT_BUFFERING, 0.4)
	elif _bot_is_low_energy:
		_transition_bot_texture(BOT_BATTERY_LOW, 0.4)
	else:
		_transition_bot_texture(_bot_idle_sequence[_bot_idle_index], 0.4)


func _pod_of(portrait: Button) -> Control:
	# portrait -> mover -> frame -> pod
	return portrait.get_parent().get_parent().get_parent()


func _on_scavenge_started(_duration: float, is_depleted: bool) -> void:
	## Helper Bot dashes down and right, exiting its frame to scout the city!
	if _bot_mover == null:
		return
	_bot_is_action = true
	if is_depleted:
		_transition_bot_texture(BOT_BUFFERING, 0.2)
	else:
		_transition_bot_texture(BOT_SEARCHING, 0.2)

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
	# Show excited reaction upon return with scavenged loot
	_bot_is_action = true
	_transition_bot_texture(BOT_EXCITED, 0.2)
	_bot_action_timer.start(2.0)

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
				pic.texture = load(_pete_idle_sequence[_pete_idle_index])
	if _operative_label:
		_operative_label.text = GameState.operative_callsign


func _make_pod(parent: Control, glyph: String, label: String, _border: Color, target: String, subtitle: String = "", tex_path: String = "", char_type: int = -1, p_size: int = PORTRAIT_SIZE) -> Button:
	var pod := VBoxContainer.new()
	pod.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	pod.alignment = BoxContainer.ALIGNMENT_END
	pod.add_theme_constant_override("separation", 8)
	parent.add_child(pod)

	var spacer := Control.new() # keeps portraits aligned with the NPC's bubble row
	spacer.custom_minimum_size = Vector2(0, BUBBLE_HEIGHT)
	spacer.name = "BubbleRow"
	pod.add_child(spacer)

	# Frame -> Mover (animatable) -> [picture + animated face overlay] + [transparent click target on top]
	var frame := Control.new()
	frame.custom_minimum_size = Vector2(p_size, p_size)
	frame.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	pod.add_child(frame)

	var mover := Control.new()
	mover.set_anchors_preset(Control.PRESET_FULL_RECT)
	mover.mouse_filter = Control.MOUSE_FILTER_IGNORE
	mover.pivot_offset = Vector2(p_size, p_size) / 2.0
	frame.add_child(mover)

	# Gentle idle breathing animation for each character
	var idle_tween := mover.create_tween().set_loops()
	var breath_time := randf_range(2.2, 3.0)
	var breath_scale := 1.025
	idle_tween.tween_property(mover, "scale", Vector2(breath_scale, breath_scale), breath_time).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	idle_tween.tween_property(mover, "scale", Vector2.ONE, breath_time).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

	var pic := TextureRect.new()
	pic.set_anchors_preset(Control.PRESET_FULL_RECT)
	pic.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	pic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	mover.add_child(pic)

	# Add procedural animated face overlay on top of sprite
	if char_type >= 0:
		var face := CHARACTER_ANIMATED_FACE.new()
		face.set_anchors_preset(Control.PRESET_FULL_RECT)
		face.character_type = char_type
		face.target_id = target
		mover.add_child(face)

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
	
	# All frame borders removed - clean transparent click/touch button directly on top of character
	var empty_style := StyleBoxEmpty.new()
	for state in ["normal", "hover", "pressed", "focus", "disabled"]:
		portrait.add_theme_stylebox_override(state, empty_style)
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
		txt.add_theme_color_override("font_color", Color("fef08a")) # Bright warm contrast against blue
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
	name_label.add_theme_color_override("font_color", Color("fef08a")) # Golden amber text contrasting with blue backdrop
	name_label.add_theme_color_override("font_outline_color", Color(0.02, 0.08, 0.14, 0.95))
	name_label.add_theme_constant_override("outline_size", 6)
	pod.add_child(name_label)

	if target == "player":
		_operative_label = name_label

	if subtitle != "":
		var sub_label := Label.new()
		sub_label.text = subtitle
		sub_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		sub_label.add_theme_font_size_override("font_size", 18)
		sub_label.add_theme_color_override("font_color", Color("67e8f9")) # Bright cyan/sky contrast
		sub_label.add_theme_color_override("font_outline_color", Color(0.02, 0.08, 0.14, 0.95))
		sub_label.add_theme_constant_override("outline_size", 4)
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

	if target == "player":
		var ratio := value / maxf(max_value, 1.0)
		var was_low := _pete_is_low_energy
		_pete_is_low_energy = (ratio < 0.30)
		if not _pete_is_action:
			if _pete_is_low_energy and not was_low:
				_transition_pete_texture(PETE_STARTING_TIRED, 0.45)
			elif not _pete_is_low_energy and was_low:
				_transition_pete_texture(_pete_idle_sequence[_pete_idle_index], 0.45)
	elif target == "minion":
		var ratio := value / maxf(max_value, 1.0)
		var was_depleted := _bot_is_depleted
		var was_low := _bot_is_low_energy
		_bot_is_depleted = (value <= 0.0)
		_bot_is_low_energy = (ratio < 0.30 and value > 0.0)
		if not _bot_is_action:
			if _bot_is_depleted and not was_depleted:
				_transition_bot_texture(BOT_BUFFERING, 0.45)
			elif _bot_is_low_energy and (not was_low or was_depleted):
				_transition_bot_texture(BOT_BATTERY_LOW, 0.45)
			elif not _bot_is_low_energy and not _bot_is_depleted and (was_low or was_depleted):
				_transition_bot_texture(_bot_idle_sequence[_bot_idle_index], 0.45)


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
	if _bot_is_depleted or GameState.minion_energy < MinionSystem.ENERGY_COST:
		_bot_is_action = true
		_transition_bot_texture(BOT_ERROR_SHOCK, 0.15)
		_bot_action_timer.start(1.5)
	MinionSystem.interact()


