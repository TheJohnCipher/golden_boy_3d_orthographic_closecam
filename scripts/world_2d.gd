extends Node2D

const GameConstants = preload("res://scripts/game_constants.gd")
const MissionManager = preload("res://scripts/mission_manager.gd")
# Constants are now handled via GameConstants class

# ── Light proxy so mission_controller tweens work in 2D ──────────────────────
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
var message_text       := ""
var message_timer      := 0.0

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
var hud                := {}

var _camera    : Camera2D
var _night_tint : ColorRect
var _hud_layer : CanvasLayer

var night_start_position := GameConstants.NIGHT_START_POSITION
var level_node : Node2D

# =============================================================================
func _ready() -> void:
	mission = MissionManager.new()
	add_child(mission)
	mission.state_changed.connect(_update_hud_elements)
	mission.message_requested.connect(_show_message)
	mission.mission_failed.connect(_fail_mission)
	mission.difficulty_spiked.connect(_on_difficulty_spiked)

	_init_input_map()
	_init_roots()
	_init_lights()
	_setup_camera()
	_setup_environment_layers()
	_spawn_player_node()
	_spawn_npc_nodes()
	_setup_hud()
	_configure_window()
	_find_level_node()
	_apply_phase_visibility()
	_show_message(
		"Golden Boy. The Velvet Strip gala. Work the contacts. Execute the extraction.")
	queue_redraw()

# ── Window ────────────────────────────────────────────────────────────────────
func _configure_window() -> void:
	var win := get_viewport().get_window()
	win.content_scale_mode = Window.CONTENT_SCALE_MODE_VIEWPORT
	win.content_scale_size = Vector2i(480, 270)
	var scr := DisplayServer.window_get_current_screen()
	win.size     = DisplayServer.screen_get_size(scr)
	win.position = DisplayServer.screen_get_position(scr)
	win.mode     = Window.MODE_FULLSCREEN

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
	# We only draw dynamic mission overlays now. 
	# Room geometry should be handled by Polygon2D nodes in the level scene.
	var night := mission.phase == "night"
	if night:
		_draw_suspicion_bar()

# ── Suspicion bar ─────────────────────────────────────────────────────────────
func _draw_suspicion_bar() -> void:
	var bar_x := 330.0
	var bar_y := 252.0
	var bar_w := 140.0
	var fill  := (mission.suspicion / 100.0) * bar_w
	var bc    := Color(1.0, 0.28, 0.28) if mission.suspicion > 60.0 else Color(0.85, 0.55, 0.30)
	# Background track
	draw_rect(Rect2(bar_x - 1, bar_y - 1, bar_w + 2, 8), Color(0.08, 0.04, 0.04))
	draw_rect(Rect2(bar_x, bar_y, bar_w, 6), Color(0.14, 0.07, 0.07))
	# Fill
	if fill > 0.0:
		draw_rect(Rect2(bar_x, bar_y, fill, 6), bc)
		# Shimmer on bar
		draw_rect(Rect2(bar_x, bar_y, fill, 2), Color(bc.r, bc.g, bc.b, 0.4))
	# Border
	draw_rect(Rect2(bar_x - 1, bar_y - 1, bar_w + 2, 8), Color(0.35, 0.12, 0.12), false, 0.8)

# ── Player ────────────────────────────────────────────────────────────────────
func _show_message(txt: String) -> void:
	message_text = txt
	message_timer = 4.0
	_update_hud_elements()

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
	hud.prompt_panel.visible = false
	if mission.is_failed or mission.is_complete: return
	for npc in npc_root.get_children():
		if npc.can_interact(player) or npc.is_takedown_reachable(player):
			hud.prompt.text = "[ E ] " + ("Talk to " if npc.role == "contact" else "Takedown ") + npc.npc_name
			hud.prompt_panel.visible = true
			return
	if near_extraction and mission.takedown_done:
		hud.prompt.text = "[ E ] Extract"; hud.prompt_panel.visible = true

# ── Extraction zone ───────────────────────────────────────────────────────────
# Extraction and Shadows should now be Area2D nodes inside your Level scene.
# We keep these callbacks so the level can trigger them.
func _on_extract_entered(body) -> void: if body == player: near_extraction = true
func _on_extract_exited(body) -> void: if body == player: near_extraction = false
func _on_shadow_entered(body) -> void: if body == player: player.enter_shadow()
func _on_shadow_exited(body) -> void: if body == player: player.exit_shadow()

# ── Game loop ─────────────────────────────────────────────────────────────────
func _process(delta: float) -> void:
	if message_timer > 0.0:
		message_timer -= delta
		if message_timer <= 0.0:
			message_text = ""
			_update_hud_elements() # Only update when message clears

	_update_prompt()
	queue_redraw()

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
	tw.tween_property(hud["title"],     "modulate:a", 0.0, 0.5).set_delay(0.4)
	tw.tween_property(hud["objective"], "modulate:a", 0.0, 0.5).set_delay(0.4)
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
	tw2.tween_property(hud["title"],     "modulate:a", 1.0, 0.5)
	tw2.tween_property(hud["objective"], "modulate:a", 1.0, 0.5)
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
	_hud_layer = CanvasLayer.new(); _hud_layer.layer = 1; add_child(_hud_layer)

func _spawn_player_node() -> void:
	player = GameConstants.PLAYER_SCRIPT.new(); player.world_ref = self
	var cs = CollisionShape2D.new(); var sh = CircleShape2D.new()
	sh.radius = 6.0; cs.shape = sh; player.add_child(cs)
	player.position = Vector2(320.0, 530.0); add_child(player)
	_camera.reparent(player); _camera.position = Vector2.ZERO

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
	hud.title = _create_label("GOLDEN BOY", 16, Vector2(150, 6), GameConstants.C_GOLD)
	hud.objective = _create_label("", 7, Vector2(6, 256), Color("#aabbcc"))
	hud.money = _create_label("$0", 7, Vector2(6, 8), Color("#44bb66"))
	hud.message = _create_label("", 8, Vector2(70, 128), Color("#ffffff"))
	hud.suspicion = _create_label("", 7, Vector2(330, 248), Color("#ff8866"))
	hud.prompt_panel = Control.new(); hud.prompt = _create_label("", 8, Vector2(90, 228), Color("#ffdd88"))
	hud.prompt_panel.add_child(hud.prompt); hud.prompt_panel.visible = false
	hud.phase_hint = _create_label("[ TAB ] Start Night", 6, Vector2(6, 264), Color(0.4, 0.4, 0.5))
	for node in [hud.title, hud.objective, hud.money, hud.message, hud.suspicion, hud.prompt_panel, hud.phase_hint]: 
		_hud_layer.add_child(node)

func _create_label(t: String, s: int, p: Vector2, c: Color) -> Label:
	var l = Label.new(); l.text = t; l.position = p
	l.add_theme_font_size_override("font_size", s); l.add_theme_color_override("font_color", c)
	return l

func _update_hud_elements() -> void:
	hud.objective.text = mission.current_objective
	hud.money.text = "$" + str(mission.money)
	hud.message.text = message_text; hud.message.visible = message_text != ""
	hud.suspicion.text = "SUSPICION: " + str(int(mission.suspicion)) if mission.phase == "night" else ""
	hud.phase_hint.visible = (mission.phase == "day" and not mission.is_failed)

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
