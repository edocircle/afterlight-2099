extends Node

func _ready() -> void:
	var path := "res://assets/sprites/characters/debug_src.png"
	var bytes := FileAccess.get_file_as_bytes(path)
	var src := Image.new()
	var err := src.load_png_from_buffer(bytes)
	var log_f := FileAccess.open("res://scripts/tools/size.txt", FileAccess.WRITE)
	log_f.store_line("debug_src bytes: %d, err: %d, size: %dx%d" % [bytes.size(), err, src.get_width(), src.get_height()])
	log_f.flush()
	if err != OK:
		log_f.store_line("FAILED LOAD debug_src: %d" % err)
		log_f.close()
		get_tree().quit(1)
		return

	# Precise 9 pose bounding boxes inside 2048x2048:
	# Row 0: Y from 24 to 585 (4 poses across 2048)
	# 1. Closing Eyes: X=[25, 485], Y=[24, 580]
	# 2. Thinking: X=[535, 995], Y=[24, 580]
	# 3. Master Crafting: X=[1045, 1500], Y=[24, 580]
	# 4. Starting to be Tired: X=[1555, 2015], Y=[24, 580]
	#
	# Row 1: Y from 700 to 1270 (3 poses across 2048)
	# 5. Very Tired/Exhausted: X=[45, 630], Y=[700, 1265]
	# 6. Eating Happily: X=[780, 1310], Y=[700, 1265]
	# 7. Curious: X=[1440, 1990], Y=[700, 1265]
	#
	# Row 2: Y from 1380 to 1960 (3 poses across 2048)
	# 8. Eating: X=[95, 620], Y=[1380, 1945]
	# 9. Joyful Crafter: X=[1440, 2015], Y=[1380, 1945]

	var cuts := {
		"closing_eyes": Rect2i(25, 24, 460, 560),
		"thinking": Rect2i(535, 24, 465, 560),
		"master_crafting": Rect2i(1045, 24, 465, 560),
		"starting_tired": Rect2i(1555, 24, 465, 560),
		"exhausted": Rect2i(45, 700, 585, 565),
		"eating_happily": Rect2i(780, 700, 540, 565),
		"curious": Rect2i(1440, 700, 550, 565),
		"eating": Rect2i(95, 1380, 530, 565),
		"joyful_crafter": Rect2i(1440, 1380, 575, 565)
	}

	for anim_name in cuts:
		var rect: Rect2i = cuts[anim_name]
		var sub := src.get_region(rect)
		sub.convert(Image.FORMAT_RGBA8)

		var sub_nz := 0
		for y in range(0, sub.get_height(), 10):
			for x in range(0, sub.get_width(), 10):
				var c := sub.get_pixel(x, y)
				if c.r > 0.08 or c.g > 0.08 or c.b > 0.08:
					sub_nz += 1

		var cleaned := _make_transparent(sub)

		var cl_nz := 0
		for y in range(0, cleaned.get_height(), 10):
			for x in range(0, cleaned.get_width(), 10):
				var c := cleaned.get_pixel(x, y)
				if c.a > 0.08:
					cl_nz += 1

		log_f.store_line("%s: sub_nz=%d, cl_nz=%d" % [anim_name, sub_nz, cl_nz])
		log_f.flush()

		# Make it square with padding so all poses have consistent centering
		var max_dim := maxi(cleaned.get_width(), cleaned.get_height()) + 20
		var square := Image.create(max_dim, max_dim, false, Image.FORMAT_RGBA8)
		square.fill(Color(0, 0, 0, 0))
		var ox := (max_dim - cleaned.get_width()) / 2
		var oy := (max_dim - cleaned.get_height()) / 2
		square.blit_rect(cleaned, Rect2i(0, 0, cleaned.get_width(), cleaned.get_height()), Vector2i(ox, oy))

		# Resize cleanly to 512x512
		square.resize(512, 512, Image.INTERPOLATE_LANCZOS)
		var out_path := "res://assets/sprites/characters/pete_%s.png" % anim_name
		square.save_png(out_path)
		log_f.store_line("SUCCESS: %s" % out_path)
		log_f.flush()

	log_f.store_line("ALL_EXTRACTION_COMPLETED_SUCCESSFULLY")
	log_f.close()
	get_tree().quit(0)


func _make_transparent(img: Image) -> Image:
	var w: int = img.get_width()
	var h: int = img.get_height()
	var out := Image.create(w, h, false, Image.FORMAT_RGBA8)

	# BFS from corners/edges to remove outside black backdrop
	var visited := []
	visited.resize(w * h)
	visited.fill(false)

	var queue: Array[Vector2i] = []

	# Seeds: border pixels where max(r,g,b) < 0.08
	for x in range(w):
		_add_seed(x, 0, img, visited, queue)
		_add_seed(x, h - 1, img, visited, queue)
	for y in range(h):
		_add_seed(0, y, img, visited, queue)
		_add_seed(w - 1, y, img, visited, queue)

	var head: int = 0
	while head < queue.size():
		var p: Vector2i = queue[head]
		head += 1

		var neighbors := [
			Vector2i(p.x + 1, p.y),
			Vector2i(p.x - 1, p.y),
			Vector2i(p.x, p.y + 1),
			Vector2i(p.x, p.y - 1)
		]

		for n: Vector2i in neighbors:
			if n.x >= 0 and n.x < w and n.y >= 0 and n.y < h:
				var idx: int = n.y * w + n.x
				if not visited[idx]:
					var c: Color = img.get_pixel(n.x, n.y)
					var max_c: float = maxf(c.r, maxf(c.g, c.b))
					# Flood-fill black backdrop
					if max_c < 0.08:
						visited[idx] = true
						queue.append(n)

	# Write out pixels with smooth antialiased outer alpha
	for y in range(h):
		for x in range(w):
			var idx: int = y * w + x
			if visited[idx]:
				out.set_pixel(x, y, Color(0, 0, 0, 0))
			else:
				var c: Color = img.get_pixel(x, y)
				var max_c: float = maxf(c.r, maxf(c.g, c.b))
				if max_c < 0.16:
					var has_bg_neighbor: bool = false
					for dy in [-1, 0, 1]:
						for dx in [-1, 0, 1]:
							var nx: int = x + dx
							var ny: int = y + dy
							if nx >= 0 and nx < w and ny >= 0 and ny < h:
								if visited[ny * w + nx]:
									has_bg_neighbor = true
									break
						if has_bg_neighbor:
							break
					if has_bg_neighbor:
						var alpha: float = clampf((max_c - 0.04) / 0.12, 0.0, 1.0)
						out.set_pixel(x, y, Color(c.r, c.g, c.b, alpha))
					else:
						out.set_pixel(x, y, c)
				else:
					out.set_pixel(x, y, c)

	return out


func _add_seed(x: int, y: int, img: Image, visited: Array, queue: Array[Vector2i]) -> void:
	var w: int = img.get_width()
	var idx: int = y * w + x
	if not visited[idx]:
		var c: Color = img.get_pixel(x, y)
		var max_c: float = maxf(c.r, maxf(c.g, c.b))
		if max_c < 0.08:
			visited[idx] = true
			queue.append(Vector2i(x, y))
