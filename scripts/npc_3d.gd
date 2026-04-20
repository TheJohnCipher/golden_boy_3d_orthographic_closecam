extends CharacterBody3D

# Shared NPC controller for:
# - daytime contacts
# - nighttime guards
# - witnesses
# - the target
# - simple civilians
#
# The world script feeds each instance different role data, patrol routes, and
# detection tuning so a single script can drive the whole prototype population.
var world_ref = null
var npc_name = ""
var role = "contact"
var contact_key = ""
var active_phase = "day"

# Patrols are authored as raw world positions in `world_3d.gd`.
var patrol_points = []
var patrol_speed = 2.0

# Detection is only meaningful for guards, witnesses, and the target during the
# night phase, but the fields live here so every NPC shares one script shape.
var detect_radius = 6.0
var detect_fov = 70.0
var detect_rate = 28.0

# Contacts can only be used once. Patrols pause briefly at each point so routes
# feel less robotic.
var interaction_used = false
var vulnerable = false
var pause_timer = 0.0
var current_point = 0

@onready var visuals = $Visuals
@onready var marker = $Marker

func _ready():
    add_to_group("npc")

    # Only NPCs that actually look for the player need the visual cone mesh.
    if role in ["guard", "witness", "target"]:
        _build_vision_cone()
    _add_character_details()
    _apply_role_visuals()
    
    patrol_speed *= randf_range(0.9, 1.1)

func _physics_process(delta):
    # Inactive NPCs are hidden by phase and should do no work.
    if not visible:
        return

    # Contacts stand in place. Guards, witnesses, the target, and civilians can patrol.
    var should_patrol = patrol_points.size() > 1 and role in ["guard", "witness", "target", "civilian"]
    if should_patrol:
        _patrol(delta)
    else:
        velocity.x = move_toward(velocity.x, 0.0, patrol_speed * 8.0 * delta)
        velocity.z = move_toward(velocity.z, 0.0, patrol_speed * 8.0 * delta)
        move_and_slide()

    if world_ref == null:
        return
    if world_ref.phase != "night":
        return
    if world_ref.mission_failed or world_ref.level_complete:
        return

    # Suspicion only grows at night and only from watchers that are meant to care.
    if role in ["guard", "witness", "target"] and can_detect_player(world_ref.player):
        world_ref.raise_suspicion(detect_rate * delta, npc_name)

func _patrol(delta):
    # Small dwell time at each point keeps the pathing readable and prevents
    # instant jitter-turns when the NPC lands exactly on a waypoint.
    if pause_timer > 0.0:
        pause_timer -= delta
        velocity.x = move_toward(velocity.x, 0.0, patrol_speed * 8.0 * delta)
        velocity.z = move_toward(velocity.z, 0.0, patrol_speed * 8.0 * delta)
        move_and_slide()
        return

    var destination = patrol_points[current_point]
    var to_point = destination - global_position
    to_point.y = 0.0
    if to_point.length() < 0.25:
        current_point = (current_point + 1) % patrol_points.size()
        pause_timer = 0.45
        velocity.x = 0.0
        velocity.z = 0.0
        move_and_slide()
        return

    var dir = to_point.normalized()
    velocity.x = dir.x * patrol_speed
    velocity.z = dir.z * patrol_speed
    velocity.y = -0.01
    move_and_slide()

    var look_target = global_position + dir
    look_target.y = global_position.y
    visuals.look_at(look_target, Vector3.UP)
    if marker:
        marker.look_at(look_target, Vector3.UP)

func can_interact(player):
    # Only day contacts use the interaction prompt.
    if not visible:
        return false
    if role != "contact":
        return false
    if interaction_used:
        return false
    return global_position.distance_to(player.global_position) <= 2.8

func is_takedown_reachable(player):
    # The takedown rule is simple on purpose: be close enough and broadly behind
    # the target's current facing direction.
    if role != "target":
        return false
    if not visible:
        return false
    if global_position.distance_to(player.global_position) > 2.7:
        return false
    var forward = -visuals.global_transform.basis.z
    forward.y = 0.0
    forward = forward.normalized()
    var to_player = player.global_position - global_position
    to_player.y = 0.0
    if to_player.length() <= 0.01:
        return false
    var dot = forward.dot(to_player.normalized())
    return dot < 0.1

func can_detect_player(player):
    # Contacts and civilians should never run this path, but the helper stays
    # generic because the world script asks it off role data.
    if not visible:
        return false
    if player == null:
        return false
    var to_player = player.global_position - global_position
    to_player.y = 0.0
    var distance = to_player.length()
    if distance > detect_radius:
        return false

    # Shadows are forgiving but not magic. If the player is extremely close,
    # guards can still notice them even inside a shadow zone.
    if player.is_hidden() and distance > 2.2:
        return false
    if distance <= 0.001:
        return true

    var forward = -visuals.global_transform.basis.z
    forward.y = 0.0
    forward = forward.normalized()
    var angle = rad_to_deg(acos(clamp(forward.dot(to_player.normalized()), -1.0, 1.0)))
    if angle > detect_fov * 0.5:
        return false

    # Final confirmation uses a raycast so walls and props can break detection.
    var query = PhysicsRayQueryParameters3D.create(global_position + Vector3.UP * 1.0, player.global_position + Vector3.UP * 0.8)
    query.exclude = [self]
    query.collide_with_areas = false
    var result = get_viewport().get_world_3d().direct_space_state.intersect_ray(query)
    if result.is_empty():
        return true
    return result.get("collider") == player

func _apply_role_visuals():
    # Enhanced character designs with distinctive silhouettes for each role
    var body = $Visuals/Body
    var chest = $Visuals.get_node_or_null("Chest")
    var head = $Visuals/Head
    var neck = $Visuals.get_node_or_null("Neck")
    var arm_left = $Visuals.get_node_or_null("ArmLeft")
    var arm_right = $Visuals.get_node_or_null("ArmRight")
    var hand_left = $Visuals.get_node_or_null("HandLeft")
    var hand_right = $Visuals.get_node_or_null("HandRight")
    var marker_mesh = $Marker.get_node_or_null("MarkerMesh")
    
    var body_material = StandardMaterial3D.new()
    var chest_material = StandardMaterial3D.new()
    var head_material = StandardMaterial3D.new()
    var neck_material = StandardMaterial3D.new()
    var arm_material = StandardMaterial3D.new()
    var hand_material = StandardMaterial3D.new()
    var marker_material = StandardMaterial3D.new()
    
    marker_material.emission_enabled = true
    marker_material.emission_energy_multiplier = 1.2
    marker_material.albedo_color = Color(1, 1, 1, 0.85)
    marker_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
    marker_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED

    match role:
        "contact":
            body_material.albedo_color = Color("5da7c7")
            chest_material.albedo_color = Color("4a9ab5")
            head_material.albedo_color = Color("d2b296")
            neck_material.albedo_color = Color("d2b296")
            arm_material.albedo_color = Color("5da7c7")
            hand_material.albedo_color = Color("d2b296")
            marker_material.emission = Color("66d8ff")
            # Individual contact styles
            if npc_name == "Mara":
                _add_character_accessory("vest", Color("2a5a7a"), 0.5, 0.2, Vector3(0.0, 0.6, 0.0))
                _add_character_accessory("hat", Color("1a3a6a"), 0.24, 0.18, Vector3(0.0, 1.6, 0.0))
                body_material.albedo_color = Color("4a9ab5")
                arm_material.albedo_color = Color("4a9ab5")
            elif npc_name == "Jules":
                _add_character_accessory("vest", Color("3a5a8a"), 0.48, 0.22, Vector3(0.0, 0.62, 0.0))
                _add_character_accessory("cap", Color("2a4a6a"), 0.26, 0.14, Vector3(0.0, 1.62, 0.0))
                body_material.albedo_color = Color("6ab5d5")
                arm_material.albedo_color = Color("6ab5d5")
            else:  # Nico
                _add_character_accessory("vest", Color("2a6a8a"), 0.52, 0.18, Vector3(0.0, 0.58, 0.0))
                _add_character_accessory("beanie", Color("1a2a4a"), 0.24, 0.2, Vector3(0.0, 1.62, 0.0))
                body_material.albedo_color = Color("5a99c5")
                arm_material.albedo_color = Color("5a99c5")
        "guard":
            body_material.albedo_color = Color("1a1a24")
            chest_material.albedo_color = Color("0a0a14")
            head_material.albedo_color = Color("b99570")
            neck_material.albedo_color = Color("b99570")
            arm_material.albedo_color = Color("1a1a24")
            hand_material.albedo_color = Color("b99570")
            marker_material.emission = Color("ff4f56")
            _add_character_accessory("duty_belt", Color("3a4f5a"), 0.35, 0.12, Vector3(0.0, 0.55, 0.0))
            _add_character_accessory("shoulder_pad_l", Color("4a5a6a"), 0.15, 0.35, Vector3(-0.28, 0.95, 0.0))
            _add_character_accessory("shoulder_pad_r", Color("4a5a6a"), 0.15, 0.35, Vector3(0.28, 0.95, 0.0))
            # Guard variations
            if npc_name.contains("One"):
                _add_character_accessory("helmet", Color("3a3a4a"), 0.26, 0.22, Vector3(0.0, 1.65, 0.0))
        "witness":
            body_material.albedo_color = Color("6a3a4b")
            chest_material.albedo_color = Color("5a2a3b")
            head_material.albedo_color = Color("d5b18b")
            neck_material.albedo_color = Color("d5b18b")
            arm_material.albedo_color = Color("6a3a4b")
            hand_material.albedo_color = Color("d5b18b")
            marker_material.emission = Color("ff9a60")
            _add_character_accessory("jacket", Color("5a3a4b"), 0.38, 0.25, Vector3(0.0, 0.72, 0.0))
            _add_character_accessory("backpack", Color("3a2a3b"), 0.2, 0.28, Vector3(0.0, 0.8, -0.15))
        "target":
            body_material.albedo_color = Color("d8cfc0")
            chest_material.albedo_color = Color("1a1a2a")
            head_material.albedo_color = Color("c7a98a")
            neck_material.albedo_color = Color("c7a98a")
            arm_material.albedo_color = Color("d8cfc0")
            hand_material.albedo_color = Color("c7a98a")
            marker_material.emission = Color("fff0a6")
            _add_character_accessory("formal_jacket", Color("1a1a2a"), 0.36, 0.32, Vector3(0.0, 0.68, 0.0))
            _add_character_accessory("tie", Color("8a3a2a"), 0.06, 0.25, Vector3(0.0, 1.15, 0.08))
        "civilian":
            body_material.albedo_color = Color("6a7a8a")
            chest_material.albedo_color = Color("5a6a7a")
            head_material.albedo_color = Color("c4a385")
            neck_material.albedo_color = Color("c4a385")
            arm_material.albedo_color = Color("6a7a8a")
            hand_material.albedo_color = Color("c4a385")
            marker_material.emission = Color("7f8da5")
            # Vary civilian appearances
            if npc_name.contains("A"):
                _add_character_accessory("casual_jacket", Color("4a5a6a"), 0.32, 0.22, Vector3(0.0, 0.75, 0.0))
                _add_character_accessory("messenger_bag", Color("5a5a5a"), 0.18, 0.24, Vector3(0.2, 0.7, -0.12))
            elif npc_name.contains("B"):
                _add_character_accessory("light_coat", Color("7a8a9a"), 0.34, 0.28, Vector3(0.0, 0.72, 0.0))
                _add_character_accessory("hat_b", Color("3a4a5a"), 0.22, 0.16, Vector3(0.0, 1.58, 0.0))
            else:
                _add_character_accessory("sporty_jacket", Color("6a5a4a"), 0.32, 0.24, Vector3(0.0, 0.74, 0.0))
        _:
            body_material.albedo_color = Color("80757a")
            chest_material.albedo_color = Color("70656a")
            head_material.albedo_color = Color("c4a385")
            neck_material.albedo_color = Color("c4a385")
            arm_material.albedo_color = Color("80757a")
            hand_material.albedo_color = Color("c4a385")
            marker_material.emission = Color("7f8da5")

    body.material_override = body_material
    if chest:
        chest.material_override = chest_material
    head.material_override = head_material
    if neck:
        neck.material_override = neck_material
    if arm_left:
        arm_left.material_override = arm_material
    if arm_right:
        arm_right.material_override = arm_material
    if hand_left:
        hand_left.material_override = hand_material
    if hand_right:
        hand_right.material_override = hand_material
    marker_mesh.material_override = marker_material
    marker.visible = role in ["contact", "target"]

func _add_character_accessory(name_str, color, width, height, offset):
    # Add distinctive silhouette details to each character type
    var accessory = MeshInstance3D.new()
    accessory.name = name_str
    var box = BoxMesh.new()
    box.size = Vector3(width, height, 0.15)
    accessory.mesh = box
    var mat = StandardMaterial3D.new()
    mat.albedo_color = color
    accessory.material_override = mat
    accessory.position = offset
    $Visuals.add_child(accessory)

func _add_character_details():
    # Add facial features and body details for more personality
    var head = $Visuals/Head
    if head == null:
        return
    
    # Eyes
    var eye_left = MeshInstance3D.new()
    eye_left.name = "EyeLeft"
    var eye_sphere = SphereMesh.new()
    eye_sphere.radius = 0.04
    eye_left.mesh = eye_sphere
    var eye_mat = StandardMaterial3D.new()
    eye_mat.albedo_color = Color("1a1a1a")
    eye_left.material_override = eye_mat
    eye_left.position = Vector3(-0.06, 1.52, 0.16)
    $Visuals.add_child(eye_left)
    
    var eye_right = MeshInstance3D.new()
    eye_right.name = "EyeRight"
    eye_right.mesh = eye_sphere
    eye_right.material_override = eye_mat
    eye_right.position = Vector3(0.06, 1.52, 0.16)
    $Visuals.add_child(eye_right)
    
    # Hands (simple detail)
    var hand_left = MeshInstance3D.new()
    hand_left.name = "HandLeft"
    var hand_mesh = SphereMesh.new()
    hand_mesh.radius = 0.08
    hand_left.mesh = hand_mesh
    var hand_mat = StandardMaterial3D.new()
    hand_mat.albedo_color = Color("c9a589")
    hand_left.material_override = hand_mat
    hand_left.position = Vector3(-0.38, 0.42, 0.0)
    $Visuals.add_child(hand_left)
    
    var hand_right = MeshInstance3D.new()
    hand_right.name = "HandRight"
    hand_right.mesh = hand_mesh
    hand_right.material_override = hand_mat
    hand_right.position = Vector3(0.38, 0.42, 0.0)
    $Visuals.add_child(hand_right)

func set_marker_visible(value):
    if marker:
        marker.visible = value

func _build_vision_cone():
    # The cone is a flat fan mesh sitting slightly above the floor. It is only a
    # debug/readability aid; actual detection comes from `can_detect_player`.
    var cone_root = Node3D.new()
    cone_root.name = "VisionCone"
    cone_root.position = Vector3(0.0, 0.03, 0.0)
    add_child(cone_root)

    var mesh_instance = MeshInstance3D.new()
    mesh_instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
    var mesh = ArrayMesh.new()
    var vertices = PackedVector3Array()
    var colors = PackedColorArray()
    var indices = PackedInt32Array()
    vertices.append(Vector3.ZERO)
    colors.append(Color(1, 1, 1, 0.0))

    # More steps means a smoother fan shape. This is still intentionally light.
    var steps = 16
    var half_angle = deg_to_rad(detect_fov * 0.5)
    for i in range(steps + 1):
        var t = float(i) / float(steps)
        var angle = lerp(-half_angle, half_angle, t)
        var x = sin(angle) * detect_radius
        var z = -cos(angle) * detect_radius
        vertices.append(Vector3(x, 0.0, z))
        colors.append(Color(1, 1, 1, 0.17))
    for i in range(1, steps + 1):
        indices.append(0)
        indices.append(i)
        indices.append(i + 1)
    var arrays = []
    arrays.resize(Mesh.ARRAY_MAX)
    arrays[Mesh.ARRAY_VERTEX] = vertices
    arrays[Mesh.ARRAY_COLOR] = colors
    arrays[Mesh.ARRAY_INDEX] = indices
    mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
    mesh_instance.mesh = mesh
    var material = StandardMaterial3D.new()
    material.vertex_color_use_as_albedo = true
    material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
    material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
    material.cull_mode = BaseMaterial3D.CULL_DISABLED
    material.albedo_color = Color(1, 1, 1, 0.18)
    mesh.surface_set_material(0, material)
    cone_root.add_child(mesh_instance)

    match role:
        "guard":
            material.albedo_color = Color(1.0, 0.35, 0.35, 0.16)
        "witness":
            material.albedo_color = Color(1.0, 0.7, 0.3, 0.14)
        "target":
            material.albedo_color = Color(1.0, 0.9, 0.5, 0.10)
