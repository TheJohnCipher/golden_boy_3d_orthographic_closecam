@tool
extends Node2D

const GameConstants = preload("res://scripts/game_constants.gd")
const Manifest = preload("res://scripts/manifest.gd") 

var active_chunks: Dictionary = {} # Key: Vector2i (chunk coord), Value: Node2D
var world_ref: Node2D # Reference back to World2D for signal wiring
var player_ref: Node2D

var _debug_tex_cache: Dictionary = {}

func _get_clean_path(path: String) -> String:
	var p = path.strip_edges()
	# Bulletproof cleaning: handle trailing dots and case sensitivity
	while p.ends_with("."): p = p.left(p.length() - 1)
	while p.to_lower().ends_with(".png.png"): p = p.left(p.length() - 4)
	while p.to_lower().ends_with(".tscn.tscn"): p = p.left(p.length() - 5)
	return p

func _ready() -> void:
	_setup_boundaries()

func _process(_delta: float) -> void:
	if not Engine.is_editor_hint():
		if not player_ref: return
		queue_redraw() # Ensure smooth updates at runtime
		_update_streaming()
	
	# Constant update to ensure the debug overlay remains visible
	queue_redraw()

func _draw() -> void:
	var cs = GameConstants.CHUNK_SIZE
	var b = GameConstants.CITY_BOUNDS
	
	# ── 1. The Grid (Blueprint Visualization) ──
	for x in range(b.position.x, b.position.x + b.size.x):
		for y in range(b.position.y, b.position.y + b.size.y):
			var rect = Rect2(Vector2(x, y) * cs, Vector2(cs, cs))
			draw_rect(rect, Color(1, 1, 1, 0.2), false, 2.0)
	
	# ── 2. Massive Origin Marker ──
	# If you see this magenta cross, the script is working!
	draw_line(Vector2(-1000, 0), Vector2(1000, 0), Color.MAGENTA, 10.0)
	draw_line(Vector2(0, -1000), Vector2(0, 1000), Color.MAGENTA, 10.0)
	draw_circle(Vector2.ZERO, 50.0, Color.MAGENTA)

	# ── 2. District Block-out Boxes ──
	_draw_district_zone("CENTRAL CORE (CBD)", Rect2i(-1, -1, 3, 3), Color(1.0, 0.8, 0.2, 0.3), false)
	_draw_district_zone("MAIN BOULEVARD (N-S)", Rect2i(0, -5, 1, 10), Color(0.2, 0.7, 1.0, 0.25), false)
	_draw_district_zone("THE STRIP (E-W)", Rect2i(-5, 0, 10, 1), Color(0.8, 0.2, 1.0, 0.25), false)
	_draw_district_zone("CITY PERIMETER", b, Color(1, 1, 1, 0.01), false)
	

func _draw_district_zone(label: String, chunk_rect: Rect2i, col: Color, fill: bool = true) -> void:
	var cs = GameConstants.CHUNK_SIZE
	var rect = Rect2(Vector2(chunk_rect.position) * cs, Vector2(chunk_rect.size) * cs)
	draw_rect(rect, col, fill) # Fill if enabled
	draw_rect(rect, col.lightened(0.6), false, 6.0) # Heavy Outline
	# Text label to mark what is what
	var font = ThemeDB.fallback_font
	if font:
		draw_string(font, rect.position + Vector2(20, 60), label, HORIZONTAL_ALIGNMENT_LEFT, -1, 42, Color.WHITE)


func _update_streaming() -> void:
	var p_pos = player_ref.global_position
	var current_coord = Vector2i(
		floor(p_pos.x / GameConstants.CHUNK_SIZE),
		floor(p_pos.y / GameConstants.CHUNK_SIZE)
	)
	
	# Check 8 surrounding neighbors
	for x in range(-1, 2):
		for y in range(-1, 2):
			var target_coord = current_coord + Vector2i(x, y)
			
			# ── Boundary Check ──
			if not _is_coord_in_bounds(target_coord): continue

			if not active_chunks.has(target_coord):
				# Check threshold for pre-loading
				var chunk_origin = Vector2(target_coord) * GameConstants.CHUNK_SIZE
				var dist_to_chunk = p_pos.distance_to(chunk_origin + Vector2.ONE * (GameConstants.CHUNK_SIZE / 2.0))
				
				if dist_to_chunk < GameConstants.CHUNK_SIZE + GameConstants.LOAD_THRESHOLD:
					_spawn_chunk_threaded(target_coord)

	# Cleanup distant chunks
	var to_remove = []
	for coord in active_chunks:
		if (coord - current_coord).length() > 2:
			to_remove.append(coord)
	
	for coord in to_remove:
		active_chunks[coord].queue_free()
		active_chunks.erase(coord)

func _setup_boundaries() -> void:
	# Create invisible physical walls at the CITY_BOUNDS defined in GameConstants
	var b = GameConstants.CITY_BOUNDS
	var cs = GameConstants.CHUNK_SIZE
	var city_rect = Rect2(Vector2(b.position) * cs, Vector2(b.size) * cs)
	
	var create_barrier = func(n: String, r: Rect2):
		var body = StaticBody2D.new()
		body.name = n
		var coll = CollisionShape2D.new()
		var shape = RectangleShape2D.new()
		shape.size = r.size
		coll.shape = shape
		body.add_child(coll)
		body.position = r.position + r.size / 2.0
		add_child(body)

	var thick = 128.0 # Thick enough to catch high-speed players
	create_barrier.call("Bound_North", Rect2(city_rect.position.x, city_rect.position.y - thick, city_rect.size.x, thick))
	create_barrier.call("Bound_South", Rect2(city_rect.position.x, city_rect.end.y, city_rect.size.x, thick))
	create_barrier.call("Bound_West",  Rect2(city_rect.position.x - thick, city_rect.position.y, thick, city_rect.size.y))
	create_barrier.call("Bound_East",  Rect2(city_rect.end.x, city_rect.position.y, thick, city_rect.size.y))

func _spawn_chunk_threaded(coord: Vector2i) -> void:
	# Prevent double-loading while thread is working
	active_chunks[coord] = null 
	WorkerThreadPool.add_task(_generate_chunk_data.bind(coord))

func _generate_chunk_data(coord: Vector2i) -> void:
	var chunk_node = Node2D.new()
	chunk_node.name = "Chunk_%d_%d" % [coord.x, coord.y]
	chunk_node.position = Vector2(coord) * GameConstants.CHUNK_SIZE
	
	# ── 1. Create Ground Slab (Blocked out with streets) ──
	var street_width = 64.0
	var ground = Sprite2D.new()
	var floor_path = _get_clean_path(GameConstants.T_FLOOR_WOOD)
	if FileAccess.file_exists(floor_path):
		ground.texture = load(floor_path)
	ground.centered = false
	# Shrink the slab slightly to create the "Street" gap between chunks
	ground.position = Vector2.ONE * (street_width / 2.0)
	ground.region_enabled = true
	ground.region_rect = Rect2(0, 0, GameConstants.CHUNK_SIZE - street_width, GameConstants.CHUNK_SIZE - street_width)
	
	# Block color (Brightened slightly for visibility)
	ground.modulate = Color(0.15, 0.15, 0.20) 
	chunk_node.add_child(ground)

	# YSort Container for Architecture
	var ysort = Node2D.new()
	ysort.name = "Architecture_YSort"
	ysort.y_sort_enabled = true
	chunk_node.add_child(ysort)
	
	# ── 2. Data-Driven City Layout ──
	for item in GameConstants.ARCHITECTURE_DATA:
		if item.chunk_coord == coord:
			_add_architecture_asset(ysort, item.asset_id, item.local_pos, item.scale)

	# Finalize on Main Thread
	call_deferred("_finalize_chunk", coord, chunk_node)

func _add_architecture_asset(container: Node2D, asset_id: String, local_pos: Vector2, s_scale: Vector2) -> void:
	var data = Manifest.get_asset_data(asset_id)
	if data.is_empty():
		push_warning("Manifest: Asset ID '%s' not found." % asset_id)
		return

	var path : String = data.get("path", "")
	path = _get_clean_path(path)
	var tex : Texture2D = null
	if not path.is_empty() and FileAccess.file_exists(path):
		tex = load(path)
	if not tex: return # No fallback, as requested

	var s = Sprite2D.new()
	s.texture = tex
	s.centered = false
	s.scale = s_scale
	# Physics Footprint: Origin at feet (Bottom-Center)
	s.offset = Vector2(-tex.get_width() * 0.5, -tex.get_height())
	s.position = local_pos
	s.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	container.add_child(s)
	
	# Collision at the base (16px)
	var body = StaticBody2D.new()
	body.position = local_pos
	var shape = RectangleShape2D.new()
	shape.size = Vector2(data.size.x * s_scale.x, data.collision_base_h)
	var cs = CollisionShape2D.new()
	cs.shape = shape
	cs.position = Vector2(0, -data.collision_base_h / 2.0)
	body.add_child(cs)
	container.add_child(body)

func _is_coord_in_bounds(coord: Vector2i) -> bool:
	return GameConstants.CITY_BOUNDS.has_point(coord)

func _finalize_chunk(coord: Vector2i, node: Node2D) -> void:
	add_child(node)
	active_chunks[coord] = node
