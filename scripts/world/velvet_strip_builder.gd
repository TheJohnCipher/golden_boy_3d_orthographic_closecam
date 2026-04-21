extends Node

# Builds the Velvet Strip district: one walkable stealth block of luxury
# nightlife facades, an interior cocktail lounge hub, a parallel Service Grid
# corridor behind the facades, a rooftop catwalk, and wet-street dressing.
#
# Coordinate system:
#   X = east/west, Z = south/north, Y = up.
#   Street runs east-west at Z ~ -18..-6 (player spawns on the south sidewalk).
#   Facade front line sits at Z = -6.
#   Ground-floor interiors occupy Z = -6..+6.
#   Service Grid corridor runs behind the facades at Z = +6..+14.
#   Back wall of district at Z = +14.
#   Facades span X = -24..+18 (parking ramp, hotel crown, lounge, boutique).

const FACADE_FRONT_Z := -6.0
const INTERIOR_BACK_Z := 6.0
const SERVICE_CORRIDOR_DEPTH := 8.0  # Z +6..+14
const SERVICE_BACK_Z := 14.0

# District block X extents for each facade.
const PARKING_X := Vector2(-24.0, -16.0)
const HOTEL_CROWN_X := Vector2(-16.0, -4.0)
const CROWN_LOUNGE_X := Vector2(-4.0, 6.0)
const BOUTIQUE_X := Vector2(6.0, 14.0)
const NEON_BANK_X := Vector2(14.0, 20.0)

static func build(world: Node3D) -> void:
	world.night_start_position = Vector3(-18.0, 0.0, -14.0)

	var mats = world.get_pbr_materials() if "get_pbr_materials" in world else null
	_build_support_floor(world)
	_build_street(world, mats)
	_build_south_sidewalk(world, mats)
	_build_parking_ramp(world, mats)
	_build_hotel_crown(world, mats)
	_build_crown_lounge(world, mats)
	_build_boutique_hotel(world, mats)
	_build_neon_bank(world, mats)
	_build_service_grid(world, mats)
	_build_rooftop_path(world, mats)
	_build_street_dressing(world, mats)
	_build_district_perimeter(world, mats)
	_build_signage(world, mats)
	_spawn_atmospherics(world, mats)
	_build_extraction(world, mats)
	_build_shadow_zones(world)

# ------------------------------------------------------------------------
# Primitives
# ------------------------------------------------------------------------

static func _block(world, name, pos: Vector3, size: Vector3, material: Material, with_collision: bool = true, parent: Node3D = null) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.name = name
	body.position = pos
	var host = parent if parent != null else world.geometry_root
	host.add_child(body)
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	mi.mesh = bm
	mi.material_override = material
	body.add_child(mi)
	if with_collision:
		var cs := CollisionShape3D.new()
		var shp := BoxShape3D.new()
		shp.size = size
		cs.shape = shp
		body.add_child(cs)
	body.set_meta("authored_size", size)
	body.set_meta("build_mode", "static_block")
	return body

static func _mesh(world, name, pos: Vector3, size: Vector3, material: Material, parent: Node3D = null) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.name = name
	var bm := BoxMesh.new()
	bm.size = size
	mi.mesh = bm
	mi.material_override = material
	mi.position = pos
	var host = parent if parent != null else world.geometry_root
	host.add_child(mi)
	return mi

static func _cylinder(world, name, pos: Vector3, radius: float, height: float, material: Material, parent: Node3D = null, emissive_light: bool = false) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.name = name
	var cm := CylinderMesh.new()
	cm.top_radius = radius
	cm.bottom_radius = radius
	cm.height = height
	mi.mesh = cm
	mi.material_override = material
	mi.position = pos
	var host = parent if parent != null else world.geometry_root
	host.add_child(mi)
	return mi

static func _collider_only(world, name, pos: Vector3, size: Vector3) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.name = name
	body.position = pos
	world.geometry_root.add_child(body)
	var cs := CollisionShape3D.new()
	var shp := BoxShape3D.new()
	shp.size = size
	cs.shape = shp
	body.add_child(cs)
	return body

# ------------------------------------------------------------------------
# Ground and street
# ------------------------------------------------------------------------

static func _build_support_floor(world) -> void:
	# Hidden safety floor beneath the visible slabs.
	_collider_only(world, "DistrictSupportFloor", Vector3(-2.0, -0.2, 0.0), Vector3(70.0, 0.3, 60.0))

static func _build_street(world, mats) -> void:
	var street = _block(world, "VelvetStripAvenue", Vector3(-2.0, -0.05, -12.0), Vector3(64.0, 0.1, 14.0), mats.get_material("wet_asphalt"))
	street.set_meta("intent_note", "Wet asphalt avenue running the full south face of the Velvet Strip.")

	# Road markings (bright centerline + crosswalk).
	var mark_mat := StandardMaterial3D.new()
	mark_mat.albedo_color = Color("e4e0cc")
	mark_mat.roughness = 0.55
	mark_mat.metallic = 0.0
	for i in range(6):
		var z_pos = -10.8 + i * 1.6
		_mesh(world, "VSLaneDash%d" % i, Vector3(-2.0, 0.0051, z_pos), Vector3(0.25, 0.005, 1.0), mark_mat)

	# Crosswalk in front of the lounge entry (just south of the sidewalk).
	for i in range(7):
		var x_pos = -1.0 + i * 0.7
		_mesh(world, "VSCrosswalk%d" % i, Vector3(x_pos, 0.0052, -11.3), Vector3(0.45, 0.005, 2.6), mark_mat)

	# Puddle decals scattered for wet reflections.
	var puddle_positions = [
		Vector3(-14.0, 0.005, -12.0),
		Vector3(-6.0, 0.005, -15.0),
		Vector3(3.0, 0.005, -13.0),
		Vector3(10.5, 0.005, -11.0),
		Vector3(-18.0, 0.005, -14.5),
		Vector3(16.0, 0.005, -16.0),
	]
	for i in range(puddle_positions.size()):
		var puddle := MeshInstance3D.new()
		puddle.name = "VSPuddle%d" % i
		var plane := PlaneMesh.new()
		plane.size = Vector2(randf_range(1.8, 3.4), randf_range(1.3, 2.6))
		puddle.mesh = plane
		puddle.material_override = mats.get_material("puddle")
		puddle.position = puddle_positions[i]
		puddle.rotation_degrees = Vector3(0.0, randf_range(0.0, 90.0), 0.0)
		world.geometry_root.add_child(puddle)

static func _build_south_sidewalk(world, mats) -> void:
	var sidewalk = _block(world, "VSSouthSidewalk", Vector3(-2.0, 0.05, -7.75), Vector3(64.0, 0.18, 3.5), mats.get_material("aged_concrete"))
	sidewalk.set_meta("intent_note", "Sidewalk between the street and facade entries — 3.5 m wide for a proper strip boulevard.")
	# Curb at the street edge (south end of the sidewalk slab).
	_mesh(world, "VSSouthCurb", Vector3(-2.0, 0.125, -9.55), Vector3(64.0, 0.15, 0.12), mats.get_material("aged_concrete"))

static func _build_district_perimeter(world, mats) -> void:
	# Hard bounds for the first playable block so the player cannot drift onto the
	# hidden support floor around the district.
	var x_min = -24.8
	var x_max = 20.8
	var z_south = -19.7
	var z_north = 14.3
	var wall_h = 2.8
	var wall_t = 0.6
	var span_x = x_max - x_min
	var span_z = z_north - z_south
	var wall_mat = mats.get_material("painted_brick_cool")
	var cap_mat = mats.get_material("dark_marble")

	_block(world, "VSDistrictSouthWall", Vector3((x_min + x_max) * 0.5, wall_h * 0.5, z_south), Vector3(span_x, wall_h, wall_t), wall_mat)
	_block(world, "VSDistrictNorthWall", Vector3((x_min + x_max) * 0.5, wall_h * 0.5, z_north), Vector3(span_x, wall_h, wall_t), wall_mat)
	_block(world, "VSDistrictWestWall", Vector3(x_min, wall_h * 0.5, (z_south + z_north) * 0.5), Vector3(wall_t, wall_h, span_z), wall_mat)
	_block(world, "VSDistrictEastWall", Vector3(x_max, wall_h * 0.5, (z_south + z_north) * 0.5), Vector3(wall_t, wall_h, span_z), wall_mat)

	# Thin caps help the border read as intentional world geometry instead of
	# plain invisible blockers.
	_mesh(world, "VSDistrictSouthCap", Vector3((x_min + x_max) * 0.5, wall_h + 0.08, z_south), Vector3(span_x, 0.16, wall_t + 0.1), cap_mat)
	_mesh(world, "VSDistrictNorthCap", Vector3((x_min + x_max) * 0.5, wall_h + 0.08, z_north), Vector3(span_x, 0.16, wall_t + 0.1), cap_mat)
	_mesh(world, "VSDistrictWestCap", Vector3(x_min, wall_h + 0.08, (z_south + z_north) * 0.5), Vector3(wall_t + 0.1, 0.16, span_z), cap_mat)
	_mesh(world, "VSDistrictEastCap", Vector3(x_max, wall_h + 0.08, (z_south + z_north) * 0.5), Vector3(wall_t + 0.1, 0.16, span_z), cap_mat)

# ------------------------------------------------------------------------
# Facade helpers: composed geometry, not single boxes.
# ------------------------------------------------------------------------

static func _facade_wall(world, name_prefix: String, x_min: float, x_max: float, z: float, y0: float, y1: float, material: Material, parent: Node3D = null) -> void:
	var width = x_max - x_min
	var height = y1 - y0
	_block(world, name_prefix, Vector3((x_min + x_max) * 0.5, y0 + height * 0.5, z), Vector3(width, height, 0.4), material, true, parent)

static func _window_bay(world, name: String, cx: float, cy: float, z: float, window_w: float, window_h: float, frame: Material, glass: Material, parent: Node3D = null) -> void:
	# Frame (slim outer ring, built as 4 thin boxes) + recessed glass pane.
	var frame_thickness = 0.08
	var outer_w = window_w + frame_thickness * 2.0
	var outer_h = window_h + frame_thickness * 2.0
	var z_out = z + 0.02  # just proud of the facade plane
	# Top/bottom frame
	_mesh(world, "%sFrameTop" % name, Vector3(cx, cy + window_h * 0.5 + frame_thickness * 0.5, z_out), Vector3(outer_w, frame_thickness, 0.12), frame, parent)
	_mesh(world, "%sFrameBot" % name, Vector3(cx, cy - window_h * 0.5 - frame_thickness * 0.5, z_out), Vector3(outer_w, frame_thickness, 0.12), frame, parent)
	# Left/right frame
	_mesh(world, "%sFrameL" % name, Vector3(cx - window_w * 0.5 - frame_thickness * 0.5, cy, z_out), Vector3(frame_thickness, window_h, 0.12), frame, parent)
	_mesh(world, "%sFrameR" % name, Vector3(cx + window_w * 0.5 + frame_thickness * 0.5, cy, z_out), Vector3(frame_thickness, window_h, 0.12), frame, parent)
	# Center mullion (vertical divider)
	_mesh(world, "%sMullion" % name, Vector3(cx, cy, z_out), Vector3(0.03, window_h, 0.14), frame, parent)
	# Glass pane (two panels either side of mullion)
	var half = window_w * 0.5 - 0.02
	_mesh(world, "%sGlassL" % name, Vector3(cx - window_w * 0.25, cy, z_out + 0.005), Vector3(half, window_h - 0.02, 0.02), glass, parent)
	_mesh(world, "%sGlassR" % name, Vector3(cx + window_w * 0.25, cy, z_out + 0.005), Vector3(half, window_h - 0.02, 0.02), glass, parent)

static func _cornice_band(world, name, x_min, x_max, z, y, thickness, depth, material: Material, parent: Node3D = null) -> void:
	_mesh(world, name, Vector3((x_min + x_max) * 0.5, y, z + 0.1), Vector3(x_max - x_min, thickness, depth), material, parent)

# ------------------------------------------------------------------------
# Parking ramp (1 story, open frontage)
# ------------------------------------------------------------------------

static func _build_parking_ramp(world, mats) -> void:
	var x_min = PARKING_X.x
	var x_max = PARKING_X.y
	var z = FACADE_FRONT_Z
	var height = 4.0

	# Side walls (west side of the ramp — the open end is to the north-east).
	_facade_wall(world, "VSParkingWestWall", x_min - 0.2, x_min, FACADE_FRONT_Z - 0.2, 0.0, height + 0.4, mats.get_material("aged_concrete"))
	# Ceiling slab
	_mesh(world, "VSParkingCeiling", Vector3((x_min + x_max) * 0.5, height, 0.0), Vector3(x_max - x_min, 0.25, 12.0), mats.get_material("aged_concrete"))
	# Support pillars
	for i in range(3):
		var cx = x_min + 1.5 + i * 2.2
		for zr in [-4.0, 0.0, 4.0]:
			_block(world, "VSParkingPillar_%d_%d" % [i, int(zr)], Vector3(cx, height * 0.5, zr), Vector3(0.5, height, 0.5), mats.get_material("aged_concrete"))
	# Back wall
	_facade_wall(world, "VSParkingBack", x_min, x_max, SERVICE_BACK_Z, 0.0, height, mats.get_material("aged_concrete"))
	# Floor
	_mesh(world, "VSParkingFloor", Vector3((x_min + x_max) * 0.5, 0.015, 3.5), Vector3(x_max - x_min, 0.03, 16.0), mats.get_material("aged_concrete"))

	# Painted parking stripes
	var stripe_mat := StandardMaterial3D.new()
	stripe_mat.albedo_color = Color("d5c06a")
	stripe_mat.roughness = 0.7
	for i in range(4):
		_mesh(world, "VSParkingStripe%d" % i, Vector3(x_min + 1.0 + i * 1.6, 0.03, 2.0), Vector3(0.08, 0.01, 4.0), stripe_mat)

	# Entry sign
	_mesh(world, "VSParkingSign", Vector3((x_min + x_max) * 0.5, height + 0.4, FACADE_FRONT_Z + 0.1), Vector3(2.6, 0.6, 0.08), mats.get_material("neon_amber"))

# ------------------------------------------------------------------------
# Hotel Crown (5-story marble hotel, main luxury anchor on the west)
# ------------------------------------------------------------------------

static func _build_hotel_crown(world, mats) -> void:
	var x_min = HOTEL_CROWN_X.x
	var x_max = HOTEL_CROWN_X.y
	var floors = 5
	var floor_h = 3.2
	var total_h = floors * floor_h

	# Base plinth in dark marble
	_mesh(world, "VSHotelCrownPlinth", Vector3((x_min + x_max) * 0.5, 0.25, FACADE_FRONT_Z + 0.2), Vector3(x_max - x_min + 0.4, 0.5, 0.6), mats.get_material("dark_marble"))

	# Ground floor facade with a wide entry recess
	var entry_cx = (x_min + x_max) * 0.5
	var entry_w = 3.0
	var entry_h = 2.8
	# Wall segments flanking the entry
	_facade_wall(world, "VSHotelCrownWallGroundL", x_min, entry_cx - entry_w * 0.5, FACADE_FRONT_Z, 0.5, floor_h, mats.get_material("marble_wall"))
	_facade_wall(world, "VSHotelCrownWallGroundR", entry_cx + entry_w * 0.5, x_max, FACADE_FRONT_Z, 0.5, floor_h, mats.get_material("marble_wall"))
	# Ground-floor tall windows in each flanking panel
	_window_bay(world, "VSHotelCrownGroundWinL", (x_min + entry_cx - entry_w * 0.5) * 0.5, 1.8, FACADE_FRONT_Z - 0.01, 2.6, 2.2, mats.get_material("brushed_gold"), mats.get_material("tinted_glass"))
	_window_bay(world, "VSHotelCrownGroundWinR", (entry_cx + entry_w * 0.5 + x_max) * 0.5, 1.8, FACADE_FRONT_Z - 0.01, 2.6, 2.2, mats.get_material("brushed_gold"), mats.get_material("tinted_glass"))

	# Entry recess (inside face is set back 0.8m into the facade)
	var recess_z = FACADE_FRONT_Z + 0.8
	# Lintel above the entry
	_mesh(world, "VSHotelCrownEntryLintel", Vector3(entry_cx, entry_h + 0.25, FACADE_FRONT_Z - 0.05), Vector3(entry_w + 0.6, 0.5, 0.6), mats.get_material("brushed_gold"))
	# Entry side walls of the recess
	_mesh(world, "VSHotelCrownEntryRecessFloor", Vector3(entry_cx, 0.03, FACADE_FRONT_Z + 0.4), Vector3(entry_w, 0.05, 0.8), mats.get_material("marble_floor"))
	_mesh(world, "VSHotelCrownEntryBackWall", Vector3(entry_cx, entry_h * 0.5, recess_z), Vector3(entry_w, entry_h, 0.2), mats.get_material("dark_marble"))
	# Revolving-door style cylinder as a visual accent (non-functional, purely decorative)
	_cylinder(world, "VSHotelCrownRevolvingDoor", Vector3(entry_cx, entry_h * 0.5, recess_z - 0.3), 0.9, entry_h - 0.1, mats.get_material("tinted_glass"))
	# Gold trim above entry
	_mesh(world, "VSHotelCrownEntryGoldTrim", Vector3(entry_cx, entry_h + 0.6, FACADE_FRONT_Z - 0.1), Vector3(entry_w * 1.15, 0.1, 0.08), mats.get_material("polished_gold"))

	# Canopy over the entry
	_mesh(world, "VSHotelCrownCanopy", Vector3(entry_cx, entry_h + 0.9, FACADE_FRONT_Z - 1.2), Vector3(entry_w + 1.8, 0.15, 2.6), mats.get_material("black_lacquer"))
	# Canopy hanging rod
	_mesh(world, "VSHotelCrownCanopyRod", Vector3(entry_cx, entry_h + 0.95, FACADE_FRONT_Z - 0.1), Vector3(0.05, 0.5, 0.05), mats.get_material("polished_gold"))

	# Upper floors: 4 floors with window bays.
	for f in range(1, floors):
		var cy = floor_h * f + floor_h * 0.5
		_facade_wall(world, "VSHotelCrownFacadeF%d" % f, x_min, x_max, FACADE_FRONT_Z, floor_h * f, floor_h * (f + 1), mats.get_material("marble_wall"))
		# Belt course between floors
		_cornice_band(world, "VSHotelCrownBeltF%d" % f, x_min - 0.15, x_max + 0.15, FACADE_FRONT_Z, floor_h * f + 0.05, 0.12, 0.25, mats.get_material("dark_marble"))
		# Window bays across the facade (3 per floor)
		var bay_count = 3
		for b in range(bay_count):
			var bx = x_min + (x_max - x_min) * (b + 1) / float(bay_count + 1)
			_window_bay(world, "VSHotelCrownF%dWin%d" % [f, b], bx, cy, FACADE_FRONT_Z - 0.01, 1.8, 2.0, mats.get_material("brushed_gold"), mats.get_material("tinted_glass"))

	# Roof parapet + cap
	_cornice_band(world, "VSHotelCrownCornice", x_min - 0.2, x_max + 0.2, FACADE_FRONT_Z, total_h - 0.1, 0.35, 0.6, mats.get_material("dark_marble"))
	_mesh(world, "VSHotelCrownParapet", Vector3((x_min + x_max) * 0.5, total_h + 0.25, FACADE_FRONT_Z + 0.05), Vector3(x_max - x_min + 0.4, 0.5, 0.3), mats.get_material("dark_marble"))
	# Roof slab (so catwalks have a surface)
	_block(world, "VSHotelCrownRoof", Vector3((x_min + x_max) * 0.5, total_h + 0.05, 0.0), Vector3(x_max - x_min, 0.3, 12.0), mats.get_material("aged_concrete"))
	# Side walls (solid from ground to roof, so catwalk can attach)
	_block(world, "VSHotelCrownSideW", Vector3(x_min - 0.15, total_h * 0.5, 0.0), Vector3(0.3, total_h, INTERIOR_BACK_Z - FACADE_FRONT_Z), mats.get_material("marble_wall"))
	_block(world, "VSHotelCrownSideE", Vector3(x_max + 0.15, total_h * 0.5, 0.0), Vector3(0.3, total_h, INTERIOR_BACK_Z - FACADE_FRONT_Z), mats.get_material("marble_wall"))
	# Back wall (toward service grid)
	_facade_wall(world, "VSHotelCrownBackWall", x_min, x_max, INTERIOR_BACK_Z, 0.0, total_h, mats.get_material("painted_brick_cool"))

	# Gold hotel name band
	_mesh(world, "VSHotelCrownSignBacking", Vector3(entry_cx, floor_h - 0.15, FACADE_FRONT_Z - 0.12), Vector3(entry_w + 3.0, 0.55, 0.04), mats.get_material("black_lacquer"))
	_mesh(world, "VSHotelCrownSignGlow", Vector3(entry_cx, floor_h - 0.15, FACADE_FRONT_Z - 0.16), Vector3(entry_w + 2.6, 0.35, 0.04), mats.get_material("neon_amber"))

	# Downlight over entry (SpotLight)
	var down := SpotLight3D.new()
	down.name = "VSHotelCrownEntryDownlight"
	down.position = Vector3(entry_cx, entry_h + 0.85, FACADE_FRONT_Z - 1.1)
	down.rotation_degrees = Vector3(-90.0, 0.0, 0.0)
	down.light_color = Color("ffd39a")
	down.light_energy = 6.0
	down.spot_range = 6.0
	down.spot_angle = 42.0
	down.spot_angle_attenuation = 0.6
	down.shadow_enabled = false
	world.add_child(down)
	world.point_lights.append(down)
	_build_hotel_crown_lobby(world, mats, x_min, x_max)

# ------------------------------------------------------------------------
# Hotel Crown lobby interior
# ------------------------------------------------------------------------

static func _build_hotel_crown_lobby(world, mats, x_min: float, x_max: float) -> void:
	var cx = (x_min + x_max) * 0.5
	var floor_h = 3.2

	# Lobby floor — polished marble
	_block(world, "VSHotelLobbyFloor", Vector3(cx, 0.03, 0.0), Vector3(x_max - x_min - 0.4, 0.06, INTERIOR_BACK_Z - FACADE_FRONT_Z - 0.2), mats.get_material("marble_floor"))

	# Reception desk — centered, set back from the revolving door
	_block(world, "VSHotelReceptionDesk", Vector3(cx, 0.55, 1.8), Vector3(4.0, 1.1, 0.8), mats.get_material("dark_marble"))
	_mesh(world, "VSHotelReceptionTop", Vector3(cx, 1.12, 1.8), Vector3(4.2, 0.06, 0.9), mats.get_material("marble_floor"))
	_mesh(world, "VSHotelReceptionFront", Vector3(cx, 0.55, 1.38), Vector3(4.0, 1.1, 0.08), mats.get_material("brushed_gold"))
	_mesh(world, "VSHotelReceptionGoldLine", Vector3(cx, 1.07, 1.34), Vector3(4.2, 0.04, 0.04), mats.get_material("polished_gold"))

	# Lobby chairs flanking the entry corridor
	for i in range(2):
		var side = 1 - i * 2
		var chair_x = cx + side * 3.5
		_block(world, "VSHotelLobbyChairSeat%d" % i, Vector3(chair_x, 0.25, -3.2), Vector3(0.8, 0.5, 0.8), mats.get_material("velvet_red"))
		_mesh(world, "VSHotelLobbyChairBack%d" % i, Vector3(chair_x, 0.75, -2.85), Vector3(0.8, 0.6, 0.12), mats.get_material("velvet_red"))
		_mesh(world, "VSHotelLobbyChairLegs%d" % i, Vector3(chair_x, 0.07, -3.2), Vector3(0.7, 0.14, 0.7), mats.get_material("polished_gold"))

	# Lobby columns flanking the main axis
	for i in range(2):
		var side = 1 - i * 2
		for row in range(2):
			var col_x = cx + side * 4.0
			var col_z = -2.0 + row * 4.0
			_block(world, "VSHotelLobbyCol%d_%d" % [i, row], Vector3(col_x, floor_h * 0.5, col_z), Vector3(0.4, floor_h, 0.4), mats.get_material("marble_wall"))
			_mesh(world, "VSHotelLobbyColCap%d_%d" % [i, row], Vector3(col_x, floor_h - 0.08, col_z), Vector3(0.55, 0.2, 0.55), mats.get_material("brushed_gold"))

	# Feature wall behind reception — back-lit dark marble panel
	_mesh(world, "VSHotelLobbyFeatureWall", Vector3(cx, floor_h * 0.5, INTERIOR_BACK_Z - 0.08), Vector3(x_max - x_min - 0.6, floor_h - 0.2, 0.1), mats.get_material("dark_marble"))
	_mesh(world, "VSHotelLobbyFeatureGlow", Vector3(cx, floor_h * 0.5, INTERIOR_BACK_Z - 0.15), Vector3(x_max - x_min - 2.0, floor_h - 0.8, 0.04), mats.get_material("neon_amber"))

	# Chandelier — central disc with drop arms and bulbs
	_cylinder(world, "VSHotelChandelierDisc", Vector3(cx, floor_h - 0.18, 0.0), 0.35, 0.1, mats.get_material("polished_gold"))
	for r in range(8):
		var ang = r * PI * 2.0 / 8.0
		var dx = cx + cos(ang) * 0.55
		var dz = sin(ang) * 0.55
		_cylinder(world, "VSHotelChandelierArm%d" % r, Vector3(dx, floor_h - 0.52, dz), 0.025, 0.42, mats.get_material("polished_gold"))
		_cylinder(world, "VSHotelChandelierBulb%d" % r, Vector3(dx, floor_h - 0.78, dz), 0.05, 0.09, mats.get_material("lamp_bulb"))

	var chan_light := OmniLight3D.new()
	chan_light.name = "VSHotelChandelierLight"
	chan_light.position = Vector3(cx, floor_h - 0.5, 0.0)
	chan_light.light_color = Color("fff5d0")
	chan_light.light_energy = 7.0
	chan_light.omni_range = 14.0
	chan_light.shadow_enabled = false
	world.add_child(chan_light)
	world.point_lights.append(chan_light)

	var desk_light := OmniLight3D.new()
	desk_light.name = "VSHotelDeskLight"
	desk_light.position = Vector3(cx, 2.2, 1.8)
	desk_light.light_color = Color("ffd39a")
	desk_light.light_energy = 3.5
	desk_light.omni_range = 7.0
	desk_light.shadow_enabled = false
	world.add_child(desk_light)
	world.point_lights.append(desk_light)

static func _build_crown_lounge(world, mats) -> void:
	# The signature interior hub: a black + gold cocktail lounge.
	# Exterior facade (south), with entry doors, large lounge glass, then full interior,
	# then a back-of-house door leading into the Service Grid.
	var x_min = CROWN_LOUNGE_X.x
	var x_max = CROWN_LOUNGE_X.y
	var floor_h = 3.4
	var stories = 2
	var total_h = floor_h * stories

	# Base plinth
	_mesh(world, "VSCrownLoungePlinth", Vector3((x_min + x_max) * 0.5, 0.18, FACADE_FRONT_Z + 0.15), Vector3(x_max - x_min + 0.4, 0.36, 0.5), mats.get_material("dark_marble"))

	# Ground facade: center entry, glass walls either side.
	var entry_cx = (x_min + x_max) * 0.5
	var entry_w = 2.4
	var entry_h = 2.6

	# Facade wall frames around the big glass bays
	_facade_wall(world, "VSCrownLoungeFacadeL", x_min, x_min + 0.4, FACADE_FRONT_Z, 0.0, total_h, mats.get_material("dark_marble"))
	_facade_wall(world, "VSCrownLoungeFacadeR", x_max - 0.4, x_max, FACADE_FRONT_Z, 0.0, total_h, mats.get_material("dark_marble"))

	# Top of ground floor — horizontal black band
	_mesh(world, "VSCrownLoungeGroundTopBand", Vector3(entry_cx, floor_h - 0.15, FACADE_FRONT_Z - 0.05), Vector3(x_max - x_min, 0.3, 0.2), mats.get_material("black_lacquer"))

	# Left and right big glass panels
	var glass_w_side = (entry_cx - entry_w * 0.5) - (x_min + 0.4)
	_mesh(world, "VSCrownLoungeBigGlassL", Vector3((x_min + 0.4 + entry_cx - entry_w * 0.5) * 0.5, floor_h * 0.5 + 0.1, FACADE_FRONT_Z - 0.02), Vector3(glass_w_side, floor_h - 0.4, 0.08), mats.get_material("tinted_glass"))
	_mesh(world, "VSCrownLoungeBigGlassR", Vector3((entry_cx + entry_w * 0.5 + x_max - 0.4) * 0.5, floor_h * 0.5 + 0.1, FACADE_FRONT_Z - 0.02), Vector3(glass_w_side, floor_h - 0.4, 0.08), mats.get_material("tinted_glass"))
	# Gold mullions
	for i in range(3):
		var f = (i + 1) / 4.0
		var lx = lerp(x_min + 0.4, entry_cx - entry_w * 0.5, f)
		var rx = lerp(entry_cx + entry_w * 0.5, x_max - 0.4, f)
		_mesh(world, "VSCrownLoungeMullionL%d" % i, Vector3(lx, floor_h * 0.5 + 0.1, FACADE_FRONT_Z - 0.04), Vector3(0.05, floor_h - 0.5, 0.12), mats.get_material("polished_gold"))
		_mesh(world, "VSCrownLoungeMullionR%d" % i, Vector3(rx, floor_h * 0.5 + 0.1, FACADE_FRONT_Z - 0.04), Vector3(0.05, floor_h - 0.5, 0.12), mats.get_material("polished_gold"))

	# Entry double doors
	_mesh(world, "VSCrownLoungeDoorL", Vector3(entry_cx - 0.55, entry_h * 0.5, FACADE_FRONT_Z - 0.03), Vector3(1.0, entry_h, 0.08), mats.get_material("black_lacquer"))
	_mesh(world, "VSCrownLoungeDoorR", Vector3(entry_cx + 0.55, entry_h * 0.5, FACADE_FRONT_Z - 0.03), Vector3(1.0, entry_h, 0.08), mats.get_material("black_lacquer"))
	_mesh(world, "VSCrownLoungeDoorHandleL", Vector3(entry_cx - 0.2, 1.2, FACADE_FRONT_Z - 0.08), Vector3(0.05, 0.5, 0.05), mats.get_material("polished_gold"))
	_mesh(world, "VSCrownLoungeDoorHandleR", Vector3(entry_cx + 0.2, 1.2, FACADE_FRONT_Z - 0.08), Vector3(0.05, 0.5, 0.05), mats.get_material("polished_gold"))
	# Gold frame around the entry
	_mesh(world, "VSCrownLoungeEntryFrameTop", Vector3(entry_cx, entry_h + 0.08, FACADE_FRONT_Z - 0.05), Vector3(entry_w + 0.2, 0.15, 0.12), mats.get_material("polished_gold"))
	_mesh(world, "VSCrownLoungeEntryFrameL", Vector3(entry_cx - entry_w * 0.5 - 0.05, entry_h * 0.5, FACADE_FRONT_Z - 0.05), Vector3(0.1, entry_h, 0.12), mats.get_material("polished_gold"))
	_mesh(world, "VSCrownLoungeEntryFrameR", Vector3(entry_cx + entry_w * 0.5 + 0.05, entry_h * 0.5, FACADE_FRONT_Z - 0.05), Vector3(0.1, entry_h, 0.12), mats.get_material("polished_gold"))

	# Illuminated sign above entry — CROWN LOUNGE
	_mesh(world, "VSCrownLoungeSignBacking", Vector3(entry_cx, floor_h + 0.1, FACADE_FRONT_Z - 0.1), Vector3(x_max - x_min - 0.8, 0.55, 0.08), mats.get_material("signage_backing"))
	_mesh(world, "VSCrownLoungeSignNeon", Vector3(entry_cx, floor_h + 0.1, FACADE_FRONT_Z - 0.15), Vector3(x_max - x_min - 1.5, 0.3, 0.05), mats.get_material("neon_pink"))
	# Vertical blade sign to the side
	_mesh(world, "VSCrownLoungeBladeSign", Vector3(x_max - 0.4, floor_h * 1.4, FACADE_FRONT_Z - 0.45), Vector3(0.3, 2.5, 0.8), mats.get_material("signage_backing"))
	_mesh(world, "VSCrownLoungeBladeSignNeon", Vector3(x_max - 0.5, floor_h * 1.4, FACADE_FRONT_Z - 0.45), Vector3(0.06, 2.2, 0.6), mats.get_material("neon_amber"))

	# Upper floor: 2nd story windows
	for b in range(4):
		var bx = x_min + (x_max - x_min) * (b + 1) / 5.0
		_window_bay(world, "VSCrownLoungeF2Win%d" % b, bx, floor_h + floor_h * 0.5, FACADE_FRONT_Z - 0.01, 1.4, 1.8, mats.get_material("polished_gold"), mats.get_material("tinted_glass"))

	# Cornice + parapet
	_cornice_band(world, "VSCrownLoungeCornice", x_min - 0.15, x_max + 0.15, FACADE_FRONT_Z, total_h - 0.15, 0.3, 0.5, mats.get_material("polished_gold"))
	_mesh(world, "VSCrownLoungeParapet", Vector3((x_min + x_max) * 0.5, total_h + 0.2, FACADE_FRONT_Z + 0.05), Vector3(x_max - x_min + 0.3, 0.4, 0.25), mats.get_material("dark_marble"))

	# Roof slab (rooftop traversal)
	_block(world, "VSCrownLoungeRoof", Vector3((x_min + x_max) * 0.5, total_h + 0.05, 0.0), Vector3(x_max - x_min, 0.3, 12.0), mats.get_material("aged_concrete"))

	# Side walls
	_block(world, "VSCrownLoungeSideW", Vector3(x_min - 0.15, total_h * 0.5, 0.0), Vector3(0.3, total_h, INTERIOR_BACK_Z - FACADE_FRONT_Z), mats.get_material("dark_marble"))
	_block(world, "VSCrownLoungeSideE", Vector3(x_max + 0.15, total_h * 0.5, 0.0), Vector3(0.3, total_h, INTERIOR_BACK_Z - FACADE_FRONT_Z), mats.get_material("dark_marble"))
	# Back wall with a BOH door opening
	var boh_cx = entry_cx + 2.0
	var boh_w = 1.6
	# Left segment
	_facade_wall(world, "VSCrownLoungeBackL", x_min, boh_cx - boh_w * 0.5, INTERIOR_BACK_Z, 0.0, total_h, mats.get_material("dark_marble"))
	# Right segment
	_facade_wall(world, "VSCrownLoungeBackR", boh_cx + boh_w * 0.5, x_max, INTERIOR_BACK_Z, 0.0, total_h, mats.get_material("dark_marble"))
	# Top lintel over BOH door
	_mesh(world, "VSCrownLoungeBOHLintel", Vector3(boh_cx, 2.4, INTERIOR_BACK_Z), Vector3(boh_w + 0.4, 0.3, 0.4), mats.get_material("dark_marble"))
	# BOH door (heavy steel look)
	_mesh(world, "VSCrownLoungeBOHDoor", Vector3(boh_cx, 1.1, INTERIOR_BACK_Z - 0.18), Vector3(boh_w - 0.2, 2.2, 0.08), mats.get_material("chrome"))
	_mesh(world, "VSCrownLoungeBOHDoorKick", Vector3(boh_cx, 0.15, INTERIOR_BACK_Z - 0.2), Vector3(boh_w - 0.2, 0.2, 0.06), mats.get_material("brushed_gold"))
	# Illuminated EXIT sign
	_mesh(world, "VSCrownLoungeBOHExitSign", Vector3(boh_cx, 2.65, INTERIOR_BACK_Z - 0.2), Vector3(0.9, 0.28, 0.04), mats.get_material("neon_red"))

	# Above-second-floor rear wall
	_facade_wall(world, "VSCrownLoungeBackTop", x_min, x_max, INTERIOR_BACK_Z, total_h * 0.62, total_h, mats.get_material("dark_marble"))

	# ================ INTERIOR ================
	_build_crown_lounge_interior(world, mats, x_min, x_max, boh_cx)

static func _build_crown_lounge_interior(world, mats, x_min, x_max, boh_cx) -> void:
	# Interior floor
	_block(world, "VSCrownLoungeInteriorFloor", Vector3((x_min + x_max) * 0.5, 0.03, (FACADE_FRONT_Z + INTERIOR_BACK_Z) * 0.5 + 0.05), Vector3(x_max - x_min - 0.4, 0.06, INTERIOR_BACK_Z - FACADE_FRONT_Z - 0.2), mats.get_material("marble_floor"))
	# Ceiling
	_mesh(world, "VSCrownLoungeCeiling", Vector3((x_min + x_max) * 0.5, 3.3, (FACADE_FRONT_Z + INTERIOR_BACK_Z) * 0.5 + 0.05), Vector3(x_max - x_min - 0.4, 0.1, INTERIOR_BACK_Z - FACADE_FRONT_Z - 0.2), mats.get_material("black_lacquer"))

	# Bar: long rectangle along the west interior wall
	var bar_x = x_min + 1.8
	var bar_cz = 0.5
	var bar_len = 5.0
	# Bar base (black lacquer)
	_block(world, "VSCrownLoungeBarBase", Vector3(bar_x, 0.5, bar_cz), Vector3(1.2, 1.0, bar_len), mats.get_material("black_lacquer"))
	# Gold kickplate
	_mesh(world, "VSCrownLoungeBarKick", Vector3(bar_x - 0.58, 0.1, bar_cz), Vector3(0.06, 0.2, bar_len), mats.get_material("polished_gold"))
	# Bar top (polished dark stone)
	_mesh(world, "VSCrownLoungeBarTop", Vector3(bar_x, 1.05, bar_cz), Vector3(1.4, 0.1, bar_len + 0.2), mats.get_material("bar_top"))
	# Under-counter glow (the classic neon reveal)
	_mesh(world, "VSCrownLoungeBarGlow", Vector3(bar_x + 0.05, 0.18, bar_cz), Vector3(0.04, 0.08, bar_len - 0.2), mats.get_material("neon_pink"))

	# Back-bar: shelves of bottles against the west wall
	_mesh(world, "VSCrownLoungeBackBar", Vector3(x_min + 0.7, 1.7, bar_cz), Vector3(0.4, 2.4, bar_len + 0.4), mats.get_material("dark_wood"))
	_mesh(world, "VSCrownLoungeBackBarMirror", Vector3(x_min + 0.9, 2.0, bar_cz), Vector3(0.04, 1.8, bar_len), mats.get_material("mirrored_glass"))
	# Bottles — alternating tints
	for i in range(10):
		var bz = bar_cz - bar_len * 0.5 + 0.25 + i * 0.5
		var tints = ["bottle_glass_amber", "bottle_glass_green", "bottle_glass_clear"]
		for shelf in range(3):
			var shelf_y = 1.3 + shelf * 0.5
			var mat_key = tints[(i + shelf) % tints.size()]
			_cylinder(world, "VSBottle%d_%d" % [i, shelf], Vector3(x_min + 1.05, shelf_y, bz), 0.06, 0.34, mats.get_material(mat_key))
		# Shelf plank
		if i == 0:
			for s in range(3):
				_mesh(world, "VSBackBarShelf%d" % s, Vector3(x_min + 1.05, 1.1 + s * 0.5, bar_cz), Vector3(0.35, 0.03, bar_len), mats.get_material("brushed_gold"))

	# Bar stools along the east side of the bar
	for i in range(4):
		var sz = bar_cz - bar_len * 0.5 + 0.7 + i * 1.2
		_cylinder(world, "VSBarStoolBase%d" % i, Vector3(bar_x + 1.0, 0.05, sz), 0.18, 0.1, mats.get_material("brushed_gold"))
		_cylinder(world, "VSBarStoolPost%d" % i, Vector3(bar_x + 1.0, 0.45, sz), 0.04, 0.7, mats.get_material("chrome"))
		_cylinder(world, "VSBarStoolSeat%d" % i, Vector3(bar_x + 1.0, 0.82, sz), 0.22, 0.08, mats.get_material("velvet_red"))

	# Banquettes along the east wall
	for i in range(3):
		var cz = -3.5 + i * 3.0
		# Bench base (black)
		_block(world, "VSBanquetteBase%d" % i, Vector3(x_max - 1.2, 0.3, cz), Vector3(1.6, 0.6, 1.8), mats.get_material("black_lacquer"))
		# Seat cushion (velvet)
		_mesh(world, "VSBanquetteSeat%d" % i, Vector3(x_max - 1.2, 0.65, cz), Vector3(1.4, 0.15, 1.7), mats.get_material("velvet_red"))
		# Back cushion
		_mesh(world, "VSBanquetteBack%d" % i, Vector3(x_max - 0.5, 1.15, cz), Vector3(0.25, 1.0, 1.7), mats.get_material("velvet_red"))
		# Little round table
		_cylinder(world, "VSBanquetteTableBase%d" % i, Vector3(x_max - 2.3, 0.35, cz), 0.05, 0.7, mats.get_material("polished_gold"))
		_cylinder(world, "VSBanquetteTableTop%d" % i, Vector3(x_max - 2.3, 0.75, cz), 0.45, 0.04, mats.get_material("dark_marble"))
		# Pendant light above each table
		_cylinder(world, "VSBanquettePendantCord%d" % i, Vector3(x_max - 2.3, 2.4, cz), 0.02, 1.6, mats.get_material("black_lacquer"))
		_cylinder(world, "VSBanquettePendantShade%d" % i, Vector3(x_max - 2.3, 1.5, cz), 0.12, 0.22, mats.get_material("brushed_gold"))
		_cylinder(world, "VSBanquettePendantBulb%d" % i, Vector3(x_max - 2.3, 1.45, cz), 0.07, 0.15, mats.get_material("lamp_bulb"))
		var pend := OmniLight3D.new()
		pend.name = "VSBanquettePendantLight%d" % i
		pend.position = Vector3(x_max - 2.3, 1.45, cz)
		pend.light_color = Color("ffc77a")
		pend.light_energy = 2.4
		pend.omni_range = 3.0
		pend.shadow_enabled = false
		world.add_child(pend)
		world.point_lights.append(pend)

	# Recessed ceiling lights (4 downlights)
	for i in range(6):
		var dx = x_min + 1.2 + i * 1.4
		var downlight := OmniLight3D.new()
		downlight.name = "VSLoungeCeiling%d" % i
		downlight.position = Vector3(dx, 3.0, -1.0 + (i % 2) * 3.0)
		downlight.light_color = Color("ffc07a")
		downlight.light_energy = 1.4
		downlight.omni_range = 4.0
		downlight.shadow_enabled = false
		world.add_child(downlight)
		world.point_lights.append(downlight)

	# Bar bottle light (underneath + reveal)
	var bar_light := OmniLight3D.new()
	bar_light.name = "VSLoungeBarLight"
	bar_light.position = Vector3(bar_x + 0.1, 1.1, bar_cz)
	bar_light.light_color = Color("ff86bf")
	bar_light.light_energy = 3.0
	bar_light.omni_range = 4.0
	bar_light.shadow_enabled = false
	world.add_child(bar_light)
	world.point_lights.append(bar_light)

	# VIP rope-and-stanchion line near the entry
	for i in range(3):
		var rx = -1.2 + i * 1.2
		_cylinder(world, "VSStanchion%d" % i, Vector3(rx, 0.55, FACADE_FRONT_Z + 1.2), 0.05, 1.1, mats.get_material("stanchion"))
	# Rope between stanchions
	for i in range(2):
		var rx = -0.6 + i * 1.2
		_mesh(world, "VSStanchionRope%d" % i, Vector3(rx, 0.7, FACADE_FRONT_Z + 1.2), Vector3(1.2, 0.05, 0.05), mats.get_material("rope_velvet"))

	# Cocktail tables in the center floor
	for i in range(2):
		var tcx = x_min + 4.0 + i * 2.2
		var tcz = -1.5 + i * 2.5
		_cylinder(world, "VSCocktailTablePost%d" % i, Vector3(tcx, 0.55, tcz), 0.04, 1.1, mats.get_material("polished_gold"))
		_cylinder(world, "VSCocktailTableTop%d" % i, Vector3(tcx, 1.12, tcz), 0.4, 0.04, mats.get_material("dark_marble"))
		for s in range(2):
			var sx = tcx + (s * 2 - 1) * 0.62
			_cylinder(world, "VSCocktailStoolPost%d_%d" % [i, s], Vector3(sx, 0.35, tcz), 0.03, 0.7, mats.get_material("chrome"))
			_cylinder(world, "VSCocktailStoolSeat%d_%d" % [i, s], Vector3(sx, 0.72, tcz), 0.18, 0.06, mats.get_material("velvet_red"))

	# DJ booth near the back wall
	var dj_cx = (x_min + x_max) * 0.5 + 1.0
	var dj_z = INTERIOR_BACK_Z - 1.2
	_block(world, "VSDJBooth", Vector3(dj_cx, 0.7, dj_z), Vector3(3.0, 1.4, 0.9), mats.get_material("black_lacquer"))
	_mesh(world, "VSDJBoothTop", Vector3(dj_cx, 1.42, dj_z), Vector3(3.2, 0.06, 1.0), mats.get_material("dark_marble"))
	_mesh(world, "VSDJBoothFront", Vector3(dj_cx, 0.7, dj_z - 0.48), Vector3(3.0, 1.4, 0.06), mats.get_material("polished_gold"))
	_mesh(world, "VSDJMixer", Vector3(dj_cx, 1.52, dj_z - 0.05), Vector3(1.0, 0.08, 0.6), mats.get_material("chrome"))
	_cylinder(world, "VSDJTurntableL", Vector3(dj_cx - 0.9, 1.52, dj_z - 0.05), 0.22, 0.04, mats.get_material("signage_backing"))
	_cylinder(world, "VSDJTurntableR", Vector3(dj_cx + 0.9, 1.52, dj_z - 0.05), 0.22, 0.04, mats.get_material("signage_backing"))
	_mesh(world, "VSDJBoothNeon", Vector3(dj_cx, 0.1, dj_z - 0.52), Vector3(2.8, 0.06, 0.04), mats.get_material("neon_cyan"))
	var dj_light := OmniLight3D.new()
	dj_light.name = "VSDJBoothLight"
	dj_light.position = Vector3(dj_cx, 1.8, dj_z)
	dj_light.light_color = Color("80c8ff")
	dj_light.light_energy = 3.5
	dj_light.omni_range = 5.0
	dj_light.shadow_enabled = false
	world.add_child(dj_light)
	world.point_lights.append(dj_light)

	# Neon art panel on north interior wall (above DJ booth zone)
	_mesh(world, "VSLoungeWallArtBack", Vector3(x_min + 4.0, 2.2, INTERIOR_BACK_Z - 0.08), Vector3(5.5, 1.8, 0.08), mats.get_material("signage_backing"))
	_mesh(world, "VSLoungeWallArtNeonA", Vector3(x_min + 3.2, 2.5, INTERIOR_BACK_Z - 0.13), Vector3(2.0, 0.08, 0.04), mats.get_material("neon_pink"))
	_mesh(world, "VSLoungeWallArtNeonB", Vector3(x_min + 4.8, 2.0, INTERIOR_BACK_Z - 0.13), Vector3(3.0, 0.08, 0.04), mats.get_material("neon_amber"))
	_mesh(world, "VSLoungeWallArtNeonC", Vector3(x_min + 4.2, 2.9, INTERIOR_BACK_Z - 0.13), Vector3(1.4, 0.06, 0.04), mats.get_material("neon_cyan"))
	var art_light := OmniLight3D.new()
	art_light.name = "VSLoungeWallArtLight"
	art_light.position = Vector3(x_min + 4.0, 2.2, INTERIOR_BACK_Z - 0.6)
	art_light.light_color = Color("ff6080")
	art_light.light_energy = 2.5
	art_light.omni_range = 4.5
	art_light.shadow_enabled = false
	world.add_child(art_light)
	world.point_lights.append(art_light)

# ------------------------------------------------------------------------
# Boutique Hotel B (4 stories, warm painted brick)
# ------------------------------------------------------------------------

static func _build_boutique_hotel(world, mats) -> void:
	var x_min = BOUTIQUE_X.x
	var x_max = BOUTIQUE_X.y
	var floor_h = 3.2
	var floors = 4
	var total_h = floor_h * floors

	# Plinth
	_mesh(world, "VSBoutiquePlinth", Vector3((x_min + x_max) * 0.5, 0.22, FACADE_FRONT_Z + 0.15), Vector3(x_max - x_min + 0.3, 0.44, 0.5), mats.get_material("dark_marble"))

	var entry_cx = (x_min + x_max) * 0.5
	var entry_w = 2.0
	var entry_h = 2.6
	# Ground floor flanking walls
	_facade_wall(world, "VSBoutiqueGroundL", x_min, entry_cx - entry_w * 0.5, FACADE_FRONT_Z, 0.44, floor_h, mats.get_material("painted_brick_warm"))
	_facade_wall(world, "VSBoutiqueGroundR", entry_cx + entry_w * 0.5, x_max, FACADE_FRONT_Z, 0.44, floor_h, mats.get_material("painted_brick_warm"))
	# Ground bay windows
	_window_bay(world, "VSBoutiqueGroundWinL", (x_min + entry_cx - entry_w * 0.5) * 0.5, 1.7, FACADE_FRONT_Z - 0.01, 2.0, 1.8, mats.get_material("brushed_gold"), mats.get_material("tinted_glass"))
	_window_bay(world, "VSBoutiqueGroundWinR", (entry_cx + entry_w * 0.5 + x_max) * 0.5, 1.7, FACADE_FRONT_Z - 0.01, 2.0, 1.8, mats.get_material("brushed_gold"), mats.get_material("tinted_glass"))
	# Entry
	_mesh(world, "VSBoutiqueEntryLintel", Vector3(entry_cx, entry_h + 0.2, FACADE_FRONT_Z - 0.05), Vector3(entry_w + 0.4, 0.4, 0.5), mats.get_material("dark_marble"))
	_mesh(world, "VSBoutiqueDoor", Vector3(entry_cx, entry_h * 0.5, FACADE_FRONT_Z - 0.04), Vector3(entry_w - 0.2, entry_h, 0.08), mats.get_material("dark_wood"))
	_mesh(world, "VSBoutiqueDoorHandle", Vector3(entry_cx + 0.35, 1.2, FACADE_FRONT_Z - 0.1), Vector3(0.05, 0.3, 0.05), mats.get_material("polished_gold"))
	# Small awning
	_mesh(world, "VSBoutiqueAwning", Vector3(entry_cx, entry_h + 0.7, FACADE_FRONT_Z - 0.9), Vector3(entry_w + 1.6, 0.18, 2.0), mats.get_material("awning_canvas"))
	# Boutique script sign
	_mesh(world, "VSBoutiqueSignBacking", Vector3(entry_cx, entry_h + 1.3, FACADE_FRONT_Z - 0.12), Vector3(entry_w + 2.0, 0.45, 0.05), mats.get_material("signage_backing"))
	_mesh(world, "VSBoutiqueSignNeon", Vector3(entry_cx, entry_h + 1.3, FACADE_FRONT_Z - 0.17), Vector3(entry_w + 1.6, 0.28, 0.04), mats.get_material("neon_cyan"))

	# Upper floors
	for f in range(1, floors):
		var cy = floor_h * f + floor_h * 0.5
		_facade_wall(world, "VSBoutiqueF%d" % f, x_min, x_max, FACADE_FRONT_Z, floor_h * f, floor_h * (f + 1), mats.get_material("painted_brick_warm"))
		_cornice_band(world, "VSBoutiqueBelt%d" % f, x_min - 0.1, x_max + 0.1, FACADE_FRONT_Z, floor_h * f + 0.05, 0.08, 0.18, mats.get_material("stucco_cream"))
		# 2 windows per floor plus a balcony on alternating floors
		for b in range(2):
			var bx = x_min + (x_max - x_min) * (b + 1) / 3.0
			_window_bay(world, "VSBoutiqueF%dWin%d" % [f, b], bx, cy, FACADE_FRONT_Z - 0.01, 1.6, 1.8, mats.get_material("brushed_gold"), mats.get_material("tinted_glass"))
		# Balcony railing on 2nd and 3rd floors
		if f == 1 or f == 2:
			_mesh(world, "VSBoutiqueBalconyF%d" % f, Vector3((x_min + x_max) * 0.5, floor_h * f + 0.15, FACADE_FRONT_Z - 0.3), Vector3(x_max - x_min - 0.6, 0.15, 0.6), mats.get_material("brushed_gold"))
			for rb in range(6):
				var rx = x_min + (x_max - x_min) * (rb + 1) / 7.0
				_mesh(world, "VSBoutiqueBalconyRailF%d_%d" % [f, rb], Vector3(rx, floor_h * f + 0.5, FACADE_FRONT_Z - 0.3), Vector3(0.04, 0.8, 0.04), mats.get_material("brushed_gold"))
			_mesh(world, "VSBoutiqueBalconyTopRailF%d" % f, Vector3((x_min + x_max) * 0.5, floor_h * f + 0.92, FACADE_FRONT_Z - 0.3), Vector3(x_max - x_min - 0.6, 0.06, 0.06), mats.get_material("brushed_gold"))

	# Cornice + parapet
	_cornice_band(world, "VSBoutiqueCornice", x_min - 0.15, x_max + 0.15, FACADE_FRONT_Z, total_h - 0.1, 0.3, 0.5, mats.get_material("stucco_cream"))
	_mesh(world, "VSBoutiqueParapet", Vector3((x_min + x_max) * 0.5, total_h + 0.2, FACADE_FRONT_Z + 0.05), Vector3(x_max - x_min + 0.3, 0.4, 0.2), mats.get_material("painted_brick_warm"))
	# Roof slab
	_block(world, "VSBoutiqueRoof", Vector3((x_min + x_max) * 0.5, total_h + 0.05, 0.0), Vector3(x_max - x_min, 0.3, 12.0), mats.get_material("aged_concrete"))
	# Side walls
	_block(world, "VSBoutiqueSideW", Vector3(x_min - 0.15, total_h * 0.5, 0.0), Vector3(0.3, total_h, INTERIOR_BACK_Z - FACADE_FRONT_Z), mats.get_material("painted_brick_warm"))
	_block(world, "VSBoutiqueSideE", Vector3(x_max + 0.15, total_h * 0.5, 0.0), Vector3(0.3, total_h, INTERIOR_BACK_Z - FACADE_FRONT_Z), mats.get_material("painted_brick_warm"))
	# Back wall toward Service Grid (with a rear utility door)
	var rear_cx = entry_cx
	var rear_door_w = 1.2
	_facade_wall(world, "VSBoutiqueBackL", x_min, rear_cx - rear_door_w * 0.5, INTERIOR_BACK_Z, 0.0, total_h, mats.get_material("painted_brick_cool"))
	_facade_wall(world, "VSBoutiqueBackR", rear_cx + rear_door_w * 0.5, x_max, INTERIOR_BACK_Z, 0.0, total_h, mats.get_material("painted_brick_cool"))
	_mesh(world, "VSBoutiqueBackLintel", Vector3(rear_cx, 2.2, INTERIOR_BACK_Z), Vector3(rear_door_w + 0.3, 0.25, 0.4), mats.get_material("aged_concrete"))
	_facade_wall(world, "VSBoutiqueBackUpper", rear_cx - rear_door_w * 0.5, rear_cx + rear_door_w * 0.5, INTERIOR_BACK_Z, 2.34, total_h, mats.get_material("painted_brick_cool"))
	_mesh(world, "VSBoutiqueBackDoor", Vector3(rear_cx, 1.05, INTERIOR_BACK_Z - 0.15), Vector3(rear_door_w - 0.1, 2.1, 0.06), mats.get_material("chrome"))
	_build_boutique_interior(world, mats, x_min, x_max)

# ------------------------------------------------------------------------
# Boutique Hotel interior
# ------------------------------------------------------------------------

static func _build_boutique_interior(world, mats, x_min: float, x_max: float) -> void:
	var cx = (x_min + x_max) * 0.5
	var floor_h = 3.2

	# Interior floor — polished stone
	_block(world, "VSBoutiqueIntFloor", Vector3(cx, 0.03, 0.0), Vector3(x_max - x_min - 0.4, 0.06, INTERIOR_BACK_Z - FACADE_FRONT_Z - 0.2), mats.get_material("marble_floor"))

	# Central display island — glass-top pedestal
	_block(world, "VSBoutiqueDisplayBase", Vector3(cx, 0.45, 0.0), Vector3(2.4, 0.9, 1.2), mats.get_material("dark_marble"))
	_mesh(world, "VSBoutiqueDisplayGlass", Vector3(cx, 0.92, 0.0), Vector3(2.6, 0.06, 1.4), mats.get_material("tinted_glass"))
	_mesh(world, "VSBoutiqueDisplayEdge", Vector3(cx, 0.935, 0.0), Vector3(2.66, 0.03, 1.46), mats.get_material("polished_gold"))

	# Shelving unit on west wall
	_mesh(world, "VSBoutiqueShelfUnit", Vector3(x_min + 0.32, 1.6, 0.5), Vector3(0.28, 3.0, 4.0), mats.get_material("dark_wood"))
	for s in range(4):
		_mesh(world, "VSBoutiqueShelf%d" % s, Vector3(x_min + 0.58, 0.8 + s * 0.7, 0.5), Vector3(0.36, 0.04, 3.8), mats.get_material("brushed_gold"))

	# Garment rack on east wall
	_mesh(world, "VSBoutiqueRackBar", Vector3(x_max - 1.5, 1.8, 1.0), Vector3(0.04, 0.04, 3.0), mats.get_material("chrome"))
	_cylinder(world, "VSBoutiqueRackPostL", Vector3(x_max - 1.5, 1.0, -0.4), 0.03, 2.0, mats.get_material("chrome"))
	_cylinder(world, "VSBoutiqueRackPostR", Vector3(x_max - 1.5, 1.0, 2.4), 0.03, 2.0, mats.get_material("chrome"))
	for g in range(5):
		var gmat = "velvet_red" if g % 2 == 0 else "black_lacquer"
		_mesh(world, "VSBoutiqueGarment%d" % g, Vector3(x_max - 1.38, 1.42, -0.1 + g * 0.55), Vector3(0.32, 0.7, 0.08), mats.get_material(gmat))

	# Checkout counter near the entry
	_block(world, "VSBoutiqueCounter", Vector3(cx + 1.2, 0.5, -3.8), Vector3(2.0, 1.0, 0.7), mats.get_material("dark_wood"))
	_mesh(world, "VSBoutiqueCounterTop", Vector3(cx + 1.2, 1.04, -3.8), Vector3(2.2, 0.04, 0.8), mats.get_material("dark_marble"))

	# Track lighting
	for t in range(4):
		var tx = x_min + 0.9 + t * (x_max - x_min - 1.0) / 4.0
		var track := SpotLight3D.new()
		track.name = "VSBoutiqueTrack%d" % t
		track.position = Vector3(tx, floor_h - 0.1, 0.5)
		track.rotation_degrees = Vector3(-80.0, 0.0, 0.0)
		track.light_color = Color("fff8e8")
		track.light_energy = 4.5
		track.spot_range = 6.0
		track.spot_angle = 28.0
		track.spot_angle_attenuation = 0.5
		track.shadow_enabled = false
		world.add_child(track)
		world.point_lights.append(track)

	var fill := OmniLight3D.new()
	fill.name = "VSBoutiqueFill"
	fill.position = Vector3(cx, 2.5, 0.5)
	fill.light_color = Color("ffe8d0")
	fill.light_energy = 2.5
	fill.omni_range = 10.0
	fill.shadow_enabled = false
	world.add_child(fill)
	world.point_lights.append(fill)

# ------------------------------------------------------------------------
# Neon bank (far east): sign towers, no interior.
# ------------------------------------------------------------------------

static func _build_neon_bank(world, mats) -> void:
	var x_min = NEON_BANK_X.x
	var x_max = NEON_BANK_X.y
	# Short utility wall
	_facade_wall(world, "VSNeonBankWall", x_min, x_max, FACADE_FRONT_Z, 0.0, 5.0, mats.get_material("painted_brick_cool"))
	# Giant billboard structure
	_mesh(world, "VSBillboardPost1", Vector3(x_min + 1.0, 6.0, FACADE_FRONT_Z - 0.6), Vector3(0.3, 12.0, 0.3), mats.get_material("signage_backing"))
	_mesh(world, "VSBillboardPost2", Vector3(x_max - 1.0, 6.0, FACADE_FRONT_Z - 0.6), Vector3(0.3, 12.0, 0.3), mats.get_material("signage_backing"))
	_mesh(world, "VSBillboardBack", Vector3((x_min + x_max) * 0.5, 9.0, FACADE_FRONT_Z - 0.75), Vector3(x_max - x_min, 5.0, 0.2), mats.get_material("signage_backing"))
	# Neon script letters suggested by stacked emissive volumes
	_mesh(world, "VSBillboardNeonA", Vector3((x_min + x_max) * 0.5 - 1.2, 9.8, FACADE_FRONT_Z - 0.87), Vector3(3.8, 1.2, 0.1), mats.get_material("neon_pink"))
	_mesh(world, "VSBillboardNeonB", Vector3((x_min + x_max) * 0.5 + 0.6, 8.2, FACADE_FRONT_Z - 0.87), Vector3(2.8, 0.9, 0.1), mats.get_material("neon_amber"))
	_mesh(world, "VSBillboardNeonC", Vector3((x_min + x_max) * 0.5 - 0.2, 6.8, FACADE_FRONT_Z - 0.87), Vector3(3.4, 0.6, 0.1), mats.get_material("neon_cyan"))

	# Add a point light to make the billboard act as a real light source
	var neon_light := OmniLight3D.new()
	neon_light.name = "VSBillboardLight"
	neon_light.position = Vector3((x_min + x_max) * 0.5, 9.0, FACADE_FRONT_Z - 1.5)
	neon_light.light_color = Color("ff7fbf")
	neon_light.light_energy = 5.0
	neon_light.omni_range = 18.0
	neon_light.shadow_enabled = false
	world.add_child(neon_light)
	world.point_lights.append(neon_light)

# ------------------------------------------------------------------------
# Service Grid corridor (the hidden layer — stealth traversal)
# ------------------------------------------------------------------------

static func _build_service_grid(world, mats) -> void:
	var x_min = PARKING_X.x - 0.5
	var x_max = BOUTIQUE_X.y + 0.5
	var z_front = INTERIOR_BACK_Z
	var z_back = SERVICE_BACK_Z
	var ceiling_h = 3.2

	# Floor (grated aged concrete)
	_block(world, "VSServiceGridFloor", Vector3((x_min + x_max) * 0.5, 0.04, (z_front + z_back) * 0.5), Vector3(x_max - x_min, 0.08, z_back - z_front), mats.get_material("service_floor"))
	# Grated strip down the center
	for i in range(int((z_back - z_front) / 0.8)):
		var gz = z_front + 0.4 + i * 0.8
		_mesh(world, "VSGrate%d" % i, Vector3(0.0, 0.085, gz), Vector3(x_max - x_min - 1.0, 0.02, 0.5), mats.get_material("grating"))

	# Ceiling (covered corridor)
	_mesh(world, "VSServiceCeiling", Vector3((x_min + x_max) * 0.5, ceiling_h, (z_front + z_back) * 0.5), Vector3(x_max - x_min, 0.2, z_back - z_front), mats.get_material("aged_concrete"))
	# Back wall (north boundary of district)
	_facade_wall(world, "VSServiceBackWall", x_min, x_max, z_back, 0.0, ceiling_h + 2.0, mats.get_material("painted_brick_cool"))
	# Side walls (east and west ends)
	_facade_wall(world, "VSServiceEndW", x_min, x_min + 0.4, (z_front + z_back) * 0.5, 0.0, ceiling_h, mats.get_material("painted_brick_cool"))
	_facade_wall(world, "VSServiceEndE", x_max - 0.4, x_max, (z_front + z_back) * 0.5, 0.0, ceiling_h, mats.get_material("painted_brick_cool"))

	# Steam vent boxes along the back wall
	var vent_positions = [-18.0, -10.0, -2.0, 5.0, 11.0]
	for i in range(vent_positions.size()):
		var vx = vent_positions[i]
		_mesh(world, "VSSteamVent%d" % i, Vector3(vx, 1.4, z_back - 0.3), Vector3(1.1, 1.2, 0.4), mats.get_material("chrome"))
		_mesh(world, "VSSteamVentLouver%d" % i, Vector3(vx, 1.4, z_back - 0.55), Vector3(0.9, 1.0, 0.02), mats.get_material("signage_backing"))
		# Vertical pipe riser
		_cylinder(world, "VSVentPipe%d" % i, Vector3(vx + 0.6, 2.0, z_back - 0.2), 0.08, 2.5, mats.get_material("chrome"))

	# Caged wall lights every few meters along both sides
	for i in range(8):
		var lx = x_min + 2.0 + i * 4.0
		var light := OmniLight3D.new()
		light.name = "VSServiceLight%d" % i
		light.position = Vector3(lx, 2.6, z_back - 0.4)
		light.light_color = Color("f6e6a4")
		light.light_energy = 2.2
		light.omni_range = 6.0
		light.shadow_enabled = false
		world.add_child(light)
		world.point_lights.append(light)
		# Physical cage (small)
		_cylinder(world, "VSServiceLightCage%d" % i, Vector3(lx, 2.6, z_back - 0.4), 0.14, 0.28, mats.get_material("chrome"))
		_cylinder(world, "VSServiceLightBulb%d" % i, Vector3(lx, 2.6, z_back - 0.4), 0.08, 0.22, mats.get_material("lamp_bulb"))

	# Dumpsters — a row of 3, green and rusted
	var dump_mat := StandardMaterial3D.new()
	dump_mat.albedo_color = Color("2f4d3a")
	dump_mat.metallic = 0.4
	dump_mat.roughness = 0.6
	for i in range(3):
		var dx = -14.0 + i * 6.0
		_block(world, "VSDumpster%d" % i, Vector3(dx, 0.7, z_front + 1.4), Vector3(2.0, 1.2, 1.2), dump_mat)
		_mesh(world, "VSDumpsterLid%d" % i, Vector3(dx, 1.4, z_front + 1.4), Vector3(2.0, 0.1, 1.2), mats.get_material("chrome"))
		# Number stencil
		_mesh(world, "VSDumpsterNum%d" % i, Vector3(dx, 0.8, z_front + 0.78), Vector3(0.3, 0.3, 0.02), mats.get_material("stucco_cream"))

	# Stacked crates / pallets
	for i in range(2):
		var cx = 8.0 + i * 2.0
		_block(world, "VSCrate%d" % i, Vector3(cx, 0.4, z_front + 1.2), Vector3(1.0, 0.8, 0.8), mats.get_material("dark_wood"))
		_block(world, "VSCrateTop%d" % i, Vector3(cx - 0.2, 1.05, z_front + 1.0), Vector3(0.7, 0.5, 0.7), mats.get_material("dark_wood"))

	# Open BOH archways from each facade into the service grid (visual connectors)
	# (doors already cut in each facade's back wall)

	# Service gantry / metal stair going up to roof level from service grid
	_build_service_stair_to_roof(world, mats)

static func _build_service_stair_to_roof(world, mats) -> void:
	# Steel switchback staircase connecting the service grid to the Crown Lounge roof.
	var base_x = 6.5
	var base_z = INTERIOR_BACK_Z + 1.0
	# Landing platform at roof height
	_block(world, "VSServiceStairLanding", Vector3(base_x, 6.7, base_z + 2.0), Vector3(1.6, 0.15, 2.0), mats.get_material("grating"))
	# First flight
	for i in range(8):
		var sy = 0.2 + i * 0.4
		var sz = base_z + 0.2 + i * 0.35
		_mesh(world, "VSServiceStairA%d" % i, Vector3(base_x - 0.5, sy, sz), Vector3(1.4, 0.08, 0.36), mats.get_material("grating"))
	# Second flight (mirrored)
	for i in range(8):
		var sy = 3.5 + i * 0.4
		var sz = base_z + 3.2 - i * 0.35
		_mesh(world, "VSServiceStairB%d" % i, Vector3(base_x + 0.5, sy, sz), Vector3(1.4, 0.08, 0.36), mats.get_material("grating"))
	# Mid landing
	_mesh(world, "VSServiceStairMidLanding", Vector3(base_x, 3.3, base_z + 3.5), Vector3(2.0, 0.12, 1.2), mats.get_material("grating"))
	# Railings (simplified — single bar along outside of each flight)
	_mesh(world, "VSServiceStairRailA", Vector3(base_x + 0.2, 2.0, base_z + 1.5), Vector3(0.04, 0.06, 3.0), mats.get_material("chrome"))
	_mesh(world, "VSServiceStairRailB", Vector3(base_x + 1.2, 5.0, base_z + 2.3), Vector3(0.04, 0.06, 3.0), mats.get_material("chrome"))

# ------------------------------------------------------------------------
# Rooftop path: catwalk between Crown Lounge roof (~6.8m) and Hotel Crown
# roof (~16m) via a fire escape ladder.
# ------------------------------------------------------------------------

static func _build_rooftop_path(world, mats) -> void:
	# The Crown Lounge roof already exists (from _build_crown_lounge at y = 6.95).
	# Add a rooftop HVAC unit and a catwalk up to the Hotel Crown roof.
	# HVAC box on lounge roof
	_block(world, "VSLoungeRoofHVAC", Vector3(-2.0, 7.5, 2.0), Vector3(1.6, 1.0, 1.4), mats.get_material("chrome"))
	_block(world, "VSLoungeRoofAC", Vector3(2.2, 7.4, -1.0), Vector3(1.2, 0.8, 1.0), mats.get_material("chrome"))
	# Pipe snaking
	_mesh(world, "VSLoungeRoofPipe", Vector3(-0.5, 7.3, 2.0), Vector3(4.0, 0.15, 0.15), mats.get_material("chrome"))

	# Rooftop ladder from lounge roof (6.8) to hotel crown roof (16.0) on the east edge of the lounge
	var ladder_x = -3.8
	var ladder_z = 0.0
	var ladder_base_y = 6.8
	var ladder_top_y = 16.0
	_mesh(world, "VSRooftopLadderRail1", Vector3(ladder_x - 0.15, (ladder_base_y + ladder_top_y) * 0.5, ladder_z), Vector3(0.06, ladder_top_y - ladder_base_y, 0.06), mats.get_material("chrome"))
	_mesh(world, "VSRooftopLadderRail2", Vector3(ladder_x + 0.15, (ladder_base_y + ladder_top_y) * 0.5, ladder_z), Vector3(0.06, ladder_top_y - ladder_base_y, 0.06), mats.get_material("chrome"))
	var rung_count = int((ladder_top_y - ladder_base_y) / 0.35)
	for i in range(rung_count):
		_mesh(world, "VSRooftopLadderRung%d" % i, Vector3(ladder_x, ladder_base_y + 0.2 + i * 0.35, ladder_z), Vector3(0.44, 0.04, 0.04), mats.get_material("chrome"))

	# Invisible collision column along the ladder so the player can climb it (walkable surface)
	# Since the prototype has no climb system, provide a steep stepped collider ramp instead.
	for i in range(rung_count):
		var sy = ladder_base_y + 0.2 + i * 0.35
		_collider_only(world, "VSRooftopLadderStep%d" % i, Vector3(ladder_x, sy, ladder_z), Vector3(0.7, 0.12, 0.3))

	# Catwalk across a small gap on the hotel crown roof
	_block(world, "VSRooftopCatwalk", Vector3(-9.0, 16.1, 0.0), Vector3(6.0, 0.15, 1.2), mats.get_material("grating"))
	# Railings on catwalk
	for i in range(5):
		var rx = -11.5 + i * 1.2
		_mesh(world, "VSCatwalkRailN_%d" % i, Vector3(rx, 16.55, 0.55), Vector3(0.04, 0.9, 0.04), mats.get_material("chrome"))
		_mesh(world, "VSCatwalkRailS_%d" % i, Vector3(rx, 16.55, -0.55), Vector3(0.04, 0.9, 0.04), mats.get_material("chrome"))
	_mesh(world, "VSCatwalkRailTopN", Vector3(-9.0, 16.95, 0.55), Vector3(6.0, 0.05, 0.05), mats.get_material("chrome"))
	_mesh(world, "VSCatwalkRailTopS", Vector3(-9.0, 16.95, -0.55), Vector3(6.0, 0.05, 0.05), mats.get_material("chrome"))

	# HVAC cluster on hotel crown roof
	_block(world, "VSHotelRoofHVAC", Vector3(-10.0, 16.7, 3.5), Vector3(2.2, 1.2, 1.6), mats.get_material("chrome"))
	_block(world, "VSHotelRoofWaterTank", Vector3(-12.5, 16.95, -2.5), Vector3(1.8, 1.5, 1.8), mats.get_material("painted_brick_cool"))
	_cylinder(world, "VSHotelRoofTankCap", Vector3(-12.5, 17.8, -2.5), 0.95, 0.3, mats.get_material("chrome"))

# ------------------------------------------------------------------------
# Street dressing: lamp posts, trees, planters, valet podium.
# ------------------------------------------------------------------------

static func _build_street_dressing(world, mats) -> void:
	# Street lamps along the south curb
	var lamp_positions = [-20.0, -12.0, -4.0, 4.0, 12.0, 18.0]
	for i in range(lamp_positions.size()):
		var lx = lamp_positions[i]
		_build_street_lamp(world, mats, "VSLamp%d" % i, Vector3(lx, 0.0, -7.0))

	# Valet podium in front of the hotel
	_build_valet_podium(world, mats, Vector3(-10.0, 0.0, -8.5))

	# Planters
	for i in range(3):
		var px = -15.0 + i * 18.0
		_mesh(world, "VSPlanterBox%d" % i, Vector3(px, 0.35, -6.6), Vector3(1.0, 0.7, 1.0), mats.get_material("dark_marble"))
		# Small topiary (sphere)
		var topiary := MeshInstance3D.new()
		topiary.name = "VSTopiary%d" % i
		var sphere := SphereMesh.new()
		sphere.radius = 0.38
		sphere.height = 0.76
		topiary.mesh = sphere
		var leaf_mat := StandardMaterial3D.new()
		leaf_mat.albedo_color = Color("1f3a26")
		leaf_mat.roughness = 0.9
		topiary.material_override = leaf_mat
		topiary.position = Vector3(px, 1.0, -6.6)
		world.geometry_root.add_child(topiary)

	# Valet cars parked along the curb
	_build_valet_car(world, mats, Vector3(-17.0, 0.0, -9.5), Color("141418"))
	_build_valet_car(world, mats, Vector3(15.5, 0.0, -9.5), Color("3a0a12"))

	# Newsstand in the east
	_build_newsstand(world, mats, Vector3(17.0, 0.0, -8.0))

static func _build_street_lamp(world, mats, name, pos: Vector3) -> void:
	_cylinder(world, "%sBase" % name, pos + Vector3(0.0, 0.15, 0.0), 0.2, 0.3, mats.get_material("dark_marble"))
	_cylinder(world, "%sPost" % name, pos + Vector3(0.0, 2.5, 0.0), 0.07, 4.6, mats.get_material("black_lacquer"))
	# Top bracket and luminaire
	_mesh(world, "%sBracket" % name, pos + Vector3(0.0, 4.7, 0.0), Vector3(0.3, 0.08, 0.08), mats.get_material("polished_gold"))
	_cylinder(world, "%sShade" % name, pos + Vector3(0.0, 4.5, 0.0), 0.2, 0.4, mats.get_material("black_lacquer"))
	_cylinder(world, "%sGlobe" % name, pos + Vector3(0.0, 4.35, 0.0), 0.15, 0.3, mats.get_material("lamp_bulb"))
	var lamp := OmniLight3D.new()
	lamp.name = "%sLight" % name
	lamp.position = pos + Vector3(0.0, 4.35, 0.0)
	lamp.light_color = Color("ffd59a")
	lamp.light_energy = 3.4
	lamp.omni_range = 10.0
	lamp.shadow_enabled = false
	world.add_child(lamp)
	world.point_lights.append(lamp)

static func _build_valet_podium(world, mats, pos: Vector3) -> void:
	_block(world, "VSValetPodium", pos + Vector3(0.0, 0.55, 0.0), Vector3(0.9, 1.1, 0.6), mats.get_material("dark_wood"))
	_mesh(world, "VSValetPodiumTop", pos + Vector3(0.0, 1.14, 0.0), Vector3(1.0, 0.05, 0.7), mats.get_material("bar_top"))
	_mesh(world, "VSValetLampArm", pos + Vector3(0.0, 1.3, 0.0), Vector3(0.04, 0.3, 0.04), mats.get_material("polished_gold"))
	_cylinder(world, "VSValetLampShade", pos + Vector3(0.0, 1.48, 0.0), 0.1, 0.15, mats.get_material("brushed_gold"))

static func _build_valet_car(world, mats, pos: Vector3, color: Color) -> void:
	var body_mat := StandardMaterial3D.new()
	body_mat.albedo_color = color
	body_mat.metallic = 0.8
	body_mat.roughness = 0.18
	body_mat.clearcoat_enabled = true
	body_mat.clearcoat = 0.9
	body_mat.clearcoat_roughness = 0.08
	# Chassis
	_block(world, "VSCarChassis", pos + Vector3(0.0, 0.5, 0.0), Vector3(1.9, 0.8, 4.4), body_mat, true)
	# Cabin
	_mesh(world, "VSCarCabin", pos + Vector3(0.0, 1.15, -0.1), Vector3(1.7, 0.7, 2.4), body_mat)
	# Windows
	_mesh(world, "VSCarWindshield", pos + Vector3(0.0, 1.2, 0.9), Vector3(1.65, 0.6, 0.05), mats.get_material("tinted_glass"))
	_mesh(world, "VSCarRearGlass", pos + Vector3(0.0, 1.2, -1.1), Vector3(1.65, 0.6, 0.05), mats.get_material("tinted_glass"))
	_mesh(world, "VSCarSideGlassL", pos + Vector3(-0.84, 1.15, -0.1), Vector3(0.04, 0.5, 2.0), mats.get_material("tinted_glass"))
	_mesh(world, "VSCarSideGlassR", pos + Vector3(0.84, 1.15, -0.1), Vector3(0.04, 0.5, 2.0), mats.get_material("tinted_glass"))
	# Wheels (cylinders rotated along x)
	for wz in [-1.5, 1.5]:
		for wx in [-0.95, 0.95]:
			var wheel := MeshInstance3D.new()
			wheel.name = "VSCarWheel_%d_%d" % [int(wx * 10), int(wz * 10)]
			var cyl := CylinderMesh.new()
			cyl.top_radius = 0.35
			cyl.bottom_radius = 0.35
			cyl.height = 0.25
			wheel.mesh = cyl
			wheel.rotation_degrees = Vector3(0.0, 0.0, 90.0)
			var rim_mat := StandardMaterial3D.new()
			rim_mat.albedo_color = Color("0a0a0c")
			rim_mat.roughness = 0.4
			wheel.material_override = rim_mat
			wheel.position = pos + Vector3(wx, 0.35, wz)
			world.geometry_root.add_child(wheel)
	# Headlights
	_cylinder(world, "VSCarHeadlightL", pos + Vector3(-0.55, 0.65, 2.2), 0.12, 0.04, mats.get_material("lamp_bulb"))
	_cylinder(world, "VSCarHeadlightR", pos + Vector3(0.55, 0.65, 2.2), 0.12, 0.04, mats.get_material("lamp_bulb"))

static func _build_newsstand(world, mats, pos: Vector3) -> void:
	_block(world, "VSNewsstandBody", pos + Vector3(0.0, 1.1, 0.0), Vector3(2.0, 2.2, 1.4), mats.get_material("painted_brick_warm"))
	_mesh(world, "VSNewsstandRoof", pos + Vector3(0.0, 2.28, 0.3), Vector3(2.4, 0.12, 1.8), mats.get_material("black_lacquer"))
	_mesh(world, "VSNewsstandCounter", pos + Vector3(0.0, 1.1, 0.8), Vector3(1.8, 0.1, 0.4), mats.get_material("dark_wood"))
	_mesh(world, "VSNewsstandGlow", pos + Vector3(0.0, 2.0, -0.65), Vector3(1.6, 0.3, 0.04), mats.get_material("neon_cyan"))

# ------------------------------------------------------------------------
# Signage & extra neon on the district
# ------------------------------------------------------------------------

static func _build_signage(world, mats) -> void:
	# Curb-side blade signs hanging from the facades
	_mesh(world, "VSBladeSignHotel", Vector3(HOTEL_CROWN_X.x + 1.0, 5.5, FACADE_FRONT_Z - 0.6), Vector3(0.2, 1.6, 1.0), mats.get_material("signage_backing"))
	_mesh(world, "VSBladeSignHotelGlow", Vector3(HOTEL_CROWN_X.x + 1.0, 5.5, FACADE_FRONT_Z - 0.7), Vector3(0.06, 1.3, 0.8), mats.get_material("neon_cyan"))

	# Faint accent ground uplights along the facades
	for x in [HOTEL_CROWN_X.x + 1.0, HOTEL_CROWN_X.y - 1.0, CROWN_LOUNGE_X.x + 1.0, CROWN_LOUNGE_X.y - 1.0, BOUTIQUE_X.x + 1.0, BOUTIQUE_X.y - 1.0]:
		var up := SpotLight3D.new()
		up.name = "VSUplight_%d" % int(x * 10)
		up.position = Vector3(x, 0.3, FACADE_FRONT_Z - 0.4)
		up.rotation_degrees = Vector3(90.0, 0.0, 0.0)
		up.light_color = Color("ffc47a")
		up.light_energy = 2.0
		up.spot_range = 7.0
		up.spot_angle = 30.0
		up.shadow_enabled = false
		world.add_child(up)
		world.point_lights.append(up)

# ------------------------------------------------------------------------
# Particles: vent steam, fine street rain mist
# ------------------------------------------------------------------------

static func _spawn_atmospherics(world, mats) -> void:
	# Vent steam — rises from service grid vents
	var vent_positions = [-18.0, -10.0, -2.0, 5.0, 11.0]
	for i in range(vent_positions.size()):
		var vx = vent_positions[i]
		var steam := GPUParticles3D.new()
		steam.name = "VSVentSteam%d" % i
		steam.position = Vector3(vx, 2.2, SERVICE_BACK_Z - 0.3)
		steam.amount = 16
		steam.lifetime = 3.5
		steam.one_shot = false
		steam.explosiveness = 0.0
		steam.preprocess = 1.5
		steam.visibility_aabb = AABB(Vector3(-2.0, 0.0, -2.0), Vector3(4.0, 4.0, 4.0))
		var pm := ParticleProcessMaterial.new()
		pm.direction = Vector3(0.0, 1.0, 0.0)
		pm.spread = 10.0
		pm.initial_velocity_min = 0.3
		pm.initial_velocity_max = 0.6
		pm.gravity = Vector3(0.0, 0.2, 0.0)
		pm.scale_min = 0.6
		pm.scale_max = 1.4
		pm.color = Color(0.9, 0.92, 0.95, 0.25)
		steam.process_material = pm
		var dm := StandardMaterial3D.new()
		dm.albedo_color = Color(0.95, 0.96, 1.0, 0.35)
		dm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		dm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		dm.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
		var qm := QuadMesh.new()
		qm.size = Vector2(1.2, 1.2)
		qm.material = dm
		steam.draw_pass_1 = qm
		world.add_child(steam)

	# Street rain mist in front of the lounge
	var mist := GPUParticles3D.new()
	mist.name = "VSStreetRainMist"
	mist.position = Vector3(0.0, 2.5, -10.0)
	mist.amount = 120
	mist.lifetime = 2.5
	mist.one_shot = false
	mist.explosiveness = 0.0
	mist.preprocess = 1.0
	mist.visibility_aabb = AABB(Vector3(-22.0, 0.0, -12.0), Vector3(44.0, 5.0, 12.0))
	var rm := ParticleProcessMaterial.new()
	rm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	rm.emission_box_extents = Vector3(18.0, 2.0, 6.0)
	rm.direction = Vector3(0.0, -1.0, 0.0)
	rm.spread = 3.0
	rm.initial_velocity_min = 4.5
	rm.initial_velocity_max = 6.2
	rm.gravity = Vector3(0.0, -1.0, 0.0)
	rm.scale_min = 0.04
	rm.scale_max = 0.06
	rm.color = Color(0.75, 0.82, 0.95, 0.4)
	mist.process_material = rm
	var rmm := StandardMaterial3D.new()
	rmm.albedo_color = Color(0.8, 0.88, 1.0, 0.5)
	rmm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	rmm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	rmm.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	var rqm := QuadMesh.new()
	rqm.size = Vector2(0.02, 0.2)
	rqm.material = rmm
	mist.draw_pass_1 = rqm
	world.add_child(mist)

# ------------------------------------------------------------------------
# Extraction point: far east end of the Service Grid.
# ------------------------------------------------------------------------

static func _build_extraction(world, mats) -> void:
	var ex_pos = Vector3(18.0, 1.2, INTERIOR_BACK_Z + 2.0)
	# Door frame + door to safehouse
	_mesh(world, "VSSafehouseFrameL", Vector3(ex_pos.x - 0.9, 1.25, ex_pos.z - 0.1), Vector3(0.15, 2.5, 0.25), mats.get_material("chrome"))
	_mesh(world, "VSSafehouseFrameR", Vector3(ex_pos.x + 0.9, 1.25, ex_pos.z - 0.1), Vector3(0.15, 2.5, 0.25), mats.get_material("chrome"))
	_mesh(world, "VSSafehouseFrameTop", Vector3(ex_pos.x, 2.5, ex_pos.z - 0.1), Vector3(1.95, 0.2, 0.25), mats.get_material("chrome"))
	_mesh(world, "VSSafehouseDoor", Vector3(ex_pos.x, 1.15, ex_pos.z - 0.15), Vector3(1.6, 2.3, 0.1), mats.get_material("dark_wood"))
	# Small green pilot light
	_mesh(world, "VSSafehouseGreenLight", Vector3(ex_pos.x, 2.35, ex_pos.z - 0.22), Vector3(0.25, 0.12, 0.04), mats.get_material("neon_cyan"))

	var area := Area3D.new()
	area.name = "VelvetStripExtractionZone"
	area.position = ex_pos
	world.geometry_root.add_child(area)
	var cs := CollisionShape3D.new()
	var sh := BoxShape3D.new()
	sh.size = Vector3(2.6, 2.4, 2.6)
	cs.shape = sh
	area.add_child(cs)
	area.body_entered.connect(world._on_extraction_body_entered)
	area.body_exited.connect(world._on_extraction_body_exited)
	world.extraction_area = area

	var marker := MeshInstance3D.new()
	marker.name = "VelvetStripExtractionMarker"
	var cm := CylinderMesh.new()
	cm.top_radius = 0.3
	cm.bottom_radius = 0.3
	cm.height = 2.6
	marker.mesh = cm
	marker.material_override = mats.get_material("neon_cyan")
	marker.position = ex_pos + Vector3(0.0, 0.2, 0.4)
	marker.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	world.marker_root.add_child(marker)
	world.extraction_marker = marker

# ------------------------------------------------------------------------
# Shadow zones (stealth cover)
# ------------------------------------------------------------------------

static func _build_shadow_zones(world: Node3D) -> void:
	# Use layout_data (updated to Velvet Strip).
	for zone in world.LAYOUT_DATA.shadow_zones():
		var area := Area3D.new()
		area.name = "ShadowZone"
		area.set_script(world.SHADOW_ZONE_SCRIPT)
		area.position = zone["pos"]
		world.geometry_root.add_child(area)
		var cs := CollisionShape3D.new()
		var sh := BoxShape3D.new()
		sh.size = zone["size"]
		cs.shape = sh
		area.add_child(cs)
