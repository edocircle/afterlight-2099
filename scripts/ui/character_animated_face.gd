class_name CharacterAnimatedFace
extends Control
## Custom procedural animated face & expression overlay for:
## 1. Pete (boy protagonist): blinking/closing eyes with cheerful smile, animated open/close mouth.
## 2. Mayor Thomas: cheerful expression, blinking/closing eyes with mustache bob.
## 3. Helper Bot: expressive digital CRT screen with glowing eyes & mouth.
##    Reactions based on energy:
##    - Normal (energy >= 30%): cute happy/smiling robotic cyan face, occasional cheerful winks/bobs.
##    - Tired (0% <= energy < 30%): droopy eyes, flat/wavy mouth, orange/amber glow.
##    - Depleted (energy < 0% or 0): red glowing alarm face, sad downward curves, flickering warning light.

enum CharacterType { PETE, MAYOR, BOT }

@export var character_type: int = CharacterType.PETE
var target_id: String = "" # "player" or "minion"

var _blink_timer: float = 0.0
var _blink_duration: float = 0.18
var _is_blinking: bool = false
var _next_blink_time: float = 2.5

var _mouth_timer: float = 0.0
var _mouth_open_ratio: float = 0.0 # 0.0 closed, 1.0 open

var _bot_expression_timer: float = 0.0
var _bot_idle_mood: int = 0 # 0: happy, 1: wink, 2: look around


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_next_blink_time = randf_range(2.0, 4.5)


func _process(delta: float) -> void:
	_blink_timer += delta
	if _is_blinking:
		if _blink_timer >= _blink_duration:
			_is_blinking = false
			_blink_timer = 0.0
			_next_blink_time = randf_range(2.0, 5.0)
			queue_redraw()
	else:
		if _blink_timer >= _next_blink_time:
			_is_blinking = true
			_blink_timer = 0.0
			queue_redraw()

	if character_type == CharacterType.PETE:
		# Cheerful talking / mouth movement & subtle breathing
		_mouth_timer += delta * 2.8
		var raw_mouth := sin(_mouth_timer)
		# Only open mouth occasionally during cheerful idle chatter
		_mouth_open_ratio = clampf((raw_mouth - 0.2) / 0.8, 0.0, 1.0)
		queue_redraw()
	elif character_type == CharacterType.MAYOR:
		# Subtle cheerful breathing/mustache bob
		_mouth_timer += delta * 2.0
		queue_redraw()
	elif character_type == CharacterType.BOT:
		_bot_expression_timer += delta
		if _bot_expression_timer > 3.5:
			_bot_expression_timer = 0.0
			_bot_idle_mood = randi() % 3
		queue_redraw()


func _draw() -> void:
	match character_type:
		CharacterType.PETE:
			# Pete now uses full multi-pose illustrated sprite artwork;
			# procedural face overlay is disabled for Pete.
			pass
		CharacterType.MAYOR:
			_draw_mayor()
		CharacterType.BOT:
			# Bot now uses full multi-pose illustrated sprite artwork;
			# procedural face overlay is disabled for Bot.
			pass


func _draw_pete() -> void:
	var s := size
	# Center of eyes and mouth on Pete's 1024x1024 source texture scaled to size:
	# Face skin color for eye closing eyelid: #ffd5b8
	var skin_col := Color("ffd5b8")
	var eye_line_col := Color("231512")
	
	# Pete's left and right eye centers relative to portrait box
	var left_eye := Vector2(s.x * 0.355, s.y * 0.54)
	var right_eye := Vector2(s.x * 0.545, s.y * 0.535)
	var eye_w := s.x * 0.095
	var eye_h := s.y * 0.095

	if _is_blinking:
		# Cover open eye with skin tone and draw cheerful curved closed eye "^ ^"
		_draw_curved_closed_eye(left_eye, eye_w, eye_h, skin_col, eye_line_col)
		_draw_curved_closed_eye(right_eye, eye_w, eye_h, skin_col, eye_line_col)

	# Pete mouth
	var mouth_center := Vector2(s.x * 0.445, s.y * 0.655)
	var mouth_w := s.x * 0.12
	# If mouth open ratio is low, we can show cheerful closed smile or animated open smile
	if _mouth_open_ratio > 0.15:
		# Animate mouth talking / smiling wider
		var open_h := s.y * 0.035 * _mouth_open_ratio
		# Mouth cavity
		var pt_l := mouth_center + Vector2(-mouth_w * 0.5, -open_h * 0.2)
		var pt_r := mouth_center + Vector2(mouth_w * 0.5, -open_h * 0.2)
		var pt_b := mouth_center + Vector2(0, open_h * 1.5)
		var poly := PackedVector2Array([pt_l, pt_r, pt_b])
		draw_colored_polygon(poly, Color("4a1212"))
		# Cute tongue
		var tongue_p := mouth_center + Vector2(0, open_h * 1.0)
		draw_circle(tongue_p, mouth_w * 0.28 * _mouth_open_ratio, Color("ff6b81"))


func _draw_mayor() -> void:
	var s := size
	var skin_col := Color("fcd3b8")
	var line_col := Color("301815")
	
	# Mayor eyes
	var left_eye := Vector2(s.x * 0.395, s.y * 0.47)
	var right_eye := Vector2(s.x * 0.595, s.y * 0.47)
	var eye_w := s.x * 0.08
	var eye_h := s.y * 0.06

	if _is_blinking:
		# Draw happy closed squint eyes
		_draw_filled_ellipse(left_eye, eye_w * 0.8, eye_h * 0.9, skin_col)
		_draw_filled_ellipse(right_eye, eye_w * 0.8, eye_h * 0.9, skin_col)
		# Deep happy squint arc
		_draw_curved_closed_eye(left_eye, eye_w * 0.9, eye_h * 0.8, skin_col, line_col)
		_draw_curved_closed_eye(right_eye, eye_w * 0.9, eye_h * 0.8, skin_col, line_col)

	# Cheerful rosy cheek pulsing
	var cheek_col := Color(1.0, 0.4, 0.45, 0.08 + 0.05 * sin(_mouth_timer * 1.5))
	draw_circle(Vector2(s.x * 0.33, s.y * 0.52), s.x * 0.07, cheek_col)
	draw_circle(Vector2(s.x * 0.67, s.y * 0.52), s.x * 0.07, cheek_col)


func _draw_bot() -> void:
	var s := size
	var cur_en := GameState.minion_energy
	var max_en := maxf(1.0, GameState.max_minion_energy)
	var pct := (cur_en / max_en) * 100.0

	# Center of the robot's dark CRT display:
	var screen_center := Vector2(s.x * 0.50, s.y * 0.58)
	var screen_w := s.x * 0.52
	var screen_h := s.y * 0.38

	# First, draw a smooth clean dark overlay over the original screen face so our procedural face displays cleanly!
	var bg_screen := Color("142c38")
	if pct <= 0.0:
		# Red warning glow
		var pulse := 0.2 + 0.15 * sin(Time.get_ticks_msec() * 0.01)
		bg_screen = Color(0.28 + pulse, 0.05, 0.08, 0.95)
	elif pct < 30.0:
		bg_screen = Color(0.24, 0.16, 0.08, 0.95)
	else:
		bg_screen = Color(0.08, 0.19, 0.24, 0.95)

	# Rounded screen patch
	_draw_rounded_rect_center(screen_center, screen_w, screen_h, s.x * 0.08, bg_screen)

	# Screen scanline effect
	for line_y in range(-int(screen_h * 0.45), int(screen_h * 0.45), 6):
		draw_line(
			Vector2(screen_center.x - screen_w * 0.45, screen_center.y + line_y),
			Vector2(screen_center.x + screen_w * 0.45, screen_center.y + line_y),
			Color(0, 0, 0, 0.22),
			1.5
		)

	# Color of LED eyes & mouth:
	var led_color: Color
	if pct <= 0.0:
		# Depleted < 0%: Red LED alarm
		led_color = Color("ff2b42")
	elif pct < 30.0:
		# Tired < 30%: Amber/Orange LED
		led_color = Color("ff9922")
	else:
		# Normal >= 30%: Vibrant glowing cyan LED
		led_color = Color("18efff")

	# Subtle LED glow layer
	var glow_color := Color(led_color.r, led_color.g, led_color.b, 0.35)

	var eye_y := screen_center.y - screen_h * 0.12
	var left_eye_x := screen_center.x - screen_w * 0.26
	var right_eye_x := screen_center.x + screen_w * 0.26
	var eye_r := screen_w * 0.12
	var line_th := s.x * 0.026

	# Draw Expressions based on state:
	if pct <= 0.0:
		# VERY SAD / DEPLETED FACE (Down-angled sad slanted eyes or sad arcs, downward frown mouth)
		# Sad eyes "> <" or downward droop
		var off := eye_r * 0.6
		# Left eye: "\"
		_draw_glow_line(Vector2(left_eye_x - off, eye_y - off * 0.8), Vector2(left_eye_x + off, eye_y + off * 0.8), led_color, glow_color, line_th)
		_draw_glow_line(Vector2(left_eye_x - off, eye_y + off * 0.8), Vector2(left_eye_x + off, eye_y - off * 0.8), led_color, glow_color, line_th)
		# Right eye: "X" or dead line
		_draw_glow_line(Vector2(right_eye_x - off, eye_y - off * 0.8), Vector2(right_eye_x + off, eye_y + off * 0.8), led_color, glow_color, line_th)
		_draw_glow_line(Vector2(right_eye_x - off, eye_y + off * 0.8), Vector2(right_eye_x + off, eye_y - off * 0.8), led_color, glow_color, line_th)

		# Sad trembling frown mouth: downward arc
		var mouth_y := screen_center.y + screen_h * 0.24 + sin(Time.get_ticks_msec() * 0.015) * 1.5
		_draw_glow_arc(Vector2(screen_center.x, mouth_y + 12), eye_r * 1.1, PI + 0.5, TAU - 0.5, 20, led_color, glow_color, line_th)

		# Cute warning text or teardrop
		draw_circle(Vector2(screen_center.x + screen_w * 0.32, eye_y + screen_h * 0.2), 3.5, Color("ff4466"))
	elif pct < 30.0:
		# TIRED / LOW BATTERY (Flat droopy eyelids, wavy tired mouth)
		# Left droopy horizontal line with slight downward angle
		_draw_glow_line(Vector2(left_eye_x - eye_r, eye_y), Vector2(left_eye_x + eye_r, eye_y + 3), led_color, glow_color, line_th)
		_draw_glow_line(Vector2(right_eye_x - eye_r, eye_y + 3), Vector2(right_eye_x + eye_r, eye_y), led_color, glow_color, line_th)

		# Wavy / flat tired mouth
		var mouth_y := screen_center.y + screen_h * 0.22
		var m_pts := PackedVector2Array([
			Vector2(screen_center.x - eye_r * 0.9, mouth_y + 2),
			Vector2(screen_center.x - eye_r * 0.3, mouth_y - 2),
			Vector2(screen_center.x + eye_r * 0.3, mouth_y + 3),
			Vector2(screen_center.x + eye_r * 0.9, mouth_y)
		])
		for i in range(m_pts.size() - 1):
			_draw_glow_line(m_pts[i], m_pts[i + 1], led_color, glow_color, line_th)
	else:
		# NORMAL CHEERFUL ROBOT
		if _is_blinking:
			# Quick happy flat blink "-" "-"
			_draw_glow_line(Vector2(left_eye_x - eye_r * 0.8, eye_y), Vector2(left_eye_x + eye_r * 0.8, eye_y), led_color, glow_color, line_th)
			_draw_glow_line(Vector2(right_eye_x - eye_r * 0.8, eye_y), Vector2(right_eye_x + eye_r * 0.8, eye_y), led_color, glow_color, line_th)
		else:
			if _bot_idle_mood == 1:
				# Wink: Left eye wink arc "^", right eye circular dot "O"
				_draw_glow_arc(Vector2(left_eye_x, eye_y + 6), eye_r * 0.8, PI + 0.3, TAU - 0.3, 16, led_color, glow_color, line_th)
				draw_circle(Vector2(right_eye_x, eye_y), eye_r * 0.65, glow_color)
				draw_circle(Vector2(right_eye_x, eye_y), eye_r * 0.45, led_color)
			else:
				# Signature cute glowing "^" "^" happy inverted arc eyes!
				_draw_glow_arc(Vector2(left_eye_x, eye_y + 6), eye_r * 0.85, PI + 0.25, TAU - 0.25, 18, led_color, glow_color, line_th)
				_draw_glow_arc(Vector2(right_eye_x, eye_y + 6), eye_r * 0.85, PI + 0.25, TAU - 0.25, 18, led_color, glow_color, line_th)

		# Big bright happy smile arc "u"
		var mouth_y := screen_center.y + screen_h * 0.14
		_draw_glow_arc(Vector2(screen_center.x, mouth_y), eye_r * 1.05, 0.35, PI - 0.35, 20, led_color, glow_color, line_th)


func _draw_curved_closed_eye(pos: Vector2, w: float, h: float, bg_col: Color, line_col: Color) -> void:
	_draw_filled_ellipse(pos, w * 0.8, h * 0.8, bg_col)
	# Closed smiling eye arc "^"
	var pts := PackedVector2Array()
	var count := 12
	for i in range(count + 1):
		var t := float(i) / float(count)
		var angle := lerpf(PI * 0.15, PI * 0.85, t)
		var px := pos.x + cos(angle) * w * 0.55
		var py := pos.y - sin(angle) * h * 0.55
		pts.append(Vector2(px, py))
	for i in range(pts.size() - 1):
		draw_line(pts[i], pts[i + 1], line_col, 4.0, true)


func _draw_glow_line(from: Vector2, to: Vector2, col: Color, glow: Color, th: float) -> void:
	draw_line(from, to, glow, th * 2.2, true)
	draw_line(from, to, col, th, true)


func _draw_glow_arc(center: Vector2, radius: float, start_angle: float, end_angle: float, point_count: int, col: Color, glow: Color, width: float) -> void:
	draw_arc(center, radius, start_angle, end_angle, point_count, glow, width * 2.2, true)
	draw_arc(center, radius, start_angle, end_angle, point_count, col, width, true)


func _draw_rounded_rect_center(center: Vector2, w: float, h: float, radius: float, col: Color) -> void:
	var rect := Rect2(center.x - w * 0.5, center.y - h * 0.5, w, h)
	var sb := StyleBoxFlat.new()
	sb.bg_color = col
	sb.set_corner_radius_all(int(radius))
	sb.draw(get_canvas_item(), rect)


func _draw_filled_ellipse(center: Vector2, rx: float, ry: float, col: Color) -> void:
	var pts := PackedVector2Array()
	var count := 24
	for i in range(count):
		var theta := (float(i) / float(count)) * TAU
		pts.append(center + Vector2(cos(theta) * rx, sin(theta) * ry))
	draw_colored_polygon(pts, col)
