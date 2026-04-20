extends RefCounted

# Shared material + procedural texture helper used by `world_3d.gd`.
# Keeping this logic separate keeps the world controller focused on gameplay
# flow and object placement while still allowing fully procedural visuals.
var texture_cache: Dictionary = {}

func _mix_colors(a: Color, b: Color, t: float) -> Color:
	return Color(
		lerpf(a.r, b.r, t),
		lerpf(a.g, b.g, t),
		lerpf(a.b, b.b, t),
		lerpf(a.a, b.a, t)
	)

func _noise_value(x: float, y: float, seed: int) -> float:
	var value = sin(float(x) * 12.9898 + float(y) * 78.233 + float(seed) * 37.719) * 43758.5453
	return value - floor(value)

func _create_noise_texture(width: int, height: int, base_color: Color, accent_color: Color, seed: int, contrast := 0.35, darken := 0.12, speckle := 0.06) -> Dictionary:
	width = 128
	height = 128
	var albedo_image = Image.create(width, height, false, Image.FORMAT_RGBA8)
	var normal_image = Image.create(width, height, false, Image.FORMAT_RGB8)
	var rough_image = Image.create(width, height, false, Image.FORMAT_RGBA8)

	for y in range(height):
		for x in range(width):
			var tone = 0.0
			var normal_dx = 0.0
			var normal_dy = 0.0
			var amplitude = 1.0
			var frequency = 1.0
			for octave in range(6):
				var nx = x * frequency
				var ny = y * frequency
				var n = _noise_value(nx, ny, seed + octave)
				tone += n * amplitude
				var nx1 = _noise_value(nx + 0.1, ny, seed + octave)
				var ny1 = _noise_value(nx, ny + 0.1, seed + octave)
				normal_dx += (nx1 - n) * amplitude * frequency
				normal_dy += (ny1 - n) * amplitude * frequency
				amplitude *= 0.45
				frequency *= 2.1
			tone = (tone / 2.3 + 0.5) * 0.28
			var color = _mix_colors(base_color, accent_color, tone * contrast)

			var grit1 = _noise_value(x * 4.2 + 11, y * 3.5 + 17, seed + 5)
			var grit2 = _noise_value(x * 8.5 + 23, y * 6.2 + 31, seed + 13)
			var rough = grit1 * 0.6 + grit2 * 0.4
			if grit1 > 0.92:
				color = _mix_colors(color, Color(1, 1, 1, 1), speckle * 1.5)
			elif grit1 < 0.08:
				color = _mix_colors(color, Color(0, 0, 0, 1), darken * 1.3)
			if grit2 > 0.88:
				color = _mix_colors(color, Color(0.8, 0.8, 0.9, 1), 0.08)

			var crack = _noise_value(x * 14 + 47, y * 11 + 53, seed + 29)
			if crack > 0.94:
				color = _mix_colors(color, Color(0.28, 0.28, 0.28, 1), 0.28)
				rough *= 1.4

			albedo_image.set_pixel(x, y, color)
			var nrm = Vector3(normal_dx * 0.5 + 0.5, normal_dy * 0.5 + 0.5, 1.0).normalized()
			normal_image.set_pixel(x, y, Color(nrm.x, nrm.y, rough, 1.0))
			rough_image.set_pixel(x, y, Color(color.r * 0.3 + 0.7, rough, rough, 1.0))

	return {
		"albedo": ImageTexture.create_from_image(albedo_image),
		"normal": ImageTexture.create_from_image(normal_image),
		"roughness": ImageTexture.create_from_image(rough_image)
	}

func _create_tile_texture(width: int, height: int, base_color: Color, accent_color: Color, grout_color: Color, tile_w: int, tile_h: int, seed: int) -> ImageTexture:
	width = 128
	height = 128
	var image = Image.create(width, height, false, Image.FORMAT_RGBA8)

	for y in range(height):
		for x in range(width):
			var tile_x = x % tile_w
			var tile_y = y % tile_h
			var is_grout = tile_x <= 2 or tile_y <= 2 or tile_x >= tile_w - 2 or tile_y >= tile_h - 2
			var color = grout_color
			if not is_grout:
				var tile_tone = 0.0
				var amp = 1.0
				var freq = 1.0
				for o in range(3):
					tile_tone += _noise_value((x + o * 7) * freq, (y + o * 11) * freq, seed + o * 19) * amp
					amp *= 0.6
					freq *= 2.5
				tile_tone = (tile_tone / 1.8 + 0.5) * 0.28
				color = _mix_colors(base_color, accent_color, tile_tone)
				if _noise_value(x * 4 + 37, y * 6 + 43, seed + 67) > 0.96:
					color = _mix_colors(color, Color(0.2, 0.2, 0.2, 1), 0.35)

			if is_grout:
				var grout_var = _noise_value(x * 2 + 5, y * 2 + 7, seed + 23)
				color = _mix_colors(grout_color, Color(grout_color.r * 1.3, grout_color.g * 1.3, grout_color.b * 1.3), grout_var * 0.25)

			if (tile_x <= 3 or tile_y <= 3 or tile_x >= tile_w - 3 or tile_y >= tile_h - 3) and _noise_value(x * 8 + 59, y * 5 + 71, seed + 89) > 0.9:
				color = _mix_colors(color, Color(0.4, 0.4, 0.4, 1), 0.4)

			image.set_pixel(x, y, color)

	return ImageTexture.create_from_image(image)

func _create_brick_texture(width: int, height: int, brick_color: Color, accent_color: Color, mortar_color: Color, brick_w: int, brick_h: int, mortar: int, seed: int) -> ImageTexture:
	width = 128
	height = 128
	var image = Image.create(width, height, false, Image.FORMAT_RGBA8)

	for y in range(height):
		var row = int(floor(float(y) / float(brick_h)))
		var offset = int(brick_w / 2) if row % 2 == 1 else 0
		for x in range(width):
			var shifted_x = int(fposmod(float(x + offset), float(brick_w)))
			var shifted_y = int(fposmod(float(y), float(brick_h)))
			var is_mortar_h = shifted_y < mortar or shifted_y > brick_h - mortar
			var is_mortar_v = shifted_x < mortar
			var is_mortar = is_mortar_h or is_mortar_v

			var color = mortar_color
			if not is_mortar:
				var brick_var = 0.0
				var amp = 1.0
				for o in range(3):
					brick_var += _noise_value(x * 2.1 + o * 13, y * 1.8 + o * 17, seed + o * 23) * amp
					amp *= 0.55
				brick_var = (brick_var / 1.65 + 0.5) * 0.22
				color = _mix_colors(brick_color, accent_color, brick_var)
				if _noise_value(x * 6 + 41, y * 4 + 59, seed + 73) > 0.93:
					color = _mix_colors(color, Color(0.25, 0.25, 0.25, 1), 0.4)

			if is_mortar:
				var mortar_noise = _noise_value(x * 1.5 + 29, y * 1.5 + 37, seed + 47)
				color = _mix_colors(mortar_color, Color(mortar_color.r * 0.8, mortar_color.g * 0.8, mortar_color.b * 0.8), mortar_noise * 0.3)
				if _noise_value(x * 9 + 61, y * 7 + 83, seed + 97) > 0.91:
					color = Color(0.15, 0.15, 0.15, 1)

			if is_mortar_v and shifted_x < mortar * 1.5:
				color = _mix_colors(color, Color(0.12, 0.12, 0.12, 1), 0.6)

			image.set_pixel(x, y, color)

	return ImageTexture.create_from_image(image)

func _create_window_texture(width: int, height: int, frame_color: Color, window_dark: Color, window_lit: Color, cols: int, rows: int, seed: int, lit_only := false) -> ImageTexture:
	width = 128
	height = 192
	var image = Image.create(width, height, false, Image.FORMAT_RGBA8)
	var cell_w = max(8, int(floor(float(width) / float(cols))))
	var cell_h = max(12, int(floor(float(height) / float(rows))))

	for y in range(height):
		for x in range(width):
			var col = int(floor(float(x) / float(cell_w)))
			var row = int(floor(float(y) / float(cell_h)))
			var local_x = x % cell_w
			var local_y = y % cell_h
			var is_frame = (
				(local_x <= 2 or local_y <= 2 or local_x >= cell_w - 3 or local_y >= cell_h - 3)
				or (local_x % (cell_w / 2) <= 1.5 or local_y % (cell_h / 2) <= 1.5)
			)

			var lit_freq1 = _noise_value(col * 5 + 3, row * 7 + 11, seed)
			var lit_freq2 = _noise_value(col * 3 + 17, row * 5 + 23, seed + 41)
			var lit = (lit_freq1 * 0.7 + lit_freq2 * 0.3) > 0.48

			var color = frame_color
			if not is_frame:
				if lit_only:
					color = window_lit if lit else Color(0, 0, 0, 1)
				else:
					var glass_base = window_lit if lit else window_dark
					var reflection = _noise_value(x * 2.5 + 59, y * 1.8 + 71, seed + 89) * 0.15
					color = _mix_colors(glass_base, Color(0.8, 0.9, 1.0, 0.3), reflection)
					if _noise_value(col * 11 + 73, row * 13 + 97, seed + 113) > 0.5:
						var curtain_var = _noise_value(x * 4 + 101, y * 3 + 107, seed + 131)
						color = _mix_colors(color, Color(0.3, 0.25, 0.2, 0.8), curtain_var * 0.6)

			if is_frame and _noise_value(x * 6.2 + 127, y * 4.1 + 139, seed + 151) > 0.92:
				color = _mix_colors(color, Color(0.6, 0.55, 0.5, 1), 0.45)

			image.set_pixel(x, y, color)

	return ImageTexture.create_from_image(image)

func _create_stripe_texture(width: int, height: int, base_color: Color, stripe_color: Color, stripe_size: int, seed: int) -> ImageTexture:
	var image = Image.create(width, height, false, Image.FORMAT_RGBA8)
	for y in range(height):
		for x in range(width):
			var stripe = int(floor(float(x + y) / float(stripe_size))) % 2 == 0
			var color = stripe_color if stripe else base_color
			color = _mix_colors(color, _mix_colors(base_color, stripe_color, _noise_value(x, y, seed)), 0.12)
			image.set_pixel(x, y, color)
	return ImageTexture.create_from_image(image)

func _get_surface_texture(key: String):
	if texture_cache.has(key):
		return texture_cache[key]

	var tex_set = null
	match key:
		"asphalt":
			tex_set = _create_noise_texture(128, 128, Color("171b24"), Color("30394a"), 11, 0.42, 0.15, 0.07)
			tex_set = {
				"albedo": tex_set["albedo"],
				"normal": null
			}
		"concrete":
			tex_set = {"albedo": _create_tile_texture(128, 128, Color("5a616d"), Color("7a818e"), Color("3d434d"), 6, 6, 21), "normal": null}
		"plaza":
			tex_set = {"albedo": _create_tile_texture(128, 128, Color("434c58"), Color("606975"), Color("313843"), 8, 8, 31), "normal": null}
		"warm_tile":
			tex_set = {"albedo": _create_tile_texture(128, 128, Color("5d473f"), Color("74594f"), Color("362923"), 5, 5, 41), "normal": null}
		"stone":
			tex_set = {"albedo": _create_tile_texture(128, 128, Color("535760"), Color("6d727c"), Color("363b44"), 7, 7, 51), "normal": null}
		"service_concrete":
			tex_set = _create_noise_texture(128, 128, Color("2b313c"), Color("46505e"), 61, 0.34, 0.2, 0.05)
			tex_set = {
				"albedo": tex_set["albedo"],
				"normal": null
			}
		"brick":
			tex_set = {"albedo": _create_brick_texture(128, 128, Color("8a8179"), Color("a1968b"), Color("625a54"), 7, 4, 1, 71), "normal": null}
		"dark_brick":
			tex_set = {"albedo": _create_brick_texture(128, 128, Color("495564"), Color("627082"), Color("2f3946"), 7, 4, 1, 81), "normal": null}
		"metal":
			tex_set = {"albedo": _create_tile_texture(128, 128, Color("4b5867"), Color("677584"), Color("36414d"), 7, 16, 91), "normal": null}
		"painted_metal":
			tex_set = _create_noise_texture(128, 128, Color("4c5564"), Color("6e7889"), 101, 0.28, 0.1, 0.04)
			tex_set = {
				"albedo": tex_set["albedo"],
				"normal": null
			}
		"fabric":
			tex_set = {"albedo": _create_stripe_texture(128, 128, Color("a64033"), Color("d17b51"), 4, 111), "normal": null}
		"tower_albedo":
			tex_set = {"albedo": _create_window_texture(128, 192, Color("28303a"), Color("141b24"), Color("667d95"), 4, 6, 121, false), "normal": null}
		"tower_emission":
			tex_set = {"albedo": _create_window_texture(128, 192, Color(0, 0, 0, 1), Color(0, 0, 0, 1), Color("ffd89d"), 4, 6, 121, true), "normal": null}
		_:
			tex_set = null

	if tex_set == null:
		return null
	texture_cache[key] = tex_set
	return tex_set

func configure_material(material: StandardMaterial3D, name: String, color: Color, emissive := false) -> void:
	var lower = name.to_lower()
	material.albedo_color = color
	material.roughness = 0.95
	material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	material.cull_mode = BaseMaterial3D.CULL_BACK
	material.uv1_triplanar = true
	material.uv1_world_triplanar = true
	material.uv1_scale = Vector3(0.85, 0.85, 0.85)

	var tex_set = _get_surface_texture(lower)
	if tex_set and tex_set.has("albedo"):
		material.albedo_texture = tex_set["albedo"]
	if tex_set and tex_set.has("normal") and tex_set["normal"] != null:
		material.normal_enabled = true
		material.normal_texture = tex_set["normal"]
	if tex_set and tex_set.has("roughness") and tex_set["roughness"] != null:
		material.roughness_texture = tex_set["roughness"]
		material.roughness_texture_channel = BaseMaterial3D.TEXTURE_CHANNEL_RED

	if emissive:
		material.emission_enabled = true
		material.emission = color
		material.emission_energy_multiplier = 1.1
		material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		material.albedo_color.a = 0.08
		material.uv1_triplanar = false
		if lower.contains("glow") or lower.contains("safehouse") or lower.contains("subway"):
			material.albedo_color.a = 0.18
		return

	if lower.contains("windowpanel") or lower.contains("glass"):
		material.albedo_color = Color(color.r, color.g, color.b, 0.28)
		material.roughness = 0.08
		material.metallic = 0.12
		material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		material.uv1_triplanar = false
		return

	if lower.contains("puddle"):
		material.albedo_color = Color(color.r, color.g, color.b, 0.68)
		material.roughness = 0.05
		material.metallic = 0.08
		material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		material.uv1_triplanar = false
		return

	if lower.contains("crosswalk") or lower.contains("centerline") or lower.contains("threshold") or lower.contains("rope") or lower.contains("mark"):
		material.uv1_triplanar = false
		material.uv1_scale = Vector3(1.0, 1.0, 1.0)
		return

	if lower.contains("mullion") or lower.contains("trim") or lower.contains("weathering") or lower.contains("coping") or lower.contains("step") or lower.contains("hood") or lower.contains("socle") or lower.contains("chimney") or lower.contains("band") or lower.contains("lintel"):
		material.uv1_triplanar = false
		material.uv1_world_triplanar = false
		material.uv1_scale = Vector3(1.2, 1.2, 1.2)
		material.roughness = 0.88
		material.cull_mode = BaseMaterial3D.CULL_DISABLED
		return

	if lower.contains("lintel") or lower.contains("cornice") or lower.contains("pilaster") or lower.contains("plinth") or lower.contains("awning"):
		material.albedo_texture = _get_surface_texture("stone")["albedo"]
		material.roughness = 0.8
		material.metallic = 0.0
		material.uv1_triplanar = false
		material.uv1_world_triplanar = false
		material.uv1_scale = Vector3(0.5, 0.5, 0.5)
		material.cull_mode = BaseMaterial3D.CULL_BACK
		return

	if lower.contains("fireescape"):
		material.albedo_texture = _get_surface_texture("metal")["albedo"]
		material.metallic = 0.8
		material.roughness = 0.45
		material.uv1_triplanar = false
		material.uv1_world_triplanar = false
		material.uv1_scale = Vector3(0.95, 0.95, 0.95)
		material.cull_mode = BaseMaterial3D.CULL_BACK
		return

	if lower.contains("doorpanel"):
		material.albedo_color = Color(0.15, 0.15, 0.15, 1.0)
		material.metallic = 0.25
		material.roughness = 0.65
		material.uv1_triplanar = false
		material.uv1_scale = Vector3(0.5, 0.5, 0.5)
		return

	if lower.contains("doorframe"):
		material.albedo_texture = _get_surface_texture("stone")["albedo"]
		material.roughness = 0.82
		material.uv1_triplanar = false
		material.uv1_scale = Vector3(0.6, 0.6, 0.6)
		return

	if lower.contains("tower"):
		material.uv1_triplanar = false
		material.uv1_world_triplanar = false
		material.albedo_texture = _get_surface_texture("tower_albedo")["albedo"]
		material.emission_enabled = true
		material.emission = Color("ffd89d")
		material.emission_texture = _get_surface_texture("tower_emission")["albedo"]
		material.emission_energy_multiplier = 1.45
		material.roughness = 0.8
		return

	if (lower.contains("roof") and not (lower.contains("vent") or lower.contains("mechanical"))) or lower.contains("parapet"):
		material.albedo_texture = _get_surface_texture("painted_metal")["albedo"]
		material.metallic = 0.18
		material.roughness = 0.78
		material.uv1_scale = Vector3(0.72, 0.72, 0.72)
		return

	if lower.contains("frontageconnectorfloor"):
		material.albedo_texture = _get_surface_texture("plaza")["albedo"]
		material.roughness = 1.0
		material.uv1_scale = Vector3(0.55, 0.55, 0.55)
	elif lower.contains("galleryhotelconnectorfloor") or lower.contains("hotelofficeconnectorfloor"):
		material.albedo_texture = _get_surface_texture("stone")["albedo"]
		material.uv1_scale = Vector3(0.5, 0.5, 0.5)
	elif lower.contains("officeserviceconnectorfloor"):
		material.albedo_texture = _get_surface_texture("service_concrete")["albedo"]
		material.uv1_scale = Vector3(0.42, 0.42, 0.42)
	elif lower.contains("median") or lower.contains("curb") or lower.contains("dockplatform") or lower.contains("dockstep") or lower.contains("entrystep"):
		material.albedo_texture = _get_surface_texture("concrete")["albedo"]
		material.uv1_scale = Vector3(0.55, 0.55, 0.55)
	elif lower.contains("avenuefloor"):
		material.albedo_texture = _get_surface_texture("asphalt")["albedo"]
		material.roughness = 1.0
		material.uv1_scale = Vector3(0.34, 0.34, 0.34)
	elif lower.contains("sidewalk"):
		material.albedo_texture = _get_surface_texture("concrete")["albedo"]
		material.uv1_scale = Vector3(0.55, 0.55, 0.55)
	elif lower.contains("forecourt") or lower.contains("safehousepad"):
		material.albedo_texture = _get_surface_texture("plaza")["albedo"]
		material.uv1_scale = Vector3(0.55, 0.55, 0.55)
	elif lower.contains("cafefloor"):
		material.albedo_texture = _get_surface_texture("warm_tile")["albedo"]
		material.uv1_scale = Vector3(0.55, 0.55, 0.55)
	elif lower.contains("galleryfloor") or lower.contains("vipfloor") or lower.contains("hotelfloor") or lower.contains("officefloor"):
		material.albedo_texture = _get_surface_texture("stone")["albedo"]
		material.uv1_scale = Vector3(0.5, 0.5, 0.5)
	elif lower.contains("servicefloor") or lower.contains("subwayalleyfloor") or lower.contains("alleyfloor") or lower.contains("servicelane"):
		material.albedo_texture = _get_surface_texture("service_concrete")["albedo"]
		material.uv1_scale = Vector3(0.42, 0.42, 0.42)
	elif lower.contains("massing"):
		material.albedo_texture = _get_surface_texture("dark_brick")["albedo"]
		material.uv1_scale = Vector3(0.5, 0.5, 0.5)
	elif lower.contains("planter"):
		material.albedo_texture = _get_surface_texture("painted_metal")["albedo"]
		material.roughness = 0.7
	elif lower.contains("taxi") or lower.contains("servicevan") or lower.contains("van") or lower.contains("dumpster"):
		material.albedo_texture = _get_surface_texture("painted_metal")["albedo"]
		material.metallic = 0.35
		material.roughness = 0.44
		material.uv1_scale = Vector3(0.95, 0.95, 0.95)
	elif lower.contains("box") or lower.contains("crate"):
		material.albedo_texture = _get_surface_texture("warm_tile")["albedo"]
		material.roughness = 0.68
		material.uv1_scale = Vector3(0.62, 0.62, 0.62)
	elif lower.contains("trashbag"):
		material.albedo_texture = _get_surface_texture("fabric")["albedo"]
		material.roughness = 0.9
		material.metallic = 0.0
		material.uv1_scale = Vector3(0.95, 0.95, 0.95)
	elif lower.contains("sign"):
		material.albedo_texture = _get_surface_texture("painted_metal")["albedo"]
		material.metallic = 0.2
		material.roughness = 0.58
		material.uv1_scale = Vector3(0.75, 0.75, 0.75)
	elif lower.contains("lamp") or lower.contains("pipe") or lower.contains("handle"):
		material.albedo_texture = _get_surface_texture("metal")["albedo"]
		material.metallic = 0.78
		material.roughness = 0.38
		material.uv1_scale = Vector3(1.0, 1.0, 1.0)
	elif lower.contains("metal") or lower.contains("post") or lower.contains("shelter") or lower.contains("cart") or lower.contains("gate") or lower.contains("safe"):
		material.albedo_texture = _get_surface_texture("metal")["albedo"]
		material.metallic = 0.8
		material.roughness = 0.42
		material.uv1_scale = Vector3(0.95, 0.95, 0.95)
	elif lower.contains("stair"):
		material.albedo_texture = _get_surface_texture("metal")["albedo"]
		material.metallic = 0.65
		material.roughness = 0.5
		material.uv1_scale = Vector3(0.95, 0.95, 0.95)
	elif lower.contains("boundary") or lower.contains("subway") or lower.contains("safehouse") or lower.contains("fence") or lower.contains("alley"):
		material.albedo_texture = _get_surface_texture("dark_brick")["albedo"]
		material.uv1_scale = Vector3(0.52, 0.52, 0.52)
	elif lower.contains("west") or lower.contains("north") or lower.contains("south") or lower.contains("east"):
		material.albedo_texture = _get_surface_texture("brick")["albedo"]
		material.uv1_scale = Vector3(0.52, 0.52, 0.52)
	elif lower.contains("awning") or lower.contains("canopy"):
		material.albedo_texture = _get_surface_texture("fabric")["albedo"]
		material.roughness = 0.78
		material.uv1_scale = Vector3(0.8, 0.8, 0.8)
	elif lower.contains("runner"):
		material.albedo_texture = _get_surface_texture("fabric")["albedo"]
		material.roughness = 0.82
		material.uv1_scale = Vector3(0.72, 0.72, 0.72)
	elif lower.contains("vent") or lower.contains("mechanical"):
		material.albedo_texture = _get_surface_texture("metal")["albedo"]
		material.metallic = 0.7
		material.roughness = 0.52
		material.uv1_scale = Vector3(0.9, 0.9, 0.9)
	elif lower.contains("bar") or lower.contains("plinth"):
		material.albedo_texture = _get_surface_texture("stone")["albedo"]
		material.uv1_scale = Vector3(0.62, 0.62, 0.62)
	elif lower.contains("counter") or lower.contains("desk") or lower.contains("bench") or lower.contains("newsstand"):
		material.albedo_texture = _get_surface_texture("warm_tile")["albedo"]
		material.uv1_scale = Vector3(0.72, 0.72, 0.72)
	elif lower.contains("booth") or lower.contains("sofa"):
		material.albedo_texture = _get_surface_texture("fabric")["albedo"]
		material.roughness = 0.84
		material.uv1_scale = Vector3(0.8, 0.8, 0.8)
	elif lower.contains("signpanel"):
		material.albedo_texture = _get_surface_texture("metal")["albedo"]
		material.metallic = 0.35
		material.roughness = 0.4
