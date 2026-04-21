extends CharacterBody3D

# Main player controller for the prototype.
# The scene is built entirely from code in `world_3d.gd`, so these node paths
# are part of a contract between the world builder and this controller.
const WALK_SPEED = 8.4
const ACCEL = 30.0
const DECEL = 36.0
const GRAVITY = 28.0

# Mouse look is intentionally mild because the user wanted a "normal 3D game"
# feel without swinging the camera too violently around the player.
const MOUSE_SENSITIVITY = 0.18
const MIN_CAMERA_PITCH = -55.0
const MAX_CAMERA_PITCH = 25.0
const LEG_SWING_DEGREES = 22.0
const SHIN_SWING_DEGREES = 28.0
const FOOT_SWING_DEGREES = 14.0

var world_ref = null
var shadow_count = 0

# `facing` is only for rotating the visible mesh. Real movement comes from the
# physics body velocity and the camera-relative input basis below.
var facing = Vector3(0, 0, 1)

# These values mirror the pivot so mouse input can accumulate freely and then
# write back into the camera rig every frame.
var camera_yaw = 0.0
var camera_pitch = 0.0
var walk_cycle_time = 0.0

@onready var visuals = $Visuals
@onready var camera_pivot = $CameraPivot
@onready var camera = $CameraPivot/Camera3D
@onready var footstep_player : AudioStreamPlayer3D = $FootstepPlayer
@onready var leg_left: Node3D = get_node_or_null("Visuals/LegLeft")
@onready var leg_right: Node3D = get_node_or_null("Visuals/LegRight")
@onready var shin_left: Node3D = get_node_or_null("Visuals/ShinLeft")
@onready var shin_right: Node3D = get_node_or_null("Visuals/ShinRight")
@onready var foot_left: Node3D = get_node_or_null("Visuals/FootLeft")
@onready var foot_right: Node3D = get_node_or_null("Visuals/FootRight")

func _ready():
	add_to_group("player")

	# Start from the camera values authored in the world script so runtime mouse
	# movement continues smoothly from the chosen default angle.
	camera_yaw = camera_pivot.rotation_degrees.y
	camera_pitch = camera_pivot.rotation_degrees.x
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	var footstep_path := "res://art/footstep.ogg"
	var audio_file := FileAccess.open(footstep_path, FileAccess.READ)
	if audio_file != null and audio_file.get_length() > 0:
		var footstep_stream = load(footstep_path)
		if footstep_stream is AudioStream:
			footstep_player.stream = footstep_stream

func _input(event):
	# Mouse motion rotates the whole pivot rig around the player body.
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		camera_yaw -= event.relative.x * MOUSE_SENSITIVITY
		camera_pitch -= event.relative.y * MOUSE_SENSITIVITY

		# Clamp vertical orbit so the camera can tilt but never flips over the top.
		camera_pitch = clamp(camera_pitch, MIN_CAMERA_PITCH, MAX_CAMERA_PITCH)
		camera_pivot.rotation_degrees = Vector3(camera_pitch, camera_yaw, 0.0)

	# Clicking re-captures the mouse after the player has freed it with Esc.
	elif event is InputEventMouseButton and event.pressed and Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

	# Esc toggles between "game controlling the mouse" and "player wants their cursor back".
	elif event.is_action_pressed("toggle_mouse_capture") and (not (event is InputEventKey) or not event.echo):
		if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
			Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		else:
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func _physics_process(delta):
	# Read movement from InputMap actions so control bindings stay centralized.
	var strafe_input = Input.get_action_strength("move_right") - Input.get_action_strength("move_left")
	var forward_input = Input.get_action_strength("move_forward") - Input.get_action_strength("move_back")
	var input_dir = Vector2(strafe_input, forward_input)
	if input_dir.length() > 1.0:
		input_dir = input_dir.normalized()

	# Movement is camera-relative, so "forward" always means "toward the current
	# camera view" instead of "toward world north".
	var forward = -camera.global_transform.basis.z
	forward.y = 0.0
	forward = forward.normalized()

	var right = camera.global_transform.basis.x
	right.y = 0.0
	right = right.normalized()

	var move_dir = (right * input_dir.x) + (forward * input_dir.y)
	if move_dir.length() > 1.0:
		move_dir = move_dir.normalized()

	var target_velocity = move_dir * WALK_SPEED

	# Separate acceleration and deceleration makes the character feel snappier
	# without instantly snapping to zero when the player lets go of a key.
	var accel = ACCEL if move_dir.length() > 0.0 else DECEL
	velocity.x = move_toward(velocity.x, target_velocity.x, accel * delta)
	velocity.z = move_toward(velocity.z, target_velocity.z, accel * delta)

	# The project is grounded-only right now, so vertical velocity is just
	# gravity plus a tiny downward force to keep floor contact stable.
	if not is_on_floor():
		velocity.y -= GRAVITY * delta
	else:
		velocity.y = -0.01

	move_and_slide()

	var flat_velocity = Vector3(velocity.x, 0.0, velocity.z)
	var flat_speed = flat_velocity.length()
	if flat_velocity.length() > 0.15:
		facing = flat_velocity.normalized()
		var target = visuals.global_position + facing
		target.y = visuals.global_position.y
		# Player model is authored with +Z as "front", so use_model_front must be true.
		visuals.look_at(target, Vector3.UP, true)
		
		# Procedural footsteps
		if is_on_floor() and footstep_player.stream != null and footstep_player.playing == false:
			footstep_player.pitch_scale = randf_range(0.85, 1.15)
			footstep_player.volume_db = -10.0 + randf_range(-3.0, 3.0)
			footstep_player.play()

	var speed_ratio = clampf(flat_speed / WALK_SPEED, 0.0, 1.0)
	var locomoting = is_on_floor() and flat_speed > 0.12
	_update_leg_pose(delta, speed_ratio, locomoting)

func _approach_rotation_x(node: Node3D, target_x: float, weight: float) -> void:
	if node == null:
		return
	node.rotation_degrees.x = lerpf(node.rotation_degrees.x, target_x, weight)

func _update_leg_pose(delta: float, speed_ratio: float, locomoting: bool) -> void:
	if locomoting:
		var cycle_rate = lerpf(6.5, 11.0, speed_ratio)
		walk_cycle_time += delta * cycle_rate
	else:
		walk_cycle_time = lerpf(walk_cycle_time, 0.0, min(1.0, delta * 6.0))

	var blend = min(1.0, delta * (14.0 if locomoting else 10.0))
	var gait_phase = walk_cycle_time
	var gait_strength = speed_ratio if locomoting else 0.0
	var leg_swing = sin(gait_phase) * LEG_SWING_DEGREES * gait_strength
	var shin_l = max(0.0, -sin(gait_phase)) * SHIN_SWING_DEGREES * gait_strength
	var shin_r = max(0.0, sin(gait_phase)) * SHIN_SWING_DEGREES * gait_strength
	var foot_swing = sin(gait_phase + PI * 0.5) * FOOT_SWING_DEGREES * gait_strength

	_approach_rotation_x(leg_left, leg_swing, blend)
	_approach_rotation_x(leg_right, -leg_swing, blend)
	_approach_rotation_x(shin_left, shin_l, blend)
	_approach_rotation_x(shin_right, shin_r, blend)
	_approach_rotation_x(foot_left, -foot_swing, blend)
	_approach_rotation_x(foot_right, foot_swing, blend)

# Shadow zones increment and decrement this counter instead of using a single
# boolean so overlapping hide areas still work correctly.
func enter_shadow():
	shadow_count += 1

func exit_shadow():
	shadow_count = max(shadow_count - 1, 0)

func is_hidden():
	return shadow_count > 0
