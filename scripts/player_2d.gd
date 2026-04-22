extends CharacterBody2D

const WALK_SPEED   = 85.0
const SPRINT_SPEED = 155.0

var world_ref      = null
var shadow_count   := 0
var facing         := Vector2(0.0, 1.0)
var _move_time     := 0.0

func _physics_process(delta: float) -> void:
	var has_sprint = InputMap.has_action("sprint")
	
	var dir := Vector2(
		Input.get_action_strength("move_right") - Input.get_action_strength("move_left"),
		Input.get_action_strength("move_back")  - Input.get_action_strength("move_forward")
	)
	if dir.length_squared() > 1.0:
		dir = dir.normalized()
	if dir.length_squared() > 0.01:
		facing = dir.normalized()
		_move_time += delta
	else:
		_move_time = 0.0
	
	var is_sprinting = has_sprint and Input.is_action_pressed("sprint")
	velocity = dir * (SPRINT_SPEED if is_sprinting else WALK_SPEED)
	move_and_slide()
	queue_redraw()

func _draw() -> void:
	var hidden := is_hidden()
	var moving := _move_time > 0.0
	var step   := sin(_move_time * 12.0)
	var sprint := InputMap.has_action("sprint") and Input.is_action_pressed("sprint")

	var c_suit := Color("#16121e") if not hidden else Color("#0a080f")
	var c_mid  := Color("#221b30") if not hidden else Color("#110f18")
	var c_gold := Color("#c8a84e") if not hidden else Color("#3a2c0e")
	var c_skin := Color("#c49a72") if not hidden else Color("#5a4030")
	var c_hair := Color("#120e0c") if not hidden else Color("#080706")
	var c_shoe := Color("#0c0a08") if not hidden else Color("#060504")

	var perp := Vector2(-facing.y, facing.x)

	# ── Oblique ground shadow (offset south = larger Y, reads as depth) ───────
	draw_circle(Vector2(0.0, 7.0), 9.0, Color(0.0, 0.0, 0.0, 0.32))

	# ── Feet / legs at bottom of figure (south = ground level in oblique) ─────
	var swing   := step * 3.0 if moving else 0.0
	# In oblique view, "ground level" is south (larger local Y).
	# Feet sit at the base; body rises upward (smaller Y) to imply height.
	var feet_y  := 4.0   # feet below body center
	var body_y  := -2.0  # body center slightly raised
	var head_y  := -10.0 # head clearly above body

	var ll := Vector2(-perp.x * 2.8 + facing.x * swing, feet_y + perp.y * 2.8 + facing.y * swing)
	var rl := Vector2( perp.x * 2.8 - facing.x * swing, feet_y - perp.y * 2.8 - facing.y * swing)
	draw_circle(ll, 2.4, c_suit)
	draw_circle(ll + Vector2(facing.x, facing.y) * 3.2, 1.8, c_shoe)
	draw_circle(rl, 2.4, c_suit)
	draw_circle(rl + Vector2(facing.x, facing.y) * 3.2, 1.8, c_shoe)

	# ── Torso (raised above feet) ─────────────────────────────────────────────
	var body := Vector2(0.0, body_y)
	draw_circle(body, 5.5, c_mid)
	draw_circle(body + perp * 2.2,  3.2, c_suit)
	draw_circle(body - perp * 2.2,  3.2, c_suit)
	# Gold tie
	draw_circle(body + Vector2(facing.x, facing.y) * 2.0, 1.4, c_gold)

	# ── Shoulders ─────────────────────────────────────────────────────────────
	draw_circle(body + perp * 5.0, 2.8, c_suit)
	draw_circle(body - perp * 5.0, 2.8, c_suit)

	# ── Neck ──────────────────────────────────────────────────────────────────
	draw_circle(Vector2(0.0, head_y + 3.5), 2.0, c_skin)

	# ── Head (highest point — clearly "above" body in oblique) ───────────────
	var head := Vector2(facing.x * 1.5, head_y)
	draw_circle(head, 4.0, c_skin)
	draw_circle(head - Vector2(facing.x, facing.y) * 1.6, 3.4, c_hair)
	draw_circle(head + Vector2(facing.x, facing.y) * 1.4 + perp * 0.7, 0.8, c_skin.lightened(0.18))

	# ── Sprint: coat flap ─────────────────────────────────────────────────────
	if sprint and moving:
		draw_circle(body - Vector2(facing.x, facing.y) + perp * absf(step), 1.1, c_gold.darkened(0.1))

	# ── Hidden ring ───────────────────────────────────────────────────────────
	if hidden:
		draw_arc(body, 12.0, 0.0, TAU, 24, Color(0.35, 0.42, 0.9, 0.6), 1.5)

func enter_shadow() -> void:
	shadow_count += 1
	queue_redraw()

func exit_shadow() -> void:
	shadow_count = max(shadow_count - 1, 0)
	queue_redraw()

func is_hidden() -> bool:
	return shadow_count > 0
