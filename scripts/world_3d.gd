
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
const INTENT_CATALOG = preload("res://scripts/world/intent_catalog.gd")
const LAYOUT_DATA = preload("res://scripts/world/layout_data.gd")
const MATERIAL_LIBRARY = preload("res://scripts/world/material_library.gd")
const VELVET_STRIP_BUILDER = preload("res://scripts/world/velvet_strip_builder.gd")
const PBR_MATERIALS = preload("res://scripts/world/pbr_materials.gd")
const PLAYER_FACTORY = preload("res://scripts/world/player_factory.gd")
const NPC_FACTORY = preload("res://scripts/world/npc_factory.gd")
const HUD_CONTROLLER = preload("res://scripts/world/hud_controller.gd")
const MISSION_CONTROLLER = preload("res://scripts/world/mission_controller.gd")
const INPUT_ACTIONS = preload("res://scripts/world/input_actions.gd")
const INPUT_REBIND_MANAGER = preload("res://scripts/world/input_rebind_manager.gd")
const PAUSE_MENU_CONTROLLER = preload("res://scripts/world/pause_menu_controller.gd")
const BUILDING_ENTRY_ZS = [-39.6, -19.8, 0.0, 19.8, 39.6]
const BUILDING_FLOORS = [2.1, 5.1, 8.1, 11.1, 14.1]
const BUILDING_WINDOW_BAYS = [-39.6, -25.2, -10.8, 3.6, 18.0, 32.4]
const BUILDING_BALCONY_LEVELS = [5.0, 9.0, 13.0]
const BUILDING_BALCONY_BAYS = [-32.4, -10.8, 10.8, 32.4]
const BUILDING_ROOF_ZS = [-36.0, -14.4, 7.2, 28.8]
const BUILDING_PIPE_ZS = [-32.4, 0.0, 32.4]
const SAFE_WINDOWED_SIZE = Vector2i(1280, 720)
const MAP_SURFACE_Y = 0.0
const MAP_MIN_VISIBLE_BOTTOM_Y = -0.04
const MAP_CURB_TOP_Y = 0.025
const MAP_TRANSITION_TOP_Y = 0.01
const STRUCTURAL_GEOMETRY_TOKENS = [
	"floor",
	"curb",
	"transition",
	"wall",
	"boundary",
	"rail",
	"roof",
	"plinth",
	"socle",
	"cornice",
	"course",
	"pilaster",
	"coping",
	"support",
	"marker",
]
const GROUND_SNAPPED_PROP_TOKENS = [
	"bench",
	"planter",
	"counter",
	"bar",
	"podium",
	"van",
	"crate",
	"dumpster",
	"trashbag",
	"bollard",
	"hydrant",
	"drain",
]

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
var audio_device_recheck_timer = 0.0
var audio_device_warning_shown = false

# HUD label references and shared visual helper state.
var hud = {}
var pause_overlay = null
var pause_menu_container = null
var material_library = MATERIAL_LIBRARY.new()
var pbr_materials = PBR_MATERIALS.new()
var forward_plus_renderer := false
var use_velvet_strip := true
var night_start_position := Vector3(-18.0, 0.0, -14.0)
var phase_transition_in_progress := false

func _enter_tree():
	# Apply native display sizing as early as possible.
	_configure_window_for_native_screen()

func _ready():
	# Boot order matters here:
	# 1. set the window size
	# 2. create rendering roots and lighting
	# 3. create player and geometry
	# 4. spawn gameplay actors
	# 5. create HUD and initial mission text
	INPUT_ACTIONS.ensure_defaults()
	INPUT_REBIND_MANAGER.load_bindings()
	# Always start at the current display's native size.
	_configure_window_for_native_screen()
	call_deferred("_reapply_native_display_size_after_boot")
	_stabilize_window_mode()
	_recover_audio_output_device(true)
	_create_environment_and_lights()
	_create_roots()
	_create_player()
	if use_velvet_strip:
		VELVET_STRIP_BUILDER.build(self)
	else:
		_build_level_blockout()
	_run_map_alignment_audit()
	if not use_velvet_strip:
		_create_shadow_zones()
	_spawn_level_characters()
	_create_extraction_zone()
	_create_hud()
	PAUSE_MENU_CONTROLLER.create_pause_menu(self)
	_apply_phase_visibility()
	_refresh_objective()
	_show_message("Velvet Strip stealth run. Work the contacts. Complete the night extraction.")

func _configure_window_for_native_screen():
	# Native fullscreen launch, no pixelation from low-res viewport scaling.
	var window = get_viewport().get_window()
	var screen = DisplayServer.window_get_current_screen()
	var screen_pos = DisplayServer.screen_get_position(screen)
	var native_size = DisplayServer.screen_get_size(screen)
	window.content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
	window.content_scale_size = native_size
	window.content_scale_factor = 1.0
	window.size = native_size
	window.position = screen_pos
	window.mode = Window.MODE_FULLSCREEN
	if ui_root != null and is_instance_valid(ui_root):
		_layout_hud()

func _configure_window_for_safe_windowed():
	# Keep startup in a stable windowed mode to avoid monitor mode switches.
	var window = get_viewport().get_window()
	var screen = DisplayServer.window_get_current_screen()
	var screen_pos = DisplayServer.screen_get_position(screen)
	var native_size = DisplayServer.screen_get_size(screen)
	var target = SAFE_WINDOWED_SIZE
	target.x = min(target.x, max(native_size.x - 120, 960))
	target.y = min(target.y, max(native_size.y - 120, 540))
	window.content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
	window.content_scale_size = target
	window.content_scale_factor = 1.0
	window.size = target
	window.position = screen_pos + (native_size - target) / 2
	if ui_root != null and is_instance_valid(ui_root):
		_layout_hud()

func _reapply_native_display_size_after_boot():
	# Some launch paths can apply window/viewport settings after _ready().
	# Re-apply on the next frame so render resolution matches display size.
	await get_tree().process_frame
	_configure_window_for_native_screen()

func _stabilize_window_mode():
	# Exclusive fullscreen can trigger monitor mode/brightness handshakes on
	# some systems. Normalize to non-exclusive fullscreen at runtime.
	var window = get_viewport().get_window()
	if window.mode == Window.MODE_EXCLUSIVE_FULLSCREEN:
		window.mode = Window.MODE_FULLSCREEN

func _process(delta):
	# Messages are timed so short mission feedback fades automatically.
	if message_timer > 0.0:
		message_timer -= delta
		if message_timer <= 0.0:
			message_text = ""
	_poll_audio_output_device(delta)
	_update_prompt()
	_update_hud()

func _poll_audio_output_device(delta):
	audio_device_recheck_timer -= delta
	if audio_device_recheck_timer > 0.0:
		return
	audio_device_recheck_timer = 1.5
	_recover_audio_output_device()

func _recover_audio_output_device(force_log := false):
	var devices = AudioServer.get_output_device_list()
	if devices.is_empty():
		if not audio_device_warning_shown:
			push_warning("No audio output device is available. Reconnect/select an output device to restore game audio.")
			audio_device_warning_shown = true
		return

	var current = AudioServer.get_output_device()
	if devices.has(current):
		audio_device_warning_shown = false
		return

	var fallback = ""
	for device in devices:
		var label = str(device).to_lower()
		if label == "default" or label.contains("default"):
			fallback = str(device)
			break
	if fallback == "":
		fallback = str(devices[0])

	AudioServer.set_output_device(fallback)
	audio_device_warning_shown = false
	if force_log:
		print("Audio output device recovered: %s" % fallback)

func _unhandled_input(event):
	# Global level controls live here instead of in the player script because
	# they affect mission state, scene reload, and window mode.
	if event.is_action_pressed("pause"):
		PAUSE_MENU_CONTROLLER.toggle_pause(self)
		get_tree().root.set_input_as_handled()
		return
	elif event.is_action_pressed("interact"):
		_handle_interaction()
	elif event.is_action_pressed("phase_switch"):
		if phase == "day":
			if phase_transition_in_progress:
				return
			if _all_contacts_met():
				phase_transition_in_progress = true
				await _begin_night()
				phase_transition_in_progress = false
			else:
				_show_message("You are still expected in public. Talk to all three daytime contacts first.")
	elif event.is_action_pressed("restart_level") and (mission_failed or level_complete):
		get_tree().reload_current_scene()
	elif event.is_action_pressed("toggle_fullscreen"):
		if event is InputEventKey and event.echo:
			return
		var window = get_viewport().get_window()
		if window.mode == Window.MODE_EXCLUSIVE_FULLSCREEN or window.mode == Window.MODE_FULLSCREEN:
			window.mode = Window.MODE_WINDOWED
			_configure_window_for_safe_windowed()
		else:
			_configure_window_for_native_screen()
			window.mode = Window.MODE_FULLSCREEN

func _create_environment_and_lights():
	# Start from a clean day profile. Mission controller swaps to a night profile
	# later, which avoids startup pulses and over-tinted daytime visuals.
	var env = Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color("8ba9c8")
	env.tonemap_mode = Environment.TONE_MAPPER_ACES
	env.tonemap_exposure = 1.02
	env.glow_enabled = false
	env.glow_intensity = 0.78
	env.glow_bloom = 0.2
	env.glow_hdr_threshold = 1.0
	env.glow_hdr_scale = 0.7
	var renderer := str(ProjectSettings.get_setting("rendering/renderer/rendering_method", "forward_plus"))
	forward_plus_renderer = renderer == "forward_plus"
	env.ssr_enabled = false
	if forward_plus_renderer:
		env.ssr_max_steps = 64
		env.ssr_fade_in = 0.2
		env.ssr_fade_out = 0.4
	env.fog_enabled = false
	env.fog_density = 0.018
	env.fog_aerial_perspective = 0.42
	env.fog_light_color = Color("ffcc99")
	env.volumetric_fog_enabled = false
	if forward_plus_renderer:
		env.volumetric_fog_density = 0.12
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("c7d7ea")
	env.ambient_light_energy = 0.66
	environment = WorldEnvironment.new()
	environment.environment = env
	add_child(environment)

	# Night moon (primary, low-angle cool wash)
	moon_light = DirectionalLight3D.new()
	moon_light.name = "MoonLight"
	moon_light.rotation_degrees = Vector3(-48.0, 120.0, 0.0)
	moon_light.light_energy = 0.32
	moon_light.set_meta("base_energy", moon_light.light_energy)
	moon_light.light_color = Color("5a7fff")
	moon_light.shadow_enabled = true
	moon_light.shadow_blur = 1.5
	moon_light.shadow_bias = 0.08
	moon_light.shadow_normal_bias = 1.1
	moon_light.visible = false
	moon_light.light_energy = 0.0
	add_child(moon_light)

	# Day sun (enabled at startup)
	day_sun = DirectionalLight3D.new()
	day_sun.name = "DaySun"
	day_sun.rotation_degrees = Vector3(-55.0, -45.0, 0.0)
	day_sun.light_energy = 1.8
	day_sun.set_meta("base_energy", day_sun.light_energy)
	day_sun.light_color = Color("ffddaa")
	day_sun.shadow_enabled = true
	day_sun.shadow_blur = 0.9
	day_sun.shadow_bias = 0.08
	day_sun.shadow_normal_bias = 1.2
	day_sun.visible = true
	add_child(day_sun)

	# Base street lamps (retained + enhanced)
	var street_lamp_zs = [-24.0, -12.0, 0.0, 12.0, 24.0]
	for i in range(street_lamp_zs.size()):
		var z_pos = street_lamp_zs[i]
		_create_point_light("WestStreetLampLight%d" % i, Vector3(-13.02, 3.98, z_pos), Color("98bcff"), 10.2, 1.2)
		_create_point_light("EastStreetLampLight%d" % i, Vector3(13.02, 3.98, z_pos), Color("98bcff"), 10.2, 1.2)

	for i in range(BUILDING_ENTRY_ZS.size()):
		var z_pos = BUILDING_ENTRY_ZS[i]
		_create_point_light("WestStorefrontWarm%d" % i, Vector3(-11.88, 2.44, z_pos), Color("ffd3a1"), 6.2, 0.85)
		_create_point_light("EastStorefrontWarm%d" % i, Vector3(11.88, 2.44, z_pos), Color("ffd3a1"), 6.2, 0.85)

	_create_point_light("AlleyCenterFill", Vector3(0.0, 4.4, 0.0), Color("9fb5d6"), 15.0, 0.55)
	_create_point_light("NorthGateFill", Vector3(0.0, 4.0, 24.0), Color("8fa9cd"), 11.0, 0.52)
	_create_point_light("SouthGateFill", Vector3(0.0, 4.0, -24.0), Color("8fa9cd"), 11.0, 0.52)

func _create_point_light(name: String, pos: Vector3, color: Color, rng: float, energy: float, with_shadow := false):
	# Point lights are stored so phase toggles can show/hide them in one pass.
	var light = OmniLight3D.new()
	light.name = name
	light.position = pos
	light.light_color = color
	light.omni_range = rng
	light.light_energy = energy
	light.shadow_enabled = with_shadow
	light.omni_attenuation = 0.9
	light.visible = false
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

func _add_detail_cylinder(parent, name, local_pos, radius, height, color, emissive := false, axis := "y"):
	var detail = MeshInstance3D.new()
	detail.name = name
	var cyl = CylinderMesh.new()
	cyl.top_radius = radius
	cyl.bottom_radius = radius
	cyl.height = max(height, 0.02)
	detail.mesh = cyl
	var mat = StandardMaterial3D.new()
	_configure_material(mat, name, color, emissive)
	detail.material_override = mat
	detail.position = local_pos
	match axis:
		"x":
			detail.rotation_degrees = Vector3(0.0, 0.0, 90.0)
		"z":
			detail.rotation_degrees = Vector3(90.0, 0.0, 0.0)
		_:
			detail.rotation_degrees = Vector3.ZERO
	if height <= 0.08:
		detail.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(detail)
	return detail

func _add_detail_sphere(parent, name, local_pos, radius, color, emissive := false):
	var detail = MeshInstance3D.new()
	detail.name = name
	var sphere = SphereMesh.new()
	sphere.radius = max(radius, 0.01)
	sphere.height = max(radius * 2.0, 0.02)
	detail.mesh = sphere
	var mat = StandardMaterial3D.new()
	_configure_material(mat, name, color, emissive)
	detail.material_override = mat
	detail.position = local_pos
	if radius <= 0.04:
		detail.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(detail)
	return detail

func _name_has_any(lower, tokens):
	for token in tokens:
		if lower.contains(token):
			return true
	return false

func _get_node_authored_size(node) -> Vector3:
	if node == null or not node.has_meta("authored_size"):
		return Vector3.ZERO
	var authored = node.get_meta("authored_size")
	if authored is Vector3:
		return authored
	return Vector3.ZERO

func _is_structural_geometry(name: String) -> bool:
	var lower = name.to_lower()
	if _name_has_any(lower, STRUCTURAL_GEOMETRY_TOKENS):
		return true
	return lower == "worldsupportfloor"

func _run_map_alignment_audit():
	if geometry_root == null or not is_instance_valid(geometry_root):
		return

	var floor_fix_count = _align_foundation_surfaces()
	var ground_fix_count = _snap_grounded_props_to_surface()
	var lift_fix_count = _lift_non_structural_geometry_above_floor()
	var light_fix_count = _align_map_lights()

	if floor_fix_count > 0 or ground_fix_count > 0 or lift_fix_count > 0 or light_fix_count > 0:
		print(
			"Map alignment audit adjusted floors=%d, grounded_props=%d, below_floor=%d, lights=%d" %
			[floor_fix_count, ground_fix_count, lift_fix_count, light_fix_count]
		)

func _align_foundation_surfaces() -> int:
	var target_tops = {
		"AlleyFloor": MAP_SURFACE_Y,
		"WestCurb": MAP_CURB_TOP_Y,
		"EastCurb": MAP_CURB_TOP_Y,
		"WestTransitionFloor": MAP_TRANSITION_TOP_Y,
		"EastTransitionFloor": MAP_TRANSITION_TOP_Y,
	}
	var adjustments = 0
	for node_name in target_tops.keys():
		var node = geometry_root.get_node_or_null(node_name)
		if node == null:
			continue
		var size = _get_node_authored_size(node)
		if size == Vector3.ZERO:
			continue
		var target_center_y = float(target_tops[node_name]) - size.y * 0.5
		if absf(node.position.y - target_center_y) > 0.001:
			node.position.y = target_center_y
			adjustments += 1
	return adjustments

func _should_snap_node_to_ground(node_name: String, size: Vector3, build_mode: String) -> bool:
	if size == Vector3.ZERO:
		return false
	if size.y > 2.4:
		return false
	if _is_structural_geometry(node_name):
		return false

	var lower = node_name.to_lower()
	if build_mode == "static_block":
		return _name_has_any(lower, GROUND_SNAPPED_PROP_TOKENS)
	if build_mode == "mesh_only":
		return lower.contains("draingrate") or lower.contains("drainframe")
	return false

func _snap_grounded_props_to_surface() -> int:
	var adjustments = 0
	for child in geometry_root.get_children():
		if not (child is Node3D):
			continue
		var node := child as Node3D
		var size = _get_node_authored_size(node)
		if size == Vector3.ZERO:
			continue
		var build_mode = ""
		if node.has_meta("build_mode"):
			build_mode = str(node.get_meta("build_mode"))
		if not _should_snap_node_to_ground(node.name, size, build_mode):
			continue

		var target_center_y = MAP_SURFACE_Y + size.y * 0.5
		if absf(node.position.y - target_center_y) > 0.001:
			node.position.y = target_center_y
			adjustments += 1
	return adjustments

func _lift_non_structural_geometry_above_floor() -> int:
	var adjustments = 0
	for child in geometry_root.get_children():
		if not (child is Node3D):
			continue
		var node := child as Node3D
		if _is_structural_geometry(node.name):
			continue
		if node.has_meta("build_mode") and str(node.get_meta("build_mode")) == "collision_only":
			continue

		var size = _get_node_authored_size(node)
		if size == Vector3.ZERO:
			continue
		var bottom_y = node.position.y - size.y * 0.5
		if bottom_y < MAP_MIN_VISIBLE_BOTTOM_Y:
			node.position.y += MAP_MIN_VISIBLE_BOTTOM_Y - bottom_y
			adjustments += 1
	return adjustments

func _align_map_lights() -> int:
	var adjustments = 0
	for light in point_lights:
		if light == null or not is_instance_valid(light):
			continue
		if light.name.begins_with("WestStreetLampLight"):
			if absf(light.position.x + 13.02) > 0.001:
				light.position.x = -13.02
				adjustments += 1
			var west_lamp_target_y = 3.98
			if absf(light.position.y - west_lamp_target_y) > 0.001:
				light.position.y = west_lamp_target_y
				adjustments += 1
		elif light.name.begins_with("EastStreetLampLight"):
			if absf(light.position.x - 13.02) > 0.001:
				light.position.x = 13.02
				adjustments += 1
			var east_lamp_target_y = 3.98
			if absf(light.position.y - east_lamp_target_y) > 0.001:
				light.position.y = east_lamp_target_y
				adjustments += 1
		elif light.name.begins_with("WestStorefrontWarm"):
			if absf(light.position.x + 11.88) > 0.001:
				light.position.x = -11.88
				adjustments += 1
			var west_store_target_y = 2.44
			if absf(light.position.y - west_store_target_y) > 0.001:
				light.position.y = west_store_target_y
				adjustments += 1
		elif light.name.begins_with("EastStorefrontWarm"):
			if absf(light.position.x - 11.88) > 0.001:
				light.position.x = 11.88
				adjustments += 1
			var east_store_target_y = 2.44
			if absf(light.position.y - east_store_target_y) > 0.001:
				light.position.y = east_store_target_y
				adjustments += 1

		if light is OmniLight3D:
			if light.omni_range < 4.0:
				light.omni_range = 4.0
				adjustments += 1
		elif light is SpotLight3D:
			if light.spot_range < 4.0:
				light.spot_range = 4.0
				adjustments += 1
		if light.light_energy < 0.2:
			light.light_energy = 0.2
			adjustments += 1
	return adjustments

func _should_auto_detail_block(name, size):
	# We only auto-detail medium/small props. Large structural pieces already
	# receive bespoke facade layering in `_build_level_blockout`.
	var lower = name.to_lower()
	if size.x > 6.0 or size.y > 6.0 or size.z > 6.0:
		return false
	# Only target props that are likely to read as "plain boxes" without help.
	return _name_has_any(lower, [
		"box",
		"crate",
		"trashbag",
		"van",
		"dumpster",
		"planter",
		"counter",
		"bar",
		"podium",
		"bench",
		"door",
	])

func _should_auto_detail_mesh(name, size, emissive):
	if emissive:
		return false
	if size.x > 6.5 or size.y > 6.5 or size.z > 6.5:
		return false

	var lower = name.to_lower()
	if lower.contains("glow"):
		return false
	if lower.contains("streetdoor") or lower.contains("streetentry"):
		return false
	if lower.contains("streetsignpanel") or lower.contains("streetsigncap") or lower.contains("streetaddressplaque") or lower.contains("streetdisplay") or lower.contains("streetsconce"):
		return false
	if lower.contains("windowtrimframe") or lower.contains("windowtrimsill") or lower.contains("windowawning"):
		return false

	if _name_has_any(lower, [
		"roof",
		"wall",
		"windowpanel",
		"weathering",
		"mullion",
		"coping",
		"band",
		"lintel",
		"hood",
		"cornice",
		"pilaster",
		"plinth",
		"socle",
		"grounddetail",
		"accentlight",
		"graffiti",
		"boarding",
		"fireescape",
		"chimney",
		"streak",
	]):
		return false

	return _name_has_any(lower, [
		"bench",
		"planter",
		"door",
		"sign",
		"lamp",
		"crate",
		"box",
		"dumpster",
		"van",
		"counter",
		"bar",
		"podium",
	])

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
		var y_offset = -size.y * 0.5 + wheel_radius + 0.02
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
		var caster_y = -size.y * 0.5 + caster_radius + 0.015
		_add_detail_wheel(body, "%sCasterFL" % name, Vector3(-caster_x, caster_y, -caster_z), caster_radius, caster_width)
		_add_detail_wheel(body, "%sCasterFR" % name, Vector3(caster_x, caster_y, -caster_z), caster_radius, caster_width)
		_add_detail_wheel(body, "%sCasterRL" % name, Vector3(-caster_x, caster_y, caster_z), caster_radius, caster_width)
		_add_detail_wheel(body, "%sCasterRR" % name, Vector3(caster_x, caster_y, caster_z), caster_radius, caster_width)

	if lower.contains("bench"):
		var leg_color = _mix_colors(color, Color("262626"), 0.4)
		var leg_w = clampf(size.x * 0.08, 0.1, 0.2)
		var leg_d = clampf(size.z * 0.22, 0.1, 0.24)
		var leg_h = clampf(size.y * 0.64, 0.24, size.y * 0.92)
		var leg_y = -size.y * 0.5 + leg_h * 0.5
		var leg_x = size.x * 0.4
		var leg_z = size.z * 0.34
		_add_detail_box(body, "%sLegFL" % name, Vector3(-leg_x, leg_y, -leg_z), Vector3(leg_w, leg_h, leg_d), leg_color)
		_add_detail_box(body, "%sLegFR" % name, Vector3(leg_x, leg_y, -leg_z), Vector3(leg_w, leg_h, leg_d), leg_color)
		_add_detail_box(body, "%sLegRL" % name, Vector3(-leg_x, leg_y, leg_z), Vector3(leg_w, leg_h, leg_d), leg_color)
		_add_detail_box(body, "%sLegRR" % name, Vector3(leg_x, leg_y, leg_z), Vector3(leg_w, leg_h, leg_d), leg_color)
		_add_detail_box(
			body,
			"%sApron" % name,
			Vector3(0.0, size.y * 0.18, 0.0),
			Vector3(size.x * 0.92, max(0.05, size.y * 0.12), size.z * 0.92),
			_mix_colors(color, Color("1f1f1f"), 0.18)
		)

	if lower.contains("door"):
		var trim_color = _mix_colors(color, Color("b8c0c8"), 0.3)
		_add_detail_box(
			body,
			"%sFrameTop" % name,
			Vector3(0.0, size.y * 0.54, 0.0),
			Vector3(size.x * 1.08, max(0.04, size.y * 0.07), size.z * 1.05),
			trim_color
		)
		_add_detail_box(
			body,
			"%sKickPlate" % name,
			Vector3(0.0, -size.y * 0.28, size.z * 0.54),
			Vector3(size.x * 0.62, max(0.08, size.y * 0.16), max(0.03, size.z * 0.18)),
			_mix_colors(color, Color("9aa6b2"), 0.42)
		)
		_add_detail_sphere(
			body,
			"%sKnob" % name,
			Vector3(-size.x * 0.33, 0.02, size.z * 0.62),
			clampf(min(size.x, min(size.y, size.z)) * 0.14, 0.03, 0.06),
			Color("a8b2bf")
		)

	if lower.contains("planter"):
		var corner_color = _mix_colors(color, Color("d2c5b5"), 0.24)
		var corner_w = clampf(size.x * 0.08, 0.06, 0.14)
		var corner_d = clampf(size.z * 0.08, 0.06, 0.14)
		var corner_h = clampf(size.y * 0.9, 0.3, size.y * 1.04)
		var corner_y = -size.y * 0.05
		var cx = size.x * 0.45
		var cz = size.z * 0.45
		_add_detail_box(body, "%sCornerFL" % name, Vector3(-cx, corner_y, -cz), Vector3(corner_w, corner_h, corner_d), corner_color)
		_add_detail_box(body, "%sCornerFR" % name, Vector3(cx, corner_y, -cz), Vector3(corner_w, corner_h, corner_d), corner_color)
		_add_detail_box(body, "%sCornerRL" % name, Vector3(-cx, corner_y, cz), Vector3(corner_w, corner_h, corner_d), corner_color)
		_add_detail_box(body, "%sCornerRR" % name, Vector3(cx, corner_y, cz), Vector3(corner_w, corner_h, corner_d), corner_color)

	if lower.contains("counter") or lower.contains("bar") or lower.contains("podium"):
		_add_detail_box(
			body,
			"%sToeKick" % name,
			Vector3(0.0, -size.y * 0.42, size.z * 0.48),
			Vector3(size.x * 0.92, max(0.06, size.y * 0.14), max(0.04, size.z * 0.1)),
			_mix_colors(color, Color("2b2f35"), 0.32)
		)
		_add_detail_box(
			body,
			"%sEdgeTrim" % name,
			Vector3(0.0, size.y * 0.44, 0.0),
			Vector3(size.x * 1.01, max(0.03, size.y * 0.06), size.z * 1.01),
			_mix_colors(color, Color("d4c8b8"), 0.26)
		)

func _decorate_mesh_only_geometry(node, name, size, color, emissive):
	if not _should_auto_detail_mesh(name, size, emissive):
		return

	var lower = name.to_lower()

	if lower.contains("benchseat"):
		var plank_color = _mix_colors(color, Color("3d271c"), 0.32)
		for i in range(3):
			var z_pos = -size.z * 0.32 + size.z * 0.32 * float(i)
			_add_detail_box(
				node,
				"%sPlank%d" % [name, i],
				Vector3(0.0, size.y * 0.3, z_pos),
				Vector3(size.x * 0.96, max(0.015, size.y * 0.45), max(0.08, size.z * 0.22)),
				plank_color
			)

	if lower.contains("benchback"):
		for i in range(4):
			var y_pos = -size.y * 0.35 + size.y * 0.23 * float(i)
			_add_detail_box(
				node,
				"%sSlat%d" % [name, i],
				Vector3(0.0, y_pos, 0.0),
				Vector3(size.x * 0.97, max(0.03, size.y * 0.07), max(0.05, size.z * 1.04)),
				_mix_colors(color, Color("3c251a"), 0.28)
			)

	if lower.contains("benchsupport"):
		var bolt_color = Color("aab4bf")
		_add_detail_sphere(node, "%sBoltTop" % name, Vector3(0.0, size.y * 0.36, size.z * 0.54), 0.03, bolt_color)
		_add_detail_sphere(node, "%sBoltBottom" % name, Vector3(0.0, -size.y * 0.3, size.z * 0.54), 0.028, bolt_color)

	if lower.contains("plantersoil"):
		var stem_color = _mix_colors(color, Color("2f6a3d"), 0.5)
		var leaf_color = _mix_colors(color, Color("62b46e"), 0.62)
		var stem_h = clampf(size.y * 2.8, 0.3, 0.85)
		for i in range(3):
			var x_pos = -size.x * 0.25 + size.x * 0.25 * float(i)
			var z_pos = -size.z * 0.16 if i % 2 == 0 else size.z * 0.16
			_add_detail_cylinder(
				node,
				"%sStem%d" % [name, i],
				Vector3(x_pos, stem_h * 0.5, z_pos),
				0.03,
				stem_h,
				stem_color
			)
			_add_detail_sphere(node, "%sLeaf%d" % [name, i], Vector3(x_pos, stem_h, z_pos), 0.12, leaf_color)

	if lower.contains("doorpanel") and not lower.contains("frame"):
		_add_detail_box(
			node,
			"%sInset" % name,
			Vector3(0.0, 0.0, size.z * 0.54),
			Vector3(size.x * 0.8, size.y * 0.82, max(0.02, size.z * 0.16)),
			_mix_colors(color, Color("181a1c"), 0.35)
		)
		_add_detail_box(
			node,
			"%sKickPlate" % name,
			Vector3(0.0, -size.y * 0.36, size.z * 0.56),
			Vector3(size.x * 0.72, max(0.06, size.y * 0.12), max(0.02, size.z * 0.2)),
			Color("9ea9b5")
		)

	if lower.contains("doorframe"):
		_add_detail_box(
			node,
			"%sTrimL" % name,
			Vector3(-size.x * 0.46, 0.0, 0.0),
			Vector3(max(0.02, size.x * 0.08), size.y * 0.98, size.z * 1.02),
			_mix_colors(color, Color("d8cfbf"), 0.32)
		)
		_add_detail_box(
			node,
			"%sTrimR" % name,
			Vector3(size.x * 0.46, 0.0, 0.0),
			Vector3(max(0.02, size.x * 0.08), size.y * 0.98, size.z * 1.02),
			_mix_colors(color, Color("d8cfbf"), 0.32)
		)

	if lower.contains("doorhandle"):
		_add_detail_box(
			node,
			"%sBackplate" % name,
			Vector3(0.0, 0.0, size.z * 0.44),
			Vector3(max(0.03, size.x * 0.82), max(0.05, size.y * 1.1), max(0.02, size.z * 0.25)),
			Color("7f8892")
		)
		_add_detail_sphere(node, "%sKnob" % name, Vector3(0.0, 0.0, size.z * 0.62), 0.025, Color("c9d2dc"))

	if lower.contains("sign") and not lower.contains("mount"):
		var frame_color = _mix_colors(color, Color("2a2e33"), 0.34)
		_add_detail_box(
			node,
			"%sTopFrame" % name,
			Vector3(0.0, size.y * 0.43, 0.0),
			Vector3(size.x * 1.05, max(0.02, size.y * 0.18), size.z * 1.05),
			frame_color
		)
		_add_detail_box(
			node,
			"%sBottomFrame" % name,
			Vector3(0.0, -size.y * 0.43, 0.0),
			Vector3(size.x * 1.05, max(0.02, size.y * 0.18), size.z * 1.05),
			frame_color
		)
		for i in range(4):
			var x_pos = -size.x * 0.4 if i < 2 else size.x * 0.4
			var y_pos = -size.y * 0.32 if i % 2 == 0 else size.y * 0.32
			_add_detail_sphere(node, "%sBolt%d" % [name, i], Vector3(x_pos, y_pos, size.z * 0.56), 0.02, Color("a7b1bc"))

	if lower.contains("signmount"):
		_add_detail_box(
			node,
			"%sAnchorPlate" % name,
			Vector3(0.0, 0.0, size.z * 0.45),
			Vector3(max(0.05, size.x * 1.22), max(0.18, size.y * 0.28), max(0.04, size.z * 0.38)),
			_mix_colors(color, Color("1f252c"), 0.28)
		)

	if lower.contains("lamphead"):
		_add_detail_sphere(
			node,
			"%sBulb" % name,
			Vector3(0.0, -size.y * 0.18, 0.0),
			clampf(min(size.x, min(size.y, size.z)) * 0.42, 0.07, 0.16),
			Color("ffd89f"),
			true
		)
		_add_detail_box(
			node,
			"%sShadeLip" % name,
			Vector3(0.0, -size.y * 0.35, 0.0),
			Vector3(size.x * 1.05, max(0.02, size.y * 0.12), size.z * 1.05),
			_mix_colors(color, Color("0f1216"), 0.35)
		)

	if lower.contains("lamp") and not lower.contains("head"):
		_add_detail_box(
			node,
			"%sBaseCollar" % name,
			Vector3(0.0, -size.y * 0.42, 0.0),
			Vector3(size.x * 1.35, max(0.04, size.y * 0.12), size.z * 1.35),
			_mix_colors(color, Color("1f252d"), 0.25)
		)
		_add_detail_cylinder(
			node,
			"%sTopJoint" % name,
			Vector3(0.0, size.y * 0.47, 0.0),
			clampf(min(size.x, size.z) * 0.28, 0.03, 0.06),
			max(0.04, size.y * 0.1),
			_mix_colors(color, Color("b6bec9"), 0.24)
		)

	if lower.contains("crate") or lower.contains("box"):
		var bracket_color = _mix_colors(color, Color("2f343b"), 0.34)
		var bracket_w = clampf(size.x * 0.08, 0.04, 0.08)
		var bracket_h = clampf(size.y * 0.14, 0.04, 0.12)
		var bracket_d = clampf(size.z * 0.08, 0.04, 0.08)
		for x_sign in [-1.0, 1.0]:
			for z_sign in [-1.0, 1.0]:
				_add_detail_box(
					node,
					"%sCorner%d%d" % [name, int(x_sign), int(z_sign)],
					Vector3(size.x * 0.44 * x_sign, size.y * 0.38, size.z * 0.44 * z_sign),
					Vector3(bracket_w, bracket_h, bracket_d),
					bracket_color
				)

	if lower.contains("boxstring"):
		_add_detail_sphere(node, "%sKnot" % name, Vector3(0.0, size.y * 0.12, size.z * 0.56), 0.03, Color("b89f82"))

	if lower.contains("dumpsterlid"):
		var hinge_color = _mix_colors(color, Color("b6c1cc"), 0.22)
		_add_detail_cylinder(
			node,
			"%sHingeL" % name,
			Vector3(-size.x * 0.3, 0.0, -size.z * 0.46),
			0.035,
			max(0.08, size.y * 0.5),
			hinge_color,
			false,
			"x"
		)
		_add_detail_cylinder(
			node,
			"%sHingeR" % name,
			Vector3(size.x * 0.3, 0.0, -size.z * 0.46),
			0.035,
			max(0.08, size.y * 0.5),
			hinge_color,
			false,
			"x"
		)

	if lower.contains("vanwindow"):
		_add_detail_box(
			node,
			"%sFrame" % name,
			Vector3(0.0, 0.0, 0.0),
			Vector3(size.x * 1.08, size.y * 1.08, max(0.02, size.z * 0.14)),
			Color("1f242c")
		)

	if lower.contains("vanbumper"):
		_add_detail_box(
			node,
			"%sReflectorL" % name,
			Vector3(-size.x * 0.34, 0.0, size.z * 0.57),
			Vector3(size.x * 0.16, max(0.03, size.y * 0.45), max(0.02, size.z * 0.22)),
			Color("e36a5b")
		)
		_add_detail_box(
			node,
			"%sReflectorR" % name,
			Vector3(size.x * 0.34, 0.0, size.z * 0.57),
			Vector3(size.x * 0.16, max(0.03, size.y * 0.45), max(0.02, size.z * 0.22)),
			Color("e36a5b")
		)

	if lower.contains("countertop") or lower.contains("bartop") or lower.contains("podiumrim"):
		_add_detail_box(
			node,
			"%sEdgeBevel" % name,
			Vector3(0.0, -size.y * 0.34, 0.0),
			Vector3(size.x * 0.98, max(0.02, size.y * 0.22), size.z * 0.98),
			_mix_colors(color, Color("ded6c9"), 0.24)
		)

func _configure_material(material: StandardMaterial3D, name: String, color: Color, emissive := false):
	# Pass 1: Rewrite for Godot 4 StandardMaterial3D + PBR delegation (fixes SpatialMaterial warnings).
	# Prioritizes velvet_strip PBR for detailed map, falls back to legacy.
	if use_velvet_strip and pbr_materials:
		pbr_materials.get_material(name.to_lower()).copy_to(material)
		material.albedo_color = material.albedo_color.lerp(color, 0.7)
	else:
		material_library.configure_material(material, name, color, emissive)

func get_pbr_materials():
	return pbr_materials

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
	
	# Legacy broad window sheets disabled; per-bay facade windows now provide
	# glazing to avoid overlapping transparent layers.
	
	# Legacy wide lintel/hood/chimney set removed from the outer shell. These
	# pieces were authored before facade anchoring and could intersect modern
	# alley-facing geometry from some camera angles.
	
	# Legacy exterior-side details disabled; replaced by `_add_building_realism_pass`.
	
# EAST BUILDING - tighter x=17.5 (6 behind curb), height=18
	_add_block("EastWall", Vector3(17.5, 9.0, 0.0), Vector3(10.02, 18.0, 56.0), Color(0.3, 0.34, 0.38, 1.0), true)
	
	# East roof
	_add_mesh_only("EastRoof", Vector3(17.5, 18.6, 0.0), Vector3(10.2, 0.4, 56.3), palette["roof"])
	
	# East base plinth
	_add_mesh_only("EastBasePlinth", Vector3(17.5, 0.25, 0.0), Vector3(10.2, 0.8, 56.2), Color("464d58"))
	
	# East socle
	_add_mesh_only("EastSocle", Vector3(17.5, 0.9, 0.0), Vector3(10.1, 1.0, 56.1), Color("3a3f48"))
	
	# Legacy broad window sheets disabled; per-bay facade windows now provide
	# glazing to avoid overlapping transparent layers.
	
	# Legacy wide lintel/hood/chimney set removed from the outer shell. These
	# pieces were authored before facade anchoring and could intersect modern
	# alley-facing geometry from some camera angles.

# 3rd Building - Office Tower tightened x=24 h=20 (fits canyon)
	_add_block("OfficeTower", Vector3(24.0, 10.0, 0.0), Vector3(8.02, 20.0, 56.0), Color(0.28, 0.32, 0.36), true)
	_add_mesh_only("OfficeRoof", Vector3(24.0, 20.6, 0.0), Vector3(8.2, 0.4, 56.3), palette["roof"])
	# Legacy office blanket window sheet disabled to prevent glass overlap.
	_add_mesh_only("OfficeLedge1", Vector3(24.0, 4.8, 0.0), Vector3(8.2, 0.2, 56.3), Color("4a5560"))
	# Legacy AC + pipe pair removed here; rooftop/facade mechanicals from the
	# realism pass now handle this detail without misplacement.

	
	# East rooftop stacks are now generated by the realism pass with safe anchor
	# offsets that avoid clipping into facade trim.
	
	# Legacy exterior-side detail set disabled; replaced by `_add_building_realism_pass`.

# HARD BOUNDARIES - tightened
	_add_block("SouthBoundary", Vector3(0.0, 2.0, -28.5), Vector3(44.0, 4.0, 1.0), palette["dark"], true)
	_add_block("NorthBoundary", Vector3(0.0, 2.0, 28.5), Vector3(44.0, 4.0, 1.0), palette["dark"], true)
	_add_block("WestBoundary", Vector3(-29.5, 2.0, 0.0), Vector3(1.0, 20.0, 56.0), palette["dark"], true)
	_add_block("EastBoundary", Vector3(29.5, 2.0, 0.0), Vector3(1.0, 20.0, 56.0), palette["dark"], true)
	
# Guard rail colliders removed because wall blocks already provide collision.
# Keeping duplicate hidden rails caused invisible collision in front of facades.


	# Legacy weathering/exterior vestibule set disabled; these were positioned on
	# the outer wall shell and conflicted with the alley-facing architecture.

# ALLEY PROPS - tightened to new +/-10 alley (west -9.5 to -16 range)
	# West side props
	# Legacy outer-shell side door removed; aligned storefront entries are handled
	# in `_add_building_realism_pass`.
	
	# West bench
	_add_block("WestBench", Vector3(-9.5, 0.4, -15.0), Vector3(3.0, 0.8, 1.0), Color("6d6055"), true)
	_add_mesh_only("WestBenchBack", Vector3(-9.5, 1.15, -15.55 - 0.01), Vector3(3.2, 0.8, 0.15), Color("5a4845"))
	_add_mesh_only("WestBenchSeat", Vector3(-9.5, 0.45 + 0.01, -15.0), Vector3(3.1, 0.08, 1.08), Color("7d7066"))
	_add_mesh_only("WestBenchSupport_L", Vector3(-11.0, 0.25, -15.2 - 0.01), Vector3(0.15, 0.5, 0.3), Color("4a3f35"))
	_add_mesh_only("WestBenchSupport_R", Vector3(-8.0, 0.25, -15.2 - 0.01), Vector3(0.15, 0.5, 0.3), Color("4a3f35"))
	
	# West planter
	_add_block("WestPlanter", Vector3(-7.5, 0.7, -18.0), Vector3(1.5, 1.4, 1.5), palette["green"], true)
	_add_mesh_only("WestPlanterRim", Vector3(-7.5, 1.5 + 0.01, -18.0), Vector3(1.65, 0.15, 1.65), Color("6a6055"))
	_add_mesh_only("WestPlanterSoil", Vector3(-7.5, 1.35 + 0.01, -18.0), Vector3(1.4, 0.15, 1.4), Color("4a5533"))
	
	_add_block("WestCounter", Vector3(-8.5, 0.75, 0.0), Vector3(3.0, 1.5, 1.0), palette["metal"], true)
	_add_mesh_only("WestCounterTop", Vector3(-8.5, 1.4 + 0.01, 0.0), Vector3(3.15, 0.1, 1.1), Color("8a9a9f"))
	
# East side props - tightened to new +/-10 alley (east 7.5-16 range)
	# Legacy outer-shell side door removed; aligned storefront entries are handled
	# in `_add_building_realism_pass`.
	
	_add_block("EastBench", Vector3(8.5, 0.4, 15.0), Vector3(3.0, 0.8, 1.0), Color("6d6055"), true)
	_add_mesh_only("EastBenchBack", Vector3(8.5, 1.15, 15.55 + 0.01), Vector3(3.2, 0.8, 0.15), Color("5a4845"))
	_add_mesh_only("EastBenchSeat", Vector3(8.5, 0.45 + 0.01, 15.0), Vector3(3.1, 0.08, 1.08), Color("7d7066"))
	_add_mesh_only("EastBenchSupport_L", Vector3(7.0, 0.25, 15.2 + 0.01), Vector3(0.15, 0.5, 0.3), Color("4a3f35"))
	_add_mesh_only("EastBenchSupport_R", Vector3(10.0, 0.25, 15.2 + 0.01), Vector3(0.15, 0.5, 0.3), Color("4a3f35"))
	
	_add_block("EastPlanter", Vector3(7.5, 0.7, 18.0), Vector3(1.5, 1.4, 1.5), palette["green"], true)
	_add_mesh_only("EastPlanterRim", Vector3(7.5, 1.5 + 0.01, 18.0), Vector3(1.65, 0.15, 1.65), Color("6a6055"))
	_add_mesh_only("EastPlanterSoil", Vector3(7.5, 1.35 + 0.01, 18.0), Vector3(1.4, 0.15, 1.4), Color("4a5533"))
	
	_add_block("EastBar", Vector3(8.5, 0.75, 5.0), Vector3(3.5, 1.5, 1.0), palette["metal"], true)
	_add_mesh_only("EastBarTop", Vector3(8.5, 1.4 + 0.01, 5.0), Vector3(3.65, 0.1, 1.1), Color("8a9a9f"))
	
	# Center alley features - unchanged (fits tight layout)
	# Center podium - raised render priority, solid
	_add_block("CenterPodium", Vector3(-3.0, 0.6, 0.0), Vector3(2.0, 1.2, 2.0), palette["stone"], true)
	_add_mesh_only("CenterPodiumRim", Vector3(-3.0, 1.25 + 0.01, 0.0), Vector3(2.2, 0.12, 2.2), Color("c8bdb0"))
	_add_mesh_only("CenterPodiumGlow", Vector3(-3.0, 1.5 + 0.01, 0.0), Vector3(1.4, 0.4, 1.4), Color("68d4ff"), true)
	

	
	# Enhanced van with windows and details
	_add_block("Van", Vector3(0.0, 0.85, 18.0), Vector3(5.0, 1.7, 2.5), Color("2a2a36"), true)
	_add_mesh_only("VanWindow_L", Vector3(-1.2, 1.3 + 0.01, 17.8 - 0.01), Vector3(1.0, 0.8, 0.15), Color(0.4, 0.6, 0.8, 0.4))
	_add_mesh_only("VanWindow_R", Vector3(1.2, 1.3 + 0.01, 17.8 - 0.01), Vector3(1.0, 0.8, 0.15), Color(0.4, 0.6, 0.8, 0.4))
	_add_mesh_only("VanDoor", Vector3(-1.8, 0.9, 18.3 + 0.01), Vector3(0.5, 1.2, 0.1), Color("3a3a40"))
	_add_mesh_only("VanDoorHandle", Vector3(-1.85, 1.1, 18.35 + 0.01), Vector3(0.08, 0.12, 0.08), Color("8a8179"))
	_add_mesh_only("VanRoof", Vector3(0.0, 1.6 + 0.01, 18.0), Vector3(5.2, 0.15, 2.7), Color("1a1a20"))
	_add_mesh_only("VanBumper", Vector3(0.0, 0.3, 19.35 + 0.01), Vector3(5.2, 0.2, 0.15), Color("1a1a1a"))
	
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
	
	# Additional exterior clutter on the outer shell was removed to prevent
	# floating/overlapping silhouettes when the camera catches side angles.
	
	# Central alley clutter
	_add_block("TrashBag1", Vector3(-5.0, 0.25, 2.0), Vector3(0.6, 0.5, 0.6), Color("3a3a3a"), true)
	_add_block("TrashBag2", Vector3(-4.2, 0.26, 4.0), Vector3(0.7, 0.52, 0.7), Color("2a2a2a"), true)
	_add_block("Pipe", Vector3(3.0, 2.5, -3.0), Vector3(0.15, 2.0, 0.15), Color("5a6a7a"), true)
	_add_block("Pipe2", Vector3(3.6, 2.2, 5.0), Vector3(0.12, 1.8, 0.12), Color("4a5a6a"), true)
	
	# Legacy facade storytelling on the far exterior shell removed. New wall art
	# and storefront detail now spawn from aligned facade anchors.
	
	# Legacy outer-shell roof/mullion/accent set disabled. Replaced by the
	# aligned facade and rooftop detail system below.

	# High-detail passes that push facades and street edges beyond blockout.
	_add_building_realism_pass(palette)
	_add_street_realism_pass(palette)
	
# Day contact position markers - tightened
	_add_marker_column(Vector3(-9.5, 0.0, -15.0), Color("7ddcff"))  # West bench
	_add_marker_column(Vector3(-2.5, 0.0, 0.0), Color("7ddcff"))     # Center podium
	_add_marker_column(Vector3(7.0, 0.0, 8.0), Color("7ddcff"))     # East bar

func _add_building_realism_pass(palette):
	# Building detail generation is split into dedicated layers so placement is
	# easier to reason about and easier to tune without reintroducing overlap.
	var side_configs = [_make_building_side_config(-1), _make_building_side_config(1)]
	for cfg in side_configs:
		_add_building_window_modules(cfg)
		_add_building_course_and_pilaster_modules(cfg)
		_add_building_storefront_modules(cfg, palette)
		_add_building_fire_escape_modules(cfg, palette)
		_add_building_roof_modules(cfg)
		_add_building_utility_pipe_modules(cfg)
	_add_cross_alley_service_cables()

func _make_building_side_config(side):
	var side_tag = "West" if side < 0 else "East"
	var alley_dir = 1.0 if side < 0 else -1.0
	var wall_face_x = -12.49 if side < 0 else 12.49
	return {
		"side_tag": side_tag,
		"alley_dir": alley_dir,
		"wall_face_x": wall_face_x,
		"deck_x": -11.3 if side < 0 else 11.3,
		"roof_x": -18.9 if side < 0 else 18.9,
	}

func _add_building_window_modules(cfg):
	var side_tag = cfg["side_tag"]
	var alley_dir = cfg["alley_dir"]
	var wall_face_x = cfg["wall_face_x"]
	var frame_x = wall_face_x + alley_dir * 0.08
	var glass_x = wall_face_x + alley_dir * 0.145 # Offset glass slightly to avoid z-fighting
	var trim_x = wall_face_x + alley_dir * 0.18
	var entry_window_clearance = 2.8

	for row_idx in range(BUILDING_FLOORS.size()):
		var y_pos = BUILDING_FLOORS[row_idx]
		for bay_idx in range(BUILDING_WINDOW_BAYS.size()):
			var z_pos = BUILDING_WINDOW_BAYS[bay_idx]
			var skip_window = false
			if row_idx == 0:
				for entry_z in BUILDING_ENTRY_ZS:
					if absf(z_pos - entry_z) < entry_window_clearance:
						skip_window = true
						break
			if skip_window:
				continue

			_add_mesh_only(
				"%sWindowTrimFrameR%dB%d" % [side_tag, row_idx, bay_idx],
				Vector3(frame_x, y_pos, z_pos),
				Vector3(0.1, 2.12, 2.85),
				Color("8f857b")
			)
			_add_mesh_only(
				"%sWindowGlassPaneR%dB%d" % [side_tag, row_idx, bay_idx],
				Vector3(glass_x, y_pos, z_pos),
				Vector3(0.06, 1.62, 2.2),
				Color(0.65, 0.79, 0.91, 0.24)
			)
			_add_mesh_only(
				"%sWindowMullionR%dB%d" % [side_tag, row_idx, bay_idx],
				Vector3(trim_x + alley_dir * 0.005, y_pos, z_pos),
				Vector3(0.06, 1.72, 0.12),
				Color("50606e")
			)
			_add_mesh_only(
				"%sWindowLintelR%dB%d" % [side_tag, row_idx, bay_idx],
				Vector3(frame_x + alley_dir * 0.005, y_pos + 1.1, z_pos),
				Vector3(0.09, 0.12, 3.0),
				Color("c8bdb0")
			)
			_add_mesh_only(
				"%sWindowTrimSillR%dB%d" % [side_tag, row_idx, bay_idx],
				Vector3(frame_x + alley_dir * 0.005, y_pos - 1.1, z_pos),
				Vector3(0.1, 0.1, 2.7),
				Color("a69887")
			)
			if row_idx <= 1 and bay_idx % 2 == 0:
				_add_mesh_only(
					"%sWindowAwningR%dB%d" % [side_tag, row_idx, bay_idx],
					Vector3(frame_x + alley_dir * 0.265, y_pos + 1.34, z_pos),
					Vector3(0.48, 0.12, 2.45),
					Color("6f6257")
				)
			if row_idx >= 2 and bay_idx % 2 == 1:
				_add_mesh_only(
					"%sWindowCrossbarR%dB%d" % [side_tag, row_idx, bay_idx],
					Vector3(trim_x + alley_dir * 0.015, y_pos, z_pos),
					Vector3(0.05, 0.06, 2.05),
					Color("627280")
				)

func _add_building_course_and_pilaster_modules(cfg):
	var side_tag = cfg["side_tag"]
	var alley_dir = cfg["alley_dir"]
	var wall_face_x = cfg["wall_face_x"]
	var course_x = wall_face_x + alley_dir * 0.045 # Offset course band
	var pilaster_x = wall_face_x + alley_dir * 0.065 # Offset pilaster
	var facade_course_heights = [1.15, 4.05, 7.05, 10.05, 13.05, 16.05]
	var pilaster_zs = [-26.0, -16.5, -5.5, 5.5, 16.5, 26.0]

	_add_mesh_only(
		"%sFacadeServiceBelt" % side_tag,
		Vector3(course_x, 0.58, 0.0),
		Vector3(0.07, 0.14, 54.6),
		Color("4f4841")
	)

	for i in range(facade_course_heights.size()):
		var y_pos = facade_course_heights[i]
		_add_mesh_only(
			"%sFacadeCourseBand%d" % [side_tag, i],
			Vector3(course_x, y_pos, 0.0),
			Vector3(0.08, 0.1, 55.0),
			Color("7a7268")
		)

	_add_mesh_only(
		"%sFacadeCorniceBand" % side_tag,
		Vector3(course_x, 17.92, 0.0),
		Vector3(0.1, 0.22, 55.3),
		Color("a79a8a")
	)

	for i in range(pilaster_zs.size()):
		var z_pos = pilaster_zs[i]
		_add_mesh_only(
			"%sFacadePilaster%d" % [side_tag, i],
			Vector3(pilaster_x, 9.2, z_pos),
			Vector3(0.1, 16.2, 0.28),
			Color("6d655b")
		)
		_add_mesh_only(
			"%sFacadePilasterBase%d" % [side_tag, i],
			Vector3(pilaster_x, 0.92, z_pos),
			Vector3(0.14, 0.16, 0.38),
			Color("564f47")
		)
		_add_mesh_only(
			"%sFacadePilasterCap%d" % [side_tag, i],
			Vector3(pilaster_x, 17.45, z_pos),
			Vector3(0.14, 0.12, 0.38),
			Color("8e8172")
		)

func _add_building_storefront_modules(cfg, palette):
	var side_tag = cfg["side_tag"]
	var alley_dir = cfg["alley_dir"]
	var wall_face_x = cfg["wall_face_x"]
	var frame_x = wall_face_x + alley_dir * 0.125 # Offset frame
	var panel_x = wall_face_x + alley_dir * 0.205 # Offset panel
	var reveal_x = wall_face_x - alley_dir * 0.055 # Offset reveal
	var step_x = wall_face_x + alley_dir * 0.885 # Offset step
	var sconce_x = frame_x + alley_dir * 0.505 # Offset sconce

	for i in range(BUILDING_ENTRY_ZS.size()):
		var z_pos = BUILDING_ENTRY_ZS[i]
		_add_mesh_only(
			"%sStreetDoorReveal%d" % [side_tag, i],
			Vector3(reveal_x, 1.45, z_pos),
			Vector3(0.06, 2.72, 2.18),
			Color("3b3f45")
		)
		_add_mesh_only(
			"%sStreetDoorFrame%d" % [side_tag, i],
			Vector3(frame_x, 1.55, z_pos),
			Vector3(0.12, 3.3, 2.4),
			palette["wall"]
		)
		_add_mesh_only(
			"%sStreetDoorPanelA%d" % [side_tag, i],
			Vector3(panel_x, 1.45, z_pos - 0.5),
			Vector3(0.06, 2.72, 0.72),
			Color("2f3136")
		)
		_add_mesh_only(
			"%sStreetDoorPanelB%d" % [side_tag, i],
			Vector3(panel_x, 1.45, z_pos + 0.5),
			Vector3(0.06, 2.72, 0.72),
			Color("2f3136")
		)
		_add_mesh_only(
			"%sStreetDoorHandleA%d" % [side_tag, i],
			Vector3(panel_x + alley_dir * 0.04, 1.05, z_pos - 0.5),
			Vector3(0.03, 0.14, 0.08),
			Color("9ea8b3")
		)
		_add_mesh_only(
			"%sStreetDoorHandleB%d" % [side_tag, i],
			Vector3(panel_x + alley_dir * 0.04, 1.05, z_pos + 0.5),
			Vector3(0.03, 0.14, 0.08),
			Color("9ea8b3")
		)
		_add_mesh_only(
			"%sStreetDoorWindowGlassPane%d" % [side_tag, i],
			Vector3(panel_x + alley_dir * 0.05, 2.6, z_pos),
			Vector3(0.05, 0.52, 1.9),
			Color(0.7, 0.84, 0.94, 0.22)
		)
		_add_mesh_only(
			"%sStreetDoorTransomWindowGlassPane%d" % [side_tag, i],
			Vector3(panel_x + alley_dir * 0.05, 2.95, z_pos),
			Vector3(0.05, 0.34, 2.02),
			Color(0.64, 0.77, 0.87, 0.2)
		)
		_add_mesh_only(
			"%sStreetDisplayFrameL%d" % [side_tag, i],
			Vector3(frame_x, 1.62, z_pos - 1.58),
			Vector3(0.08, 2.42, 0.62),
			Color("857a6e")
		)
		_add_mesh_only(
			"%sStreetDisplayFrameR%d" % [side_tag, i],
			Vector3(frame_x, 1.62, z_pos + 1.58),
			Vector3(0.08, 2.42, 0.62),
			Color("857a6e")
		)
		_add_mesh_only(
			"%sStreetDisplayWindowGlassPaneL%d" % [side_tag, i],
			Vector3(panel_x + alley_dir * 0.05, 1.62, z_pos - 1.58),
			Vector3(0.05, 1.92, 0.46),
			Color(0.66, 0.78, 0.88, 0.2)
		)
		_add_mesh_only(
			"%sStreetDisplayWindowGlassPaneR%d" % [side_tag, i],
			Vector3(panel_x + alley_dir * 0.05, 1.62, z_pos + 1.58),
			Vector3(0.05, 1.92, 0.46),
			Color(0.66, 0.78, 0.88, 0.2)
		)
		_add_mesh_only(
			"%sStreetEntryStep%d" % [side_tag, i],
			Vector3(step_x, 0.12, z_pos),
			Vector3(1.75, 0.24, 2.34),
			Color("4a525c")
		)
		_add_mesh_only(
			"%sStreetEntryAwning%d" % [side_tag, i],
			Vector3(frame_x + alley_dir * 0.78, 3.38, z_pos),
			Vector3(1.9, 0.22, 2.55),
			Color("85766a")
		)
		_add_mesh_only(
			"%sStreetSignPanel%d" % [side_tag, i],
			Vector3(frame_x + alley_dir * 0.84, 4.05, z_pos),
			Vector3(0.08, 0.46, 1.3),
			Color("8f6f4d")
		)
		_add_mesh_only(
			"%sStreetSignCap%d" % [side_tag, i],
			Vector3(frame_x + alley_dir * 0.9, 4.33, z_pos),
			Vector3(0.1, 0.08, 1.34),
			Color("6f5b48")
		)
		_add_mesh_only(
			"%sStreetAddressPlaque%d" % [side_tag, i],
			Vector3(frame_x + alley_dir * 0.72, 4.68, z_pos),
			Vector3(0.08, 0.26, 0.64),
			Color("726355")
		)

		var suffixes = ["L", "R"]
		var sconce_offsets = [-1.15, 1.15]
		for s_idx in range(suffixes.size()):
			var suffix = suffixes[s_idx]
			var sconce_z = z_pos + sconce_offsets[s_idx]
			_add_mesh_only(
				"%sStreetSconce%s%d" % [side_tag, suffix, i],
				Vector3(sconce_x, 2.55, sconce_z),
				Vector3(0.06, 0.22, 0.16),
				Color("4f5964")
			)
			_add_mesh_only(
				"%sStreetSconceGlow%s%d" % [side_tag, suffix, i],
				Vector3(sconce_x + alley_dir * 0.02, 2.42, sconce_z),
				Vector3(0.04, 0.08, 0.1),
				Color("ffd7a4"),
				true
			)

func _add_building_fire_escape_modules(cfg, palette):
	var side_tag = cfg["side_tag"]
	var alley_dir = cfg["alley_dir"]
	var deck_x = cfg["deck_x"]

	for level_idx in range(BUILDING_BALCONY_LEVELS.size()):
		var y_pos = BUILDING_BALCONY_LEVELS[level_idx]
		for bay_idx in range(BUILDING_BALCONY_BAYS.size()):
			var z_pos = BUILDING_BALCONY_BAYS[bay_idx]
			_add_mesh_only(
				"%sFireEscapeBalconyDeckL%dB%d" % [side_tag, level_idx, bay_idx],
				Vector3(deck_x, y_pos, z_pos),
				Vector3(1.55, 0.12, 2.7),
				palette["metal"]
			)
			_add_mesh_only(
				"%sFireEscapeBalconyRailOuterL%dB%d" % [side_tag, level_idx, bay_idx],
				Vector3(deck_x + alley_dir * 0.72, y_pos + 0.42, z_pos),
				Vector3(0.1, 0.84, 2.7),
				palette["metal"]
			)
			_add_mesh_only(
				"%sFireEscapeBalconyRailInnerL%dB%d" % [side_tag, level_idx, bay_idx],
				Vector3(deck_x - alley_dir * 0.72, y_pos + 0.42, z_pos),
				Vector3(0.1, 0.84, 2.7),
				palette["metal"]
			)
			_add_mesh_only(
				"%sFireEscapeBalconyRailEndAL%dB%d" % [side_tag, level_idx, bay_idx],
				Vector3(deck_x, y_pos + 0.42, z_pos - 1.3),
				Vector3(1.45, 0.84, 0.08),
				palette["metal"]
			)
			_add_mesh_only(
				"%sFireEscapeBalconyRailEndBL%dB%d" % [side_tag, level_idx, bay_idx],
				Vector3(deck_x, y_pos + 0.42, z_pos + 1.3),
				Vector3(1.45, 0.84, 0.08),
				palette["metal"]
			)
			if level_idx < BUILDING_BALCONY_LEVELS.size() - 1:
				_add_mesh_only(
					"%sFireEscapeLadderL%dB%d" % [side_tag, level_idx, bay_idx],
					Vector3(deck_x, y_pos - 1.02, z_pos + 1.34),
					Vector3(0.16, 1.92, 0.12),
					palette["metal"]
				)
			if level_idx == 0 and bay_idx == 1:
				_add_mesh_only(
					"%sFireEscapeDropLadderB%d" % [side_tag, bay_idx],
					Vector3(deck_x, y_pos - 2.2, z_pos - 1.18),
					Vector3(0.14, 4.2, 0.1),
					palette["metal"]
				)

func _add_building_roof_modules(cfg):
	var side_tag = cfg["side_tag"]
	var alley_dir = cfg["alley_dir"]
	var roof_x = cfg["roof_x"]

	for i in range(BUILDING_ROOF_ZS.size()):
		var z_pos = BUILDING_ROOF_ZS[i]
		_add_mesh_only(
			"%sRoofMechanicalPad%d" % [side_tag, i],
			Vector3(roof_x, 18.72, z_pos),
			Vector3(1.9, 0.08, 1.9),
			Color("3d434c")
		)
		_add_mesh_only(
			"%sRoofMechanicalUnit%d" % [side_tag, i],
			Vector3(roof_x, 18.95, z_pos),
			Vector3(1.7, 1.05, 1.7),
			Color("4f5864")
		)
		_add_mesh_only(
			"%sRoofMechanicalVent%d" % [side_tag, i],
			Vector3(roof_x + alley_dir * 0.24, 19.65, z_pos + 0.28),
			Vector3(0.36, 0.34, 0.36),
			Color("65707d")
		)
		_add_mesh_only(
			"%sRoofPipeStack%d" % [side_tag, i],
			Vector3(roof_x - alley_dir * 0.22, 20.08, z_pos - 0.26),
			Vector3(0.12, 0.95, 0.12),
			Color("4e5c6d")
		)

	_add_mesh_only(
		"%sRoofAccessRail" % side_tag,
		Vector3(roof_x - alley_dir * 0.95, 19.25, 0.0),
		Vector3(0.1, 0.95, 54.0),
		Color("556371")
	)

func _add_building_utility_pipe_modules(cfg):
	var side_tag = cfg["side_tag"]
	var alley_dir = cfg["alley_dir"]
	var wall_face_x = cfg["wall_face_x"]
	var pipe_x = wall_face_x + alley_dir * 0.44

	for i in range(BUILDING_PIPE_ZS.size()):
		var z_pos = BUILDING_PIPE_ZS[i]
		_add_mesh_only(
			"%sFacadePipeRun%d" % [side_tag, i],
			Vector3(pipe_x, 8.0, z_pos),
			Vector3(0.1, 16.0, 0.1),
			Color("5f6f80")
		)
		for band_y in [1.8, 4.2, 6.6, 9.0, 11.4, 13.8]:
			_add_mesh_only(
				"%sFacadePipeClamp%dY%d" % [side_tag, i, int(round(band_y * 10.0))],
				Vector3(pipe_x - alley_dir * 0.12, band_y, z_pos),
				Vector3(0.18, 0.06, 0.26),
				Color("3f4853")
			)
		_add_mesh_only(
			"%sFacadeUtilityBox%d" % [side_tag, i],
			Vector3(pipe_x - alley_dir * 0.14, 1.08, z_pos),
			Vector3(0.24, 0.38, 0.32),
			Color("495664")
		)
		_add_mesh_only(
			"%sFacadeUtilityBranch%d" % [side_tag, i],
			Vector3(pipe_x - alley_dir * 0.33, 1.3, z_pos),
			Vector3(0.4, 0.06, 0.08),
			Color("5f6f80")
		)
		_add_mesh_only(
			"%sFacadeUtilityFoot%d" % [side_tag, i],
			Vector3(pipe_x, 0.26, z_pos),
			Vector3(0.14, 0.22, 0.14),
			Color("3f4853")
		)

func _add_cross_alley_service_cables():
	for i in range(5):
		var y_pos = 8.8 + float(i) * 1.55
		var z_pos = -22.0 + float(i) * 11.0
		_add_mesh_only(
			"CrossAlleyPipeCable%d" % i,
			Vector3(0.0, y_pos, z_pos),
			Vector3(50.0, 0.04, 0.04),
			Color("2d333b")
		)
		_add_mesh_only(
			"CrossAlleyCableHangerWest%d" % i,
			Vector3(-12.6, y_pos - 0.45, z_pos),
			Vector3(0.08, 0.9, 0.08),
			Color("313942")
		)
		_add_mesh_only(
			"CrossAlleyCableHangerEast%d" % i,
			Vector3(12.6, y_pos - 0.45, z_pos),
			Vector3(0.08, 0.9, 0.08),
			Color("313942")
		)

func _add_street_realism_pass(palette):
	# Street-level density pass: more lamps, bollards, drains, and service props.
	var lamp_zs = [-24.0, -12.0, 0.0, 12.0, 24.0]
	for i in range(lamp_zs.size()):
		var z_pos = lamp_zs[i]
		for side in [-1, 1]:
			var side_tag = "West" if side < 0 else "East"
			var pole_x = -13.8 if side < 0 else 13.8
			var arm_dir = -side
			_add_mesh_only(
				"%sStreetLampPole%d" % [side_tag, i],
				Vector3(pole_x, 2.2, z_pos),
				Vector3(0.14, 4.4, 0.14),
				palette["metal"]
			)
			_add_mesh_only(
				"%sStreetLampArm%d" % [side_tag, i],
				Vector3(pole_x + arm_dir * 0.42, 4.2, z_pos),
				Vector3(0.86, 0.08, 0.08),
				palette["metal"]
			)
			_add_mesh_only(
				"%sStreetLampHead%d" % [side_tag, i],
				Vector3(pole_x + arm_dir * 0.78, 4.04, z_pos),
				Vector3(0.3, 0.2, 0.3),
				Color("3b4d5f")
			)
			_add_mesh_only(
				"%sStreetLampGlow%d" % [side_tag, i],
				Vector3(pole_x + arm_dir * 0.78, 3.92, z_pos),
				Vector3(0.18, 0.12, 0.18),
				Color("ffd79a"),
				true
			)

	for i in range(9):
		var z_pos = -24.0 + float(i) * 6.0
		_add_block("WestMetalBollard%d" % i, Vector3(-12.4, 0.38, z_pos), Vector3(0.18, 0.76, 0.18), Color("4b535f"), true)
		_add_block("EastMetalBollard%d" % i, Vector3(12.4, 0.38, z_pos), Vector3(0.18, 0.76, 0.18), Color("4b535f"), true)
		_add_mesh_only("WestMetalBollardCap%d" % i, Vector3(-12.4, 0.82, z_pos), Vector3(0.24, 0.08, 0.24), Color("737f8d"))
		_add_mesh_only("EastMetalBollardCap%d" % i, Vector3(12.4, 0.82, z_pos), Vector3(0.24, 0.08, 0.24), Color("737f8d"))

	for i in range(4):
		var z_pos = -18.0 + float(i) * 12.0
		_add_mesh_only("WestMetalDrainGrate%d" % i, Vector3(-10.6, 0.03, z_pos), Vector3(0.9, 0.03, 0.45), Color("5a6571"))
		_add_mesh_only("EastMetalDrainGrate%d" % i, Vector3(10.6, 0.03, z_pos), Vector3(0.9, 0.03, 0.45), Color("5a6571"))
		_add_mesh_only("WestMetalDrainFrame%d" % i, Vector3(-10.6, 0.04, z_pos), Vector3(1.02, 0.04, 0.58), Color("3f4853"))
		_add_mesh_only("EastMetalDrainFrame%d" % i, Vector3(10.6, 0.04, z_pos), Vector3(1.02, 0.04, 0.58), Color("3f4853"))

	_add_block("WestMetalHydrant", Vector3(-11.7, 0.5, -2.0), Vector3(0.34, 1.0, 0.34), Color("b94b3c"), true)
	_add_mesh_only("WestMetalHydrantTop", Vector3(-11.7, 1.05, -2.0), Vector3(0.42, 0.14, 0.42), Color("8f3d33"))
	_add_mesh_only("WestMetalHydrantValve", Vector3(-11.7, 0.75, -1.8), Vector3(0.5, 0.12, 0.12), Color("7f8792"))

	_add_block("EastMetalHydrant", Vector3(11.7, 0.5, 2.0), Vector3(0.34, 1.0, 0.34), Color("b94b3c"), true)
	_add_mesh_only("EastMetalHydrantTop", Vector3(11.7, 1.05, 2.0), Vector3(0.42, 0.14, 0.42), Color("8f3d33"))
	_add_mesh_only("EastMetalHydrantValve", Vector3(11.7, 0.75, 1.8), Vector3(0.5, 0.12, 0.12), Color("7f8792"))

	_add_mesh_only("WestServiceMeterPanel", Vector3(-12.44, 0.78, -26.0), Vector3(0.08, 1.2, 0.72), Color("6a747f"))
	_add_mesh_only("EastServiceMeterPanel", Vector3(12.44, 0.78, 26.0), Vector3(0.08, 1.2, 0.72), Color("6a747f"))
	_add_mesh_only("WestServiceMeterPipe", Vector3(-12.34, 1.88, -26.0), Vector3(0.06, 1.35, 0.06), Color("5c6978"))
	_add_mesh_only("EastServiceMeterPipe", Vector3(12.34, 1.88, 26.0), Vector3(0.06, 1.35, 0.06), Color("5c6978"))
	_add_mesh_only("WestServiceMeterBackplate", Vector3(-12.47, 0.78, -26.0), Vector3(0.03, 1.28, 0.9), Color("48525e"))
	_add_mesh_only("EastServiceMeterBackplate", Vector3(12.47, 0.78, 26.0), Vector3(0.03, 1.28, 0.9), Color("48525e"))
	_add_mesh_only("WestServiceMeterConduitStub", Vector3(-12.3, 0.28, -26.0), Vector3(0.05, 0.3, 0.05), Color("5c6978"))
	_add_mesh_only("EastServiceMeterConduitStub", Vector3(12.3, 0.28, 26.0), Vector3(0.05, 0.3, 0.05), Color("5c6978"))

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

	_decorate_mesh_only_geometry(node, name, size, color, emissive)
	geometry_root.add_child(node)
	_annotate_object(node, name, size, "mesh_only")
	return node


func _create_shadow_zones():
	# Data lives in `scripts/world/layout_data.gd` so world behavior and authored
	# coordinates can evolve independently.
	for child in geometry_root.get_children():
		if child is Area3D and child.name.begins_with("ShadowZone"):
			return
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
	if extraction_area != null and is_instance_valid(extraction_area):
		return

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
	await MISSION_CONTROLLER.begin_night(self)

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
	# Guard tree check (fixes log spam).
	var candidates = []
	var origin: Vector3 = player.global_position if player != null and is_instance_valid(player) else global_position
	for npc in get_tree().get_nodes_in_group("npc"):
		if npc.is_inside_tree() and npc.can_interact(player):
			candidates.append(npc)
	if candidates.is_empty():
		return null
	candidates.sort_custom(func(a, b): return origin.distance_to(a.global_position) < origin.distance_to(b.global_position))
	return candidates[0]

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
