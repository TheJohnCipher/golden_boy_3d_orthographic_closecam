
extends Node3D

# This file is the current "everything scene" for the prototype.
# It owns:
# - boot/setup
# - environment lighting
# - procedural city geometry
# - shadow zones
# - NPC spawning
# - mission flow
# - HUD
#
# The companion visual reference for all of the major coordinates below lives in:
# `docs/city_block_map.md`
const PLAYER_SCRIPT = preload("res://scripts/player_3d.gd")
const NPC_SCRIPT = preload("res://scripts/npc_3d.gd")
const SHADOW_ZONE_SCRIPT = preload("res://scripts/shadow_zone_3d.gd")
const PIXEL_VIEWPORT_MIN_HEIGHT = 240
const PIXEL_VIEWPORT_TARGET_DIVISOR = 3
const PIXEL_VIEWPORT_MAX_HEIGHT = 420

# Core scene references created at runtime.
var player = null
var environment = null
var geometry_root = null
var npc_root = null
var marker_root = null
var ui_root = null
var day_sun = null
var moon_light = null
var point_lights = []

# Mission state and actor collections.
var phase = "day"
var contacts = {
	"alibi": false,
	"guest_pass": false,
	"route_intel": false,
}
var contact_npcs = []
var guard_npcs = []
var civilian_npcs = []
var target_npc = null
var extraction_area = null
var extraction_marker = null
var near_extraction = false
var takedown_done = false
var mission_failed = false
var level_complete = false
var suspicion = 0.0
var heat = 8.0
var reputation = 30.0
var money = 0
var current_objective = ""
var message_text = ""
var message_timer = 0.0

# HUD label references and the procedural texture cache.
var hud = {}
var texture_cache = {}

func _ready():
	# Boot order matters here:
	# 1. set the window size
	# 2. create rendering roots and lighting
	# 3. create player and geometry
	# 4. spawn gameplay actors
	# 5. create HUD and initial mission text
	_configure_window_for_native_screen()
	_create_environment_and_lights()
	_create_roots()
	_create_player()
	_build_level_blockout()
	_create_shadow_zones()
	_spawn_level_characters()
	_create_extraction_zone()
	_create_hud()
	_apply_phase_visibility()
	_refresh_objective()
	_show_message("Alleyway stealth run. Work the contacts. Complete the night extraction.")

func _configure_window_for_native_screen():
	# Native resolution, no pixelation for smooth detailed visuals
	var window = get_viewport().get_window()
	var screen = DisplayServer.window_get_current_screen()
	var native_size = DisplayServer.screen_get_size(screen)
	window.content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
	window.size = native_size

func _get_pixel_viewport_size(native_size):
	var pixel_height = clampi(native_size.y / PIXEL_VIEWPORT_TARGET_DIVISOR, PIXEL_VIEWPORT_MIN_HEIGHT, PIXEL_VIEWPORT_MAX_HEIGHT)
	if pixel_height % 2 != 0:
		pixel_height -= 1
	var safe_height = max(native_size.y, 1)
	var aspect = float(native_size.x) / float(safe_height)
	var pixel_width = int(round(aspect * float(pixel_height)))
	if pixel_width % 2 != 0:
		pixel_width -= 1
	return Vector2i(max(pixel_width, 320), pixel_height)

func _process(delta):
	# Messages are timed so short mission feedback fades automatically.
	if message_timer > 0.0:
		message_timer -= delta
		if message_timer <= 0.0:
			message_text = ""
	_update_prompt()
	_update_hud()

func _unhandled_input(event):
	# Global level controls live here instead of in the player script because
	# they affect mission state, scene reload, and window mode.
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_E:
			_handle_interaction()
		elif event.keycode == KEY_TAB:
			if phase == "day":
				if _all_contacts_met():
					_begin_night()
				else:
					_show_message("You are still expected in public. Talk to all three daytime contacts first.")
		elif event.keycode == KEY_R and (mission_failed or level_complete):
			get_tree().reload_current_scene()
		elif event.keycode == KEY_F11:
			var window = get_viewport().get_window()
			if window.mode == Window.MODE_EXCLUSIVE_FULLSCREEN:
				window.mode = Window.MODE_WINDOWED
				_configure_window_for_native_screen()
			else:
				_configure_window_for_native_screen()
				window.mode = Window.MODE_EXCLUSIVE_FULLSCREEN

func _create_environment_and_lights():
	# The block uses one environment plus two directional lights, then flips
	# visibility and ambient energy between day and night.
	var env = Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.08, 0.09, 0.1)  # Darker neutral
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.25, 0.28, 0.3)  # Neutral gray - no blue
	env.ambient_light_energy = 0.35
	environment = WorldEnvironment.new()
	environment.environment = env
	add_child(environment)

	day_sun = DirectionalLight3D.new()
	day_sun.name = "DaySun"
	day_sun.rotation_degrees = Vector3(-58.0, -40.0, 0.0)
	day_sun.light_energy = 2.1
	day_sun.light_color = Color("fff0cf")
	day_sun.shadow_enabled = true
	add_child(day_sun)

	moon_light = DirectionalLight3D.new()
	moon_light.name = "MoonLight"
	moon_light.rotation_degrees = Vector3(-48.0, 120.0, 0.0)
	moon_light.light_energy = 0.38
	moon_light.light_color = Color("7ea0ff")
	moon_light.shadow_enabled = true
	add_child(moon_light)

	_create_point_light("CafeWarmA", Vector3(-16.0, 3.6, 2.0), Color("ffc67a"), 10.0, 2.0)
	_create_point_light("CafeWarmB", Vector3(-11.0, 3.6, 6.0), Color("ffbd69"), 8.5, 1.7)
	_create_point_light("GalleryWarmA", Vector3(0.0, 4.0, 2.5), Color("ffd992"), 11.0, 2.0)
	_create_point_light("GalleryWarmB", Vector3(6.0, 4.0, 8.5), Color("ffd18d"), 10.0, 1.8)
	_create_point_light("HotelWarm", Vector3(18.0, 4.0, 5.5), Color("ffcf87"), 10.0, 1.7)
	_create_point_light("OfficeLamp", Vector3(31.0, 3.2, 8.5), Color("ffd38f"), 9.0, 1.55)
	_create_point_light("StreetLampWest", Vector3(-20.0, 4.8, -19.0), Color("8bb1ff"), 14.0, 1.15)
	_create_point_light("StreetLampMid", Vector3(0.0, 4.8, -19.0), Color("8bb1ff"), 14.0, 1.15)
	_create_point_light("StreetLampEast", Vector3(20.0, 4.8, -19.0), Color("8bb1ff"), 14.0, 1.15)
	_create_point_light("SubwayLamp", Vector3(-24.0, 4.6, 10.5), Color("6d8eff"), 11.0, 1.0)
	_create_point_light("AlleyLamp", Vector3(20.0, 4.6, 18.0), Color("6d8eff"), 12.0, 1.05)
	_create_point_light("ForecourtAccent", Vector3(1.5, 4.2, -5.6), Color("ffd49a"), 11.0, 1.35)
	_create_point_light("HotelValetLamp", Vector3(21.0, 4.0, -4.4), Color("ffd39d"), 9.0, 1.3)
	_create_point_light("DockWorkLight", Vector3(33.0, 3.8, 15.2), Color("b7c8ff"), 8.5, 1.2)

func _create_point_light(name, pos, color, rng, energy):
	# Point lights are stored so phase toggles can show/hide them in one pass.
	var light = OmniLight3D.new()
	light.name = name
	light.position = pos
	light.light_color = color
	light.omni_range = rng
	light.light_energy = energy
	light.shadow_enabled = true
	add_child(light)
	point_lights.append(light)

# The helpers below generate lightweight procedural textures so the city can
# read as asphalt, brick, tile, or glass before real art is imported.
func _mix_colors(a, b, t):
	return Color(
		lerpf(a.r, b.r, t),
		lerpf(a.g, b.g, t),
		lerpf(a.b, b.b, t),
		lerpf(a.a, b.a, t)
	)

func _noise_value(x, y, seed):
	var value = sin(float(x) * 12.9898 + float(y) * 78.233 + float(seed) * 37.719) * 43758.5453
	return value - floor(value)

func _create_noise_texture(width, height, base_color, accent_color, seed, contrast := 0.35, darken := 0.12, speckle := 0.06):
	# Ultra-detailed 128px multi-octave noise with normals/roughness variation - enhanced octaves/normals
	width = 128
	height = 128
	var albedo_image = Image.create(width, height, false, Image.FORMAT_RGBA8)
	var normal_image = Image.create(width, height, false, Image.FORMAT_RGB8)
	var rough_image = Image.create(width, height, false, Image.FORMAT_RGBA8)
	for y in range(height):
		for x in range(width):
			# 6 octaves for richer detail
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
				# Normal map from gradients
				var nx1 = _noise_value(nx + 0.1, ny, seed + octave)
				var ny1 = _noise_value(nx, ny + 0.1, seed + octave)
				normal_dx += (nx1 - n) * amplitude * frequency
				normal_dy += (ny1 - n) * amplitude * frequency
				amplitude *= 0.45
				frequency *= 2.1
			tone = (tone / 2.3 + 0.5) * 0.28  # Normalize/bias
			var color = _mix_colors(base_color, accent_color, tone * contrast)
			
			# Enhanced grit/roughness
			var grit1 = _noise_value(x * 4.2 + 11, y * 3.5 + 17, seed + 5)
			var grit2 = _noise_value(x * 8.5 + 23, y * 6.2 + 31, seed + 13)
			var rough = grit1 * 0.6 + grit2 * 0.4
			if grit1 > 0.92:
				color = _mix_colors(color, Color(1, 1, 1, 1), speckle * 1.5)
			elif grit1 < 0.08:
				color = _mix_colors(color, Color(0, 0, 0, 1), darken * 1.3)
			if grit2 > 0.88:
				color = _mix_colors(color, Color(0.8, 0.8, 0.9, 1), 0.08)
			
			# Fine cracks with roughness boost
			var crack = _noise_value(x * 14 + 47, y * 11 + 53, seed + 29)
			if crack > 0.94:
				color = _mix_colors(color, Color(0.28, 0.28, 0.28, 1), 0.28)
				rough *= 1.4
			
			albedo_image.set_pixel(x, y, color)
			# Pack normal (RG), roughness (B)
			var nrm = Vector3(normal_dx * 0.5 + 0.5, normal_dy * 0.5 + 0.5, 1.0).normalized()
			normal_image.set_pixel(x, y, Color(nrm.x, nrm.y, rough, 1.0))
			rough_image.set_pixel(x, y, Color(color.r * 0.3 + 0.7, rough, rough, 1.0))  # Rough/metal/AO
			
	return {
		"albedo": ImageTexture.create_from_image(albedo_image),
		"normal": ImageTexture.create_from_image(normal_image),
		"roughness": ImageTexture.create_from_image(rough_image)
	}


func _create_tile_texture(width, height, base_color, accent_color, grout_color, tile_w, tile_h, seed):
	# Ultra-detailed tiles with grout variation, edge wear, multi-noise
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
				# Tile surface multi-noise for realism
				var tile_tone = 0.0
				var amp = 1.0
				var freq = 1.0
				for o in range(3):
					tile_tone += _noise_value((x + o*7) * freq, (y + o*11) * freq, seed + o*19) * amp
					amp *= 0.6
					freq *= 2.5
				tile_tone = (tile_tone / 1.8 + 0.5) * 0.28  # Bias toward midtones
				color = _mix_colors(base_color, accent_color, tile_tone)
				
				# Tile defects/cracks
				if _noise_value(x * 4 + 37, y * 6 + 43, seed + 67) > 0.96:
					color = _mix_colors(color, Color(0.2, 0.2, 0.2, 1), 0.35)
			
			# Grout variation (sand/dirt)
			if is_grout:
				var grout_var = _noise_value(x * 2 + 5, y * 2 + 7, seed + 23)
				color = _mix_colors(grout_color, Color(grout_color.r * 1.3, grout_color.g * 1.3, grout_color.b * 1.3), grout_var * 0.25)
			
			# Edge chipping
			if (tile_x <= 3 or tile_y <= 3 or tile_x >= tile_w - 3 or tile_y >= tile_h - 3) and _noise_value(x * 8 + 59, y * 5 + 71, seed + 89) > 0.9:
				color = _mix_colors(color, Color(0.4, 0.4, 0.4, 1), 0.4)
			
			image.set_pixel(x, y, color)
	return ImageTexture.create_from_image(image)

func _create_brick_texture(width, height, brick_color, accent_color, mortar_color, brick_w, brick_h, mortar, seed):
	# Advanced running bond brick with mortar cracks, weathering, multi-patterns
	width = 128
	height = 128
	var image = Image.create(width, height, false, Image.FORMAT_RGBA8)
	for y in range(height):
		var row = int(floor(float(y) / float(brick_h)))
		var offset = int(brick_w / 2) if row % 2 == 1 else 0  # Running bond pattern
		for x in range(width):
			var shifted_x = int(fposmod(float(x + offset), float(brick_w)))
			var shifted_y = int(fposmod(float(y), float(brick_h)))
			var is_mortar_h = shifted_y < mortar or shifted_y > brick_h - mortar
			var is_mortar_v = shifted_x < mortar
			var is_mortar = is_mortar_h or is_mortar_v
			
			var color = mortar_color
			if not is_mortar:
				# Brick surface detail - multi-noise
				var brick_var = 0.0
				var amp = 1.0
				for o in range(3):
					brick_var += _noise_value(x * 2.1 + o*13, y * 1.8 + o*17, seed + o*23) * amp
					amp *= 0.55
				brick_var = (brick_var / 1.65 + 0.5) * 0.22
				color = _mix_colors(brick_color, accent_color, brick_var)
				
				# Brick chips/cracks
				if _noise_value(x * 6 + 41, y * 4 + 59, seed + 73) > 0.93:
					color = _mix_colors(color, Color(0.25, 0.25, 0.25, 1), 0.4)
			
			# Mortar variation & cracks
			if is_mortar:
				var mortar_noise = _noise_value(x * 1.5 + 29, y * 1.5 + 37, seed + 47)
				color = _mix_colors(mortar_color, Color(mortar_color.r * 0.8, mortar_color.g * 0.8, mortar_color.b * 0.8), mortar_noise * 0.3)
				# Mortar cracks
				if _noise_value(x * 9 + 61, y * 7 + 83, seed + 97) > 0.91:
					color = Color(0.15, 0.15, 0.15, 1)
			
			# Vertical mortar joints thicker at edges
			if is_mortar_v and shifted_x < mortar * 1.5:
				color = _mix_colors(color, Color(0.12, 0.12, 0.12, 1), 0.6)
			
			image.set_pixel(x, y, color)
	return ImageTexture.create_from_image(image)

func _create_window_texture(width, height, frame_color, window_dark, window_lit, cols, rows, seed, lit_only := false):
	# Ultra-detailed windows with mullions, curtains, reflections, blinds
	width = 128
	height = 192  # Taller for building scale
	var image = Image.create(width, height, false, Image.FORMAT_RGBA8)
	var cell_w = max(8, int(floor(float(width) / float(cols))))
	var cell_h = max(12, int(floor(float(height) / float(rows))))
	for y in range(height):
		for x in range(width):
			var col = int(floor(float(x) / float(cell_w)))
			var row = int(floor(float(y) / float(cell_h)))
			var local_x = x % cell_w
			var local_y = y % cell_h
			
			# Complex frame with mullions
			var is_frame = (local_x <= 2 or local_y <= 2 or local_x >= cell_w - 3 or local_y >= cell_h - 3) or \
							 (local_x % (cell_w/2) <= 1.5 or local_y % (cell_h/2) <= 1.5)  # Cross mullions
			
			var lit = 0.0
			var lit_freq1 = _noise_value(col * 5 + 3, row * 7 + 11, seed)
			var lit_freq2 = _noise_value(col * 3 + 17, row * 5 + 23, seed + 41)
			lit = (lit_freq1 * 0.7 + lit_freq2 * 0.3) > 0.48
			
			var color = frame_color
			if not is_frame:
				if lit_only:
					color = window_lit if lit else Color(0, 0, 0, 1)
				else:
					# Window glass with reflections/curtains
					var glass_base = window_lit if lit else window_dark
					var reflection = _noise_value(x * 2.5 + 59, y * 1.8 + 71, seed + 89) * 0.15
					color = _mix_colors(glass_base, Color(0.8, 0.9, 1.0, 0.3), reflection)
					
					# Random curtains/blinds (50% panes)
					if _noise_value(col * 11 + 73, row * 13 + 97, seed + 113) > 0.5:
						var curtain_var = _noise_value(x * 4 + 101, y * 3 + 107, seed + 131)
						color = _mix_colors(color, Color(0.3, 0.25, 0.2, 0.8), curtain_var * 0.6)
			
			# Frame wear
			if is_frame and _noise_value(x * 6.2 + 127, y * 4.1 + 139, seed + 151) > 0.92:
				color = _mix_colors(color, Color(0.6, 0.55, 0.5, 1), 0.45)
			
			image.set_pixel(x, y, color)
	return ImageTexture.create_from_image(image)

func _create_stripe_texture(width, height, base_color, stripe_color, stripe_size, seed):
	var image = Image.create(width, height, false, Image.FORMAT_RGBA8)
	for y in range(height):
		for x in range(width):
			var stripe = int(floor(float(x + y) / float(stripe_size))) % 2 == 0
			var color = stripe_color if stripe else base_color
			color = _mix_colors(color, _mix_colors(base_color, stripe_color, _noise_value(x, y, seed)), 0.12)
			image.set_pixel(x, y, color)
	return ImageTexture.create_from_image(image)

func _get_surface_texture(key):
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

func _configure_material(material, name, color, emissive := false):
	# Material selection... enhanced PBR with normal/rough from textures
	var lower = name.to_lower()
	material.albedo_color = color
	material.roughness = 0.95
	material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	
	# Default triplanar
	material.uv1_triplanar = true
	material.uv1_world_triplanar = true
	material.uv1_scale = Vector3(0.85, 0.85, 0.85)

	var tex_set = _get_surface_texture(lower)
	if tex_set and tex_set.has("albedo"):
		material.albedo_texture = tex_set["albedo"]
	if tex_set and tex_set.has("normal"):
		material.normal_enabled = true
		material.normal_texture = tex_set["normal"]
	if tex_set and tex_set.has("roughness"):
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
		# Keep glass setup on StandardMaterial3D to avoid invalid legacy remap warnings.
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

	# THIN ELEMENTS - enhanced anti-clipping + no shadows/depth issues
	if lower.contains("mullion") or lower.contains("trim") or lower.contains("weathering") or lower.contains("coping") or lower.contains("step") or lower.contains("hood") or lower.contains("socle") or lower.contains("chimney") or lower.contains("band") or lower.contains("lintel"):
		material.uv1_triplanar = false
		material.uv1_world_triplanar = false
		material.uv1_scale = Vector3(1.2, 1.2, 1.2)
		material.roughness = 0.88
		material.cull_mode = BaseMaterial3D.CULL_DISABLED  # Double-sided
		material.no_depth_test = true
		material.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_OPAQUE_ONLY
		return


	if lower.contains("lintel") or lower.contains("cornice") or lower.contains("pilaster") or lower.contains("plinth") or lower.contains("awning"):
		material.albedo_texture = _get_surface_texture("stone").albedo
		material.roughness = 0.8
		material.metallic = 0.0
		material.uv1_triplanar = false
		material.uv1_world_triplanar = false
		material.uv1_scale = Vector3(0.5, 0.5, 0.5)
		material.cull_mode = BaseMaterial3D.CULL_BACK
		return

	if lower.contains("fireescape"):
		material.albedo_texture = _get_surface_texture("metal").albedo
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
		material.albedo_texture = _get_surface_texture("stone").albedo
		material.roughness = 0.82
		material.uv1_triplanar = false
		material.uv1_scale = Vector3(0.6, 0.6, 0.6)
		return

	if lower.contains("tower"):
		material.uv1_triplanar = false
		material.uv1_world_triplanar = false
		material.albedo_texture = _get_surface_texture("tower_albedo").albedo
		material.emission_enabled = true
		material.emission = Color("ffd89d")
		material.emission_texture = _get_surface_texture("tower_emission").albedo
		material.emission_energy_multiplier = 1.45
		material.roughness = 0.8
		return

	if (lower.contains("roof") and not (lower.contains("vent") or lower.contains("mechanical"))) or lower.contains("parapet"):
		material.albedo_texture = _get_surface_texture("painted_metal").albedo
		material.metallic = 0.18
		material.roughness = 0.78
		material.uv1_scale = Vector3(0.72, 0.72, 0.72)
	return

	if lower.contains("frontageconnectorfloor"):
		material.albedo_texture = _get_surface_texture("plaza").albedo
		material.roughness = 1.0
		material.uv1_scale = Vector3(0.55, 0.55, 0.55)
	elif lower.contains("galleryhotelconnectorfloor") or lower.contains("hotelofficeconnectorfloor"):
		material.albedo_texture = _get_surface_texture("stone").albedo
		material.uv1_scale = Vector3(0.5, 0.5, 0.5)
	elif lower.contains("officeserviceconnectorfloor"):
		material.albedo_texture = _get_surface_texture("service_concrete").albedo
		material.uv1_scale = Vector3(0.42, 0.42, 0.42)
	elif lower.contains("median") or lower.contains("curb") or lower.contains("dockplatform") or lower.contains("dockstep") or lower.contains("entrystep"):
		material.albedo_texture = _get_surface_texture("concrete").albedo
		material.uv1_scale = Vector3(0.55, 0.55, 0.55)
	elif lower.contains("avenuefloor"):
		material.albedo_texture = _get_surface_texture("asphalt").albedo
		material.roughness = 1.0
		material.uv1_scale = Vector3(0.34, 0.34, 0.34)
	elif lower.contains("sidewalk"):
		material.albedo_texture = _get_surface_texture("concrete").albedo
		material.uv1_scale = Vector3(0.55, 0.55, 0.55)
	elif lower.contains("forecourt") or lower.contains("safehousepad"):
		material.albedo_texture = _get_surface_texture("plaza").albedo
		material.uv1_scale = Vector3(0.55, 0.55, 0.55)
	elif lower.contains("cafefloor"):
		material.albedo_texture = _get_surface_texture("warm_tile").albedo
		material.uv1_scale = Vector3(0.55, 0.55, 0.55)
	elif lower.contains("galleryfloor") or lower.contains("vipfloor") or lower.contains("hotelfloor") or lower.contains("officefloor"):
		material.albedo_texture = _get_surface_texture("stone").albedo
		material.uv1_scale = Vector3(0.5, 0.5, 0.5)
	elif lower.contains("servicefloor") or lower.contains("subwayalleyfloor") or lower.contains("alleyfloor") or lower.contains("servicelane"):
		material.albedo_texture = _get_surface_texture("service_concrete").albedo
		material.uv1_scale = Vector3(0.42, 0.42, 0.42)
	elif lower.contains("massing"):
		material.albedo_texture = _get_surface_texture("dark_brick").albedo
		material.uv1_scale = Vector3(0.5, 0.5, 0.5)
	elif lower.contains("planter"):
		material.albedo_texture = _get_surface_texture("painted_metal").albedo
		material.roughness = 0.7
	elif lower.contains("taxi") or lower.contains("servicevan") or lower.contains("dumpster"):
		material.albedo_texture = _get_surface_texture("painted_metal").albedo
		material.metallic = 0.35
		material.roughness = 0.44
		material.uv1_scale = Vector3(0.95, 0.95, 0.95)
	elif lower.contains("metal") or lower.contains("post") or lower.contains("shelter") or lower.contains("cart") or lower.contains("gate") or lower.contains("safe"):
		material.albedo_texture = _get_surface_texture("metal").albedo
		material.metallic = 0.8
		material.roughness = 0.42
		material.uv1_scale = Vector3(0.95, 0.95, 0.95)
	elif lower.contains("stair") or lower.contains("gate"):
		material.albedo_texture = _get_surface_texture("metal").albedo
		material.metallic = 0.65
		material.roughness = 0.5
		material.uv1_scale = Vector3(0.95, 0.95, 0.95)
	elif lower.contains("boundary") or lower.contains("subway") or lower.contains("safehouse") or lower.contains("fence") or lower.contains("alley"):
		material.albedo_texture = _get_surface_texture("dark_brick").albedo
		material.uv1_scale = Vector3(0.52, 0.52, 0.52)
	elif lower.contains("west") or lower.contains("north") or lower.contains("south") or lower.contains("east"):
		material.albedo_texture = _get_surface_texture("brick").albedo
		material.uv1_scale = Vector3(0.52, 0.52, 0.52)
	elif lower.contains("awning") or lower.contains("canopy"):
		material.albedo_texture = _get_surface_texture("fabric").albedo
		material.roughness = 0.78
		material.uv1_scale = Vector3(0.8, 0.8, 0.8)
	elif lower.contains("runner"):
		material.albedo_texture = _get_surface_texture("fabric").albedo
		material.roughness = 0.82
		material.uv1_scale = Vector3(0.72, 0.72, 0.72)
	elif lower.contains("vent") or lower.contains("mechanical"):
		material.albedo_texture = _get_surface_texture("metal").albedo
		material.metallic = 0.7
		material.roughness = 0.52
		material.uv1_scale = Vector3(0.9, 0.9, 0.9)
	elif lower.contains("bar") or lower.contains("plinth"):
		material.albedo_texture = _get_surface_texture("stone").albedo
		material.uv1_scale = Vector3(0.62, 0.62, 0.62)
	elif lower.contains("counter") or lower.contains("desk") or lower.contains("bench") or lower.contains("newsstand"):
		material.albedo_texture = _get_surface_texture("warm_tile").albedo
		material.uv1_scale = Vector3(0.72, 0.72, 0.72)
	elif lower.contains("crate"):
		material.albedo_texture = _get_surface_texture("warm_tile").albedo
		material.uv1_scale = Vector3(0.68, 0.68, 0.68)
	elif lower.contains("booth") or lower.contains("sofa"):
		material.albedo_texture = _get_surface_texture("fabric").albedo
		material.roughness = 0.84
		material.uv1_scale = Vector3(0.8, 0.8, 0.8)
	elif lower.contains("signpanel"):
		material.albedo_texture = _get_surface_texture("metal").albedo
		material.metallic = 0.35
		material.roughness = 0.4

func _create_roots():
	# Keeping geometry, markers, and NPCs under separate roots makes it much
	# easier to inspect the generated level in the remote scene tree.
	geometry_root = Node3D.new()
	geometry_root.name = "Geometry"
	add_child(geometry_root)

	marker_root = Node3D.new()
	marker_root.name = "Markers"
	add_child(marker_root)

	npc_root = Node3D.new()
	npc_root.name = "NPCs"
	add_child(npc_root)

func _create_player():
	# The player starts in the west side of the alley during day phase.
	player = CharacterBody3D.new()
	player.name = "Player"
	player.set_script(PLAYER_SCRIPT)
	player.position = Vector3(-12.0, 0.0, -20.0)  # Day spawn - west alley, south end
	player.world_ref = self

	var collision = CollisionShape3D.new()
	var capsule = CapsuleShape3D.new()
	capsule.radius = 0.32
	capsule.height = 1.64
	collision.shape = capsule
	collision.position = Vector3(0.0, 0.92, 0.0)
	player.add_child(collision)

	var visuals = Node3D.new()
	visuals.name = "Visuals"
	visuals.position = Vector3(0.0, 0.0, 0.0)
	player.add_child(visuals)

	# Improved core body - realistic proportions
	var body_mesh = MeshInstance3D.new()
	body_mesh.name = "BodyMesh"
	var body = CapsuleMesh.new()
	body.radius = 0.28
	body.height = 1.44
	body_mesh.mesh = body
	var body_mat = StandardMaterial3D.new()
	body_mat.albedo_color = Color("d3b787")
	body_mat.roughness = 0.75
	body_mesh.material_override = body_mat
	body_mesh.position = Vector3(0.0, 0.78, 0.0)
	body_mesh.scale = Vector3(1.05, 1.05, 1.05)
	visuals.add_child(body_mesh)
	
	# Chest detail (darker vest)
	var chest_mesh = MeshInstance3D.new()
	chest_mesh.name = "ChestVest"
	var chest = BoxMesh.new()
	chest.size = Vector3(0.32, 0.44, 0.24)
	chest_mesh.mesh = chest
	var chest_mat = StandardMaterial3D.new()
	chest_mat.albedo_color = Color("3a4a5a")
	chest_mat.roughness = 0.68
	chest_mesh.material_override = chest_mat
	chest_mesh.position = Vector3(0.0, 0.88, 0.0)
	chest_mesh.scale = Vector3(1.05, 1.05, 1.05)
	visuals.add_child(chest_mesh)
	
	# Arms - realistic proportions
	var arm_left = MeshInstance3D.new()
	arm_left.name = "ArmLeft"
	var arm_left_mesh = CapsuleMesh.new()
	arm_left_mesh.radius = 0.11
	arm_left_mesh.height = 0.68
	arm_left.mesh = arm_left_mesh
	var arm_mat = StandardMaterial3D.new()
	arm_mat.albedo_color = Color("c5a585")
	arm_mat.roughness = 0.72
	arm_left.material_override = arm_mat
	arm_left.position = Vector3(-0.28, 0.92, 0.0)
	arm_left.scale = Vector3(1.05, 1.05, 1.05)
	visuals.add_child(arm_left)
	
	var arm_right = MeshInstance3D.new()
	arm_right.name = "ArmRight"
	var arm_right_mesh = CapsuleMesh.new()
	arm_right_mesh.radius = 0.11
	arm_right_mesh.height = 0.68
	arm_right.mesh = arm_right_mesh
	arm_right.material_override = arm_mat
	arm_right.position = Vector3(0.28, 0.92, 0.0)
	arm_right.scale = Vector3(1.05, 1.05, 1.05)
	visuals.add_child(arm_right)
	
	# Hands - detailed
	var hand_left = MeshInstance3D.new()
	hand_left.name = "HandLeft"
	var hand_left_mesh = SphereMesh.new()
	hand_left_mesh.radius = 0.09
	hand_left.mesh = hand_left_mesh
	var hand_mat = StandardMaterial3D.new()
	hand_mat.albedo_color = Color("c5a585")
	hand_mat.roughness = 0.7
	hand_left.material_override = hand_mat
	hand_left.position = Vector3(-0.28, 0.42, 0.0)
	hand_left.scale = Vector3(1.05, 1.05, 1.05)
	visuals.add_child(hand_left)
	
	var hand_right = MeshInstance3D.new()
	hand_right.name = "HandRight"
	var hand_right_mesh = SphereMesh.new()
	hand_right_mesh.radius = 0.09
	hand_right.mesh = hand_right_mesh
	hand_right.material_override = hand_mat
	hand_right.position = Vector3(0.28, 0.42, 0.0)
	hand_right.scale = Vector3(1.05, 1.05, 1.05)
	visuals.add_child(hand_right)

	# Head - improved proportions and facial features
	var head = MeshInstance3D.new()
	head.name = "Head"
	var sphere = SphereMesh.new()
	sphere.radius = 0.24
	sphere.height = 0.48
	head.mesh = sphere
	var head_mat = StandardMaterial3D.new()
	head_mat.albedo_color = Color("dfc0a0")
	head_mat.roughness = 0.74
	head.material_override = head_mat
	head.position = Vector3(0.0, 1.58, 0.0)
	head.scale = Vector3(1.05, 1.05, 1.05)
	visuals.add_child(head)
	
	# Neck detail
	var neck_mesh = MeshInstance3D.new()
	neck_mesh.name = "Neck"
	var neck = CapsuleMesh.new()
	neck.radius = 0.08
	neck.height = 0.18
	neck_mesh.mesh = neck
	var neck_mat = StandardMaterial3D.new()
	neck_mat.albedo_color = Color("dfc0a0")
	neck_mesh.material_override = neck_mat
	neck_mesh.position = Vector3(0.0, 1.32, 0.0)
	neck_mesh.scale = Vector3(1.05, 1.05, 1.05)
	visuals.add_child(neck_mesh)
	
	# Eyes - realistic facial detail
	var eye_left = MeshInstance3D.new()
	eye_left.name = "EyeLeft"
	var eye_left_mesh = SphereMesh.new()
	eye_left_mesh.radius = 0.05
	eye_left.mesh = eye_left_mesh
	var eye_mat = StandardMaterial3D.new()
	eye_mat.albedo_color = Color("1a1a1a")
	eye_left.material_override = eye_mat
	eye_left.position = Vector3(-0.08, 1.62, 0.18)
	eye_left.scale = Vector3(1.05, 1.05, 1.05)
	visuals.add_child(eye_left)
	
	var eye_right = MeshInstance3D.new()
	eye_right.name = "EyeRight"
	var eye_right_mesh = SphereMesh.new()
	eye_right_mesh.radius = 0.05
	eye_right.mesh = eye_right_mesh
	eye_right.material_override = eye_mat
	eye_right.position = Vector3(0.08, 1.62, 0.18)
	eye_right.scale = Vector3(1.05, 1.05, 1.05)
	visuals.add_child(eye_right)
	
	# Tactical hat with brim
	var hat = MeshInstance3D.new()
	hat.name = "Hat"
	var hat_mesh = CylinderMesh.new()
	hat_mesh.top_radius = 0.18
	hat_mesh.bottom_radius = 0.26
	hat_mesh.height = 0.22
	hat.mesh = hat_mesh
	var hat_mat = StandardMaterial3D.new()
	hat_mat.albedo_color = Color("1a2a3a")
	hat_mat.roughness = 0.65
	hat.material_override = hat_mat
	hat.position = Vector3(0.0, 1.96, 0.0)
	hat.scale = Vector3(1.05, 1.05, 1.05)
	visuals.add_child(hat)
	
	# Hat brim detail
	var hat_brim = MeshInstance3D.new()
	hat_brim.name = "HatBrim"
	var brim_mesh = CylinderMesh.new()
	brim_mesh.top_radius = 0.28
	brim_mesh.bottom_radius = 0.3
	brim_mesh.height = 0.08
	hat_brim.mesh = brim_mesh
	var brim_mat = StandardMaterial3D.new()
	brim_mat.albedo_color = Color("0a1a2a")
	brim_mat.roughness = 0.68
	hat_brim.material_override = brim_mat
	hat_brim.position = Vector3(0.0, 2.08, 0.0)
	hat_brim.scale = Vector3(1.05, 1.05, 1.05)
	visuals.add_child(hat_brim)
	
	# Tactical backpack - large, structured
	var backpack = MeshInstance3D.new()
	backpack.name = "Backpack"
	var pack_mesh = BoxMesh.new()
	pack_mesh.size = Vector3(0.36, 0.62, 0.3)
	backpack.mesh = pack_mesh
	var pack_mat = StandardMaterial3D.new()
	pack_mat.albedo_color = Color("2a4a3a")
	pack_mat.roughness = 0.72
	backpack.material_override = pack_mat
	backpack.position = Vector3(0.0, 0.95, -0.38)
	backpack.scale = Vector3(1.05, 1.05, 1.05)
	visuals.add_child(backpack)
	
	# Backpack straps
	var strap_left = MeshInstance3D.new()
	strap_left.name = "StrapLeft"
	var strap_mesh = BoxMesh.new()
	strap_mesh.size = Vector3(0.08, 0.5, 0.12)
	strap_left.mesh = strap_mesh
	var strap_mat = StandardMaterial3D.new()
	strap_mat.albedo_color = Color("1a3a2a")
	strap_mat.roughness = 0.7
	strap_left.material_override = strap_mat
	strap_left.position = Vector3(-0.14, 1.1, -0.28)
	strap_left.scale = Vector3(1.05, 1.05, 1.05)
	visuals.add_child(strap_left)
	
	var strap_right = MeshInstance3D.new()
	strap_right.name = "StrapRight"
	strap_right.mesh = strap_mesh
	strap_right.material_override = strap_mat
	strap_right.position = Vector3(0.14, 1.1, -0.28)
	strap_right.scale = Vector3(1.05, 1.05, 1.05)
	visuals.add_child(strap_right)
	
	# Gloves - tactical
	var glove_left = MeshInstance3D.new()
	glove_left.name = "GloveLeft"
	var glove_mesh = BoxMesh.new()
	glove_mesh.size = Vector3(0.12, 0.26, 0.12)
	glove_left.mesh = glove_mesh
	var glove_mat = StandardMaterial3D.new()
	glove_mat.albedo_color = Color("2a2a3a")
	glove_mat.roughness = 0.62
	glove_left.material_override = glove_mat
	glove_left.position = Vector3(-0.32, 0.48, 0.0)
	glove_left.scale = Vector3(1.05, 1.05, 1.05)
	visuals.add_child(glove_left)
	
	var glove_right = MeshInstance3D.new()
	glove_right.name = "GloveRight"
	glove_right.mesh = glove_mesh
	glove_right.material_override = glove_mat
	glove_right.position = Vector3(0.32, 0.48, 0.0)
	glove_right.scale = Vector3(1.05, 1.05, 1.05)
	visuals.add_child(glove_right)
	
	# Belt with pouches
	var belt = MeshInstance3D.new()
	belt.name = "Belt"
	var belt_mesh = BoxMesh.new()
	belt_mesh.size = Vector3(0.38, 0.12, 0.15)
	belt.mesh = belt_mesh
	var belt_mat = StandardMaterial3D.new()
	belt_mat.albedo_color = Color("3a3a4a")
	belt_mat.roughness = 0.58
	belt.material_override = belt_mat
	belt.position = Vector3(0.0, 0.58, 0.0)
	belt.scale = Vector3(1.05, 1.05, 1.05)
	visuals.add_child(belt)
	
	# Pouch left
	var pouch_left = MeshInstance3D.new()
	pouch_left.name = "PouchLeft"
	var pouch_mesh = BoxMesh.new()
	pouch_mesh.size = Vector3(0.1, 0.15, 0.12)
	pouch_left.mesh = pouch_mesh
	var pouch_mat = StandardMaterial3D.new()
	pouch_mat.albedo_color = Color("2a2a3a")
	pouch_mat.roughness = 0.6
	pouch_left.material_override = pouch_mat
	pouch_left.position = Vector3(-0.2, 0.56, 0.08)
	pouch_left.scale = Vector3(1.05, 1.05, 1.05)
	visuals.add_child(pouch_left)
	
	# Pouch right
	var pouch_right = MeshInstance3D.new()
	pouch_right.name = "PouchRight"
	pouch_right.mesh = pouch_mesh
	pouch_right.material_override = pouch_mat
	pouch_right.position = Vector3(0.2, 0.56, 0.08)
	pouch_right.scale = Vector3(1.05, 1.05, 1.05)
	visuals.add_child(pouch_right)

	# Camera defaults:
	# - yaw 90 so the view is aligned parallel to the map instead of on a corner
	# - shallow downward pitch for the flatter side-on feel the user wanted
	var camera_pivot = Node3D.new()
	camera_pivot.name = "CameraPivot"
	camera_pivot.rotation_degrees = Vector3(-18.0, 90.0, 0.0)
	player.add_child(camera_pivot)

	var camera = Camera3D.new()
	camera.name = "Camera3D"

	# This is a real perspective camera now, not the original orthographic setup.
	camera.position = Vector3(0.0, 0.0, 10.5)
	camera.projection = Camera3D.PROJECTION_PERSPECTIVE
	camera.fov = 52.0  # Slightly wider for taller buildings
	camera.far = 110.0
	camera.near = 0.1  # Avoid near-plane clipping see-through
	camera.current = true
	camera_pivot.add_child(camera)

	var footstep_player = AudioStreamPlayer3D.new()
	footstep_player.name = "FootstepPlayer"
	player.add_child(footstep_player)

	add_child(player)

func _build_level_blockout():
	# Clean urban alleyway design - simple, clean, and playable.
	# Central 40-unit-wide alley with tall buildings on both sides.
	var palette = {

		"alley": Color("1a1f28"),
		"sidewalk": Color("2b303a"),
		"stone": Color("535760"),
		"roof": Color("39424c"),
		"trim": Color("d6cec0"),
		"wall": Color("8a8179"),
		"tall_wall": Color("3a4452"),
		"building": Color("2e3540"),
		"dark": Color("1f252e"),
		"metal": Color("4d5967"),
		"accent": Color("68d4ff"),
		"green": Color("395442"),
	}
	
# Continuous safety floor under the entire playable block.
	_add_collision_block("WorldSupportFloor", Vector3(0.0, -0.18, 0.0), Vector3(80.0, 0.36, 64.0))

# ALLEYWAY FLOOR - tight canyon ±20u total (±10 alley + ±5 curbs), 56 deep
	_add_block("AlleyFloor", Vector3(0.0, -0.1, 0.0), Vector3(20.0, 0.2, 56.0), palette["alley"], true, false)
	
	# SIDE CURBS - 5u total (2.5u each side)
	_add_block("WestCurb", Vector3(-11.25, -0.05, 0.0), Vector3(2.5, 0.15, 56.0), palette["sidewalk"], true, false)
	_add_block("EastCurb", Vector3(11.25, -0.05, 0.0), Vector3(2.5, 0.15, 56.0), palette["sidewalk"], true, false)
	
	# FILL GAPS - tighter transitions (3u per side)
	_add_block("WestTransitionFloor", Vector3(-16.25, -0.08, 0.0), Vector3(3.0, 0.18, 56.0), Color("2b3540"), true, false)
	_add_block("EastTransitionFloor", Vector3(16.25, -0.08, 0.0), Vector3(3.0, 0.18, 56.0), Color("2b3540"), true, false)


# WEST BUILDING - tighter x=-17.5 (6 behind new curb), height=18, depth=56
	_add_block("WestWall", Vector3(-17.5, 9.0, 0.0), Vector3(10.02, 18.0, 56.0), Color(0.3, 0.34, 0.38, 1.0), true)
	
	# West roof
	_add_mesh_only("WestRoof", Vector3(-17.5, 18.6, 0.0), Vector3(10.2, 0.4, 56.3), palette["roof"])
	
	# West base plinth
	_add_mesh_only("WestBasePlinth", Vector3(-17.5, 0.25, 0.0), Vector3(10.2, 0.8, 56.2), Color("464d58"))
	
	# West socle
	_add_mesh_only("WestSocle", Vector3(-17.5, 0.9, 0.0), Vector3(10.1, 1.0, 56.1), Color("3a3f48"))
	
	# West window bands - adjusted x
	_add_mesh_only("WestWindowPanelLower", Vector3(-17.38, 1.8, 0.0), Vector3(10.0, 2.4, 56.0), Color(0.74, 0.84, 0.9, 0.08))
	_add_mesh_only("WestWindowPanelLower2", Vector3(-17.38, 3.6, 0.0), Vector3(10.0, 2.4, 56.0), Color(0.74, 0.84, 0.9, 0.08))
	_add_mesh_only("WestWindowPanelMid", Vector3(-17.38, 6.6, 0.0), Vector3(10.0, 2.4, 56.0), Color(0.74, 0.84, 0.9, 0.07))
	_add_mesh_only("WestWindowPanelUpper", Vector3(-17.38, 10.2, 0.0), Vector3(10.0, 2.4, 56.0), Color(0.74, 0.84, 0.9, 0.06))
	_add_mesh_only("WestWindowPanelUpper2", Vector3(-17.38, 13.8, 0.0), Vector3(10.0, 2.4, 56.0), Color(0.74, 0.84, 0.9, 0.05))
	
	# West lintels (5 now, scaled)
	_add_mesh_only("WestLintelLower", Vector3(-20.0, 2.55, 0.0), Vector3(10.1, 0.16, 56.1), Color("c8bdb0"))
	_add_mesh_only("WestLintelLower2", Vector3(-20.0, 4.35, 0.0), Vector3(10.1, 0.16, 56.1), Color("c8bdb0"))
	_add_mesh_only("WestLintelMid", Vector3(-20.0, 7.35, 0.0), Vector3(10.1, 0.16, 56.1), Color("c8bdb0"))
	_add_mesh_only("WestLintelUpper", Vector3(-20.0, 11.55, 0.0), Vector3(10.1, 0.16, 56.1), Color("c8bdb0"))
	_add_mesh_only("WestLintelUpper2", Vector3(-20.0, 15.15, 0.0), Vector3(10.1, 0.16, 56.1), Color("c8bdb0"))
	
	# West hoods (5, taller)
	_add_mesh_only("WestHoodLower", Vector3(-20.0, 4.2, 0.0), Vector3(10.2, 0.24, 56.1), Color("d6cec0"))
	_add_mesh_only("WestHoodLower2", Vector3(-20.0, 6.0, 0.0), Vector3(10.2, 0.24, 56.1), Color("d6cec0"))
	_add_mesh_only("WestHoodMid", Vector3(-20.0, 9.0, 0.0), Vector3(10.2, 0.24, 56.1), Color("d6cec0"))
	_add_mesh_only("WestHoodUpper", Vector3(-20.0, 12.6, 0.0), Vector3(10.2, 0.24, 56.1), Color("d6cec0"))
	_add_mesh_only("WestHoodUpper2", Vector3(-20.0, 15.9, 0.0), Vector3(10.2, 0.24, 56.1), Color("d6cec0"))
	
	# West cornice - taller building
	_add_mesh_only("WestCornice", Vector3(-20.0, 18.25, 0.0), Vector3(10.2, 0.35, 56.2), Color("d6cec0"))

	# West chimney stacks - repositioned & taller
	for i in range(0, 56, 14):
		_add_mesh_only("WestChimney%d" % i, Vector3(-22.5, 14.5, -28.0 + i), Vector3(0.8, 5.0, 0.8), Color("464d58"))
		_add_mesh_only("WestChimneyTop%d" % i, Vector3(-22.5, 19.6, -28.0 + i), Vector3(0.9, 0.4, 0.9), Color("3a3f48"))
	
	# West fire escape - taller range, repositioned to new wall
	for i in range(0, 16, 2):
		var y_pos = 1.0 + float(i)
		_add_mesh_only("WestFireEscapeBar%d" % i, Vector3(-24.8, y_pos, -8.0), Vector3(0.4, 0.08, 5.0), Color("4d5967"))
		_add_mesh_only("WestFireEscapeBar%dE" % i, Vector3(-24.8, y_pos, 8.0), Vector3(0.4, 0.08, 5.0), Color("4d5967"))
		if i < 15:
			_add_mesh_only("WestFireEscapeVertical%d" % i, Vector3(-24.8, y_pos + 1.0, -6.5), Vector3(0.15, 0.8, 0.15), Color("4d5967"))
			_add_mesh_only("WestFireEscapeVertical%dE" % i, Vector3(-24.8, y_pos + 1.0, 6.5), Vector3(0.15, 0.8, 0.15), Color("4d5967"))
	
	# West entry doors - repositioned to new layout
	_add_mesh_only("WestDoorPanelFrame1", Vector3(-25.0, 1.5, -15.0), Vector3(0.4, 3.2, 0.2), Color("8a8179"))
	_add_mesh_only("WestDoorPanel1", Vector3(-24.8, 1.5, -15.0), Vector3(0.08, 2.8, 0.15), Color("3a3a3a"))
	_add_mesh_only("WestDoorLintel1", Vector3(-25.0, 3.25, -15.0), Vector3(0.6, 0.2, 0.25), Color("c8bdb0"))
	
	_add_mesh_only("WestDoorPanelFrame2", Vector3(-25.0, 1.5, 0.0), Vector3(0.4, 3.2, 0.2), Color("8a8179"))
	_add_mesh_only("WestDoorPanel2", Vector3(-24.8, 1.5, 0.0), Vector3(0.08, 2.8, 0.15), Color("3a3a3a"))
	_add_mesh_only("WestDoorLintel2", Vector3(-25.0, 3.25, 0.0), Vector3(0.6, 0.2, 0.25), Color("c8bdb0"))
	
	# West entry doors with frames (NAMED FOR TEXTURE)
	_add_mesh_only("WestDoorPanelFrame1", Vector3(-35.0, 1.5, -15.0), Vector3(0.4, 3.2, 0.2), Color("8a8179"))
	_add_mesh_only("WestDoorPanel1", Vector3(-34.8, 1.5, -15.0), Vector3(0.08, 2.8, 0.15), Color("3a3a3a"))
	_add_mesh_only("WestDoorLintel1", Vector3(-35.0, 3.25, -15.0), Vector3(0.6, 0.2, 0.25), Color("c8bdb0"))
	
	_add_mesh_only("WestDoorPanelFrame2", Vector3(-35.0, 1.5, 0.0), Vector3(0.4, 3.2, 0.2), Color("8a8179"))
	_add_mesh_only("WestDoorPanel2", Vector3(-34.8, 1.5, 0.0), Vector3(0.08, 2.8, 0.15), Color("3a3a3a"))
	_add_mesh_only("WestDoorLintel2", Vector3(-35.0, 3.25, 0.0), Vector3(0.6, 0.2, 0.25), Color("c8bdb0"))
	
# West corner pilasters - tightened
	for z in range(-28, 28, 4):
		_add_mesh_only("WestPilaster%d" % (z + 28), Vector3(-29.0, 5.0, float(z)), Vector3(0.3, 5.0, 0.3), Color("8a8179"))
		_add_mesh_only("WestPilasterEast%d" % (z + 28), Vector3(-19.5, 5.0, float(z)), Vector3(0.3, 5.0, 0.3), Color("8a8179"))
	
# EAST BUILDING - tighter x=17.5 (6 behind curb), height=18
	_add_block("EastWall", Vector3(17.5, 9.0, 0.0), Vector3(10.02, 18.0, 56.0), Color(0.3, 0.34, 0.38, 1.0), true)
	
	# East roof
	_add_mesh_only("EastRoof", Vector3(17.5, 18.6, 0.0), Vector3(10.2, 0.4, 56.3), palette["roof"])
	
	# East base plinth
	_add_mesh_only("EastBasePlinth", Vector3(17.5, 0.25, 0.0), Vector3(10.2, 0.8, 56.2), Color("464d58"))
	
	# East socle
	_add_mesh_only("EastSocle", Vector3(17.5, 0.9, 0.0), Vector3(10.1, 1.0, 56.1), Color("3a3f48"))
	
	# East windows - adjusted x
	_add_mesh_only("EastWindowPanelLower", Vector3(17.62, 1.8, 0.0), Vector3(10.0, 2.4, 56.0), Color(0.74, 0.84, 0.9, 0.16))
	_add_mesh_only("EastWindowPanelLower2", Vector3(17.62, 3.6, 0.0), Vector3(10.0, 2.4, 56.0), Color(0.74, 0.84, 0.9, 0.16))
	_add_mesh_only("EastWindowPanelMid", Vector3(17.62, 6.6, 0.0), Vector3(10.0, 2.4, 56.0), Color(0.74, 0.84, 0.9, 0.14))
	_add_mesh_only("EastWindowPanelUpper", Vector3(17.62, 10.2, 0.0), Vector3(10.0, 2.4, 56.0), Color(0.74, 0.84, 0.9, 0.12))
	_add_mesh_only("EastWindowPanelUpper2", Vector3(17.62, 13.8, 0.0), Vector3(10.0, 2.4, 56.0), Color(0.74, 0.84, 0.9, 0.10))
	
	# East lintels (5)
	_add_mesh_only("EastLintelLower", Vector3(20.0, 2.55, 0.0), Vector3(10.1, 0.16, 56.1), Color("c8bdb0"))
	_add_mesh_only("EastLintelLower2", Vector3(20.0, 4.35, 0.0), Vector3(10.1, 0.16, 56.1), Color("c8bdb0"))
	_add_mesh_only("EastLintelMid", Vector3(20.0, 7.35, 0.0), Vector3(10.1, 0.16, 56.1), Color("c8bdb0"))
	_add_mesh_only("EastLintelUpper", Vector3(20.0, 11.55, 0.0), Vector3(10.1, 0.16, 56.1), Color("c8bdb0"))
	_add_mesh_only("EastLintelUpper2", Vector3(20.0, 15.15, 0.0), Vector3(10.1, 0.16, 56.1), Color("c8bdb0"))
	
	# East hoods (5)
	_add_mesh_only("EastHoodLower", Vector3(20.0, 4.2, 0.0), Vector3(10.2, 0.24, 56.1), Color("d6cec0"))
	_add_mesh_only("EastHoodLower2", Vector3(20.0, 6.0, 0.0), Vector3(10.2, 0.24, 56.1), Color("d6cec0"))
	_add_mesh_only("EastHoodMid", Vector3(20.0, 9.0, 0.0), Vector3(10.2, 0.24, 56.1), Color("d6cec0"))
	_add_mesh_only("EastHoodUpper", Vector3(20.0, 12.6, 0.0), Vector3(10.2, 0.24, 56.1), Color("d6cec0"))
	_add_mesh_only("EastHoodUpper2", Vector3(20.0, 15.9, 0.0), Vector3(10.2, 0.24, 56.1), Color("d6cec0"))
	
	# East cornice
	_add_mesh_only("EastCornice", Vector3(20.0, 18.25, 0.0), Vector3(10.2, 0.35, 56.2), Color("d6cec0"))

# 3rd Building - Office Tower tightened x=24 h=20 (fits canyon)
	_add_block("OfficeTower", Vector3(24.0, 10.0, 0.0), Vector3(8.02, 20.0, 56.0), Color(0.28, 0.32, 0.36), true)
	_add_mesh_only("OfficeRoof", Vector3(24.0, 20.6, 0.0), Vector3(8.2, 0.4, 56.3), palette["roof"])
	_add_mesh_only("OfficeTowerWindows1", Vector3(24.12, 2.0, 0.0), Vector3(8.0, 3.0, 56.0), Color(0.74, 0.84, 0.9, 0.1))
	_add_mesh_only("OfficeLedge1", Vector3(24.0, 4.8, 0.0), Vector3(8.2, 0.2, 56.3), Color("4a5560"))
	_add_mesh_only("OfficeAC1", Vector3(27.0, 6.0, 10.0), Vector3(1.2, 1.0, 1.2), Color("3a4452"))
	_add_mesh_only("OfficePipe1", Vector3(26.5, 15.0, 20.0), Vector3(0.15, 6.0, 0.15), Color("5a6a7a"))

	
	# East chimney stacks
	for i in range(0, 56, 14):
		_add_mesh_only("EastChimney%d" % i, Vector3(32.5, 7.5, -28.0 + i), Vector3(0.8, 3.0, 0.8), Color("464d58"))
		_add_mesh_only("EastChimneyTop%d" % i, Vector3(32.5, 10.6, -28.0 + i), Vector3(0.9, 0.3, 0.9), Color("3a3f48"))
	
	# ADDITIONAL ARCHITECTURAL IMPROVEMENTS
	# West building - additional facade details
	for i in range(0, 56, 7):
		_add_mesh_only("WestWallBand%d" % i, Vector3(-30.1, 5.5, -28.0 + i), Vector3(9.8, 0.08, 0.4), Color("4a5560"))
	
	# East building - additional facade details
	for i in range(0, 56, 7):
		_add_mesh_only("EastWallBand%d" % i, Vector3(30.1, 5.5, -28.0 + i), Vector3(9.8, 0.08, 0.4), Color("4a5560"))
	
	# East fire escape
	for i in range(0, 10, 2):
		var y_pos = 1.0 + float(i)
		_add_mesh_only("EastFireEscapeBar%d" % i, Vector3(34.8, y_pos, -8.0), Vector3(0.4, 0.08, 5.0), Color("4d5967"))
		_add_mesh_only("EastFireEscapeBar%dE" % i, Vector3(34.8, y_pos, 8.0), Vector3(0.4, 0.08, 5.0), Color("4d5967"))
		if i < 9:
			_add_mesh_only("EastFireEscapeVertical%d" % i, Vector3(34.8, y_pos + 1.0, -6.5), Vector3(0.15, 0.8, 0.15), Color("4d5967"))
			_add_mesh_only("EastFireEscapeVertical%dE" % i, Vector3(34.8, y_pos + 1.0, 6.5), Vector3(0.15, 0.8, 0.15), Color("4d5967"))
	
	# East entry doors with frames
	_add_mesh_only("EastDoorPanelFrame1", Vector3(35.0, 1.5, 15.0), Vector3(0.4, 3.2, 0.2), Color("8a8179"))
	_add_mesh_only("EastDoorPanel1", Vector3(34.8, 1.5, 15.0), Vector3(0.08, 2.8, 0.15), Color("3a3a3a"))
	_add_mesh_only("EastDoorLintel1", Vector3(35.0, 3.25, 15.0), Vector3(0.6, 0.2, 0.25), Color("c8bdb0"))
	
	_add_mesh_only("EastDoorPanelFrame2", Vector3(35.0, 1.5, 0.0), Vector3(0.4, 3.2, 0.2), Color("8a8179"))
	_add_mesh_only("EastDoorPanel2", Vector3(34.8, 1.5, 0.0), Vector3(0.08, 2.8, 0.15), Color("3a3a3a"))
	_add_mesh_only("EastDoorLintel2", Vector3(35.0, 3.25, 0.0), Vector3(0.6, 0.2, 0.25), Color("c8bdb0"))
	
# East corner pilasters - tightened
	for z in range(-28, 28, 4):
		_add_mesh_only("EastPilaster%d" % (z + 28), Vector3(29.0, 5.0, float(z)), Vector3(0.3, 5.0, 0.3), Color("8a8179"))
		_add_mesh_only("EastPilasterWest%d" % (z + 28), Vector3(19.5, 5.0, float(z)), Vector3(0.3, 5.0, 0.3), Color("8a8179"))

# HARD BOUNDARIES - tightened
	_add_block("SouthBoundary", Vector3(0.0, 2.0, -28.5), Vector3(44.0, 4.0, 1.0), palette["dark"], true)
	_add_block("NorthBoundary", Vector3(0.0, 2.0, 28.5), Vector3(44.0, 4.0, 1.0), palette["dark"], true)
	_add_block("WestBoundary", Vector3(-29.5, 2.0, 0.0), Vector3(1.0, 20.0, 56.0), palette["dark"], true)
	_add_block("EastBoundary", Vector3(29.5, 2.0, 0.0), Vector3(1.0, 20.0, 56.0), palette["dark"], true)
	
# GUARD RAILS - tightened to new walls
	_add_collision_block("WestBuildingRail", Vector3(-17.5, 9.0, 0.0), Vector3(11.0, 19.0, 56.0))
	_add_collision_block("EastBuildingRail", Vector3(17.5, 9.0, 0.0), Vector3(11.0, 19.0, 56.0))


	# BUILDING WEATHERING & ACCENT DETAILS
	# West building staining/weathering (vertical streaks)
	for i in range(0, 56, 7):
		_add_mesh_only("WestWeatheringStreak%d" % i, Vector3(-30.0, 7.0, -28.0 + i), Vector3(10.1, 2.5, 0.15), Color(0.25, 0.28, 0.32, 0.08))
	
	# West ground level base detail
	_add_mesh_only("WestGroundDetail", Vector3(-30.0, 0.5, 0.0), Vector3(10.15, 1.0, 56.2), Color("464d58"))
	
	# East building staining/weathering
	for i in range(0, 56, 7):
		_add_mesh_only("EastWeatheringStreak%d" % i, Vector3(30.0, 7.0, -28.0 + i), Vector3(10.1, 2.5, 0.15), Color(0.25, 0.28, 0.32, 0.08))
	
	# East ground level base detail
	_add_mesh_only("EastGroundDetail", Vector3(30.0, 0.5, 0.0), Vector3(10.15, 1.0, 56.2), Color("464d58"))
	
	# BUILDING ENTRY VESTIBULES (ground level recessed areas)
	# West entry vestibule - recessed entry area
	_add_mesh_only("WestEntryStep1", Vector3(-34.0, 0.08, -15.0), Vector3(2.0, 0.2, 1.2), Color("464d58"))
	_add_mesh_only("WestEntryStep2", Vector3(-34.0, 0.25, 0.0), Vector3(2.0, 0.5, 1.2), Color("464d58"))
	_add_mesh_only("WestEntryAwning", Vector3(-34.5, 2.8, -15.0), Vector3(1.0, 0.6, 1.5), Color("8a8179"))
	
	# East entry vestibule
	_add_mesh_only("EastEntryStep1", Vector3(34.0, 0.08, 15.0), Vector3(2.0, 0.2, 1.2), Color("464d58"))
	_add_mesh_only("EastEntryStep2", Vector3(34.0, 0.25, 0.0), Vector3(2.0, 0.5, 1.2), Color("464d58"))
	_add_mesh_only("EastEntryAwning", Vector3(34.5, 2.8, 15.0), Vector3(1.0, 0.6, 1.5), Color("8a8179"))

# ALLEY PROPS - tightened to new ±10 alley (west -9.5 to -16 range)
	# West side props
	_add_block("WestDoor1", Vector3(-20.0, 1.5, -20.0), Vector3(1.0, 3.0, 0.2), palette["wall"], true)
	_add_mesh_only("WestDoorFrame", Vector3(-20.0, 1.5, -19.95), Vector3(1.08, 3.08, 0.08), Color("3a3a3a"))
	_add_mesh_only("WestDoorHandle", Vector3(-20.45, 2.3, -20.15), Vector3(0.08, 0.15, 0.08), Color("8a8179"))
	_add_mesh_only("WestDoorGlow1", Vector3(-20.0, 1.5, -20.1), Vector3(0.8, 2.6, 0.06), Color("68d4ff"), true)
	
	# West bench
	_add_block("WestBench", Vector3(-9.5, 0.4, -15.0), Vector3(3.0, 0.8, 1.0), Color("6d6055"), true)
	_add_mesh_only("WestBenchBack", Vector3(-9.5, 1.15, -15.55), Vector3(3.2, 0.8, 0.15), Color("5a4845"))
	_add_mesh_only("WestBenchSeat", Vector3(-9.5, 0.45, -15.0), Vector3(3.1, 0.08, 1.08), Color("7d7066"))
	_add_mesh_only("WestBenchSupport_L", Vector3(-11.0, 0.25, -15.2), Vector3(0.15, 0.5, 0.3), Color("4a3f35"))
	_add_mesh_only("WestBenchSupport_R", Vector3(-8.0, 0.25, -15.2), Vector3(0.15, 0.5, 0.3), Color("4a3f35"))
	
	# West planter
	_add_block("WestPlanter", Vector3(-7.5, 0.7, -18.0), Vector3(1.5, 1.4, 1.5), palette["green"], true)
	_add_mesh_only("WestPlanterRim", Vector3(-7.5, 1.5, -18.0), Vector3(1.65, 0.15, 1.65), Color("6a6055"))
	_add_mesh_only("WestPlanterSoil", Vector3(-7.5, 1.35, -18.0), Vector3(1.4, 0.15, 1.4), Color("4a5533"))
	
	_add_block("WestCounter", Vector3(-8.5, 0.75, 0.0), Vector3(3.0, 1.5, 1.0), palette["metal"], true)
	_add_mesh_only("WestCounterTop", Vector3(-8.5, 1.4, 0.0), Vector3(3.15, 0.1, 1.1), Color("8a9a9f"))
	
# East side props - tightened to new ±10 alley (east 7.5-16 range)
	_add_block("EastDoor1", Vector3(20.0, 1.5, 20.0), Vector3(1.0, 3.0, 0.2), palette["wall"], true)
	_add_mesh_only("EastDoorFrame", Vector3(20.0, 1.5, 20.05), Vector3(1.08, 3.08, 0.08), Color("3a3a3a"))
	_add_mesh_only("EastDoorHandle", Vector3(19.55, 2.3, 20.15), Vector3(0.08, 0.15, 0.08), Color("8a8179"))
	_add_mesh_only("EastDoorGlow1", Vector3(20.0, 1.5, 20.1), Vector3(0.8, 2.6, 0.06), Color("38d388"), true)
	
	_add_block("EastBench", Vector3(8.5, 0.4, 15.0), Vector3(3.0, 0.8, 1.0), Color("6d6055"), true)
	_add_mesh_only("EastBenchBack", Vector3(8.5, 1.15, 15.55), Vector3(3.2, 0.8, 0.15), Color("5a4845"))
	_add_mesh_only("EastBenchSeat", Vector3(8.5, 0.45, 15.0), Vector3(3.1, 0.08, 1.08), Color("7d7066"))
	_add_mesh_only("EastBenchSupport_L", Vector3(7.0, 0.25, 15.2), Vector3(0.15, 0.5, 0.3), Color("4a3f35"))
	_add_mesh_only("EastBenchSupport_R", Vector3(10.0, 0.25, 15.2), Vector3(0.15, 0.5, 0.3), Color("4a3f35"))
	
	_add_block("EastPlanter", Vector3(7.5, 0.7, 18.0), Vector3(1.5, 1.4, 1.5), palette["green"], true)
	_add_mesh_only("EastPlanterRim", Vector3(7.5, 1.5, 18.0), Vector3(1.65, 0.15, 1.65), Color("6a6055"))
	_add_mesh_only("EastPlanterSoil", Vector3(7.5, 1.35, 18.0), Vector3(1.4, 0.15, 1.4), Color("4a5533"))
	
	_add_block("EastBar", Vector3(8.5, 0.75, 5.0), Vector3(3.5, 1.5, 1.0), palette["metal"], true)
	_add_mesh_only("EastBarTop", Vector3(8.5, 1.4, 5.0), Vector3(3.65, 0.1, 1.1), Color("8a9a9f"))
	
	# Center alley features - unchanged (fits tight layout)
	# Center podium - raised render priority, solid
	_add_block("CenterPodium", Vector3(-3.0, 0.6, 0.0), Vector3(2.0, 1.2, 2.0), palette["stone"], true)
	_add_mesh_only("CenterPodiumRim", Vector3(-3.0, 1.25, 0.0), Vector3(2.2, 0.12, 2.2), Color("c8bdb0"))
	_add_mesh_only("CenterPodiumGlow", Vector3(-3.0, 1.5, 0.0), Vector3(1.4, 0.4, 1.4), Color("68d4ff"), true)
	

	
	# Enhanced van with windows and details
	_add_block("Van", Vector3(0.0, 0.85, 18.0), Vector3(5.0, 1.7, 2.5), Color("2a2a36"), true)
	_add_mesh_only("VanWindow_L", Vector3(-1.2, 1.3, 17.8), Vector3(1.0, 0.8, 0.15), Color(0.4, 0.6, 0.8, 0.4))
	_add_mesh_only("VanWindow_R", Vector3(1.2, 1.3, 17.8), Vector3(1.0, 0.8, 0.15), Color(0.4, 0.6, 0.8, 0.4))
	_add_mesh_only("VanDoor", Vector3(-1.8, 0.9, 18.3), Vector3(0.5, 1.2, 0.1), Color("3a3a40"))
	_add_mesh_only("VanDoorHandle", Vector3(-1.85, 1.1, 18.35), Vector3(0.08, 0.12, 0.08), Color("8a8179"))
	_add_mesh_only("VanRoof", Vector3(0.0, 1.6, 18.0), Vector3(5.2, 0.15, 2.7), Color("1a1a20"))
	_add_mesh_only("VanBumper", Vector3(0.0, 0.3, 19.35), Vector3(5.2, 0.2, 0.15), Color("1a1a1a"))
	
	# Enhanced crate with lid and markings
	_add_block("Crate1", Vector3(-8.0, 0.55, 10.0), Vector3(1.5, 1.1, 1.5), Color("6a5944"), true)
	_add_mesh_only("CrateLid", Vector3(-8.0, 1.15, 10.0), Vector3(1.6, 0.15, 1.6), Color("5a4939"))
	_add_mesh_only("CrateStripe", Vector3(-8.0, 0.5, 10.35), Vector3(1.55, 1.0, 0.08), Color("d0ad0f"))
	
	# Enhanced dumpster with lid and details
	_add_block("Dumpster", Vector3(6.0, 0.68, 12.0), Vector3(2.2, 1.36, 1.3), Color("2a3a2a"), true)
	_add_mesh_only("DumpsterLid", Vector3(6.0, 1.4, 11.8), Vector3(2.4, 0.2, 0.4), Color("1a2a1a"))
	_add_mesh_only("DumpsterHandle_L", Vector3(4.8, 1.45, 11.8), Vector3(0.12, 0.15, 0.12), Color("8a8179"))
	_add_mesh_only("DumpsterHandle_R", Vector3(7.2, 1.45, 11.8), Vector3(0.12, 0.15, 0.12), Color("8a8179"))
	_add_mesh_only("DumpsterDent", Vector3(6.2, 0.85, 11.9), Vector3(0.3, 0.4, 0.2), Color("1a2a1a"))
	
	# Simple street markings
	for i in range(12):
		var z_pos = -24.0 + i * 5.0
		_add_mesh_only("StreetMark%d" % i, Vector3(-1.0, 0.02, z_pos), Vector3(2.0, 0.02, 0.8), Color("d8dde7"))
	
	# ADDITIONAL ENVIRONMENTAL DETAILS FOR IMMERSION
	# West side alcove with additional clutter
	_add_block("WestBox1", Vector3(-22.0, 0.35, -10.0), Vector3(0.9, 0.7, 0.9), Color("5a6055"), true)
	_add_block("WestBox2", Vector3(-20.5, 0.3, -8.0), Vector3(1.1, 0.6, 1.1), Color("6a7055"), true)
	_add_mesh_only("WestBoxString", Vector3(-21.2, 0.8, -9.0), Vector3(1.8, 0.04, 1.8), Color("8a7a6a"))
	_add_mesh_only("WestSign", Vector3(-28.0, 3.0, -18.0), Vector3(0.8, 0.3, 0.08), Color("8a7a5a"))
	_add_mesh_only("WestSignMount", Vector3(-29.5, 3.0, -18.0), Vector3(0.15, 0.8, 0.15), Color("4a5a6a"))
	_add_mesh_only("WestLamp1", Vector3(-32.0, 4.5, -5.0), Vector3(0.12, 1.5, 0.12), Color("5a6a7a"))
	_add_mesh_only("WestLampHead", Vector3(-32.0, 5.8, -5.0), Vector3(0.3, 0.2, 0.3), Color("3a4a5a"))
	
	# East side alcove with details
	_add_block("EastBox1", Vector3(22.0, 0.35, 8.0), Vector3(0.9, 0.7, 0.9), Color("5a6055"), true)
	_add_block("EastBox2", Vector3(20.5, 0.3, 10.0), Vector3(1.1, 0.6, 1.1), Color("6a7055"), true)
	_add_mesh_only("EastBoxString", Vector3(21.2, 0.8, 9.0), Vector3(1.8, 0.04, 1.8), Color("8a7a6a"))
	_add_mesh_only("EastSign", Vector3(28.0, 3.0, 18.0), Vector3(0.8, 0.3, 0.08), Color("8a7a5a"))
	_add_mesh_only("EastSignMount", Vector3(29.5, 3.0, 18.0), Vector3(0.15, 0.8, 0.15), Color("4a5a6a"))
	_add_mesh_only("EastLamp1", Vector3(32.0, 4.5, 5.0), Vector3(0.12, 1.5, 0.12), Color("5a6a7a"))
	_add_mesh_only("EastLampHead", Vector3(32.0, 5.8, 5.0), Vector3(0.3, 0.2, 0.3), Color("3a4a5a"))
	
	# Central alley clutter
	_add_block("TrashBag1", Vector3(-5.0, 0.25, 2.0), Vector3(0.6, 0.5, 0.6), Color("3a3a3a"), true)
	_add_block("TrashBag2", Vector3(-4.2, 0.26, 4.0), Vector3(0.7, 0.52, 0.7), Color("2a2a2a"), true)
	_add_block("Pipe", Vector3(3.0, 2.5, -3.0), Vector3(0.15, 2.0, 0.15), Color("5a6a7a"), true)
	_add_block("Pipe2", Vector3(3.6, 2.2, 5.0), Vector3(0.12, 1.8, 0.12), Color("4a5a6a"), true)
	
	# Additional facade storytelling
	_add_mesh_only("WestGraffiti1", Vector3(-30.1, 3.5, -12.0), Vector3(0.08, 0.6, 8.0), Color(0.8, 0.6, 0.2, 0.15))
	_add_mesh_only("EastGraffiti1", Vector3(30.1, 3.5, 12.0), Vector3(0.08, 0.6, 8.0), Color(0.8, 0.6, 0.2, 0.15))
	_add_mesh_only("WestBoarding", Vector3(-35.1, 2.0, -22.0), Vector3(0.08, 1.5, 2.0), Color("5a6a5a"))
	_add_mesh_only("EastBoarding", Vector3(35.1, 2.0, 22.0), Vector3(0.08, 1.5, 2.0), Color("5a6a5a"))
	
	# ADDITIONAL BUILDING DETAILS FOR VISUAL RICHNESS
	# West roof edge coping stones
	for i in range(0, 56, 8):
		_add_mesh_only("WestRoofCoping%d" % i, Vector3(-35.2, 10.4, -28.0 + i), Vector3(0.4, 0.2, 0.4), Color("d6cec0"))
		_add_mesh_only("WestRoofCopingEast%d" % i, Vector3(-24.8, 10.4, -28.0 + i), Vector3(0.4, 0.2, 0.4), Color("d6cec0"))
	
	# West window mullions (subtle cross divisions)
	for level in range(0, 9, 3):
		for section in range(-28, 28, 7):
			_add_mesh_only("WestMullion%dH%d" % [level, section], Vector3(-30.0, 0.5 + level, float(section)), Vector3(10.1, 0.08, 0.1), Color("4a525c"))
	
	# East roof edge coping stones
	for i in range(0, 56, 8):
		_add_mesh_only("EastRoofCoping%d" % i, Vector3(35.2, 10.4, -28.0 + i), Vector3(0.4, 0.2, 0.4), Color("d6cec0"))
		_add_mesh_only("EastRoofCopingWest%d" % i, Vector3(24.8, 10.4, -28.0 + i), Vector3(0.4, 0.2, 0.4), Color("d6cec0"))
	
	# East window mullions
	for level in range(0, 9, 3):
		for section in range(-28, 28, 7):
			_add_mesh_only("EastMullion%dH%d" % [level, section], Vector3(30.0, 0.5 + level, float(section)), Vector3(10.1, 0.08, 0.1), Color("4a525c"))
	
	# ACCENT LIGHTING - subtle highlights on key building features (REDUCED TO FIX FLASHING)
	# These are now very subtle to prevent rendering artifacts
	_add_mesh_only("WestAccentLightRoof", Vector3(-30.0, 10.6, 0.0), Vector3(10.5, 0.15, 56.5), Color("3a5a7f"), true)
	_add_mesh_only("WestAccentLightEntry1", Vector3(-35.0, 1.8, -15.0), Vector3(0.2, 1.0, 0.3), Color("4a6a8f"), true)
	_add_mesh_only("WestAccentLightEntry2", Vector3(-35.0, 1.8, 0.0), Vector3(0.2, 1.0, 0.3), Color("4a6a8f"), true)
	
	# East building accent lights - subtle
	_add_mesh_only("EastAccentLightRoof", Vector3(30.0, 10.6, 0.0), Vector3(10.5, 0.15, 56.5), Color("3a5a7f"), true)
	_add_mesh_only("EastAccentLightEntry1", Vector3(35.0, 1.8, 15.0), Vector3(0.2, 1.0, 0.3), Color("4a6a8f"), true)
	_add_mesh_only("EastAccentLightEntry2", Vector3(35.0, 1.8, 0.0), Vector3(0.2, 1.0, 0.3), Color("4a6a8f"), true)
	
# Day contact position markers - tightened
	_add_marker_column(Vector3(-9.5, 0.0, -15.0), Color("7ddcff"))  # West bench
	_add_marker_column(Vector3(-2.5, 0.0, 0.0), Color("7ddcff"))     # Center podium
	_add_marker_column(Vector3(7.0, 0.0, 8.0), Color("7ddcff"))     # East bar


func _add_marker_column(pos, color):
	# These are non-blocking route beacons for the day contacts.
	var column = MeshInstance3D.new()
	column.name = "DayRouteMarker"
	var mesh = CylinderMesh.new()
	mesh.top_radius = 0.05
	mesh.bottom_radius = 0.05
	mesh.height = 1.6
	column.mesh = mesh
	var mat = StandardMaterial3D.new()
	mat.emission_enabled = true
	mat.emission = color
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.albedo_color = Color(color.r, color.g, color.b, 0.22)
	column.material_override = mat
	column.position = Vector3(pos.x, 0.8, pos.z)
	marker_root.add_child(column)

func _add_block(name, pos, size, color, with_collision := true, flat := false):
	# Standard helper for visible city geometry. Most walls, props, and floors
	# are built through this so material rules and collisions stay consistent.
	var body = StaticBody3D.new()
	body.name = name
	body.position = pos
	geometry_root.add_child(body)

	var mesh_instance = MeshInstance3D.new()
	var box = BoxMesh.new()
	box.size = size
	mesh_instance.mesh = box
	var mat = StandardMaterial3D.new()
	_configure_material(mat, name, color, false)
	mesh_instance.material_override = mat
	if flat:
		mesh_instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	body.add_child(mesh_instance)

	if with_collision:
		var shape = CollisionShape3D.new()
		var box_shape = BoxShape3D.new()
		box_shape.size = size
		shape.shape = box_shape
		body.add_child(shape)
	return body

func _add_collision_block(name, pos, size):
	# Collision-only blocks are used for hidden support geometry where we want
	# gameplay solidity without visible meshes.
	var body = StaticBody3D.new()
	body.name = name
	body.position = pos
	geometry_root.add_child(body)

	var shape = CollisionShape3D.new()
	var box_shape = BoxShape3D.new()
	box_shape.size = size
	shape.shape = box_shape
	body.add_child(shape)
	return body

func _add_mesh_only(name, pos, size, color, emissive := false):
	# Enhanced mesh-only with LOD culling, better clipping fixes
	var node = MeshInstance3D.new()
	node.name = name
	var box = BoxMesh.new()
	box.size = size
	node.mesh = box
	var mat = StandardMaterial3D.new()
	_configure_material(mat, name, color, emissive)
	
	var lower = name.to_lower()
	var is_thin = size.y <= 0.25 or size.z <= 0.25 or size.x <= 0.25
	if is_thin:
		mat.cull_mode = BaseMaterial3D.CULL_DISABLED
		node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		mat.disable_receive_shadows = true
		# no_depth_test only for glass to avoid overwriting front objects
	
	# Simple LOD
	node.visible = true
	
	node.material_override = mat
	node.position = pos
	if size.y <= 0.12 or size.z <= 0.12 or size.x <= 0.12:
		node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		node.gi_mode = GeometryInstance3D.GI_MODE_DISABLED
		
	geometry_root.add_child(node)
	return node


func _create_shadow_zones():
	# Shadow zones tightened for canyon (±10 alley focus)
	_add_shadow_zone(Vector3(-9.5, 1.0, -20.0), Vector3(5.8, 2.0, 2.2)) # bench
	_add_shadow_zone(Vector3(-16.0, 1.0, -4.8), Vector3(2.2, 2.0, 2.2))
	_add_shadow_zone(Vector3(-12.0, 1.0, -4.9), Vector3(2.2, 2.0, 2.2))
	_add_shadow_zone(Vector3(-16.0, 1.0, 6.0), Vector3(2.4, 2.0, 2.8))
	_add_shadow_zone(Vector3(-10.0, 1.0, 6.0), Vector3(2.4, 2.0, 2.8))
	_add_shadow_zone(Vector3(-25.0, 1.0, 11.0), Vector3(4.4, 2.0, 5.8))
	_add_shadow_zone(Vector3(-27.0, 1.0, -14.7), Vector3(3.0, 2.0, 2.0))
	_add_shadow_zone(Vector3(-2.2, 1.0, 3.2), Vector3(2.4, 2.0, 2.4))
	_add_shadow_zone(Vector3(4.5, 1.0, 8.1), Vector3(2.4, 2.0, 2.4))
	_add_shadow_zone(Vector3(17.0, 1.0, 7.4), Vector3(3.6, 2.0, 2.2))
	_add_shadow_zone(Vector3(25.5, 1.0, 4.1), Vector3(2.8, 2.0, 2.0))
	_add_shadow_zone(Vector3(16.0, 1.0, 17.2), Vector3(5.6, 2.0, 2.8))
	_add_shadow_zone(Vector3(13.0, 1.0, 18.1), Vector3(4.8, 2.0, 2.4))
	_add_shadow_zone(Vector3(27.0, 1.0, 18.2), Vector3(3.2, 2.0, 3.4))

func _add_shadow_zone(pos, size):
	# Each zone is a simple Area3D with the shared shadow script attached.
	var area = Area3D.new()
	area.name = "ShadowZone"
	area.set_script(SHADOW_ZONE_SCRIPT)
	area.position = pos
	geometry_root.add_child(area)
	var shape = CollisionShape3D.new()
	var box = BoxShape3D.new()
	box.size = size
	shape.shape = box
	area.add_child(shape)

func _spawn_level_characters():
	# Day contacts teach the layout along the alleyway.
	# Night actors create the stealth challenge in the same space.
	
# Day contacts - tightened alley
	contact_npcs.append(_spawn_npc("Mara", "contact", "alibi", "day", Vector3(-9.5, 0.0, -15.0), [], 0.0))
	contact_npcs.append(_spawn_npc("Jules", "contact", "guest_pass", "day", Vector3(-2.5, 0.0, 0.0), [], 0.0))
	contact_npcs.append(_spawn_npc("Nico", "contact", "route_intel", "day", Vector3(7.0, 0.0, 8.0), [], 0.0))

# Night guards - 2nd set + night2 ramp (extend patrols/detection)
	guard_npcs.append(_spawn_npc("Guard One", "guard", "", "night", Vector3(-7.5, 0.0, -8.0), [Vector3(-7.5, 0.0, -8.0), Vector3(-7.5, 0.0, 8.0), Vector3(-3.0, 0.0, 12.0)], 1.6))
	guard_npcs.append(_spawn_npc("Guard Two", "guard", "", "night", Vector3(7.5, 0.0, 10.0), [Vector3(7.5, 0.0, 10.0), Vector3(7.5, 0.0, 20.0)], 1.7))
	guard_npcs.append(_spawn_npc("Guard Three", "guard", "", "night", Vector3(0.0, 0.0, 15.0), [Vector3(0.0, 0.0, 15.0), Vector3(4.0, 0.0, 22.0)], 1.8))  # 2nd guard night2
	guard_npcs.append(_spawn_npc("Guard Four", "guard", "", "night", Vector3(-4.0, 0.0, 18.0), [Vector3(-4.0, 0.0, 18.0), Vector3(2.0, 0.0, 25.0)], 1.65))
	
	# Witness
	var witness = _spawn_npc("Observer", "witness", "", "night", Vector3(1.5, 0.0, 2.0), [Vector3(1.5, 0.0, 2.0), Vector3(3.5, 0.0, 10.0)], 1.1)
	civilian_npcs.append(witness)

	# Target - tightened path
	target_npc = _spawn_npc("Target", "target", "", "night", Vector3(0.0, 0.0, -12.0), [Vector3(0.0, 0.0, -12.0), Vector3(3.5, 0.0, -4.0), Vector3(5.0, 0.0, 4.0), Vector3(4.5, 0.0, 14.0), Vector3(1.5, 0.0, 20.0)], 1.4)

	# Civilians - tightened paths
	civilian_npcs.append(_spawn_npc("Civilian A", "civilian", "", "night", Vector3(-4.5, 0.0, 3.0), [Vector3(-4.5, 0.0, 3.0), Vector3(-5.5, 0.0, 8.0)], 0.9))
	civilian_npcs.append(_spawn_npc("Civilian B", "civilian", "", "night", Vector3(2.5, 0.0, -4.0), [Vector3(2.5, 0.0, -4.0), Vector3(5.5, 0.0, 2.0)], 0.8))
	civilian_npcs.append(_spawn_npc("Civilian C", "civilian", "", "night", Vector3(9.0, 0.0, 12.0), [Vector3(9.0, 0.0, 12.0), Vector3(11.0, 0.0, 18.0)], 0.85))

func _spawn_npc(name_text, role, key, phase_tag, start_pos, patrol, speed):
	# NPCs are assembled procedurally for the same reason as the city geometry:
	# fast iteration while the design is still moving.
	var npc = CharacterBody3D.new()
	npc.name = name_text.replace(" ", "")
	npc.set_script(NPC_SCRIPT)
	npc.position = start_pos

	var collision = CollisionShape3D.new()
	var capsule = CapsuleShape3D.new()
	capsule.radius = 0.32
	capsule.height = 1.64
	collision.shape = capsule
	collision.position = Vector3(0.0, 0.92, 0.0)
	npc.add_child(collision)

	var visuals = Node3D.new()
	visuals.name = "Visuals"
	npc.add_child(visuals)

	# Improved body proportions - more realistic human silhouette
	var body_mesh = MeshInstance3D.new()
	body_mesh.name = "Body"
	var body = CapsuleMesh.new()
	body.radius = 0.28
	body.height = 1.44
	body_mesh.mesh = body
	body_mesh.position = Vector3(0.0, 0.78, 0.0)
	visuals.add_child(body_mesh)

	# Chest/torso detail (separate from body for better proportions)
	var chest_mesh = MeshInstance3D.new()
	chest_mesh.name = "Chest"
	var chest = BoxMesh.new()
	chest.size = Vector3(0.32, 0.44, 0.22)
	chest_mesh.mesh = chest
	chest_mesh.position = Vector3(0.0, 0.88, 0.0)
	visuals.add_child(chest_mesh)

	# Improved head proportions - slightly larger, better positioned
	var head_mesh = MeshInstance3D.new()
	head_mesh.name = "Head"
	var head = SphereMesh.new()
	head.radius = 0.22
	head.height = 0.44
	head_mesh.mesh = head
	head_mesh.position = Vector3(0.0, 1.56, 0.0)
	visuals.add_child(head_mesh)
	
	# Neck detail
	var neck_mesh = MeshInstance3D.new()
	neck_mesh.name = "Neck"
	var neck = CapsuleMesh.new()
	neck.radius = 0.08
	neck.height = 0.16
	neck_mesh.mesh = neck
	neck_mesh.position = Vector3(0.0, 1.32, 0.0)
	visuals.add_child(neck_mesh)
	
	# Arms and hands for realistic silhouette
	var arm_left = MeshInstance3D.new()
	arm_left.name = "ArmLeft"
	var arm_left_mesh = CapsuleMesh.new()
	arm_left_mesh.radius = 0.1
	arm_left_mesh.height = 0.6
	arm_left.mesh = arm_left_mesh
	arm_left.position = Vector3(-0.24, 0.95, 0.0)
	visuals.add_child(arm_left)
	
	var arm_right = MeshInstance3D.new()
	arm_right.name = "ArmRight"
	var arm_right_mesh = CapsuleMesh.new()
	arm_right_mesh.radius = 0.1
	arm_right_mesh.height = 0.6
	arm_right.mesh = arm_right_mesh
	arm_right.position = Vector3(0.24, 0.95, 0.0)
	visuals.add_child(arm_right)
	
	var hand_left = MeshInstance3D.new()
	hand_left.name = "HandLeft"
	var hand_left_mesh = SphereMesh.new()
	hand_left_mesh.radius = 0.085
	hand_left.mesh = hand_left_mesh
	hand_left.position = Vector3(-0.24, 0.48, 0.0)
	visuals.add_child(hand_left)
	
	var hand_right = MeshInstance3D.new()
	hand_right.name = "HandRight"
	var hand_right_mesh = SphereMesh.new()
	hand_right_mesh.radius = 0.085
	hand_right.mesh = hand_right_mesh
	hand_right.position = Vector3(0.24, 0.48, 0.0)
	visuals.add_child(hand_right)

	var marker = Node3D.new()
	marker.name = "Marker"
	marker.position = Vector3(0.0, 2.3, 0.0)
	npc.add_child(marker)

	var marker_mesh = MeshInstance3D.new()
	marker_mesh.name = "MarkerMesh"
	var diamond = CylinderMesh.new()
	diamond.top_radius = 0.0
	diamond.bottom_radius = 0.2
	diamond.height = 0.36
	marker_mesh.mesh = diamond
	marker_mesh.rotation_degrees = Vector3(180.0, 0.0, 0.0)
	marker.add_child(marker_mesh)

	npc.world_ref = self
	npc.npc_name = name_text
	npc.role = role
	npc.contact_key = key
	npc.active_phase = phase_tag
	npc.patrol_points = patrol
	npc.patrol_speed = speed if speed > 0.0 else 0.0

	if role == "contact":
		npc.rotation_degrees = Vector3(0.0, 190.0, 0.0)
	elif role == "guard":
		npc.detect_radius = 5.5
		npc.detect_fov = 56.0
		npc.detect_rate = 22.0
	elif role == "witness":
		npc.detect_radius = 4.8
		npc.detect_fov = 62.0
		npc.detect_rate = 15.0
	elif role == "target":
		npc.detect_radius = 3.9
		npc.detect_fov = 52.0
		npc.detect_rate = 10.0
	elif role == "civilian":
		npc.set_marker_visible(false)

	npc_root.add_child(npc)
	return npc

func _create_extraction_zone():
	# The extraction trigger at the north end of the alley.
	extraction_area = Area3D.new()
	extraction_area.name = "ExtractionZone"
	extraction_area.position = Vector3(8.0, 1.0, 25.0)  # North side extraction point
	geometry_root.add_child(extraction_area)
	var shape = CollisionShape3D.new()
	var box = BoxShape3D.new()
	box.size = Vector3(2.8, 2.0, 2.8)
	shape.shape = box
	extraction_area.add_child(shape)
	extraction_area.body_entered.connect(_on_extraction_body_entered)
	extraction_area.body_exited.connect(_on_extraction_body_exited)

	extraction_marker = MeshInstance3D.new()
	var cylinder = CylinderMesh.new()
	cylinder.top_radius = 0.35
	cylinder.bottom_radius = 0.35
	cylinder.height = 2.8
	extraction_marker.mesh = cylinder
	var mat = StandardMaterial3D.new()
	mat.emission_enabled = true
	mat.emission = Color("38d388")
	mat.emission_energy_multiplier = 1.5
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.albedo_color = Color(0.22, 0.83, 0.55, 0.35)
	extraction_marker.material_override = mat
	extraction_marker.position = Vector3(8.0, 1.4, 25.0)  # Visual marker at extraction point
	extraction_marker.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	marker_root.add_child(extraction_marker)

func _create_hud():
	# Ultra-compact minimal HUD - almost invisible
	ui_root = Control.new()
	ui_root.name = "HUD"
	add_child(ui_root)
	ui_root.set_anchors_preset(Control.PRESET_FULL_RECT)

	# Title - tiny, top left corner
	var title = Label.new()
	title.text = "ALLEY"
	title.position = Vector2(8, 6)
	title.add_theme_font_size_override("font_size", 11)
	title.add_theme_color_override("font_color", Color("68d4ff"))
	ui_root.add_child(title)
	hud["title"] = title

	# Objective - compact, single line
	var objective = Label.new()
	objective.position = Vector2(8, 20)
	objective.size = Vector2(300, 24)
	objective.autowrap_mode = TextServer.AUTOWRAP_WORD
	objective.add_theme_font_size_override("font_size", 12)
	objective.add_theme_color_override("font_color", Color("e6ecff"))
	ui_root.add_child(objective)
	hud["objective"] = objective

	# Stats - top right, tiny
	var stats = Label.new()
	stats.position = Vector2(1750, 6)
	stats.size = Vector2(154, 36)
	stats.autowrap_mode = TextServer.AUTOWRAP_WORD
	stats.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	stats.add_theme_font_size_override("font_size", 10)
	stats.add_theme_color_override("font_color", Color("7a8999"))
	ui_root.add_child(stats)
	hud["stats"] = stats

	# Center message - small, fade away
	var message = Label.new()
	message.position = Vector2(700, 12)
	message.size = Vector2(520, 32)
	message.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	message.add_theme_font_size_override("font_size", 13)
	message.add_theme_color_override("font_color", Color("fff3c6"))
	ui_root.add_child(message)
	hud["message"] = message

	# Bottom prompt - tiny, only when needed
	var prompt_panel = ColorRect.new()
	prompt_panel.color = Color(0.02, 0.03, 0.05, 0.58)
	prompt_panel.position = Vector2(650, 1045)
	prompt_panel.size = Vector2(620, 28)
	ui_root.add_child(prompt_panel)
	hud["prompt_panel"] = prompt_panel

	var prompt = Label.new()
	prompt.position = Vector2(670, 1050)
	prompt.size = Vector2(580, 20)
	prompt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	prompt.add_theme_font_size_override("font_size", 11)
	prompt.add_theme_color_override("font_color", Color("8a9aaa"))
	ui_root.add_child(prompt)
	hud["prompt"] = prompt

func _handle_interaction():
	# One interaction key handles contacts, takedowns, and extraction in priority order.
	if mission_failed or level_complete:
		return
	if near_extraction and extraction_marker.visible and takedown_done:
		_complete_level()
		return

	var nearest = _get_nearest_interactable()
	if nearest == null:
		return

	if nearest.role == "contact":
		_handle_contact_interaction(nearest)
		return

	if nearest.role == "target" and phase == "night":
		_attempt_takedown(nearest)
		return

func _handle_contact_interaction(npc):
	# Every daytime contact improves the player's night setup in a slightly
	# different way, even if the bonuses are still abstract prototype numbers.
	if npc.interaction_used:
		return
	npc.interaction_used = true
	npc.set_marker_visible(false)

	match npc.contact_key:
		"alibi":
			contacts["alibi"] = true
			reputation += 8.0
			heat = max(heat - 4.0, 0.0)
			_show_message("First contact secure. You've got an ally.")
		"guest_pass":
			contacts["guest_pass"] = true
			reputation += 6.0
			_show_message("Second contact made. Routes are confirmed.")
		"route_intel":
			contacts["route_intel"] = true
			reputation += 4.0
			_show_message("Third contact complete. Escape route locked in.")

	_refresh_objective()
	if _all_contacts_met():
		_show_message("All contacts made. Press Tab to begin night phase.")

func _attempt_takedown(npc):
	# Failure here should feel like "bad setup" rather than instant death, so
	# the script raises suspicion first unless the player is fully blown.
	if takedown_done:
		return
	if not npc.is_takedown_reachable(player):
		suspicion = min(suspicion + 8.0, 100.0)
		_show_message("Too exposed. Get behind Alden or use cover first.")
		return
	if _any_watcher_sees_player(npc):
		suspicion = min(suspicion + 18.0, 100.0)
		_show_message("Someone has sight on you. Break line of sight first.")
		if suspicion >= 100.0:
			_fail_mission("The gala locks down around you.")
		return

	takedown_done = true
	money += 15000
	heat += 24.0
	reputation -= 6.0
	npc.visible = false
	npc.set_process(false)
	extraction_marker.visible = true
	_refresh_objective()
	_show_message("Alden is down. Cut through the loading alley and reach the safehouse.")

func _begin_night():
	# Night transition with Tween fog/UI fade
	if phase == "night":
		return
	
	# Tween environment fog/post-process
	var tween = create_tween()
	tween.parallel().tween_property(environment.environment, "ambient_light_energy", 0.26, 2.0)
	tween.parallel().tween_property(environment.environment, "background_color", Color("0c1018"), 2.0)
	tween.parallel().tween_property(day_sun, "visible", false, 1.0)
	tween.parallel().tween_property(moon_light, "visible", true, 1.0)
	
	# UI fade
	tween.parallel().tween_property(hud["title"], "modulate:a", 0.0, 0.5).set_delay(1.5)
	tween.parallel().tween_property(hud["objective"], "modulate:a", 0.0, 0.5).set_delay(1.5)
	await tween.finished
	
	phase = "night"
	suspicion = 0.0
	player.position = Vector3(8.5, 0.0, 17.0)  # Tightened east alley spawn
	_apply_phase_visibility()
	_refresh_objective()
	
	# Fade UI back
	var tween2 = create_tween()
	tween2.tween_property(hud["title"], "modulate:a", 1.0, 0.5)
	tween2.parallel().tween_property(hud["objective"], "modulate:a", 1.0, 0.5)
	
	_show_message("Night phase active. Target is in the alley. Take them down and extract through the north door.")

func _apply_phase_visibility():
	# Point lights/NPC vis only (env tweened in _begin_night/_begin_day)
	var night = phase == "night"
	for light in point_lights:
		light.visible = night

	for npc in npc_root.get_children():
		var is_active = npc.active_phase == phase or npc.active_phase == "both"
		npc.visible = is_active
		npc.set_physics_process(is_active)
		if npc.role == "contact":
			npc.set_marker_visible(is_active and not npc.interaction_used)
		elif npc.role == "target":
			npc.set_marker_visible(is_active and not takedown_done)
		else:
			npc.set_marker_visible(false)

	for marker in marker_root.get_children():
		if marker.name.begins_with("DayRouteMarker"):
			marker.visible = not night

	extraction_marker.visible = night and takedown_done
	day_sun.visible = not night
	moon_light.visible = night

func _update_prompt():
	# Prompt logic is intentionally explicit so it stays readable while design changes.
	var prompt = ""
	if mission_failed:
		prompt = "Mission failed. Press R to restart this level."
	elif level_complete:
		prompt = "Level complete. Press R to restart and tune the blockout."
	elif near_extraction and extraction_marker.visible and takedown_done:
		prompt = "Press E to enter the safehouse and end the level."
	else:
		var nearest = _get_nearest_interactable()
		if nearest != null:
			if nearest.role == "contact":
				prompt = "Press E to talk to %s." % nearest.npc_name
			elif nearest.role == "target":
				if nearest.is_takedown_reachable(player):
					prompt = "Press E to take down %s." % nearest.npc_name
				else:
					prompt = "Shadow %s and get behind him before you strike." % nearest.npc_name
		elif phase == "day" and _all_contacts_met():
			prompt = "Press Tab to start the gala night."

	hud["prompt"].text = prompt
	hud["prompt_panel"].visible = prompt != ""

func _update_hud():
	# HUD text is rebuilt every frame because the data set is tiny and the
	# simplicity is worth more than optimizing a prototype.
	hud["objective"].text = current_objective
	hud["stats"].text = "Phase: %s\nReputation: %d\nSuspicion: %d\nHeat: %d\nMoney: $%s\nHidden: %s" % [phase.capitalize(), int(round(reputation)), int(round(suspicion)), int(round(heat)), _format_money(money), "Yes" if player and player.is_hidden() else "No"]
	hud["message"].text = message_text

func _refresh_objective():
	# Objective text mirrors the current mission phase and state so the player
	# always has a short "what next" summary in the corner.
	if mission_failed:
		current_objective = "Mission failed. Restart and try a cleaner run."
		return
	if level_complete:
		current_objective = "You escaped cleanly. Use this blockout as the base for production polish."
		return
	if phase == "day":
		var remaining = []
		if not contacts["alibi"]:
			remaining.append("contact at west bench")
		if not contacts["guest_pass"]:
			remaining.append("contact at center plaza")
		if not contacts["route_intel"]:
			remaining.append("contact at east side")
		if remaining.is_empty():
			current_objective = "All contacts met. Press Tab to start night phase."
		else:
			current_objective = "Make contact: %s." % ", ".join(remaining)
	else:
		if not takedown_done:
			current_objective = "Night phase: locate target, take them down silently."
		else:
			current_objective = "Target down. Reach the green door at the north end."

func _show_message(text):
	# All temporary banner messages share one timer-driven channel.
	message_text = text
	message_timer = 4.0

func _get_nearest_interactable():
	# This chooses the closest valid interaction target for the prompt and E key.
	if player == null or not is_instance_valid(player) or not player.is_inside_tree():
		return null
	if npc_root == null or not is_instance_valid(npc_root):
		return null
	var player_position = player.global_position
	var best = null
	var best_distance = 99999.0
	for npc in npc_root.get_children():
		if npc == null or not is_instance_valid(npc) or not npc.is_inside_tree():
			continue
		if not npc.visible:
			continue
		var dist = npc.global_position.distance_to(player_position)
		if npc.role == "contact" and npc.can_interact(player):
			if dist < best_distance:
				best = npc
				best_distance = dist
		elif npc.role == "target" and phase == "night" and not takedown_done and dist <= 2.75:
			if dist < best_distance:
				best = npc
				best_distance = dist
	return best

func _any_watcher_sees_player(ignore_npc = null):
	# Used during takedown validation so witnesses and guards can spoil the hit.
	for npc in npc_root.get_children():
		if npc == ignore_npc:
			continue
		if not npc.visible:
			continue
		if npc.role in ["guard", "witness"] and npc.can_detect_player(player):
			return true
	return false

var night2_active = false

func raise_suspicion(amount, source_name = ""):
	# Night2 ramp: after takedown, guards more aggressive
	if mission_failed or level_complete:
		return
	if takedown_done:
		amount *= 1.6  # Night2 ramp
		if not night2_active:
			night2_active = true
			for npc in guard_npcs:
				npc.detect_radius *= 1.3
				npc.detect_rate *= 1.4
				npc.patrol_speed *= 1.2
				_show_message("Night 2: Guards on alert - faster, wider vision.")
	suspicion = min(suspicion + amount, 100.0)
	if source_name != "" and int(suspicion) % 20 == 0:
		_show_message("%s is getting a better look at you." % source_name)
	if suspicion >= 100.0:
		_fail_mission("The room turns on you. Your cover collapses.")

func _fail_mission(reason):
	# Mission state changes are guarded so they only happen once.
	if mission_failed or level_complete:
		return
	mission_failed = true
	current_objective = "Mission failed. Press R to restart."
	_show_message(reason)

func _complete_level():
	if level_complete:
		return
	level_complete = true
	current_objective = "Level complete. Press R to run the blockout again."
	_show_message("Clean exit. This is now a real first level blockout.")

func _on_extraction_body_entered(body):
	if body == player:
		near_extraction = true

func _on_extraction_body_exited(body):
	if body == player:
		near_extraction = false

func _all_contacts_met():
	return contacts["alibi"] and contacts["guest_pass"] and contacts["route_intel"]

func _format_money(value):
	# Lightweight manual formatting keeps the display readable without needing
	# any extra utility dependency just for comma separators.
	var s = str(value)
	var out = ""
	while s.length() > 3:
		out = "," + s.substr(s.length() - 3, 3) + out
		s = s.substr(0, s.length() - 3)
	out = s + out
	return out
