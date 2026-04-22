@tool
extends Node2D

const GameConstants = preload("res://scripts/game_constants.gd")

## Click this in the Inspector to instantly restore the map as nodes
@export var build_prototype : bool = false : set = _set_build

func _set_build(v: bool) -> void:
	build_prototype = v
	# Prevent running setter logic if we are just loading the scene
	if not is_inside_tree(): return
	
	# Safe way to clear children in tool scripts: iterate over a copy of the list
	for c in get_children():
		c.free()
	
	if v:
		_generate_geometry()

func _ready() -> void:
	if not Engine.is_editor_hint():
		var world = get_parent()
		if world:
			_hook_up_logic(world)
	elif get_child_count() == 0:
		_generate_geometry()

func _hook_up_logic(world: Node) -> void:
	for child in get_children():
		if child is Area2D:
			if child.name.begins_with("Shadow"):
				child.body_entered.connect(world._on_shadow_entered)
				child.body_exited.connect(world._on_shadow_exited)
			elif child.name == "ExtractionZone":
				child.body_entered.connect(world._on_extract_entered)
				child.body_exited.connect(world._on_extract_exited)
				world.extraction_area = child
				world.extraction_marker = get_node_or_null("ExtractionMarker")

func _generate_geometry() -> void:
	var rooms = [
		["Alley", GameConstants.R_ALLEY, GameConstants.C_ALLEY],
		["BackHall", GameConstants.R_BACK_HALL, GameConstants.C_BACK_HALL],
		["WestWing", GameConstants.R_WEST, GameConstants.C_WEST],
		["MainHall", GameConstants.R_MAIN_HALL, GameConstants.C_MAIN_HALL],
		["EastWing", GameConstants.R_EAST, GameConstants.C_EAST],
		["Foyer", GameConstants.R_FOYER, GameConstants.C_FOYER],
		["Plaza", GameConstants.R_PLAZA, GameConstants.C_PLAZA]
	]
	
	for data in rooms:
		_create_room_nodes(data[0], data[1], data[2])
	
	# --- ARCHITECTURAL HEADERS (Lintels) ---
	# These connect room tops over openings to create "doorways"
	_create_lintel("FoyerEntrance", Rect2(260, 370, 120, 10))
	_create_lintel("MainHallEntrance", Rect2(200, 150, 240, 10))

	# --- MAP DESIGN REFINEMENT: INTERIOR & COVER ---
	
	# 1. Alley: Industrial Clutter (Hiding Spots)
	# Forces player to weave between obstacles instead of running a straight line.
	_create_collision_rect("AlleyDumpster_1", Rect2(150, 20, 40, 30))
	_create_visual_rect("AlleyDumpster_1_Vis", Rect2(150, 20, 40, 30), Color("#2a303b"), true)
	_create_collision_rect("AlleyCrates", Rect2(380, 45, 30, 40))
	_create_visual_rect("AlleyCrates_Vis", Rect2(380, 45, 30, 40), Color("#3d2e20"), true)

	# 2. Back Hall: Service Alcove (Closet)
	_create_collision_rect("ServiceAlcove", Rect2(480, 85, 60, 45))
	_create_visual_rect("ServiceAlcove_Vis", Rect2(480, 85, 60, 45), GameConstants.C_WALL_FACE, true)

	# 3. West Wing (Cafe): Counter and Seating
	_create_collision_rect("CafeCounter", Rect2(30, 180, 15, 100))
	_create_visual_rect("CafeCounter_Vis", Rect2(30, 180, 15, 100), Color("#3e2723"), true)
	_create_visual_circle("CafeTable_1", Vector2(85, 210), 10.0, Color("#1c1420"))
	_create_visual_circle("CafeTable_2", Vector2(85, 290), 10.0, Color("#1c1420"))

	# 4. Main Hall (Gallery): Central Hub and Art Displays
	# Adding a central divider to break line of sight in the middle of the room.
	_create_collision_rect("CentralDisplay", Rect2(280, 240, 80, 30))
	_create_visual_rect("CentralDisplay_Vis", Rect2(280, 240, 80, 30), Color("#455a64"), true)
	_create_visual_circle("ArtPedestal_1", Vector2(180, 190), 8.0, Color("#cfd8dc"))
	_create_visual_circle("ArtPedestal_2", Vector2(460, 190), 8.0, Color("#cfd8dc"))

	# 5. East Wing (Hotel): Reception Desk
	_create_collision_rect("ReceptionDesk", Rect2(480, 220, 80, 20))
	_create_visual_rect("ReceptionDesk_Vis", Rect2(480, 220, 80, 20), Color("#263238"), true)

	# 6. Plaza (Public South): Kiosks and Benches
	_create_collision_rect("NewsKiosk", Rect2(450, 500, 45, 45))
	_create_visual_rect("NewsKiosk_Vis", Rect2(450, 500, 45, 45), Color("#1a1a2e"), true)
	_create_collision_rect("PlazaBench_1", Rect2(120, 520, 60, 12))
	_create_visual_rect("PlazaBench_1_Vis", Rect2(120, 520, 60, 12), Color("#4e342e"), true)
	_create_collision_rect("PlazaBench_2", Rect2(240, 520, 60, 12))
	_create_visual_rect("PlazaBench_2_Vis", Rect2(240, 520, 60, 12), Color("#4e342e"), true)

	# Restore Neon Strips
	_create_neon_strip("NeonPink", Vector2(120, 165), Vector2(480, 165), GameConstants.C_NEON_PINK)
	_create_neon_strip("NeonCyan", Vector2(120, 358), Vector2(480, 358), GameConstants.C_NEON_CYAN)
	_create_neon_strip("NeonAmb",  Vector2(100, 88),  Vector2(540, 88),  GameConstants.C_NEON_AMB)

	# Create Perimeter Walls (North, South, West, East)
	_create_collision_rect("WallNorth", Rect2(20, 12, 600, 7))
	_create_collision_rect("WallSouth", Rect2(20, 606, 600, 7))
	_create_collision_rect("WallWest",  Rect2(12, 12, 7, 601))
	_create_collision_rect("WallEast",  Rect2(621, 12, 7, 601))

	# Create Structural Pillars
	var pillars = [Vector2(195, 210), Vector2(365, 210), Vector2(195, 315), Vector2(365, 315)]
	for i in range(pillars.size()):
		_create_collision_circle("Pillar_" + str(i), pillars[i], 9.0)
		_create_visual_circle("PillarVis_" + str(i), pillars[i], 9.0, Color("#1c2030"))
		_create_pillar_face("PillarFace_" + str(i), pillars[i], 9.0)

	# Create some furniture props (Tables in Main Hall)
	var tables = [Vector2(175, 220), Vector2(175, 310), Vector2(320, 190), Vector2(320, 340)]
	for i in range(tables.size()):
		_create_visual_circle("Table_" + str(i), tables[i], 10.0, Color("#1c1420"))
	
	# Create Stealth/Shadow Zones
	_create_logic_area("ShadowWest", GameConstants.R_WEST)
	_create_logic_area("ShadowEast", GameConstants.R_EAST)
	_create_logic_area("ShadowAlleyLeft", Rect2(100, 20, 122, 65))
	_create_logic_area("ShadowAlleyRight", Rect2(418, 20, 122, 65))
	
	# Create Extraction Zone
	_create_logic_area("ExtractionZone", Rect2(GameConstants.EXTRACTION_POS - Vector2(30,24), Vector2(60, 48)))
	_create_visual_marker("ExtractionMarker", GameConstants.EXTRACTION_POS)

func _create_room_nodes(n_name: String, rect: Rect2, color: Color) -> void:
	var poly = Polygon2D.new()
	poly.name = n_name + "Floor"
	poly.polygon = PackedVector2Array([
		rect.position, Vector2(rect.end.x, rect.position.y),
		rect.end, Vector2(rect.position.x, rect.end.y)
	])
	poly.color = color
	add_child(poly)
	if Engine.is_editor_hint(): poly.owner = self
	
	# --- MATERIAL SPECIFIC FLOORING ---
	_add_room_flooring(n_name, rect, color)
	
	# Wall Shadow (Ambient Occlusion on the floor where it hits the wall)
	var shadow = Polygon2D.new()
	shadow.name = n_name + "WallShadow"
	var sh_h = 4.0
	shadow.polygon = PackedVector2Array([
		Vector2(rect.position.x, rect.end.y - sh_h), Vector2(rect.end.x, rect.end.y - sh_h),
		Vector2(rect.end.x, rect.end.y), Vector2(rect.position.x, rect.end.y)
	])
	shadow.color = Color(0, 0, 0, 0.15)
	add_child(shadow)
	if Engine.is_editor_hint(): shadow.owner = self

	var face = Polygon2D.new()
	face.name = n_name + "WallFace"
	var h = GameConstants.WALL_FACE_H
	face.polygon = PackedVector2Array([
		Vector2(rect.position.x, rect.end.y), Vector2(rect.end.x, rect.end.y),
		Vector2(rect.end.x, rect.end.y + h), Vector2(rect.position.x, rect.end.y + h)
	])
	face.color = GameConstants.C_WALL_FACE
	add_child(face)
	if Engine.is_editor_hint(): face.owner = self
	
	# --- NORTH WINDOW LIGHT SHAFTS ---
	if n_name != "Alley" and n_name != "Plaza":
		for i in range(2):
			var wx = rect.position.x + (rect.size.x * (0.3 + i * 0.4))
			var w_rect = Rect2(wx - 20, rect.position.y, 40, rect.size.y * 0.4)
			var shaft = Polygon2D.new()
			shaft.polygon = PackedVector2Array([w_rect.position, Vector2(w_rect.end.x, w_rect.position.y), Vector2(w_rect.end.x + 20, w_rect.end.y), Vector2(w_rect.position.x - 20, w_rect.end.y)])
			shaft.color = Color(1, 1, 1, 0.03) # Very subtle dust/light
			add_child(shaft)
			if Engine.is_editor_hint(): shaft.owner = self
	
	# Wall Top (The thickness/rim of the wall)
	var top = Polygon2D.new()
	top.name = n_name + "WallTop"
	var t_h = 4.0
	top.polygon = PackedVector2Array([
		rect.position, Vector2(rect.end.x, rect.position.y),
		Vector2(rect.end.x, rect.position.y - t_h), Vector2(rect.position.x, rect.position.y - t_h)
	])
	top.color = GameConstants.C_WALL_FACE.lightened(0.1)
	add_child(top)
	if Engine.is_editor_hint(): top.owner = self
	
	# --- SIDE WALLS (Depth for West/East boundaries) ---
	var side_w = 4.0
	# West Wall Depth
	var w_face = Polygon2D.new()
	w_face.name = n_name + "WestDepth"
	w_face.polygon = PackedVector2Array([
		rect.position, Vector2(rect.position.x - side_w, rect.position.y + h),
		Vector2(rect.position.x - side_w, rect.end.y + h), Vector2(rect.position.x, rect.end.y)
	])
	w_face.color = GameConstants.C_WALL_FACE.darkened(0.1)
	add_child(w_face)
	if Engine.is_editor_hint(): w_face.owner = self
	
	# East Wall Depth
	var e_face = Polygon2D.new()
	e_face.name = n_name + "EastDepth"
	e_face.polygon = PackedVector2Array([
		Vector2(rect.end.x, rect.position.y), Vector2(rect.end.x + side_w, rect.position.y + h),
		Vector2(rect.end.x + side_w, rect.end.y + h), Vector2(rect.end.x, rect.end.y)
	])
	e_face.color = GameConstants.C_WALL_FACE.darkened(0.1)
	add_child(e_face)
	if Engine.is_editor_hint(): e_face.owner = self
	
	# --- WALL PANELING (Vertical seams every 40px) ---
	for x in range(int(rect.position.x) + 40, int(rect.end.x), 40):
		_create_detail_line(n_name + "Panel_" + str(x), Vector2(x, rect.end.y), Vector2(x, rect.end.y + h), GameConstants.C_WALL_FACE.darkened(0.15))
	
	# Baseboard (Dark line at the very bottom of the wall face)
	_create_detail_line(n_name + "Baseboard", Vector2(rect.position.x, rect.end.y + h), Vector2(rect.end.x, rect.end.y + h), GameConstants.C_WALL_FACE.darkened(0.3), 2.0)

	# Wall Cap/Trim (A thin highlight line at the top of the wall face)
	var trim = Line2D.new()
	trim.name = n_name + "WallTrim"
	trim.points = PackedVector2Array([
		Vector2(rect.position.x, rect.end.y), 
		Vector2(rect.end.x, rect.end.y)
	])
	trim.width = 1.0
	trim.default_color = GameConstants.C_WALL_FACE.lightened(0.15)
	add_child(trim)
	if Engine.is_editor_hint(): trim.owner = self

func _create_visual_rect(v_name: String, rect: Rect2, color: Color, add_face: bool = false) -> void:
	var chamfer = 4.0
	
	# Floor Shadow (Cast North-West to ground the object)
	var sh = Polygon2D.new()
	sh.name = v_name + "_Shadow"
	sh.polygon = _get_chamfered_rect_pts(Rect2(rect.position + Vector2(-2, -2), rect.size), chamfer)
	sh.color = Color(0, 0, 0, 0.25)
	add_child(sh)
	if Engine.is_editor_hint(): sh.owner = self

	var poly = Polygon2D.new()
	poly.name = v_name
	poly.polygon = _get_chamfered_rect_pts(rect, chamfer)
	poly.color = color
	add_child(poly)
	if Engine.is_editor_hint(): poly.owner = self
	
	if add_face:
		var face = Polygon2D.new()
		face.name = v_name + "_Face"
		var h = GameConstants.WALL_FACE_H * 0.5 # Props are shorter than walls
		face.polygon = PackedVector2Array([
			Vector2(rect.position.x, rect.end.y), Vector2(rect.end.x, rect.end.y),
			Vector2(rect.end.x, rect.end.y + h), Vector2(rect.position.x, rect.end.y + h)
		])
		face.color = color.darkened(0.2)
		add_child(face)
		if Engine.is_editor_hint(): face.owner = self
		
		# Top Bevel (Sell the 3D edge)
		var bevel = Line2D.new()
		bevel.name = v_name + "_Bevel"
		bevel.points = PackedVector2Array([
			Vector2(rect.position.x, rect.end.y), Vector2(rect.end.x, rect.end.y)
		])
		bevel.width = 1.0
		bevel.default_color = color.lightened(0.1)
		add_child(bevel)
		if Engine.is_editor_hint(): bevel.owner = self

func _create_neon_strip(l_name: String, from: Vector2, to: Vector2, color: Color) -> void:
	var container = Node2D.new()
	container.name = l_name
	add_child(container)
	if Engine.is_editor_hint(): container.owner = self

	var line = Line2D.new()
	line.points = PackedVector2Array([from, to])
	line.width = 2.0
	line.default_color = color
	container.add_child(line)
	if Engine.is_editor_hint(): line.owner = self

	# Add a glow/light effect using a PointLight2D
	var light = PointLight2D.new()
	light.color = color
	light.energy = 0.8
	light.blend_mode = Light2D.BLEND_MODE_ADD
	light.position = (from + to) / 2.0
	
	# Create a procedural glow texture
	var tex = GradientTexture2D.new()
	tex.fill = GradientTexture2D.FILL_RADIAL
	tex.fill_from = Vector2(0.5, 0.5)
	tex.gradient = Gradient.new()
	tex.gradient.set_color(0, Color(1, 1, 1, 1))
	tex.gradient.set_color(1, Color(1, 1, 1, 0))
	light.texture = tex
	light.texture_scale = (from.distance_to(to) / 64.0)
	container.add_child(light)
	if Engine.is_editor_hint(): light.owner = self

func _create_visual_circle(v_name: String, pos: Vector2, radius: float, color: Color) -> void:
	var poly = Polygon2D.new()
	poly.name = v_name
	var pts = PackedVector2Array()
	for i in range(16):
		var a = TAU * i / 16.0
		pts.append(pos + Vector2(cos(a), sin(a)) * radius)
	poly.polygon = pts
	poly.color = color
	add_child(poly)
	if Engine.is_editor_hint(): poly.owner = self
	
	# Inner Rim for circles (Pillars/Tables)
	var rim = Polygon2D.new()
	rim.name = v_name + "_Rim"
	var pts_rim = PackedVector2Array()
	for i in range(16):
		var a = TAU * i / 16.0
		pts_rim.append(pos + Vector2(cos(a), sin(a)) * (radius * 0.8))
	rim.polygon = pts_rim
	rim.color = color.lightened(0.05)
	add_child(rim)
	if Engine.is_editor_hint(): rim.owner = self

func _create_pillar_face(f_name: String, pos: Vector2, radius: float) -> void:
	var face = Polygon2D.new()
	face.name = f_name
	var h = GameConstants.WALL_FACE_H
	# A simple vertical face representing the "front" of the pillar
	face.polygon = PackedVector2Array([
		Vector2(pos.x - radius, pos.y), Vector2(pos.x + radius, pos.y),
		Vector2(pos.x + radius, pos.y + h), Vector2(pos.x - radius, pos.y + h)
	])
	face.color = GameConstants.C_WALL_FACE
	add_child(face)
	if Engine.is_editor_hint(): face.owner = self
	
	# Pillar Cap (The dark top edge where the pillar meets the ceiling)
	var cap = Line2D.new()
	cap.name = f_name + "_Cap"
	cap.points = PackedVector2Array([Vector2(pos.x - radius, pos.y), Vector2(pos.x + radius, pos.y)])
	cap.width = 1.5
	cap.default_color = GameConstants.C_WALL_FACE.lightened(0.2)
	add_child(cap)
	if Engine.is_editor_hint(): cap.owner = self

# --- ARCHITECTURAL HELPERS ---

func _create_lintel(l_name: String, rect: Rect2) -> void:
	var h = GameConstants.WALL_FACE_H * 0.4 # Lintel is shorter than full wall
	var poly = Polygon2D.new()
	poly.name = l_name + "_Face"
	poly.polygon = PackedVector2Array([
		rect.position, Vector2(rect.end.x, rect.position.y),
		Vector2(rect.end.x, rect.position.y + h), Vector2(rect.position.x, rect.position.y + h)
	])
	poly.color = GameConstants.C_WALL_FACE.darkened(0.05)
	add_child(poly)
	if Engine.is_editor_hint(): poly.owner = self

# --- NEW HELPER FUNCTIONS FOR SHAPE & TEXTURE ---

func _add_room_flooring(n_name: String, rect: Rect2, color: Color) -> void:
	var detail_color = color.darkened(0.15)
	
	if n_name.contains("Alley"):
		# Concrete: Random cracks
		for i in range(5):
			var start = rect.position + Vector2(randf() * rect.size.x, randf() * rect.size.y)
			var end = start + Vector2(randf_range(-20, 20), randf_range(-20, 20))
			_create_detail_line(n_name + "Crack_" + str(i), start, end, detail_color, 0.5)
	
	elif n_name.contains("MainHall") or n_name.contains("Foyer"):
		# Grand Gallery: Diamond Tiles
		var step = 32.0
		for x in range(int(rect.position.x), int(rect.end.x), int(step)):
			for y in range(int(rect.position.y), int(rect.end.y), int(step)):
				if (int(x/step) + int(y/step)) % 2 == 0:
					var tile = Polygon2D.new()
					tile.name = n_name + "Tile_" + str(x) + "_" + str(y)
					tile.polygon = _get_chamfered_rect_pts(Rect2(x+4, y+4, step-8, step-8), 2.0)
					tile.color = detail_color
					add_child(tile)
					if Engine.is_editor_hint(): tile.owner = self
					
	elif n_name.contains("WestWing"):
		# Cafe: Wood Planks
		var p_h = 12.0
		for y in range(int(rect.position.y), int(rect.end.y), int(p_h)):
			_create_detail_line(n_name + "Plank_" + str(y), Vector2(rect.position.x, y), Vector2(rect.end.x, y), detail_color)
			
	elif n_name.contains("EastWing"):
		# Hotel: Plush Stipple
		for i in range(20):
			var p = rect.position + Vector2(randf() * rect.size.x, randf() * rect.size.y)
			_create_tiny_dot(n_name + "Stipple_" + str(i), p, detail_color)
	
	else:
		# Default Grid
		var grid = 64.0
		for x in range(int(rect.position.x), int(rect.end.x), int(grid)):
			_create_detail_line(n_name + "V_" + str(x), Vector2(x, rect.position.y), Vector2(x, rect.end.y), detail_color)

func _get_chamfered_rect_pts(rect: Rect2, r: float) -> PackedVector2Array:
	return PackedVector2Array([
		rect.position + Vector2(r, 0), Vector2(rect.end.x - r, rect.position.y),
		Vector2(rect.end.x, rect.position.y + r), Vector2(rect.end.x, rect.end.y - r),
		rect.end - Vector2(r, 0), Vector2(rect.position.x + r, rect.end.y),
		Vector2(rect.position.x, rect.end.y - r), Vector2(rect.position.x, rect.position.y + r)
	])

func _create_detail_line(l_name: String, start: Vector2, end: Vector2, color: Color, width: float = 1.0) -> void:
	var line = Line2D.new()
	line.name = l_name
	line.points = PackedVector2Array([start, end])
	line.width = width
	line.default_color = color
	add_child(line)
	if Engine.is_editor_hint(): line.owner = self

func _create_tiny_dot(d_name: String, pos: Vector2, color: Color) -> void:
	var dot = Polygon2D.new()
	dot.name = d_name
	dot.polygon = PackedVector2Array([
		pos + Vector2(-1,-1), pos + Vector2(1,-1), pos + Vector2(1,1), pos + Vector2(-1,1)
	])
	dot.color = color
	add_child(dot)
	if Engine.is_editor_hint(): dot.owner = self

func _create_visual_marker(m_name: String, pos: Vector2) -> void:
	var marker = Node2D.new()
	marker.name = m_name
	marker.position = pos
	# Add a small pulse visual
	var pulse = Polygon2D.new()
	pulse.name = "Pulse"
	var pts = PackedVector2Array()
	for i in range(8):
		var a = TAU * i / 8.0
		pts.append(Vector2(cos(a), sin(a)) * 10.0)
	pulse.polygon = pts
	pulse.color = Color(0.2, 1.0, 0.4, 0.4)
	marker.add_child(pulse)
	add_child(marker)
	if Engine.is_editor_hint(): marker.owner = self; pulse.owner = self

func _create_collision_rect(p_name: String, rect: Rect2) -> void:
	var body = StaticBody2D.new()
	body.name = p_name
	body.position = rect.get_center()
	var cs = CollisionShape2D.new()
	var sh = RectangleShape2D.new()
	sh.size = rect.size
	cs.shape = sh
	body.add_child(cs)
	add_child(body)
	if Engine.is_editor_hint():
		body.owner = self
		cs.owner = self

func _create_collision_circle(p_name: String, pos: Vector2, radius: float) -> void:
	var body = StaticBody2D.new()
	body.name = p_name
	body.position = pos
	var cs = CollisionShape2D.new()
	var sh = CircleShape2D.new()
	sh.radius = radius
	cs.shape = sh
	body.add_child(cs)
	add_child(body)
	if Engine.is_editor_hint():
		body.owner = self
		cs.owner = self

func _create_logic_area(a_name: String, rect: Rect2) -> void:
	var area = Area2D.new()
	area.name = a_name
	area.position = rect.get_center()
	var cs = CollisionShape2D.new()
	var sh = RectangleShape2D.new()
	sh.size = rect.size
	cs.shape = sh
	area.add_child(cs)
	add_child(area)
	if Engine.is_editor_hint():
		area.owner = self
		cs.owner = self
