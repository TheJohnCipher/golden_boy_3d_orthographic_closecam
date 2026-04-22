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
	
	# --- ADVANCED ARCHITECTURE (Archways & Entrances) ---
	_create_archway("FoyerEntrance", Vector2(260, 370), 120.0)
	_create_archway("MainHallEntrance", Vector2(200, 150), 240.0)

	# --- GALLERY ART (Main Hall Decor) ---
	_create_painting("Art_1", Vector2(150, 150), Vector2(30, 20), Color("#7b1fa2"))
	_create_painting("Art_2", Vector2(300, 150), Vector2(40, 25), Color("#1b5e20"))
	_create_painting("Art_3", Vector2(450, 150), Vector2(25, 30), Color("#b71c1c"))

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
	
	# --- FLOORING & AMBIENT OCCLUSION ---
	_add_room_flooring(n_name, rect, color)
	_add_surface_texture(n_name + "FloorTex", rect, color.darkened(0.05), 40)
	
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
	
	# --- VERTICAL GRADIENT (Lighter at top, darker at bottom) ---
	face.vertex_colors = PackedColorArray([
		GameConstants.C_WALL_FACE.lightened(0.05),
		GameConstants.C_WALL_FACE.lightened(0.05),
		GameConstants.C_WALL_FACE.darkened(0.08),
		GameConstants.C_WALL_FACE.darkened(0.08)
	])
	add_child(face)
	if Engine.is_editor_hint(): face.owner = self

	# Wall Grit/Texture
	var wall_rect = Rect2(rect.position.x, rect.end.y, rect.size.x, h)
	_add_surface_texture(n_name + "WallGrit", wall_rect, GameConstants.C_WALL_FACE.darkened(0.15), 30)

	# Wall Pilasters (Structural vertical beams)
	for x in range(int(rect.position.x) + 60, int(rect.end.x), 120):
		_create_pilaster(n_name + "Pilaster_" + str(x), Vector2(x, rect.end.y), h)

	# --- CORNER OCCLUSION (Subtle vertical shadows at room edges) ---
	_create_detail_rect(n_name + "L_AO", Rect2(rect.position.x, rect.end.y, 6, h), Color(0, 0, 0, 0.12))
	_create_detail_rect(n_name + "R_AO", Rect2(rect.end.x - 6, rect.end.y, 6, h), Color(0, 0, 0, 0.12))
	
	# Crown Molding (The ornate trim at the top of the wall face)
	var molding = Line2D.new()
	molding.name = n_name + "CrownMolding"
	molding.points = PackedVector2Array([
		rect.position, 
		Vector2(rect.end.x, rect.position.y)
	])
	molding.width = 2.0
	molding.default_color = GameConstants.C_WALL_FACE.lightened(0.08)
	add_child(molding)
	if Engine.is_editor_hint(): molding.owner = self

	# --- ARCHITECTURAL ORNAMENTATION ---
	_add_wall_decor(n_name, rect, h)
	
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
	var line = Line2D.new()
	line.name = l_name
	line.points = PackedVector2Array([from, to])
	line.width = 1.5
	line.default_color = color
	add_child(line)
	if Engine.is_editor_hint(): line.owner = self

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

func _add_wall_decor(n_name: String, rect: Rect2, h: float) -> void:
	# Rooms that get interior paneling/wainscoting
	var is_interior = n_name.contains("MainHall") or n_name.contains("EastWing") or n_name.contains("WestWing") or n_name.contains("Foyer")
	
	if is_interior:
		# Wainscoting (Lower wall paneling)
		var w_h = h * 0.45
		var wainscot = Polygon2D.new()
		wainscot.name = n_name + "Wainscot"
		wainscot.polygon = PackedVector2Array([
			Vector2(rect.position.x, rect.end.y + h - w_h), Vector2(rect.end.x, rect.end.y + h - w_h),
			Vector2(rect.end.x, rect.end.y + h), Vector2(rect.position.x, rect.end.y + h)
		])
		wainscot.color = GameConstants.C_WALL_FACE.darkened(0.12)
		add_child(wainscot)
		if Engine.is_editor_hint(): wainscot.owner = self
		
		# Sub-panels inside Wainscoting
		var p_w = 32.0
		for x in range(int(rect.position.x) + 12, int(rect.end.x) - 12, int(p_w + 8)):
			var p_rect = Rect2(x, rect.end.y + h - w_h + 6, p_w, w_h - 12)
			var panel = Polygon2D.new()
			panel.polygon = _get_chamfered_rect_pts(p_rect, 2.0)
			panel.color = GameConstants.C_WALL_FACE.darkened(0.18)
			add_child(panel)
			if Engine.is_editor_hint(): panel.owner = self
		
		# Chair Rail (The trim line at the top of the wainscot)
		_create_detail_line(n_name + "ChairRail", Vector2(rect.position.x, rect.end.y + h - w_h), Vector2(rect.end.x, rect.end.y + h - w_h), GameConstants.C_WALL_FACE.lightened(0.05), 1.5)

func _create_archway(l_name: String, pos: Vector2, width: float) -> void:
	var h = GameConstants.WALL_FACE_H * 0.5
	var bracket_w = 12.0
	
	# Left Bracket
	_create_visual_rect(l_name + "L", Rect2(pos.x, pos.y, bracket_w, h), GameConstants.C_WALL_FACE, false)
	# Right Bracket
	_create_visual_rect(l_name + "R", Rect2(pos.x + width - bracket_w, pos.y, bracket_w, h), GameConstants.C_WALL_FACE, false)
	# Lintel Beam
	_create_visual_rect(l_name + "Beam", Rect2(pos.x, pos.y, width, 6), GameConstants.C_WALL_FACE.lightened(0.05), false)

func _create_pilaster(p_name: String, pos: Vector2, height: float) -> void:
	var w = 8.0
	var face = Polygon2D.new()
	face.name = p_name
	face.polygon = PackedVector2Array([
		pos + Vector2(-w/2, 0), pos + Vector2(w/2, 0),
		pos + Vector2(w/2, height), pos + Vector2(-w/2, height)
	])
	face.color = GameConstants.C_WALL_FACE.lightened(0.03)
	add_child(face)
	if Engine.is_editor_hint(): face.owner = self
	
	# Side highlights for the pilaster depth
	_create_detail_line(p_name + "_L", pos + Vector2(-w/2, 0), pos + Vector2(-w/2, height), GameConstants.C_WALL_FACE.lightened(0.1))
	_create_detail_line(p_name + "_R", pos + Vector2(w/2, 0), pos + Vector2(w/2, height), GameConstants.C_WALL_FACE.darkened(0.1))

func _create_painting(p_name: String, pos: Vector2, size: Vector2, art_color: Color) -> void:
	# Frame
	var frame = Polygon2D.new()
	frame.name = p_name + "_Frame"
	var f_rect = Rect2(pos.x, pos.y, size.x, size.y)
	frame.polygon = _get_chamfered_rect_pts(f_rect, 2.0)
	frame.color = Color("#3e2723") # Dark wood
	add_child(frame)
	if Engine.is_editor_hint(): frame.owner = self
	
	# Canvas
	var canvas = Polygon2D.new()
	canvas.name = p_name + "_Canvas"
	var c_rect = Rect2(pos.x + 2, pos.y + 2, size.x - 4, size.y - 4)
	canvas.polygon = _get_chamfered_rect_pts(c_rect, 1.0)
	canvas.color = art_color
	add_child(canvas)
	if Engine.is_editor_hint(): canvas.owner = self
	
	# Subtle spotlight hit
	var shine = Polygon2D.new()
	shine.polygon = PackedVector2Array([
		Vector2(pos.x + 2, pos.y + 2), Vector2(pos.x + size.x - 4, pos.y + 2),
		Vector2(pos.x + 2, pos.y + size.y - 4)
	])
	shine.color = Color(1, 1, 1, 0.1)
	add_child(shine)
	if Engine.is_editor_hint(): shine.owner = self

# --- NEW HELPER FUNCTIONS FOR SHAPE & TEXTURE ---

func _add_surface_texture(t_name: String, rect: Rect2, color: Color, count: int) -> void:
	var parent = Node2D.new(); parent.name = t_name; add_child(parent)
	if Engine.is_editor_hint(): parent.owner = self
	for i in range(count):
		var p = rect.position + Vector2(randf() * rect.size.x, randf() * rect.size.y)
		_create_tiny_dot_parented(parent, t_name + "_" + str(i), p, color)

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

func _create_detail_rect(r_name: String, rect: Rect2, color: Color) -> void:
	var poly = Polygon2D.new()
	poly.name = r_name
	poly.polygon = PackedVector2Array([
		rect.position, Vector2(rect.end.x, rect.position.y),
		rect.end, Vector2(rect.position.x, rect.end.y)
	])
	poly.color = color
	add_child(poly)
	if Engine.is_editor_hint(): poly.owner = self

func _create_tiny_dot(d_name: String, pos: Vector2, color: Color) -> void:
	var dot = Polygon2D.new()
	dot.name = d_name
	dot.polygon = PackedVector2Array([
		pos + Vector2(-1,-1), pos + Vector2(1,-1), pos + Vector2(1,1), pos + Vector2(-1,1)
	])
	dot.color = color
	add_child(dot)
	if Engine.is_editor_hint(): dot.owner = self

func _create_tiny_dot_parented(parent: Node, d_name: String, pos: Vector2, color: Color) -> void:
	var dot = Polygon2D.new()
	dot.name = d_name
	dot.polygon = PackedVector2Array([
		pos + Vector2(-1,-1), pos + Vector2(1,-1), pos + Vector2(1,1), pos + Vector2(-1,1)
	])
	dot.color = color
	parent.add_child(dot)
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
