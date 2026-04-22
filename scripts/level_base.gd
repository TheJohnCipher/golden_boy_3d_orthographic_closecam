@tool
extends Node2D

const GameConstants = preload("res://scripts/game_constants.gd")

## Click this in the Inspector to instantly restore the map as nodes
@export var build_prototype : bool = false : set = _set_build

func _set_build(_v: bool) -> void:
	for c in get_children(): c.free()
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

	# Create Perimeter Walls (North, South, West, East)
	_create_collision_rect("WallNorth", Rect2(20, 12, 600, 7))
	_create_collision_rect("WallSouth", Rect2(20, 606, 600, 7))
	_create_collision_rect("WallWest",  Rect2(12, 12, 7, 601))
	_create_collision_rect("WallEast",  Rect2(621, 12, 7, 601))

	# Create Structural Pillars
	var pillars = [Vector2(195, 210), Vector2(365, 210), Vector2(195, 315), Vector2(365, 315)]
	for i in range(pillars.size()):
		_create_collision_circle("Pillar_" + str(i), pillars[i], 9.0)
	
	# Create Stealth/Shadow Zones
	_create_logic_area("ShadowWest", GameConstants.R_WEST)
	_create_logic_area("ShadowEast", GameConstants.R_EAST)
	_create_logic_area("ShadowAlleyLeft", Rect2(100, 20, 122, 65))
	_create_logic_area("ShadowAlleyRight", Rect2(418, 20, 122, 65))
	
	# Create Extraction Zone
	_create_logic_area("ExtractionZone", Rect2(GameConstants.EXTRACTION_POS - Vector2(30,24), Vector2(60, 48)))

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
