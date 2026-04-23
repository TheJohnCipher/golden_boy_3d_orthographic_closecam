extends Node

# Asset Registry Singleton
# Maps Asset IDs to paths and metadata for the chunk-based engine.

const ASSETS = {
	"skyscraper_cyber_01": {
		"path": "res://assets/sprites/arch_skyscraper_base_cyber_01.png.png",
		"collision_base_h": 16.0,
		"ysort": true,
		"size": Vector2(128, 512),
		"type": "architecture"
	},
	"neon_barrier": {
		"path": "res://scenes/prefabs/wall_architecture.tscn",
		"collision_base_h": 8.0,
		"ysort": true,
		"size": Vector2(64, 32),
		"type": "prefab"
	},
	"brick_building_01": {
		"path": "res://assets/sprites/brickbuilding1.png",
		"collision_base_h": 16.0,
		"ysort": true,
		"size": Vector2(128, 512),
		"type": "architecture"
	}
}

static func get_asset_data(id: String) -> Dictionary:
	# Duplicate to prevent reference pollution (modifying the const by accident)
	var data = ASSETS.get(id, {}).duplicate()
	
	if data.has("path") and data["path"] is String:
		var p = data["path"].strip_edges()
		# Remove accidental trailing dots from OS/Export errors
		while p.ends_with("."): p = p.left(p.length() - 1)
		
		# Aggressively strip multiple/case-insensitive extensions
		while p.to_lower().ends_with(".png.png"): p = p.left(p.length() - 4)
		while p.to_lower().ends_with(".tscn.tscn"): p = p.left(p.length() - 5)
		
		data["path"] = p
	return data