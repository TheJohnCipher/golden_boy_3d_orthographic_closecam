extends Node2D

const GameConstants = preload("res://scripts/game_constants.gd")
const MissionManager = preload("res://scripts/mission_manager.gd")
# Constants are now handled via GameConstants class

# ── Light proxy so mission_controller tweens work in 2D ──────────────────────
const HUD_SCENE = preload("res://scenes/hud_2d.tscn")

class LightProxy extends Node:
	var light_energy : float = 0.0
	var visible      : bool  = true

# ── Mission state (same contract as world_3d) ─────────────────────────────────
var contact_npcs       : Array = []
var guard_npcs         : Array = []
var civilian_npcs      : Array = []
var target_npc                 = null
var extraction_area            = null
var extraction_marker          = null

var mission : MissionManager
var player             = null
var near_extraction    := false
var phase_transition_in_progress := false

# 2D-specific: null so mission_controller's _apply_environment_profile no-ops
var environment        = null
var day_sun  : LightProxy
var moon_light : LightProxy
var point_lights       : Array = []
var npc_root   : Node2D
var marker_root : Node2D
var hud                : CanvasLayer

var _camera    : Camera2D
var _night_tint : ColorRect

var night_start_position := GameConstants.NIGHT_START_POSITION
var level_node : Node2D

# =============================================================================
func _ready() -> void:
	mission = MissionManager.new()
	add_child(mission)

	_init_input_map()
	_setup_hud() # Initialize HUD early so other nodes can reference it
	mission.message_requested.connect(_show_message)
	mission.mission_failed.connect(_fail_mission)
	mission.difficulty_spiked.connect(_on_difficulty_spiked)

	_init_roots()
	_init_lights()
	_setup_camera()
	_setup_environment_layers()
	_spawn_player_node()
	_spawn_npc_nodes()
	_configure_window()
	_find_level_node()
	_apply_phase_visibility()
	_show_message(
		"Golden Boy. The Velvet Strip gala. Work the contacts. Execute the extraction.")
	queue_redraw()

# ── Window ────────────────────────────────────────────────────────────────────
func _configure_window() -> void:
	var win := get_viewport().get_window()
	# Viewport mode keeps pixels sharp; EXPAND fills non-standard aspect ratios
	win.content_scale_mode = Window.CONTENT_SCALE_MODE_VIEWPORT
	win.content_scale_aspect = Window.CONTENT_SCALE_ASPECT_EXPAND
	win.content_scale_size = Vector2i(480, 270)
	
	var scr := DisplayServer.window_get_current_screen()
	# Set window position and size to match the display before entering fullscreen
	win.position = DisplayServer.screen_get_position(scr)
	win.size = DisplayServer.screen_get_size(scr)

	if OS.get_name() != "Web":
		win.mode = Window.MODE_FULLSCREEN
	else:
		win.mode = Window.MODE_WINDOWED

# ── Roots & lights ────────────────────────────────────────────────────────────
func _init_roots() -> void:
	npc_root    = Node2D.new(); npc_root.name    = "NPCs";    add_child(npc_root)
	marker_root = Node2D.new(); marker_root.name = "Markers"; add_child(marker_root)

func _init_lights() -> void:
	day_sun    = LightProxy.new()
	moon_light = LightProxy.new()
	day_sun.light_energy    = 1.8;  day_sun.set_meta("base_energy", 1.8)
	moon_light.light_energy = 0.0;  moon_light.set_meta("base_energy", 0.32)
	day_sun.visible    = true
	moon_light.visible = false
	add_child(day_sun)
	add_child(moon_light)

# ── Runtime Overlays ─────────────────────────────────────────────────────────
func _draw() -> void:
	pass # All drawing is now handled by nodes!

# ── Player ────────────────────────────────────────────────────────────────────
func _show_message(txt: String) -> void:
	hud.show_temporary_message(txt)

func _apply_phase_visibility() -> void:
	for npc in contact_npcs: npc.visible = (mission.phase == "day")
	for npc in civilian_npcs: npc.visible = (mission.phase == "day")
	if target_npc: target_npc.visible = (mission.phase == "night")
	for npc in guard_npcs: npc.visible = (mission.phase == "night")
	if extraction_marker: extraction_marker.visible = (mission.phase == "night" and mission.takedown_done)

func _fail_mission(reason: String) -> void:
	_show_message("MISSION FAILED: " + reason)
	if player: player.set_physics_process(false)

# ── NPCs ──────────────────────────────────────────────────────────────────────
func _update_prompt() -> void:
	if mission.is_failed or mission.is_complete: return
	for npc in npc_root.get_children():
		if npc.can_interact(player) or npc.is_takedown_reachable(player):
			hud.set_prompt("[ E ] " + ("Talk to " if npc.role == "contact" else "Takedown ") + npc.npc_name)
			return
	if near_extraction and mission.takedown_done:
		hud.set_prompt("[ E ] Extract")
	else:
		hud.set_prompt("")

# ── Extraction zone ───────────────────────────────────────────────────────────
# Extraction and Shadows should now be Area2D nodes inside your Level scene.
# We keep these callbacks so the level can trigger them.
func _on_extract_entered(body) -> void: if body == player: near_extraction = true
func _on_extract_exited(body) -> void: if body == player: near_extraction = false

func _on_shadow_entered(body) -> void:
	if body == player:
		player.enter_shadow()
		create_tween().tween_property(player, "modulate", Color(0.4, 0.5, 0.8), 0.2)

func _on_shadow_exited(body) -> void:
	if body == player:
		player.exit_shadow()
		create_tween().tween_property(player, "modulate", Color.WHITE, 0.2)

# ── Game loop ─────────────────────────────────────────────────────────────────
func _process(delta: float) -> void:
	_update_prompt()
	# queue_redraw() no longer needed for UI

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("interact"):
		_handle_interaction()

	elif event.is_action_pressed("phase_switch"):
		if mission.phase == "day" and not phase_transition_in_progress:
			if mission.all_contacts_met():
				phase_transition_in_progress = true
				await _begin_night()
				phase_transition_in_progress = false
			else:
				_show_message(
					"Talk to all three contacts before starting the night.")

	elif event.is_action_pressed("restart_level") and (mission.is_failed or mission.is_complete):
		get_tree().reload_current_scene()

	elif event.is_action_pressed("toggle_fullscreen"):
		var win := get_viewport().get_window()
		if win.mode in [Window.MODE_FULLSCREEN, Window.MODE_EXCLUSIVE_FULLSCREEN]:
			win.mode = Window.MODE_WINDOWED
		else:
			win.mode = Window.MODE_FULLSCREEN

	elif event.is_action_pressed("pause"):
		_show_message("Paused. Press Esc to resume.")

# ── Night phase transition ────────────────────────────────────────────────────
func _begin_night() -> void:
	# Fade out title + objective, fade in night tint
	var tw := create_tween()
	tw.set_parallel(true)
	tw.tween_property(hud.title,     "modulate:a", 0.0, 0.5).set_delay(0.4)
	tw.tween_property(hud.objective, "modulate:a", 0.0, 0.5).set_delay(0.4)
	tw.tween_property(_night_tint,      "color",
		Color(0.0, 0.03, 0.12, 0.58), 1.2)
	await tw.finished

	mission.start_night()
	player.position = night_start_position
	_apply_phase_visibility()
	queue_redraw()

	# Fade title + objective back in
	var tw2 := create_tween()
	tw2.set_parallel(true)
	tw2.tween_property(hud.title,     "modulate:a", 1.0, 0.5)
	tw2.tween_property(hud.objective, "modulate:a", 1.0, 0.5)
	_show_message(
		"Night phase. Alden is in the main hall. Get behind him and strike. Extract through the alley.")

func _on_difficulty_spiked() -> void:
	# Update all existing guard/witness NPCs with higher stats
	for npc in guard_npcs:
		if is_instance_valid(npc):
			npc.detect_radius *= 1.3
			npc.detect_rate *= 1.4
			npc.patrol_speed *= 1.2

# =============================================================================
# CONSOLIDATED LOGIC
# =============================================================================
func _init_input_map() -> void:
	var map = {
		"move_left": KEY_A, "move_right": KEY_D, "move_forward": KEY_W, "move_back": KEY_S,
		"interact": KEY_E, "phase_switch": KEY_TAB, "restart_level": KEY_R,
		"toggle_fullscreen": KEY_F11, "pause": KEY_P, "toggle_mouse_capture": KEY_ESCAPE
	}
	for act in map:
		if not InputMap.has_action(act):
			InputMap.add_action(act)
			var ev = InputEventKey.new(); ev.keycode = map[act]
			InputMap.action_add_event(act, ev)

func _find_level_node() -> void:
	level_node = get_node_or_null("Level")
	# Apply the oblique projection to the WHOLE world (self)
	# This ensures Player, NPCs, and Level all match the same Y-scale.
	transform = Transform2D(
		Vector2(1.0, 0.0),
		Vector2(0.0, GameConstants.ISO_Y_SCALE),
		Vector2.ZERO
	)

func _setup_camera() -> void:
	# Camera setup
	var camera = Camera2D.new(); camera.position_smoothing_enabled = true
	camera.zoom = Vector2(1.8, 1.8); add_child(camera); _camera = camera

func _setup_environment_layers() -> void:
	# Tint & HUD Layers
	var tint_layer = CanvasLayer.new(); tint_layer.layer = 0; add_child(tint_layer)
	_night_tint = ColorRect.new(); _night_tint.size = Vector2(1000, 1000)
	_night_tint.position = Vector2(-500, -500); _night_tint.color = Color(0,0,0,0)
	tint_layer.add_child(_night_tint)

func _spawn_player_node() -> void:
	player = GameConstants.PLAYER_SCRIPT.new(); player.world_ref = self
	var cs = CollisionShape2D.new(); var sh = CircleShape2D.new()
	sh.radius = 6.0; cs.shape = sh; player.add_child(cs)
	player.position = Vector2(320.0, 530.0); add_child(player)
	_camera.get_parent().remove_child(_camera)
	player.add_child(_camera); _camera.position = Vector2.ZERO

func _spawn_npc_nodes() -> void:
	for s in GameConstants.NPC_SPAWNS:
		var npc = GameConstants.NPC_SCRIPT.new(); npc.world_ref = self
		npc.setup(s.role, s.name, s.key, s.phase)
		npc.position = s.pos; npc.patrol_points.assign(s.patrol)
		npc.suspicion_detected.connect(mission.raise_suspicion)
		var cs = CollisionShape2D.new(); var sh = CircleShape2D.new()
		sh.radius = 5.0; cs.shape = sh; npc.add_child(cs)
		npc_root.add_child(npc)
		match s.role:
			"contact": contact_npcs.append(npc)
			"guard", "witness": guard_npcs.append(npc)
			"civilian": civilian_npcs.append(npc)
			"target": target_npc = npc

func _setup_hud() -> void:
	# We now use the visual scene instead of building it in code
	hud = HUD_SCENE.instantiate()
	add_child(hud)
	hud.setup(mission)

func _handle_contact_logic(npc) -> void:
	if npc.interaction_used: return
	npc.interaction_used = true; npc.set_marker_visible(false)
	mission.add_contact(npc.contact_key, npc.npc_name)

func _handle_interaction() -> void:
	if mission.is_failed or mission.is_complete: return
	for npc in npc_root.get_children():
		if npc.can_interact(player):
			_handle_contact_logic(npc); return
		if npc.is_takedown_reachable(player):
			mission.set_takedown_done(); npc.visible = false; return
	if near_extraction and mission.takedown_done:
		mission.complete_mission()
