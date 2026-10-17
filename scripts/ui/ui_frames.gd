class_name UiFrames
extends RefCounted
## Shared frame styles matching the HUD prototype (Ref screenshot):
## dark navy rim -> glowing cyan / orange / steel border -> deep teal fill -> thin inner bevel line.
## Frames only - no layout or content changes.

const RIM := Color("051a26")
const CYAN := Color("2fd8f2")
const CYAN_SOFT := Color("8beaf8")
const FILL := Color("0f3a4f")
const FILL_HOVER := Color("145068")
const FILL_PRESSED := Color("0a2a3a")
const BEVEL := Color("23637b")
const ORANGE := Color("f08c2a")
const ORANGE_SOFT := Color("ffb15c")
const GOLD := Color("e8b04a")
const STEEL := Color("3f6676")
const STEEL_LIGHT := Color("a9c7d1")


static func flat(fill: Color, border: Color = Color(0, 0, 0, 0), width: int = 0, radius: int = 16, center: bool = true) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = fill
	sb.draw_center = center
	sb.border_color = border
	sb.set_border_width_all(width)
	sb.set_corner_radius_all(radius)
	sb.anti_aliasing = true
	return sb


static func _glow(sb: StyleBoxFlat, color: Color, alpha: float, size: int) -> StyleBoxFlat:
	sb.shadow_color = Color(color, alpha)
	sb.shadow_size = size
	return sb


## Inventory / drawer slot: thick glowing cyan frame with a brighter bottom edge.
static func slot(state: String = "normal", accent: Color = CYAN) -> LayeredStyleBox:
	var fill := FILL
	var border := accent
	var glow := 0.30
	match state:
		"hover":
			fill = FILL_HOVER
			border = accent.lightened(0.25)
			glow = 0.45
		"pressed":
			fill = FILL_PRESSED
			border = accent.lightened(0.4)
			glow = 0.55
	var ring := flat(fill, border, 4, 17)
	ring.border_width_bottom = 6
	var box := LayeredStyleBox.new()
	box.add_layer(_glow(flat(RIM, Color(0, 0, 0, 0), 0, 20), accent, glow, 6), 0)
	box.add_layer(ring, 3)
	box.add_layer(flat(Color(0, 0, 0, 0), BEVEL, 2, 12, false), 10)
	return box


## Crafting bench input / tool slot: orange frame variant.
static func bench_slot(state: String = "normal") -> LayeredStyleBox:
	return slot(state, ORANGE)


## Big HUD panel (character trio, mini map, drawer).
static func panel(margin: float = 24.0) -> LayeredStyleBox:
	var outer := flat(RIM, Color(0, 0, 0, 0), 0, 34)
	outer.shadow_color = Color(0, 0, 0, 0.45)
	outer.shadow_size = 10
	var box := LayeredStyleBox.new()
	box.add_layer(outer, 0)
	box.add_layer(flat(Color("123c52", 0.95), Color("62cde2"), 5, 31), 3)
	box.add_layer(flat(Color(0, 0, 0, 0), Color("2a7690", 0.75), 2, 22, false), 14)
	box.set_margins(margin)
	return box


## Crafting slab: steel body, light rim and an orange-lined inner recess.
static func slab(margin: float = 28.0) -> LayeredStyleBox:
	var outer := flat(RIM, Color(0, 0, 0, 0), 0, 30)
	outer.shadow_color = Color(0, 0, 0, 0.45)
	outer.shadow_size = 10
	var box := LayeredStyleBox.new()
	box.add_layer(outer, 0)
	box.add_layer(flat(Color("2a6a80"), Color("8fd3e2"), 4, 27), 3)
	box.add_layer(flat(Color("164a60"), ORANGE, 3, 18), 12)
	box.set_margins(margin)
	return box


## Primary action button (Construct).
static func action_button(state: String = "normal") -> LayeredStyleBox:
	var fill := Color("0d3a50")
	var border := CYAN
	var glow := 0.35
	match state:
		"hover":
			fill = FILL_HOVER
			border = CYAN_SOFT
			glow = 0.5
		"pressed":
			fill = FILL_PRESSED
			border = CYAN_SOFT
			glow = 0.6
		"disabled":
			fill = Color("0a2533")
			border = Color("1e4a68")
			glow = 0.0
	var box := LayeredStyleBox.new()
	box.add_layer(_glow(flat(RIM, Color(0, 0, 0, 0), 0, 24), CYAN, glow, 6), 0)
	box.add_layer(flat(fill, border, 5, 21), 3)
	box.add_layer(flat(Color(0, 0, 0, 0), Color("2a8aa6", 0.8 if state != "disabled" else 0.3), 2, 14, false), 11)
	box.set_margins(12)
	return box


## Small utility button (EXPAND, CLOSE).
static func small_button(state: String = "normal") -> LayeredStyleBox:
	var fill := Color("0d3a50")
	var border := CYAN
	match state:
		"hover":
			fill = FILL_HOVER
			border = CYAN_SOFT
		"pressed":
			fill = FILL_PRESSED
			border = CYAN_SOFT
	var box := LayeredStyleBox.new()
	box.add_layer(flat(RIM, Color(0, 0, 0, 0), 0, 14), 0)
	box.add_layer(flat(fill, border, 3, 12), 2)
	box.content_margin_left = 16
	box.content_margin_right = 16
	box.content_margin_top = 6
	box.content_margin_bottom = 6
	return box


## Round top-bar button: metallic outer ring, dark gap, glowing cyan inner ring.
static func circle_button(state: String = "normal") -> LayeredStyleBox:
	var fill := Color("14475c")
	var ring := CYAN
	match state:
		"hover":
			fill = Color("1a5a73")
			ring = CYAN_SOFT
		"pressed":
			fill = Color("0c3344")
			ring = CYAN_SOFT
	var metal := flat(STEEL, STEEL_LIGHT, 4, 999)
	metal.shadow_color = Color(0, 0, 0, 0.5)
	metal.shadow_size = 8
	var inner := _glow(flat(fill, ring, 3, 999), CYAN, 0.35, 5)
	var box := LayeredStyleBox.new()
	box.add_layer(metal, 0)
	box.add_layer(flat(RIM, Color(0, 0, 0, 0), 0, 999), 9)
	box.add_layer(inner, 12)
	box.add_layer(flat(Color(0, 0, 0, 0), Color(1, 1, 1, 0.12), 2, 999, false), 18)
	return box


## Pipe connecting the round top-bar buttons.
static func pipe() -> LayeredStyleBox:
	var box := LayeredStyleBox.new()
	box.add_layer(flat(RIM, Color(0, 0, 0, 0), 0, 20), 0)
	box.add_layer(flat(STEEL, STEEL_LIGHT, 3, 18), 2)
	box.add_layer(flat(Color(0, 0, 0, 0), Color(1, 1, 1, 0.18), 2, 12, false), 8)
	return box


## Portrait overlay frame (drawn on top of the picture, so no fill and no shadow).
static func portrait(border: Color, pressed: bool, radius: int = 40) -> LayeredStyleBox:
	var box := LayeredStyleBox.new()
	box.add_layer(flat(Color(0, 0, 0, 0), RIM, 9, radius, false), 0)
	box.add_layer(flat(Color(0, 0, 0, 0), border, 5, radius - 3, false), 3)
	box.add_layer(flat(Color(0, 0, 0, 0), Color(1, 1, 1, 0.35), 2, radius - 8, false), 8)
	if pressed:
		box.add_layer(flat(Color(0, 0, 0, 0.22), Color(0, 0, 0, 0), 0, radius - 9), 9)
	return box


## Glow behind the portrait (applied to the backing panel, beneath the picture).
static func portrait_backing(border: Color, fill: Color, radius: int = 40) -> StyleBoxFlat:
	return _glow(flat(fill, Color(0, 0, 0, 0), 0, radius), border, 0.45, 9)


static func bar_back() -> LayeredStyleBox:
	var box := LayeredStyleBox.new()
	box.add_layer(flat(RIM, Color(0, 0, 0, 0), 0, 24), 0)
	box.add_layer(flat(Color("0a1f2e"), Color("4fc9e0"), 3, 22), 2)
	return box


static func bar_fill() -> StyleBoxFlat:
	var sb := flat(CYAN, Color("b9f4fc"), 0, 22)
	sb.border_width_top = 3
	return sb


static func quest_bubble() -> LayeredStyleBox:
	var box := LayeredStyleBox.new()
	box.add_layer(_glow(flat(RIM, Color(0, 0, 0, 0), 0, 20), CYAN, 0.3, 5), 0)
	box.add_layer(flat(Color("0f3b50"), CYAN_SOFT, 3, 18), 2)
	box.content_margin_left = 24
	box.content_margin_right = 24
	return box
