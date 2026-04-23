extends Node

# Professional Procedural Sprite Generator
# Follows "Project Architecture Specification": 3-color ramp, 1px outlines, Center-Bottom offsets.

static func get_shadow(c: Color) -> Color:
	return c.darkened(0.25).lerp(Color("#2a1a3a"), 0.3)

static func get_highlight(c: Color) -> Color:
	return c.lightened(0.2).lerp(Color("#fff4e0"), 0.2)

static func create_actor_texture(base_color: Color, is_player: bool = false) -> ImageTexture:
	var w := 16
	var h := 24
	var img := Image.create(w, h, false, Image.FORMAT_RGBA8)
	
	var c_base := base_color
	var c_shad := get_shadow(c_base)
	var c_high := get_highlight(c_base)
	var c_out  := Color(0, 0, 0, 0.8) # 1px dark interior stroke

	# 1. Fill Body (12x18 block)
	img.fill_rect(Rect2i(2, 4, 12, 18), c_base)
	
	# 2. Add Shadow (Right and Bottom edges)
	img.fill_rect(Rect2i(8, 4, 6, 18), c_shad)
	img.fill_rect(Rect2i(2, 18, 12, 4), c_shad)
	
	# 3. Add Highlight (Top and Left edges)
	img.fill_rect(Rect2i(2, 4, 6, 6), c_high)
	
	# 4. Noir Detail: Gold Tie for Player
	if is_player:
		img.set_pixel(7, 8, Color("#c8a84e"))
		img.set_pixel(7, 9, Color("#c8a84e"))

	# 5. 1px Dark Interior Stroke
	for x in range(2, 14):
		img.set_pixel(x, 4, c_out)
		img.set_pixel(x, 21, c_out)
	for y in range(4, 22):
		img.set_pixel(2, y, c_out)
		img.set_pixel(13, y, c_out)
		
	return ImageTexture.create_from_image(img)

static func create_floor_wood(w: int, h: int) -> ImageTexture:
	var img := Image.create(w, h, false, Image.FORMAT_RGBA8)
	var c_base := Color("#121216") # Cyber-Noir Neutral Gray
	var c_shad := get_shadow(c_base)
	var c_high := get_highlight(c_base)
	
	img.fill(c_base)
	
	# Draw horizontal planks
	var plank_h := 16
	for y in range(0, h, plank_h):
		# Deep seam
		for x in range(w):
			img.set_pixel(x, y, c_shad)
		
		# Grain highlights
		for x in range(0, w, 32):
			var offset = (y / plank_h) % 2 * 16
			var px = (x + offset) % w
			img.set_pixel(px, y + 2, c_high)
			
	return ImageTexture.create_from_image(img)

static func create_floor_carpet(w: int, h: int) -> ImageTexture:
	var img := Image.create(w, h, false, Image.FORMAT_RGBA8)
	var c_base := Color("#35203a")
	var c_shad := get_shadow(c_base)
	
	img.fill(c_base)
	
	# Fine-grain stipple texture
	for i in range((w * h) / 12):
		var x = randi() % w
		var y = randi() % h
		img.set_pixel(x, y, c_shad)
		
	return ImageTexture.create_from_image(img)

static func create_wall_stone(w: int, h: int) -> ImageTexture:
	var img := Image.create(w, h, false, Image.FORMAT_RGBA8)
	var c_base := Color("#1c1c26")
	var c_shad := get_shadow(c_base)
	var c_high := get_highlight(c_base)
	
	img.fill(c_base)
	
	# Heavy masonry pattern
	for y in range(0, h, 24):
		for x in range(w):
			img.set_pixel(x, y, c_shad)
		
		for x in range(0, w, 40):
			var offset = (y / 24) % 2 * 20
			var px = (x + offset) % w
			for py in range(y, min(y + 24, h)):
				img.set_pixel(px, py, c_shad)
				
	# Catch the light on the top edge
	for x in range(w):
		img.set_pixel(x, 0, c_high)
		
	return ImageTexture.create_from_image(img)

static func create_top_surface(w: int, h: int, color: Color) -> ImageTexture:
	var img := Image.create(w, h, false, Image.FORMAT_RGBA8)
	img.fill(color)
	img.fill_rect(Rect2i(0, 0, w, 1), get_highlight(color))
	img.fill_rect(Rect2i(0, h-1, w, 1), get_shadow(color))
	return ImageTexture.create_from_image(img)
