extends Node

func _ready() -> void:
	var path := "res://assets/sprites/characters/robot_animation.jfif"
	var f := FileAccess.open(path, FileAccess.READ)
	var buf := f.get_buffer(f.get_length())
	var src := Image.new()
	src.load_jpg_from_buffer(buf)
	
	var w := src.get_width() # 1696
	var h := src.get_height() # 2528

	# Check the row bounds carefully:
	# Row 0: y_start = 30, y_end = 560
	# Row 1: y_start = 640, y_end = 1190
	# Row 2: y_start = 1270, y_end = 1820
	# Row 3: y_start = 1900, y_end = 2450

	var row_bounds := [
		{"y_start": 30, "y_end": 560},
		{"y_start": 640, "y_end": 1190},
		{"y_start": 1270, "y_end": 1820},
		{"y_start": 1900, "y_end": 2450}
	]

	var col_w := float(w) / 2.0

	var poses := [
		{"name": "bot_idling_happy", "col": 0, "row": 0},
		{"name": "bot_off_rest", "col": 1, "row": 0},
		{"name": "bot_analyzing", "col": 0, "row": 1},
		{"name": "bot_searching", "col": 1, "row": 1},
		{"name": "bot_buffering", "col": 0, "row": 2},
		{"name": "bot_error_shock", "col": 1, "row": 2},
		{"name": "bot_excited", "col": 0, "row": 3},
		{"name": "bot_battery_low", "col": 1, "row": 3},
	]

	for p in poses:
		var c: int = p["col"]
		var r: int = p["row"]
		var name_str: String = p["name"]

		var cell_x := int(c * col_w)
		var y_start: int = row_bounds[r]["y_start"]
		var y_end: int = row_bounds[r]["y_end"]
		var cell_y := y_start
		var cell_w_int := int(col_w)
		var cell_h_int := y_end - y_start

		var cell_rect := Rect2i(cell_x, cell_y, cell_w_int, cell_h_int)
		var cell_img := src.get_region(cell_rect)
		cell_img.convert(Image.FORMAT_RGBA8)

		var iw := cell_img.get_width()
		var ih := cell_img.get_height()

		# Flood fill transparency from borders
		var visited := PackedByteArray()
		visited.resize(iw * ih)
		visited.fill(0)

		var queue: Array[Vector2i] = []
		for x in iw:
			queue.append(Vector2i(x, 0))
			queue.append(Vector2i(x, ih - 1))
		for y in ih:
			queue.append(Vector2i(0, y))
			queue.append(Vector2i(iw - 1, y))

		while not queue.is_empty():
			var pt: Vector2i = queue.pop_back()
			var idx := pt.y * iw + pt.x
			if visited[idx] == 1:
				continue
			visited[idx] = 1

			var col := cell_img.get_pixel(pt.x, pt.y)
			# Background detection: off-white paper
			var is_bg := (col.r > 0.85 and col.g > 0.85 and col.b > 0.85) or (col.r > 0.80 and col.g > 0.80 and col.b > 0.80 and absf(col.r - col.g) < 0.04 and absf(col.g - col.b) < 0.04)
			if is_bg:
				cell_img.set_pixel(pt.x, pt.y, Color(0, 0, 0, 0))
				if pt.x > 0 and visited[pt.y * iw + (pt.x - 1)] == 0:
					queue.append(Vector2i(pt.x - 1, pt.y))
				if pt.x < iw - 1 and visited[pt.y * iw + (pt.x + 1)] == 0:
					queue.append(Vector2i(pt.x + 1, pt.y))
				if pt.y > 0 and visited[(pt.y - 1) * iw + pt.x] == 0:
					queue.append(Vector2i(pt.x, pt.y - 1))
				if pt.y < ih - 1 and visited[(pt.y + 1) * iw + pt.x] == 0:
					queue.append(Vector2i(pt.x, pt.y + 1))

		# Find connected components of non-transparent pixels!
		# Keep only the largest connected component(s) that belong to the bot + sparks/sweat
		# Any isolated component that touches the top 30 px or bottom 50 px is text!
		var comp_visited := PackedByteArray()
		comp_visited.resize(iw * ih)
		comp_visited.fill(0)

		var components: Array[Array] = []
		for y in ih:
			for x in iw:
				var c_idx := y * iw + x
				if comp_visited[c_idx] == 0 and cell_img.get_pixel(x, y).a > 0.1:
					var comp: Array[Vector2i] = []
					var c_queue: Array[Vector2i] = [Vector2i(x, y)]
					comp_visited[c_idx] = 1
					var comp_min_y := y
					var comp_max_y := y

					while not c_queue.is_empty():
						var cp: Vector2i = c_queue.pop_back()
						comp.append(cp)
						if cp.y < comp_min_y: comp_min_y = cp.y
						if cp.y > comp_max_y: comp_max_y = cp.y

						var neighbors := [
							Vector2i(cp.x - 1, cp.y), Vector2i(cp.x + 1, cp.y),
							Vector2i(cp.x, cp.y - 1), Vector2i(cp.x, cp.y + 1)
						]
						for n in neighbors:
							if n.x >= 0 and n.x < iw and n.y >= 0 and n.y < ih:
								var n_idx: int = n.y * iw + n.x
								if comp_visited[n_idx] == 0 and cell_img.get_pixel(n.x, n.y).a > 0.1:
									comp_visited[n_idx] = 1
									c_queue.append(n)

					# If component is in the text band at top (comp_max_y < 80) or bottom (comp_min_y > ih - 60):
					# and total pixel count is small (text letters are < 5000 pixels): erase it!
					if (comp_max_y < 80 and comp.size() < 6000) or (comp_min_y > ih - 65 and comp.size() < 6000):
						for pxl in comp:
							cell_img.set_pixel(pxl.x, pxl.y, Color(0, 0, 0, 0))

		var min_x := iw
		var min_y := ih
		var max_x := 0
		var max_y := 0

		for y in ih:
			for x in iw:
				var px := cell_img.get_pixel(x, y)
				if px.a > 0.1:
					if x < min_x: min_x = x
					if x > max_x: max_x = x
					if y < min_y: min_y = y
					if y > max_y: max_y = y

		if min_x <= max_x and min_y <= max_y:
			var pad := 10
			min_x = maxi(0, min_x - pad)
			min_y = maxi(0, min_y - pad)
			max_x = mini(iw - 1, max_x + pad)
			max_y = mini(ih - 1, max_y + pad)

			var crop_w := max_x - min_x + 1
			var crop_h := max_y - min_y + 1
			var cropped := cell_img.get_region(Rect2i(min_x, min_y, crop_w, crop_h))

			var out_sq := Image.create(512, 512, false, Image.FORMAT_RGBA8)
			out_sq.fill(Color(0, 0, 0, 0))

			var max_dim := maxi(crop_w, crop_h)
			var scale_factor := 480.0 / float(max_dim)
			var target_w := int(crop_w * scale_factor)
			var target_h := int(crop_h * scale_factor)
			cropped.resize(target_w, target_h, Image.INTERPOLATE_LANCZOS)

			var dst_x := (512 - target_w) / 2
			var dst_y := (512 - target_h) / 2
			out_sq.blit_rect(cropped, Rect2i(0, 0, target_w, target_h), Vector2i(dst_x, dst_y))

			var save_path := "res://assets/sprites/characters/%s.png" % name_str
			out_sq.save_png(save_path)
			print("SPOTLESS SAVED: ", save_path)

	get_tree().quit()
