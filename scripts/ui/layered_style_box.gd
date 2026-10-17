class_name LayeredStyleBox
extends StyleBox
## Draws several StyleBoxFlat layers on top of each other, each inset by its own margin.
## Lets us build multi-ring sci-fi frames (dark rim + metal/cyan border + inner bevel line)
## that a single StyleBoxFlat cannot express.

var layers: Array[StyleBoxFlat] = []
var insets: Array[float] = []


func add_layer(sb: StyleBoxFlat, inset: float = 0.0) -> LayeredStyleBox:
	layers.append(sb)
	insets.append(inset)
	return self


func set_margins(all: float) -> LayeredStyleBox:
	content_margin_left = all
	content_margin_right = all
	content_margin_top = all
	content_margin_bottom = all
	return self


func _draw(to_canvas_item: RID, rect: Rect2) -> void:
	for i in layers.size():
		var r := rect.grow(-insets[i])
		if r.size.x > 0.0 and r.size.y > 0.0:
			layers[i].draw(to_canvas_item, r)
