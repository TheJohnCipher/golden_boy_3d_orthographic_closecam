
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
const INTENT_CATALOG = preload("res://scripts/world/intent_catalog.gd")
const LAYOUT_DATA = preload("res://scripts/world/layout_data.gd")
const MATERIAL_LIBRARY = preload("res://scripts/world/material_library.gd")
const PLAYER_FACTORY = preload("res://scripts/world/player_factory.gd")
const NPC_FACTORY = preload("res://scripts/world/npc_factory.gd")
const HUD_CONTROLLER = preload("res://scripts/world/hud_controller.gd")
const MISSION_CONTROLLER = preload("res://scripts/world/mission_controller.gd")

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

# HUD label references and shared visual helper state.
var hud = {}
var material_library = MATERIAL_LIBRARY.new()

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
	if ui_root != null and is_instance_valid(ui_root):
		_layout_hud()

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

# Small color helper used by procedural geometry detail accents.
func _mix_colors(a, b, t):
	return Color(
		lerpf(a.r, b.r, t),
		lerpf(a.g, b.g, t),
		lerpf(a.b, b.b, t),
		lerpf(a.a, b.a, t)
	)

# Procedural texture generation and surface assignment rules live in
# `scripts/world/material_library.gd`. Keeping this out of the main world
# controller makes gameplay changes much easier to review.
func _get_object_intent(name):
	# Delegated to shared catalog so intent docs can live in a focused module.
	return INTENT_CATALOG.resolve(name)

func _annotate_object(node, name, size, build_mode):
	# We attach rich metadata to every generated object so level intent remains
	# discoverable in the remote scene tree and in debug tools.
	if node == null:
		return
	node.set_meta("intent_note", _get_object_intent(name))
	node.set_meta("authored_name", name)
	node.set_meta("authored_size", size)
	node.set_meta("build_mode", build_mode)

func _build_mesh_profile(name, size):
	# "Box everywhere" is fast for blockout, but it hurts readability.
	# This profile builder swaps in simple primitives for specific prop types.
	var lower = name.to_lower()

	if lower.contains("pipe") and size.x <= 0.5 and size.z <= 0.5:
		var pipe = CylinderMesh.new()
		var pipe_radius = max(0.04, min(size.x, size.z) * 0.5)
		pipe.top_radius = pipe_radius
		pipe.bottom_radius = pipe_radius
		pipe.height = max(size.y, 0.1)
		return {"mesh": pipe, "rotation_degrees": Vector3.ZERO}

	if lower.contains("trashbag"):
		var bag = SphereMesh.new()
		var bag_radius = max(0.12, min(size.x, size.z) * 0.48)
		bag.radius = bag_radius
		bag.height = max(size.y, bag_radius * 2.0)
		return {"mesh": bag, "rotation_degrees": Vector3.ZERO}

	if lower.contains("handle") and size.x <= 0.25 and size.z <= 0.25:
		var handle = CylinderMesh.new()
		var min_dim = min(size.x, min(size.y, size.z))
		var handle_radius = max(0.015, min_dim * 0.45)
		handle.top_radius = handle_radius
		handle.bottom_radius = handle_radius
		handle.height = max(size.x, max(size.y, size.z))
		return {"mesh": handle, "rotation_degrees": Vector3(0.0, 0.0, 90.0)}

	var box = BoxMesh.new()
	box.size = size
	return {"mesh": box, "rotation_degrees": Vector3.ZERO}

func _add_detail_box(parent, name, local_pos, size, color, emissive := false):
	# Detail strips/caps are tiny helper meshes that break plain rectangular
	# silhouettes while keeping the blockout workflow procedural.
	var detail = MeshInstance3D.new()
	detail.name = name
	var mesh = BoxMesh.new()
	mesh.size = size
	detail.mesh = mesh
	var mat = StandardMaterial3D.new()
	_configure_material(mat, name, color, emissive)
	detail.material_override = mat
	detail.position = local_pos
	if size.y <= 0.08:
		detail.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(detail)
	return detail

func _add_detail_wheel(parent, name, local_pos, radius, width):
	var wheel = MeshInstance3D.new()
	wheel.name = name
	var cyl = CylinderMesh.new()
	cyl.top_radius = radius
	cyl.bottom_radius = radius
	cyl.height = width
	wheel.mesh = cyl
	var mat = StandardMaterial3D.new()
	_configure_material(mat, name, Color("1f232b"), false)
	mat.metallic = 0.25
	mat.roughness = 0.68
	wheel.material_override = mat
	wheel.position = local_pos
	wheel.rotation_degrees = Vector3(0.0, 0.0, 90.0)
	parent.add_child(wheel)
	return wheel

func _should_auto_detail_block(name, size):
	# We only auto-detail medium/small props. Large structural pieces already
	# receive bespoke facade layering in `_build_level_blockout`.
	var lower = name.to_lower()
	if size.x > 6.0 or size.y > 6.0 or size.z > 6.0:
		return false
	# Only target props that are likely to read as "plain boxes" without help.
	return (
		lower.contains("box")
		or lower.contains("crate")
		or lower.contains("trashbag")
		or lower == "van"
		or lower.contains("dumpster")
		or lower.contains("planter")
		or lower.contains("counter")
		or lower.contains("bar")
		or lower.contains("podium")
	)

func _decorate_block_geometry(body, name, size, color):
	# Automatic detail pass for `_add_block` objects. This is intentionally subtle:
	# enough to identify props at a glance without losing blockout editability.
	if not _should_auto_detail_block(name, size):
		return

	var lower = name.to_lower()
	var top_cap_h = clampf(size.y * 0.08, 0.03, 0.12)
	var top_cap_color = _mix_colors(color, Color(1.0, 1.0, 1.0, 1.0), 0.22)
	if size.y > 0.35 and not lower.contains("trashbag") and not lower.contains("pipe"):
		_add_detail_box(body, "%sTopCap" % name, Vector3(0.0, size.y * 0.5 + top_cap_h * 0.5, 0.0), Vector3(size.x * 1.03, top_cap_h, size.z * 1.03), top_cap_color)

	# Cargo-like props get a mid-band so they read as containers, not bare cubes.
	if (lower.contains("box") or lower.contains("crate")) and size.y > 0.4:
		_add_detail_box(body, "%sBand" % name, Vector3(0.0, 0.0, 0.0), Vector3(size.x * 1.02, max(0.05, size.y * 0.12), size.z * 1.02), _mix_colors(color, Color("d7bf8a"), 0.35))

	# Trash bags get a small top knot to sell the silhouette.
	if lower.contains("trashbag"):
		_add_detail_box(body, "%sKnot" % name, Vector3(0.0, size.y * 0.38, 0.0), Vector3(size.x * 0.22, size.y * 0.18, size.z * 0.22), _mix_colors(color, Color("6a6a6a"), 0.25))

	# Van gets wheels so it immediately reads as a vehicle rather than a slab.
	if lower == "van":
		var wheel_radius = clampf(min(size.y, size.z) * 0.22, 0.18, 0.34)
		var wheel_width = clampf(size.x * 0.08, 0.12, 0.22)
		var x_offset = size.x * 0.34
		var z_offset = size.z * 0.46
		var y_offset = -size.y * 0.34
		_add_detail_wheel(body, "%sWheelFL" % name, Vector3(-x_offset, y_offset, -z_offset), wheel_radius, wheel_width)
		_add_detail_wheel(body, "%sWheelFR" % name, Vector3(x_offset, y_offset, -z_offset), wheel_radius, wheel_width)
		_add_detail_wheel(body, "%sWheelRL" % name, Vector3(-x_offset, y_offset, z_offset), wheel_radius, wheel_width)
		_add_detail_wheel(body, "%sWheelRR" % name, Vector3(x_offset, y_offset, z_offset), wheel_radius, wheel_width)

	# Dumpster gets compact casters for clearer utility-prop readability.
	if lower.contains("dumpster"):
		var caster_radius = clampf(min(size.x, size.z) * 0.07, 0.06, 0.1)
		var caster_width = clampf(size.x * 0.05, 0.06, 0.1)
		var caster_x = size.x * 0.43
		var caster_z = size.z * 0.43
		var caster_y = -size.y * 0.46
		_add_detail_wheel(body, "%sCasterFL" % name, Vector3(-caster_x, caster_y, -caster_z), caster_radius, caster_width)
		_add_detail_wheel(body, "%sCasterFR" % name, Vector3(caster_x, caster_y, -caster_z), caster_radius, caster_width)
		_add_detail_wheel(body, "%sCasterRL" % name, Vector3(-caster_x, caster_y, caster_z), caster_radius, caster_width)
		_add_detail_wheel(body, "%sCasterRR" % name, Vector3(caster_x, caster_y, caster_z), caster_radius, caster_width)

func _configure_material(material, name, color, emissive := false):
	# Delegates visual rule selection to the shared material helper.
	material_library.configure_material(material, name, color, emissive)

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
	# Delegated to a focused builder to keep this file readable.
	player = PLAYER_FACTORY.create_player(self)

func _build_level_blockout():
	# Clean urban alleyway design - simple, clean, and playable.
	# Central 40-unit-wide alley with tall buildings on both sides.
	#
	# Documentation note for future maintainers:
	# Every object spawned here is automatically annotated with:
	# - `intent_note` (what the object is and why it exists)
	# - `build_mode` (static block / mesh-only / collision-only)
	# - `authored_size` (original dimensions)
	#
	# The source text for those intent notes lives in:
	# `scripts/world/intent_catalog.gd`.
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

# ALLEYWAY FLOOR - tight canyon +/-20u total (+/-10 alley + +/-5 curbs), 56 deep
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

# ALLEY PROPS - tightened to new +/-10 alley (west -9.5 to -16 range)
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
	
# East side props - tightened to new +/-10 alley (east 7.5-16 range)
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
	_annotate_object(column, column.name, Vector3(0.1, 1.6, 0.1), "marker_mesh")

func _add_block(name, pos, size, color, with_collision := true, flat := false):
	# Standard helper for visible city geometry. Most walls, props, and floors
	# are built through this so material rules and collisions stay consistent.
	var body = StaticBody3D.new()
	body.name = name
	body.position = pos
	geometry_root.add_child(body)

	var mesh_instance = MeshInstance3D.new()
	var mesh_profile = _build_mesh_profile(name, size)
	mesh_instance.mesh = mesh_profile["mesh"]
	mesh_instance.rotation_degrees = mesh_profile["rotation_degrees"]
	var mat = StandardMaterial3D.new()
	_configure_material(mat, name, color, false)
	mesh_instance.material_override = mat
	if flat:
		mesh_instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	body.add_child(mesh_instance)
	_decorate_block_geometry(body, name, size, color)

	if with_collision:
		var shape = CollisionShape3D.new()
		var box_shape = BoxShape3D.new()
		box_shape.size = size
		shape.shape = box_shape
		body.add_child(shape)
	_annotate_object(body, name, size, "static_block")
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
	_annotate_object(body, name, size, "collision_only")
	return body

func _add_mesh_only(name, pos, size, color, emissive := false):
	# Enhanced mesh-only with LOD culling, better clipping fixes
	var node = MeshInstance3D.new()
	node.name = name
	var mesh_profile = _build_mesh_profile(name, size)
	node.mesh = mesh_profile["mesh"]
	node.rotation_degrees = mesh_profile["rotation_degrees"]
	var mat = StandardMaterial3D.new()
	_configure_material(mat, name, color, emissive)
	
	var lower = name.to_lower()
	var is_thin = size.y <= 0.25 or size.z <= 0.25 or size.x <= 0.25
	if is_thin:
		mat.cull_mode = BaseMaterial3D.CULL_DISABLED
		node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		mat.disable_receive_shadows = true
		# Keep thin trim double-sided, but preserve depth testing to avoid overdraw artifacts.
	
	# Simple LOD
	node.visible = true
	
	node.material_override = mat
	node.position = pos
	if size.y <= 0.12 or size.z <= 0.12 or size.x <= 0.12:
		node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		node.gi_mode = GeometryInstance3D.GI_MODE_DISABLED
		
	geometry_root.add_child(node)
	_annotate_object(node, name, size, "mesh_only")
	return node


func _create_shadow_zones():
	# Data lives in `scripts/world/layout_data.gd` so world behavior and authored
	# coordinates can evolve independently.
	for zone in LAYOUT_DATA.shadow_zones():
		_add_shadow_zone(zone["pos"], zone["size"])

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
	_annotate_object(area, area.name, size, "shadow_area")

func _spawn_level_characters():
	NPC_FACTORY.spawn_level_characters(self)

func _spawn_group(spawn_rows, destination):
	NPC_FACTORY.spawn_group(self, spawn_rows, destination)

func _spawn_from_record(spawn_row):
	return NPC_FACTORY.spawn_from_record(self, spawn_row)

func _spawn_npc(name_text, role, key, phase_tag, start_pos, patrol, speed):
	return NPC_FACTORY.spawn_npc(self, name_text, role, key, phase_tag, start_pos, patrol, speed)

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
	HUD_CONTROLLER.create_hud(self)

func _on_viewport_size_changed():
	HUD_CONTROLLER.on_viewport_size_changed(self)

func _layout_hud():
	HUD_CONTROLLER.layout_hud(self)

func _handle_interaction():
	MISSION_CONTROLLER.handle_interaction(self)

func _handle_contact_interaction(npc):
	MISSION_CONTROLLER.handle_contact_interaction(self, npc)

func _attempt_takedown(npc):
	MISSION_CONTROLLER.attempt_takedown(self, npc)

func _begin_night():
	return MISSION_CONTROLLER.begin_night(self)

func _apply_phase_visibility():
	MISSION_CONTROLLER.apply_phase_visibility(self)

func _update_prompt():
	MISSION_CONTROLLER.update_prompt(self)

func _update_hud():
	HUD_CONTROLLER.update_hud(self)

func _refresh_objective():
	MISSION_CONTROLLER.refresh_objective(self)

func _show_message(text):
	MISSION_CONTROLLER.show_message(self, text)

func _get_nearest_interactable():
	return MISSION_CONTROLLER.get_nearest_interactable(self)

func _any_watcher_sees_player(ignore_npc = null):
	return MISSION_CONTROLLER.any_watcher_sees_player(self, ignore_npc)

var night2_active = false

func raise_suspicion(amount, source_name = ""):
	MISSION_CONTROLLER.raise_suspicion(self, amount, source_name)

func _fail_mission(reason):
	MISSION_CONTROLLER.fail_mission(self, reason)

func _complete_level():
	MISSION_CONTROLLER.complete_level(self)

func _on_extraction_body_entered(body):
	MISSION_CONTROLLER.on_extraction_body_entered(self, body)

func _on_extraction_body_exited(body):
	MISSION_CONTROLLER.on_extraction_body_exited(self, body)

func _all_contacts_met():
	return MISSION_CONTROLLER.all_contacts_met(self)

func _format_money(value):
	return MISSION_CONTROLLER.format_money(value)
