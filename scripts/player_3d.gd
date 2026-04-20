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

var world_ref = null
var shadow_count = 0

# `facing` is only for rotating the visible mesh. Real movement comes from the
# physics body velocity and the camera-relative input basis below.
var facing = Vector3(0, 0, 1)

# These values mirror the pivot so mouse input can accumulate freely and then
# write back into the camera rig every frame.
var camera_yaw = 0.0
var camera_pitch = 0.0

@onready var visuals = $Visuals
@onready var camera_pivot = $CameraPivot
@onready var camera = $CameraPivot/Camera3D
@onready var footstep_player : AudioStreamPlayer3D = $FootstepPlayer

func _ready():
	add_to_group("player")

	# Start from the camera values authored in the world script so runtime mouse
	# movement continues smoothly from the chosen default angle.
	camera_yaw = camera_pivot.rotation_degrees.y
	camera_pitch = camera_pivot.rotation_degrees.x
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	footstep_player.stream = load("res://art/footstep.ogg")

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
	elif event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_ESCAPE:
		if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
			Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		else:
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func _physics_process(delta):
	# Read raw WASD input. This project currently avoids InputMap setup and keeps
	# the prototype controls explicit in script for easier iteration.
	var input_dir = Vector2.ZERO
	if Input.is_key_pressed(KEY_A):
		input_dir.x -= 1.0
	if Input.is_key_pressed(KEY_D):
		input_dir.x += 1.0
	if Input.is_key_pressed(KEY_W):
		input_dir.y -= 1.0
	if Input.is_key_pressed(KEY_S):
		input_dir.y += 1.0
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

	# `input_dir.y` is negative for W, so we invert it here to keep W moving in
	# the visually expected forward direction.
	var move_dir = (right * input_dir.x) + (forward * -input_dir.y)
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
	if flat_velocity.length() > 0.15:
		facing = flat_velocity.normalized()
		var target = visuals.global_position + facing
		target.y = visuals.global_position.y
		visuals.look_at(target, Vector3.UP)
		
		# Procedural footsteps
		if is_on_floor() and footstep_player.playing == false:
			footstep_player.pitch_scale = randf_range(0.85, 1.15)
			footstep_player.volume_db = -10.0 + randf_range(-3.0, 3.0)
			footstep_player.play()

# Shadow zones increment and decrement this counter instead of using a single
# boolean so overlapping hide areas still work correctly.
func enter_shadow():
	shadow_count += 1

func exit_shadow():
	shadow_count = max(shadow_count - 1, 0)

func is_hidden():
	return shadow_count > 0
