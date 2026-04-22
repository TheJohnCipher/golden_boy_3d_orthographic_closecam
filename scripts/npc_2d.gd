extends CharacterBody2D

var world_ref        = null
var npc_name         := "NPC"
var role             := "civilian"
var contact_key      := ""
var active_phase     := "both"
var interaction_used := false
var patrol_points    : Array[Vector2] = []
var patrol_speed     := 35.0
var detect_radius    := 100.0
var detect_fov       := 70.0
var detect_rate      := 22.0

var _current_point   := 0
var _pause_timer     := 0.0
var _facing          := Vector2(0.0, 1.0)
var _body_color      := Color("#7a8a9a")
var _marker_visible  := false

func setup(p_role: String, p_name: String, p_key: String, p_phase: String) -> void:
	role         = p_role
	npc_name     = p_name
	contact_key  = p_key
	active_phase = p_phase
	match role:
		"contact":  _body_color = Color("#5da7c7")
		"guard":    _body_color = Color("#cc4444")
		"witness":  _body_color = Color("#c87050")
		"target":   _body_color = Color("#d8cfc0")
		_:          _body_color = Color("#7a8a9a")

func set_marker_visible(show: bool) -> void:
	_marker_visible = show
	queue_redraw()

func can_interact(player) -> bool:
	if interaction_used or role != "contact" or not visible:
		return false
	return global_position.distance_to(player.global_position) <= 26.0

func is_takedown_reachable(player) -> bool:
	if role != "target" or not self.visible:
		return false
	if global_position.distance_to(player.global_position) > 28.0:
		return false
	# Player must be broadly behind/beside the target
	var to_player : Vector2 = (player.global_position - global_position).normalized()
	return _facing.dot(to_player) < 0.25

func can_detect_player(player) -> bool:
	if not self.visible or player == null:
		return false
	var to_p  : Vector2 = player.global_position - global_position
	var dist  := to_p.length()
	if dist > detect_radius:
		return false
	# Shadows cut detection range to 30 %
	if player.is_hidden() and dist > detect_radius * 0.3:
		return false
	if dist < 0.01:
		return true
	var ang : float = absf(rad_to_deg(_facing.angle_to(to_p.normalized())))
	return ang <= detect_fov * 0.5

func _process(_delta: float) -> void:
	if _marker_visible:
		queue_redraw()

func _physics_process(delta: float) -> void:
	_run_patrol(delta)
	if world_ref == null or world_ref.phase != "night":
		return
	if world_ref.mission_failed or world_ref.level_complete:
		return
	if world_ref != null and world_ref.player != null and role in ["guard", "witness", "target"] and can_detect_player(world_ref.player):
		world_ref.raise_suspicion(detect_rate * delta, npc_name)

func _run_patrol(delta: float) -> void:
	if patrol_points.size() < 2 or role not in ["guard", "witness", "civilian"]:
		return
	if _pause_timer > 0.0:
		_pause_timer -= delta
		velocity = velocity.move_toward(Vector2.ZERO, patrol_speed * 12.0 * delta)
		move_and_slide()
		return
	var dest := patrol_points[_current_point]
	var diff := dest - global_position
	if diff.length() < 5.0:
		_current_point = (_current_point + 1) % patrol_points.size()
		_pause_timer   = randf_range(0.3, 0.6)
		return
	_facing  = diff.normalized()
	velocity = _facing * patrol_speed
	move_and_slide()
	queue_redraw()

func _draw() -> void:
	# Vision cone for watchers
	if role in ["guard", "witness"]:
		var pts      := PackedVector2Array()
		pts.append(Vector2.ZERO)
		var half     := deg_to_rad(detect_fov * 0.5)
		var base_ang := _facing.angle()
		for i in range(11):
			var a := base_ang - half + (half * 2.0 * float(i) / 10.0)
			pts.append(Vector2(cos(a), sin(a)) * detect_radius)
		var cc := Color(1.0, 0.2, 0.15, 0.12) if role == "guard" else Color(1.0, 0.6, 0.2, 0.10)
		draw_polygon(pts, PackedColorArray([cc]))

	# Body circle + direction nub
	draw_circle(Vector2.ZERO, 7.0, _body_color)
	draw_circle(_facing * 8.5, 2.5, _body_color.lightened(0.35))

	# Floating marker with name
	if _marker_visible:
		var t     := float(Time.get_ticks_msec()) * 0.005
		var pulse : float = absf(sin(t)) * 1.5
		var mc    := Color("#44d8ff") if role == "contact" else Color("#ffbf44")
		draw_circle(Vector2(0.0, -14.0), 3.0 + pulse, mc)
		draw_string(ThemeDB.fallback_font, Vector2(-20.0, -24.0), npc_name,
				HORIZONTAL_ALIGNMENT_LEFT, -1, 7, mc)
