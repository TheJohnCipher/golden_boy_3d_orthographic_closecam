@tool
extends Node2D

const GameConstants = preload("res://scripts/game_constants.gd")
const MissionManager = preload("res://scripts/mission_manager.gd")
const WorldManager = preload("res://scripts/world_manager.gd")
const HUD_SCENE = preload("res://scenes/hud_2d.tscn")

# ── Mission state ─────────────────────────────────────────────────────────────
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
var is_paused := false

var world_manager      : Node2D
var hud                : CanvasLayer

var _camera    : Camera2D
var _night_tint : ColorRect

var night_start_position := GameConstants.NIGHT_START_POSITION
var level_node : Node2D

var _shake_intensity := 0.0

# =============================================================================
func _ready() -> void:
	# ── 1. Architecture (Runs in Editor and Game) ──
	_find_level_node()
	_setup_world_manager()

	if Engine.is_editor_hint():
		return # Stop here; do not run mission or entity logic in the editor.

	mission = MissionManager.new()
	add_child(mission)
	mission.message_requested.connect(_show_message)
	mission.mission_failed.connect(_fail_mission)
	mission.difficulty_spiked.connect(_on_difficulty_spiked)

	_configure_window()
	_init_input_map()
	RenderingServer.set_default_clear_color(Color("#050508")) # Deep Noir Void
	y_sort_enabled = true

	_setup_environment_layers()
	_setup_camera()

	# ── 3. Entity Population ──
	_spawn_player_node()
	_setup_hud()
	_apply_phase_visibility()

	_show_message("Golden Boy: Seamless City Engine. Explore the infinite Noir sprawl.")
	await get_tree().create_timer(2.0).timeout
	_show_message("Controls: WASD move, E interact, TAB phase switch, R restart, F11 fullscreen")

# ── Window ────────────────────────────────────────────────────────────────────
func _configure_window() -> void:
	var win := get_viewport().get_window()
	win.content_scale_mode = Window.CONTENT_SCALE_MODE_VIEWPORT
	win.content_scale_size = Vector2i(480, 270)
	var scr := DisplayServer.window_get_current_screen()
	win.size     = DisplayServer.screen_get_size(scr)
	win.position = DisplayServer.screen_get_position(scr)
	win.mode     = Window.MODE_FULLSCREEN

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
	_show_message("MISSION FAILED: " + reason + ". Press R to restart.")
	if player: player.set_physics_process(false)

# ── NPCs ──────────────────────────────────────────────────────────────────────
func _update_prompt() -> void:
	if mission == null or is_instance_valid(mission) == false or mission.is_failed or mission.is_complete: return
	for npc in _get_ysort_container().get_children():
		if not npc.has_method("can_interact"): continue
		if npc.can_interact(player) or npc.is_takedown_reachable(player):
			var action = "Talk to " if npc.role == "contact" else "Takedown "
			var status = " [MET]" if npc.interaction_used else ""
			hud.set_prompt("[ E ] " + action + npc.npc_name + status)
			return
	if near_extraction and mission.takedown_done:
		hud.set_prompt("[ E ] Extract")
	else:
		hud.set_prompt("")

# ── Extraction zone ───────────────────────────────────────────────────────────
# Extraction and Shadows should now be Area2D nodes inside your Level scene.
# We keep these callbacks so the level can trigger them.
func _on_extract_entered(body) -> void:
	if body == player:
		near_extraction = true
		if mission.takedown_done:
			_show_message("Extraction point reached. Press E to extract.")
func _on_extract_exited(body) -> void:
	if body == player:
		near_extraction = false
func _on_shadow_entered(body) -> void:
	if body == player:
		player.enter_shadow()
		_show_message("In shadow. Guards less likely to detect you.")
func _on_shadow_exited(body) -> void:
	if body == player:
		player.exit_shadow()
		_show_message("Left shadow.")

# ── Game loop ─────────────────────────────────────────────────────────────────
func _process(delta: float) -> void:
	if Engine.is_editor_hint() or mission == null:
		return

	_update_prompt()
	if _shake_intensity > 0:
		_shake_intensity = lerp(_shake_intensity, 0.0, delta * 10.0)
		if _camera:
			_camera.offset = Vector2(randf_range(-1, 1), randf_range(-1, 1)) * _shake_intensity

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
				var met = contact_npcs.filter(func(npc): return npc.interaction_used).size()
				var remaining = contact_npcs.filter(func(npc): return not npc.interaction_used).map(func(npc): return npc.npc_name)
				_show_message("Contacts met: %d/3. Find: %s" % [met, ", ".join(remaining)])

	elif event.is_action_pressed("restart_level") and (mission.is_failed or mission.is_complete):
		get_tree().reload_current_scene()

	elif event.is_action_pressed("toggle_fullscreen"):
		var win := get_viewport().get_window()
		if win.mode in [Window.MODE_FULLSCREEN, Window.MODE_EXCLUSIVE_FULLSCREEN]:
			win.mode = Window.MODE_WINDOWED
		else:
			win.mode = Window.MODE_FULLSCREEN

	elif event.is_action_pressed("pause"):
		is_paused = not is_paused
		get_tree().paused = is_paused
		if is_paused:
			_show_message("PAUSED. Press Esc to resume.")
		else:
			_show_message("Resumed.")

# ── Night phase transition ────────────────────────────────────────────────────
func _begin_night() -> void:
	# Fade out title + objective, fade in night tint
	var tw := create_tween()
	tw.set_parallel(true)
	tw.tween_property(hud.title,     "modulate:a", 0.0, 0.5).set_delay(0.4)
	tw.tween_property(hud.objective, "modulate:a", 0.0, 0.5).set_delay(0.4)
	tw.tween_property(_night_tint,      "color",
		Color(0.04, 0.02, 0.08, 0.45), 1.2) # Deeper, more opaque Noir tint
	await tw.finished

	mission.start_night()
	player.position = night_start_position
	_apply_phase_visibility()

	# Fade title + objective back in
	var tw2 := create_tween()
	tw2.set_parallel(true)
	tw2.tween_property(hud.title,     "modulate:a", 1.0, 0.5)
	tw2.tween_property(hud.objective, "modulate:a", 1.0, 0.5)
	_show_message(
		"Night phase. Alden patrols the main hall. Guards and witnesses will spot you - use shadows. Takedown from behind. Extract via alley.")

func _on_difficulty_spiked() -> void:
	_show_message("Alert raised! Guards are more vigilant.")
	for npc in guard_npcs:
		if is_instance_valid(npc):
			npc.detect_radius *= 1.3
			npc.detect_rate *= 1.4
			npc.patrol_speed *= 1.2

func add_camera_shake(intensity: float) -> void:
	_shake_intensity = intensity

# =============================================================================
# CONSOLIDATED LOGIC
# =============================================================================
func _init_input_map() -> void:
	var map = {
		"move_left": KEY_A, "move_right": KEY_D, "move_forward": KEY_W, "move_back": KEY_S,
		"interact": KEY_E, "phase_switch": KEY_TAB, "sprint": KEY_SHIFT, "restart_level": KEY_R,
		"toggle_fullscreen": KEY_F11, "pause": KEY_P, "toggle_mouse_capture": KEY_ESCAPE
	}
	for act in map:
		if not InputMap.has_action(act):
			InputMap.add_action(act)
			var ev = InputEventKey.new(); ev.keycode = map[act]
			InputMap.action_add_event(act, ev)

func _setup_world_manager() -> void:
	if level_node:
		world_manager = level_node.get_node_or_null("CityWorldManager")
	
	if not world_manager:
		push_warning("SYSTEM: WorldManager not found in Level node. Map streaming disabled.")
		return

	world_manager.world_ref = self
	
func _find_level_node() -> void:
	# Legacy support removed in favor of dynamic streaming
	level_node = null 
	
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
	# ── 5. Lighting: Warm low-intensity tint ──
	var modulate = CanvasModulate.new()
	modulate.color = Color(1, 1, 1, 1)
	add_child(modulate)

	var tint_layer = CanvasLayer.new(); tint_layer.layer = 0; add_child(tint_layer)
	_night_tint = ColorRect.new(); _night_tint.size = Vector2(2000, 2000)
	_night_tint.position = Vector2(-1000, -1000); _night_tint.color = Color(0,0,0,0)
	tint_layer.add_child(_night_tint)

	var vignette_layer = CanvasLayer.new(); vignette_layer.layer = 10; add_child(vignette_layer)
	var vignette = TextureRect.new()
	vignette.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	vignette.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var v_tex = GradientTexture2D.new()
	v_tex.fill = GradientTexture2D.FILL_RADIAL
	v_tex.fill_from = Vector2(0.5, 0.5)
	v_tex.gradient = Gradient.new()
	v_tex.gradient.set_color(0, Color(0, 0, 0, 0))
	v_tex.gradient.set_color(1, Color(0, 0, 0, 0.25))
	vignette.texture = v_tex
	vignette_layer.add_child(vignette)

func _spawn_player_node() -> void:
	# Prevent "Other Players" from spawning if one exists in the Level scene
	var ysort = _get_ysort_container()
	if ysort.get_node_or_null("Player"):
		player = ysort.get_node("Player"); return

	player = GameConstants.PLAYER_SCRIPT.new(); player.world_ref = self
	player.y_sort_enabled = true # Ensure player sorts against the world
	var cs = CollisionShape2D.new(); var sh = CircleShape2D.new()
	sh.radius = 6.0; cs.shape = sh; player.add_child(cs)
	player.position = Vector2(544.0, 350.0)
	
	# Place player in the Level's YSort container for correct depth
	if world_manager:
		world_manager.player_ref = player
		add_child(player) # Player is outside chunks to prevent unloading
	else:
		ysort.add_child(player)
	_camera.reparent(player); _camera.position = Vector2.ZERO

func _setup_hud() -> void:
	# We now use the visual scene instead of building it in code
	hud = HUD_SCENE.instantiate()
	add_child(hud)
	hud.setup(mission)

func _get_ysort_container() -> Node2D:
	var target = level_node.get_node("YSort_Container") if level_node else null
	if target: return target
	return self # Fallback to world root

func _handle_contact_logic(npc) -> void:
	if npc.interaction_used: return
	npc.interaction_used = true
	npc.set_marker_visible(false)
	mission.add_contact(npc.contact_key, npc.npc_name)
	_show_message("Contact %s: Intel acquired. %d/3 contacts met." % [npc.npc_name, contact_npcs.filter(func(c): return c.interaction_used).size()])

func _handle_interaction() -> void:
	if mission.is_failed or mission.is_complete: return
	for npc in _get_ysort_container().get_children():
		if not npc.has_method("can_interact"): continue
		if npc.can_interact(player):
			_handle_contact_logic(npc); return
		if npc.is_takedown_reachable(player):
			mission.set_takedown_done()
			npc.visible = false
			add_camera_shake(10.0)
			_show_message("Target neutralized. Head to extraction point.")
			return
	if near_extraction and mission.takedown_done:
		mission.complete_mission()
		_show_message("Extraction successful. Mission complete!")
