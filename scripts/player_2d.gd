extends CharacterBody2D

const GameConstants = preload("res://scripts/game_constants.gd")

const WALK_SPEED   = 85.0
const SPRINT_SPEED = 155.0

var world_ref      = null
var shadow_count   := 0
var facing         := Vector2(0.0, 1.0)
var _move_time     := 0.0
var _step_timer    := 0.0

var sprite : Sprite2D

func _ready() -> void:
	sprite = Sprite2D.new()
	var path := GameConstants.T_PLAYER_SPRITE
	var tex = load(path)
	if tex: sprite.texture = tex
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	# Physics Footprint Protocol: Origin at feet
	sprite.offset = Vector2(0, -sprite.texture.get_height() * 0.5) if sprite.texture else Vector2.ZERO
	add_child(sprite)

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
	
	if dir.length() > 0.1:
		_step_timer += delta
		if _step_timer >= (0.3 if is_sprinting else 0.5):
			_step_timer = 0.0
			_play_footstep()

func _process(delta: float) -> void:
	var hidden := is_hidden()
	var moving := _move_time > 0.0
	var sprint := InputMap.has_action("sprint") and Input.is_action_pressed("sprint")

	# Update visual state
	if sprite:
		sprite.modulate = Color(0.5, 0.6, 1.0, 0.7) if hidden else Color.WHITE
		# Professional procedural lean: Rotates based on velocity, snaps back to 0 when idle
		var target_rot = (velocity.x / SPRINT_SPEED) * 0.12 if moving else 0.0
		sprite.rotation = lerp(sprite.rotation, target_rot, delta * 10.0)
	
	_update_occlusion(delta)

func _update_occlusion(delta: float) -> void:
	# Check for buildings in the YSort container that are north of the player
	# but whose sprites might overlap the player's screen position.
	var space_state = get_world_2d().direct_space_state
	var query = PhysicsRayQueryParameters2D.create(global_position, global_position + Vector2(0, -60))
	query.collision_mask = 1 # Architecture layer
	var result = space_state.intersect_ray(query)

	if world_ref and world_ref.world_manager:
		for chunk in world_ref.world_manager.active_chunks.values():
			if not chunk: continue
			for b in chunk.get_node("Architecture_YSort").get_children():
				if b is Sprite2D and b.global_position.distance_to(global_position) < 180:
					var is_above = b.global_position.y < global_position.y
					b.modulate.a = lerp(b.modulate.a, 0.75 if is_above else 1.0, delta * 5.0)

func _play_footstep() -> void:
	var am = get_node_or_null("/root/AudioManager")
	if am:
		am.play_sound_2d(GameConstants.S_FOOTSTEP, global_position, -15.0, randf_range(0.9, 1.1))

func enter_shadow() -> void:
	shadow_count += 1

func exit_shadow() -> void:
	shadow_count = max(shadow_count - 1, 0)

func is_hidden() -> bool:
	return shadow_count > 0
