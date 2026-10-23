extends Node
## One-shot script to remove background from character images and save as transparent PNGs.

func _ready() -> void:
	print("Processing character images for background removal...")
	_remove_bg("res://assets/sprites/characters/pete.jpg", "res://assets/sprites/characters/pete.png")
	_remove_bg("res://assets/sprites/characters/mayor_thomas.jpg", "res://assets/sprites/characters/mayor_thomas.png")
	_remove_bg("res://assets/sprites/characters/helper_bot.jpg", "res://assets/sprites/characters/helper_bot.png")
	print("Finished processing transparent character PNGs.")
	get_tree().quit(0)

func _remove_bg(src_path: String, dst_path: String) -> void:
	if not FileAccess.file_exists(src_path):
		print("Source not found: ", src_path)
		return
	var img := Image.load_from_file(ProjectSettings.globalize_path(src_path))
	if img == null or img.is_empty():
		print("Failed to load: ", src_path)
		return
	
	img.convert(Image.FORMAT_RGBA8)
	var w := img.get_width()
	var h := img.get_height()
	
	# Sample corner colors to get the background color
	var c1 := img.get_pixel(4, 4)
	var c2 := img.get_pixel(w - 5, 4)
	var c3 := img.get_pixel(4, h - 5)
	var c4 := img.get_pixel(w - 5, h - 5)
	var bg_color := (c1 + c2 + c3 + c4) * 0.25
	print(src_path, " sampled background color: ", bg_color)
	
	# Flood fill / BFS from edges so we only remove the OUTER background, not character insides!
	var visited := PackedByteArray()
	visited.resize(w * h)
	visited.fill(0)
	
	var queue: Array[Vector2i] = []
	for x in range(w):
		queue.append(Vector2i(x, 0))
		queue.append(Vector2i(x, h - 1))
	for y in range(1, h - 1):
		queue.append(Vector2i(0, y))
		queue.append(Vector2i(w - 1, y))
		
	var head := 0
	# For helper bot with cream rounded box, background is cream outside the robot
	var threshold := 0.28
	
	while head < queue.size():
		var p: Vector2i = queue[head]
		head += 1
		var idx: int = p.y * w + p.x
		if visited[idx] == 1:
			continue
		visited[idx] = 1
		
		var px := img.get_pixel(p.x, p.y)
		# Calculate Euclidean distance in RGB to corner background color
		var dr := px.r - bg_color.r
		var dg := px.g - bg_color.g
		var db := px.b - bg_color.b
		var dist := sqrt(dr * dr + db * db + dg * dg)
		
		# Helper bot body outline is dark (px.r < 0.45, px.g < 0.45, px.b < 0.45 or luminance < 0.45)
		# Background is cream/white/light off-white
		var is_outline := (px.r * 0.299 + px.g * 0.587 + px.b * 0.114) < 0.45
		var is_bg := not is_outline and (dist < 0.38 or (px.r > 0.85 and px.g > 0.80 and px.b > 0.70))
		
		if is_bg:
			px.a = 0.0
			img.set_pixel(p.x, p.y, px)
			
			# Add 4-directional neighbors
			if p.x > 0 and visited[idx - 1] == 0:
				queue.append(Vector2i(p.x - 1, p.y))
			if p.x < w - 1 and visited[idx + 1] == 0:
				queue.append(Vector2i(p.x + 1, p.y))
			if p.y > 0 and visited[idx - w] == 0:
				queue.append(Vector2i(p.x, p.y - 1))
			if p.y < h - 1 and visited[idx + w] == 0:
				queue.append(Vector2i(p.x, p.y + 1))
	
	var err := img.save_png(ProjectSettings.globalize_path(dst_path))
	print("Saved ", dst_path, " err code: ", err)
