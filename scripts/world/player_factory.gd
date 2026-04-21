extends RefCounted

# Builds the runtime player node hierarchy for the blockout scene.
static func create_player(world):
	var player = CharacterBody3D.new()
	player.name = "Player"
	player.set_script(world.PLAYER_SCRIPT)
	player.position = Vector3(-12.0, 0.0, -20.0)
	player.world_ref = world

	var collision = CollisionShape3D.new()
	var capsule = CapsuleShape3D.new()
	capsule.radius = 0.32
	capsule.height = 1.64
	collision.shape = capsule
	collision.position = Vector3(0.0, 0.92, 0.0)
	player.add_child(collision)

	var visuals = Node3D.new()
	visuals.name = "Visuals"
	visuals.position = Vector3(0.0, 0.0, 0.0)
	visuals.rotation_degrees = Vector3(0.0, 180.0, 0.0)
	player.add_child(visuals)

	var body_mesh = MeshInstance3D.new()
	body_mesh.name = "BodyMesh"
	var body = CapsuleMesh.new()
	body.radius = 0.28
	body.height = 1.44
	body_mesh.mesh = body
	var body_mat = StandardMaterial3D.new()
	body_mat.albedo_color = Color("d3b787")
	body_mat.roughness = 0.75
	body_mesh.material_override = body_mat
	body_mesh.position = Vector3(0.0, 0.78, 0.0)
	body_mesh.scale = Vector3(1.05, 1.05, 1.05)
	visuals.add_child(body_mesh)

	var chest_mesh = MeshInstance3D.new()
	chest_mesh.name = "ChestVest"
	var chest = BoxMesh.new()
	chest.size = Vector3(0.32, 0.44, 0.24)
	chest_mesh.mesh = chest
	var chest_mat = StandardMaterial3D.new()
	chest_mat.albedo_color = Color("3a4a5a")
	chest_mat.roughness = 0.68
	chest_mesh.material_override = chest_mat
	chest_mesh.position = Vector3(0.0, 0.88, 0.0)
	chest_mesh.scale = Vector3(1.05, 1.05, 1.05)
	visuals.add_child(chest_mesh)

	var arm_left = MeshInstance3D.new()
	arm_left.name = "ArmLeft"
	var arm_left_mesh = CapsuleMesh.new()
	arm_left_mesh.radius = 0.11
	arm_left_mesh.height = 0.68
	arm_left.mesh = arm_left_mesh
	var arm_mat = StandardMaterial3D.new()
	arm_mat.albedo_color = Color("c5a585")
	arm_mat.roughness = 0.72
	arm_left.material_override = arm_mat
	arm_left.position = Vector3(-0.28, 0.92, 0.0)
	arm_left.scale = Vector3(1.05, 1.05, 1.05)
	visuals.add_child(arm_left)

	var arm_right = MeshInstance3D.new()
	arm_right.name = "ArmRight"
	var arm_right_mesh = CapsuleMesh.new()
	arm_right_mesh.radius = 0.11
	arm_right_mesh.height = 0.68
	arm_right.mesh = arm_right_mesh
	arm_right.material_override = arm_mat
	arm_right.position = Vector3(0.28, 0.92, 0.0)
	arm_right.scale = Vector3(1.05, 1.05, 1.05)
	visuals.add_child(arm_right)

	var hand_left = MeshInstance3D.new()
	hand_left.name = "HandLeft"
	var hand_left_mesh = SphereMesh.new()
	hand_left_mesh.radius = 0.09
	hand_left.mesh = hand_left_mesh
	var hand_mat = StandardMaterial3D.new()
	hand_mat.albedo_color = Color("c5a585")
	hand_mat.roughness = 0.7
	hand_left.material_override = hand_mat
	hand_left.position = Vector3(-0.28, 0.42, 0.0)
	hand_left.scale = Vector3(1.05, 1.05, 1.05)
	visuals.add_child(hand_left)

	var hand_right = MeshInstance3D.new()
	hand_right.name = "HandRight"
	var hand_right_mesh = SphereMesh.new()
	hand_right_mesh.radius = 0.09
	hand_right.mesh = hand_right_mesh
	hand_right.material_override = hand_mat
	hand_right.position = Vector3(0.28, 0.42, 0.0)
	hand_right.scale = Vector3(1.05, 1.05, 1.05)
	visuals.add_child(hand_right)

	var head = MeshInstance3D.new()
	head.name = "Head"
	var sphere = SphereMesh.new()
	sphere.radius = 0.24
	sphere.height = 0.48
	head.mesh = sphere
	var head_mat = StandardMaterial3D.new()
	head_mat.albedo_color = Color("dfc0a0")
	head_mat.roughness = 0.74
	head.material_override = head_mat
	head.position = Vector3(0.0, 1.58, 0.0)
	head.scale = Vector3(1.05, 1.05, 1.05)
	visuals.add_child(head)

	var neck_mesh = MeshInstance3D.new()
	neck_mesh.name = "Neck"
	var neck = CapsuleMesh.new()
	neck.radius = 0.08
	neck.height = 0.18
	neck_mesh.mesh = neck
	var neck_mat = StandardMaterial3D.new()
	neck_mat.albedo_color = Color("dfc0a0")
	neck_mesh.material_override = neck_mat
	neck_mesh.position = Vector3(0.0, 1.32, 0.0)
	neck_mesh.scale = Vector3(1.05, 1.05, 1.05)
	visuals.add_child(neck_mesh)

	var eye_left = MeshInstance3D.new()
	eye_left.name = "EyeLeft"
	var eye_left_mesh = SphereMesh.new()
	eye_left_mesh.radius = 0.05
	eye_left.mesh = eye_left_mesh
	var eye_mat = StandardMaterial3D.new()
	eye_mat.albedo_color = Color("1a1a1a")
	eye_left.material_override = eye_mat
	eye_left.position = Vector3(-0.08, 1.62, 0.18)
	eye_left.scale = Vector3(1.05, 1.05, 1.05)
	visuals.add_child(eye_left)

	var eye_right = MeshInstance3D.new()
	eye_right.name = "EyeRight"
	var eye_right_mesh = SphereMesh.new()
	eye_right_mesh.radius = 0.05
	eye_right.mesh = eye_right_mesh
	eye_right.material_override = eye_mat
	eye_right.position = Vector3(0.08, 1.62, 0.18)
	eye_right.scale = Vector3(1.05, 1.05, 1.05)
	visuals.add_child(eye_right)

	var hat = MeshInstance3D.new()
	hat.name = "Hat"
	var hat_mesh = CylinderMesh.new()
	hat_mesh.top_radius = 0.18
	hat_mesh.bottom_radius = 0.26
	hat_mesh.height = 0.22
	hat.mesh = hat_mesh
	var hat_mat = StandardMaterial3D.new()
	hat_mat.albedo_color = Color("1a2a3a")
	hat_mat.roughness = 0.65
	hat.material_override = hat_mat
	hat.position = Vector3(0.0, 1.96, 0.0)
	hat.scale = Vector3(1.05, 1.05, 1.05)
	visuals.add_child(hat)

	var hat_brim = MeshInstance3D.new()
	hat_brim.name = "HatBrim"
	var brim_mesh = CylinderMesh.new()
	brim_mesh.top_radius = 0.28
	brim_mesh.bottom_radius = 0.3
	brim_mesh.height = 0.08
	hat_brim.mesh = brim_mesh
	var brim_mat = StandardMaterial3D.new()
	brim_mat.albedo_color = Color("0a1a2a")
	brim_mat.roughness = 0.68
	hat_brim.material_override = brim_mat
	hat_brim.position = Vector3(0.0, 2.08, 0.0)
	hat_brim.scale = Vector3(1.05, 1.05, 1.05)
	visuals.add_child(hat_brim)

	var backpack = MeshInstance3D.new()
	backpack.name = "Backpack"
	var pack_mesh = BoxMesh.new()
	pack_mesh.size = Vector3(0.36, 0.62, 0.3)
	backpack.mesh = pack_mesh
	var pack_mat = StandardMaterial3D.new()
	pack_mat.albedo_color = Color("2a4a3a")
	pack_mat.roughness = 0.72
	backpack.material_override = pack_mat
	backpack.position = Vector3(0.0, 0.95, -0.38)
	backpack.scale = Vector3(1.05, 1.05, 1.05)
	visuals.add_child(backpack)

	var strap_left = MeshInstance3D.new()
	strap_left.name = "StrapLeft"
	var strap_mesh = BoxMesh.new()
	strap_mesh.size = Vector3(0.08, 0.5, 0.12)
	strap_left.mesh = strap_mesh
	var strap_mat = StandardMaterial3D.new()
	strap_mat.albedo_color = Color("1a3a2a")
	strap_mat.roughness = 0.7
	strap_left.material_override = strap_mat
	strap_left.position = Vector3(-0.14, 1.1, -0.28)
	strap_left.scale = Vector3(1.05, 1.05, 1.05)
	visuals.add_child(strap_left)

	var strap_right = MeshInstance3D.new()
	strap_right.name = "StrapRight"
	strap_right.mesh = strap_mesh
	strap_right.material_override = strap_mat
	strap_right.position = Vector3(0.14, 1.1, -0.28)
	strap_right.scale = Vector3(1.05, 1.05, 1.05)
	visuals.add_child(strap_right)

	var glove_left = MeshInstance3D.new()
	glove_left.name = "GloveLeft"
	var glove_mesh = BoxMesh.new()
	glove_mesh.size = Vector3(0.12, 0.26, 0.12)
	glove_left.mesh = glove_mesh
	var glove_mat = StandardMaterial3D.new()
	glove_mat.albedo_color = Color("2a2a3a")
	glove_mat.roughness = 0.62
	glove_left.material_override = glove_mat
	glove_left.position = Vector3(-0.32, 0.48, 0.0)
	glove_left.scale = Vector3(1.05, 1.05, 1.05)
	visuals.add_child(glove_left)

	var glove_right = MeshInstance3D.new()
	glove_right.name = "GloveRight"
	glove_right.mesh = glove_mesh
	glove_right.material_override = glove_mat
	glove_right.position = Vector3(0.32, 0.48, 0.0)
	glove_right.scale = Vector3(1.05, 1.05, 1.05)
	visuals.add_child(glove_right)

	var belt = MeshInstance3D.new()
	belt.name = "Belt"
	var belt_mesh = BoxMesh.new()
	belt_mesh.size = Vector3(0.38, 0.12, 0.15)
	belt.mesh = belt_mesh
	var belt_mat = StandardMaterial3D.new()
	belt_mat.albedo_color = Color("3a3a4a")
	belt_mat.roughness = 0.58
	belt.material_override = belt_mat
	belt.position = Vector3(0.0, 0.58, 0.0)
	belt.scale = Vector3(1.05, 1.05, 1.05)
	visuals.add_child(belt)

	var pants_mat = StandardMaterial3D.new()
	pants_mat.albedo_color = Color("233247")
	pants_mat.roughness = 0.66

	var boot_mat = StandardMaterial3D.new()
	boot_mat.albedo_color = Color("191919")
	boot_mat.roughness = 0.62

	var leg_left = MeshInstance3D.new()
	leg_left.name = "LegLeft"
	var leg_left_mesh = CapsuleMesh.new()
	leg_left_mesh.radius = 0.11
	leg_left_mesh.height = 0.58
	leg_left.mesh = leg_left_mesh
	leg_left.material_override = pants_mat
	leg_left.position = Vector3(-0.13, 0.22, 0.0)
	visuals.add_child(leg_left)

	var leg_right = MeshInstance3D.new()
	leg_right.name = "LegRight"
	var leg_right_mesh = CapsuleMesh.new()
	leg_right_mesh.radius = 0.11
	leg_right_mesh.height = 0.58
	leg_right.mesh = leg_right_mesh
	leg_right.material_override = pants_mat
	leg_right.position = Vector3(0.13, 0.22, 0.0)
	visuals.add_child(leg_right)

	var shin_left = MeshInstance3D.new()
	shin_left.name = "ShinLeft"
	var shin_left_mesh = CapsuleMesh.new()
	shin_left_mesh.radius = 0.1
	shin_left_mesh.height = 0.5
	shin_left.mesh = shin_left_mesh
	shin_left.material_override = pants_mat
	shin_left.position = Vector3(-0.13, -0.14, 0.0)
	visuals.add_child(shin_left)

	var shin_right = MeshInstance3D.new()
	shin_right.name = "ShinRight"
	var shin_right_mesh = CapsuleMesh.new()
	shin_right_mesh.radius = 0.1
	shin_right_mesh.height = 0.5
	shin_right.mesh = shin_right_mesh
	shin_right.material_override = pants_mat
	shin_right.position = Vector3(0.13, -0.14, 0.0)
	visuals.add_child(shin_right)

	var foot_left = MeshInstance3D.new()
	foot_left.name = "FootLeft"
	var foot_left_mesh = BoxMesh.new()
	foot_left_mesh.size = Vector3(0.2, 0.12, 0.3)
	foot_left.mesh = foot_left_mesh
	foot_left.material_override = boot_mat
	foot_left.position = Vector3(-0.13, -0.44, 0.07)
	visuals.add_child(foot_left)

	var foot_right = MeshInstance3D.new()
	foot_right.name = "FootRight"
	var foot_right_mesh = BoxMesh.new()
	foot_right_mesh.size = Vector3(0.2, 0.12, 0.3)
	foot_right.mesh = foot_right_mesh
	foot_right.material_override = boot_mat
	foot_right.position = Vector3(0.13, -0.44, 0.07)
	visuals.add_child(foot_right)

	var pouch_left = MeshInstance3D.new()
	pouch_left.name = "PouchLeft"
	var pouch_mesh = BoxMesh.new()
	pouch_mesh.size = Vector3(0.1, 0.15, 0.12)
	pouch_left.mesh = pouch_mesh
	var pouch_mat = StandardMaterial3D.new()
	pouch_mat.albedo_color = Color("2a2a3a")
	pouch_mat.roughness = 0.6
	pouch_left.material_override = pouch_mat
	pouch_left.position = Vector3(-0.2, 0.56, 0.08)
	pouch_left.scale = Vector3(1.05, 1.05, 1.05)
	visuals.add_child(pouch_left)

	var pouch_right = MeshInstance3D.new()
	pouch_right.name = "PouchRight"
	pouch_right.mesh = pouch_mesh
	pouch_right.material_override = pouch_mat
	pouch_right.position = Vector3(0.2, 0.56, 0.08)
	pouch_right.scale = Vector3(1.05, 1.05, 1.05)
	visuals.add_child(pouch_right)

	var camera_pivot = Node3D.new()
	camera_pivot.name = "CameraPivot"
	camera_pivot.rotation_degrees = Vector3(-18.0, 0.0, 0.0)
	player.add_child(camera_pivot)

	var camera = Camera3D.new()
	camera.name = "Camera3D"
	camera.position = Vector3(0.0, 0.0, 10.5)
	camera.projection = Camera3D.PROJECTION_PERSPECTIVE
	camera.fov = 52.0
	camera.far = 110.0
	camera.near = 0.1
	camera.current = true
	camera_pivot.add_child(camera)

	var footstep_player = AudioStreamPlayer3D.new()
	footstep_player.name = "FootstepPlayer"
	player.add_child(footstep_player)

	world.add_child(player)
	return player
