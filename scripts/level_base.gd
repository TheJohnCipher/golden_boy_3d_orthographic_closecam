@tool
extends Node2D

const GameConstants = preload("res://scripts/game_constants.gd")
const AssetGenerator = preload("res://scripts/asset_generator.gd")
const Manifest = preload("res://scripts/Manifest.gd")
const WorldManager = preload("res://scripts/world_manager.gd")

# ── Engine Skeleton Roots ──
var floor_base    : Node2D
var floor_decor   : Node2D
var ysort_container : Node2D
var city_manager : Node2D

var _is_building := false
@export var build_prototype : bool = false : set = _set_build

func _set_build(v: bool) -> void:
	if _is_building:
		return

	_is_building = true
	build_prototype = false # Force the checkbox to reset so it doesn't "stick" and save as true
	if not Engine.is_editor_hint() or not is_inside_tree():
		_is_building = false
		return
	for c in get_children():
		if is_instance_valid(c) and not c.is_queued_for_deletion():
			c.queue_free()
	if v:
		await get_tree().process_frame
		if is_instance_valid(self):
			_generate_level()
	_is_building = false

func _ready() -> void:
	_setup_city_manager()
	# Removed the auto-generation check that was causing nodes to "come back" in the editor.
	if not Engine.is_editor_hint():
		_generate_level()

func _generate_level() -> void:
	# ── 1. Create Mandatory Hierarchy ──
	_create_skeleton()
	
	# ── 2. Data-Driven City Population ──
	# We stop placing the cottage floor so the City Engine streets are visible
	# _place_floor_tiles()

	# _instance_architecture() # Disabled: using manual scene sprites instead
	
	_instance_prefabs()      # Handles static props
	_generate_zones()
	print("ARCHITECTURE: Level successfully generated from GameConstants data.")

func _setup_city_manager() -> void:
	city_manager = get_node_or_null("CityWorldManager")
	if not city_manager:
		city_manager = WorldManager.new()
		city_manager.name = "CityWorldManager"
		add_child(city_manager)
		
	if Engine.is_editor_hint() and get_tree():
		var root = get_tree().edited_scene_root
		if root: city_manager.owner = root

func _create_skeleton() -> void:
	floor_base = Node2D.new(); floor_base.name = "Floor_Base"
	add_child(floor_base)
	
	floor_decor = Node2D.new(); floor_decor.name = "Floor_Decor"
	floor_decor.z_index = -1
	add_child(floor_decor)
	
	ysort_container = Node2D.new(); ysort_container.name = "YSort_Container"
	ysort_container.y_sort_enabled = true # IMPORTANT: Mandatory for depth
	add_child(ysort_container)
	
	if Engine.is_editor_hint():
		floor_base.owner = self
		floor_decor.owner = self
		ysort_container.owner = self

func _get_clean_path(path: String) -> String:
	var p = path.strip_edges()
	# Bulletproof cleaning: handle trailing dots and case sensitivity
	while p.ends_with("."): p = p.left(p.length() - 1)
	
	while p.to_lower().ends_with(".png.png"): p = p.left(p.length() - 4)
	while p.to_lower().ends_with(".tscn.tscn"): p = p.left(p.length() - 5)
	
	return p

func _place_floor_tiles() -> void:
	# Place a Sprite2D representing floor texture instead of a Polygon2D
	var room = Sprite2D.new()
	var path := _get_clean_path(GameConstants.T_FLOOR_WOOD)
	
	var tex = null
	if FileAccess.file_exists(path):
		tex = load(path)
	
	if not tex:
		push_warning("SYSTEM: Asset %s not found. Generating procedural wood floor." % path)
		var size := GameConstants.R_COTTAGE.size
		tex = AssetGenerator.create_floor_wood(int(size.x), int(size.y))
	
	room.texture = tex
	
	room.centered = false
	room.region_enabled = true
	room.region_rect = GameConstants.R_COTTAGE
	floor_base.add_child(room)
	if Engine.is_editor_hint(): room.owner = self

func _instance_architecture() -> void:
	# Clear existing architecture nodes to prevent overlapping duplicates
	for c in ysort_container.get_children():
		if c.name.begins_with("Arch_") or c.name.begins_with("Wall_"):
			c.free()

	# Instances structural elements (Walls/Building) into the YSort Container
	for item in GameConstants.ARCHITECTURE_DATA:
		# Look up the path from the Manifest using the asset_id
		var asset_id = item.get("asset_id", "")
		var asset_metadata = Manifest.get_asset_data(asset_id)
		var path = asset_metadata.get("path", "")
		
		if path == "": 
			continue
		
		path = _get_clean_path(path)
		if not FileAccess.file_exists(path):
			push_warning("ENGINE: Missing architecture asset: %s" % path)
			continue
			
		var res = load(path) if not path.is_empty() else null
		if not res: continue

		var world_pos = Vector2(item.chunk_coord) * GameConstants.CHUNK_SIZE + item.local_pos

		if res is PackedScene:
			var inst = res.instantiate()
			inst.position = world_pos
			inst.scale = item.get("scale", Vector2.ONE)
			# Naming it 'Wall_Architecture' as per specification
			if not inst.name.begins_with("Wall"):
				inst.name = "Wall_Architecture_" + str(GameConstants.ARCHITECTURE_DATA.find(item))
			
			ysort_container.add_child(inst)
			if Engine.is_editor_hint(): inst.owner = self
		elif res is Texture2D:
			# Support for raw skyscraper sprites
			var s = Sprite2D.new()
			s.name = "Arch_Sprite_" + str(GameConstants.ARCHITECTURE_DATA.find(item))
			s.texture = res
			s.centered = false
			s.scale = item.get("scale", Vector2.ONE)
			# Physics Footprint Protocol: Origin at feet (bottom-center)
			s.offset = Vector2(-res.get_width() * 0.5, -res.get_height())
			s.position = world_pos
			s.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
			ysort_container.add_child(s)
			if Engine.is_editor_hint(): s.owner = self

func _instance_prefabs() -> void:
	var count = 0
	for item in GameConstants.PROP_DATA:
		var path = _get_clean_path(item.prefab)
		if not FileAccess.file_exists(path):
			push_warning("ENGINE: Missing prefab asset: %s" % path)
			continue
			
		var scene = load(path) as PackedScene
		if not scene:
			continue
			
		var prefab = scene.instantiate()
		prefab.position = item.pos
		prefab.scale = item.get("scale", Vector2.ONE)
		ysort_container.add_child(prefab)
		count += 1
		if Engine.is_editor_hint(): prefab.owner = self
	print("ENGINE: Built architecture and instanced %d props." % count)

func _generate_zones() -> void:
	for z in GameConstants.ZONE_DATA:
		var area = Area2D.new()
		area.name = z.name
		area.position = z.rect.get_center()
		
		var cs = CollisionShape2D.new()
		var sh = RectangleShape2D.new()
		sh.size = z.rect.size
		cs.shape = sh
		area.add_child(cs)
		
		add_child(area)
		if Engine.is_editor_hint():
			area.owner = self
			cs.owner = self
		
		# Logic wiring is handled by world_2d.gd searching for these names
		if not Engine.is_editor_hint():
			var world = get_parent()
			if world:
				if z.type == "shadow":
					area.body_entered.connect(world._on_shadow_entered)
					area.body_exited.connect(world._on_shadow_exited)
				elif z.type == "extract":
					area.body_entered.connect(world._on_extract_entered)
					area.body_exited.connect(world._on_extract_exited)
					world.extraction_area = area
