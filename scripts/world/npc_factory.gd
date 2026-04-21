extends RefCounted

# Builds and configures all NPC runtime nodes from declarative layout data.
static func spawn_level_characters(world) -> void:
	spawn_group(world, world.LAYOUT_DATA.day_contacts(), world.contact_npcs)
	spawn_group(world, world.LAYOUT_DATA.day_civilians(), world.civilian_npcs)
	spawn_group(world, world.LAYOUT_DATA.night_guards(), world.guard_npcs)

	var witness_npc = spawn_from_record(world, world.LAYOUT_DATA.night_witness())
	if witness_npc != null:
		world.civilian_npcs.append(witness_npc)

	world.target_npc = spawn_from_record(world, world.LAYOUT_DATA.night_target())
	spawn_group(world, world.LAYOUT_DATA.night_civilians(), world.civilian_npcs)

static func spawn_group(world, spawn_rows, destination) -> void:
	for spawn_row in spawn_rows:
		var npc = spawn_from_record(world, spawn_row)
		if npc != null:
			destination.append(npc)

static func spawn_from_record(world, spawn_row):
	var required_fields = ["name_text", "role", "key", "phase_tag", "start_pos", "patrol", "speed"]
	for field in required_fields:
		if not spawn_row.has(field):
			push_warning("Skipped spawn row because '%s' is missing: %s" % [field, spawn_row])
			return null

	return spawn_npc(
		world,
		spawn_row["name_text"],
		spawn_row["role"],
		spawn_row["key"],
		spawn_row["phase_tag"],
		spawn_row["start_pos"],
		spawn_row["patrol"],
		spawn_row["speed"]
	)

static func spawn_npc(world, name_text, role, key, phase_tag, start_pos, patrol, speed):
	var npc = CharacterBody3D.new()
	npc.name = name_text.replace(" ", "")
	npc.set_script(world.NPC_SCRIPT)
	npc.position = start_pos

	var collision = CollisionShape3D.new()
	var capsule = CapsuleShape3D.new()
	capsule.radius = 0.32
	capsule.height = 1.64
	collision.shape = capsule
	collision.position = Vector3(0.0, 0.92, 0.0)
	npc.add_child(collision)

	var visuals = Node3D.new()
	visuals.name = "Visuals"
	npc.add_child(visuals)

	var body_mesh = MeshInstance3D.new()
	body_mesh.name = "Body"
	var body = CapsuleMesh.new()
	body.radius = 0.28
	body.height = 1.44
	body_mesh.mesh = body
	body_mesh.position = Vector3(0.0, 0.78, 0.0)
	visuals.add_child(body_mesh)

	var chest_mesh = MeshInstance3D.new()
	chest_mesh.name = "Chest"
	var chest = BoxMesh.new()
	chest.size = Vector3(0.32, 0.44, 0.22)
	chest_mesh.mesh = chest
	chest_mesh.position = Vector3(0.0, 0.88, 0.0)
	visuals.add_child(chest_mesh)

	var head_mesh = MeshInstance3D.new()
	head_mesh.name = "Head"
	var head = SphereMesh.new()
	head.radius = 0.22
	head.height = 0.44
	head_mesh.mesh = head
	head_mesh.position = Vector3(0.0, 1.56, 0.0)
	visuals.add_child(head_mesh)

	var neck_mesh = MeshInstance3D.new()
	neck_mesh.name = "Neck"
	var neck = CapsuleMesh.new()
	neck.radius = 0.08
	neck.height = 0.16
	neck_mesh.mesh = neck
	neck_mesh.position = Vector3(0.0, 1.32, 0.0)
	visuals.add_child(neck_mesh)

	var arm_left = MeshInstance3D.new()
	arm_left.name = "ArmLeft"
	var arm_left_mesh = CapsuleMesh.new()
	arm_left_mesh.radius = 0.1
	arm_left_mesh.height = 0.6
	arm_left.mesh = arm_left_mesh
	arm_left.position = Vector3(-0.24, 0.95, 0.0)
	visuals.add_child(arm_left)

	var arm_right = MeshInstance3D.new()
	arm_right.name = "ArmRight"
	var arm_right_mesh = CapsuleMesh.new()
	arm_right_mesh.radius = 0.1
	arm_right_mesh.height = 0.6
	arm_right.mesh = arm_right_mesh
	arm_right.position = Vector3(0.24, 0.95, 0.0)
	visuals.add_child(arm_right)

	var hand_left = MeshInstance3D.new()
	hand_left.name = "HandLeft"
	var hand_left_mesh = SphereMesh.new()
	hand_left_mesh.radius = 0.085
	hand_left.mesh = hand_left_mesh
	hand_left.position = Vector3(-0.24, 0.48, 0.0)
	visuals.add_child(hand_left)

	var hand_right = MeshInstance3D.new()
	hand_right.name = "HandRight"
	var hand_right_mesh = SphereMesh.new()
	hand_right_mesh.radius = 0.085
	hand_right.mesh = hand_right_mesh
	hand_right.position = Vector3(0.24, 0.48, 0.0)
	visuals.add_child(hand_right)

	var marker = Node3D.new()
	marker.name = "Marker"
	marker.position = Vector3(0.0, 2.3, 0.0)
	npc.add_child(marker)

	var marker_mesh = MeshInstance3D.new()
	marker_mesh.name = "MarkerMesh"
	var diamond = CylinderMesh.new()
	diamond.top_radius = 0.0
	diamond.bottom_radius = 0.2
	diamond.height = 0.36
	marker_mesh.mesh = diamond
	marker_mesh.rotation_degrees = Vector3(180.0, 0.0, 0.0)
	marker.add_child(marker_mesh)

	npc.world_ref = world
	npc.npc_name = name_text
	npc.role = role
	npc.contact_key = key
	npc.active_phase = phase_tag
	npc.patrol_points = patrol
	npc.patrol_speed = speed if speed > 0.0 else 0.0

	if role == "contact":
		npc.rotation_degrees = Vector3(0.0, 190.0, 0.0)
	elif role == "guard":
		npc.detect_radius = 9.9  # 5.5 * 1.8
		npc.detect_fov = 56.0
		npc.detect_rate = 22.0
	elif role == "witness":
		npc.detect_radius = 8.64  # 4.8 * 1.8
		npc.detect_fov = 62.0
		npc.detect_rate = 15.0
	elif role == "target":
		npc.detect_radius = 7.02  # 3.9 * 1.8
		npc.detect_fov = 52.0
		npc.detect_rate = 10.0
	elif role == "civilian":
		npc.set_marker_visible(false)

	world.npc_root.add_child(npc)
	return npc
