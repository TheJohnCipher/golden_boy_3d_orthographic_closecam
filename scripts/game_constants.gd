extends Node

# ── 1. Sprite Asset Paths (res://assets/sprites/) ──
const T_FLOOR_WOOD      = "res://assets/sprites/floor_wood.png"
const T_FLOOR_CARPET    = "res://assets/sprites/floor_carpet.png"
const T_SKYSCRAPER      = "res://assets/sprites/arch_skyscraper_base_cyber_01.png.png"
const T_WALL_TEXTURE    = "res://assets/sprites/wall_architecture.png"
const T_PLAYER_SPRITE   = "res://assets/sprites/player.png"
const T_NPC_SPRITE      = "res://assets/sprites/npc_base.png"

# ── 2. Prefab Registry (res://scenes/prefabs/) ──
const P_FRIDGE          = "res://scenes/prefabs/fridge.tscn"
const P_STOVE           = "res://scenes/prefabs/stove.tscn"
const P_TABLE           = "res://scenes/prefabs/table.tscn"
const P_STOOL           = "res://scenes/prefabs/stool.tscn"
const P_WALL_SECTION    = "res://scenes/prefabs/wall_architecture.tscn"

# ── 3. Professional Lighting & Palettes ──
const COLOR_WARM_TINT   = Color("#fff4e0", 0.6) # Low-intensity warm tint
const COLOR_SHADOW      = Color("#2a1a3a", 0.4)

# ── 4. World Streaming Config ──
const CHUNK_SIZE     := 1024.0
const LOAD_THRESHOLD := 512.0
const CITY_BOUNDS    := Rect2i(-5, -5, 10, 10) # 10x10 total chunks


# ── 5. Audio Registry ──
const S_FOOTSTEP    = "res://assets/audio/step_concrete.wav"
const S_ALERT       = "res://assets/audio/alert_stinger.wav"

const ISO_Y_SCALE  := 0.7

# Cottage interior: single room 1088×512
const R_COTTAGE   := Rect2(0, 0, 1088, 512)

const ARCHITECTURE_DATA := [
	# ── THE HERO BUILDING ──
	{"chunk_coord": Vector2i(0, 0),  "local_pos": Vector2(512, 512), "asset_id": "skyscraper_cyber_01", "scale": Vector2(0.4, 0.4)},
	# ── NEIGHBORING BRICK BUILDING ──
	{"chunk_coord": Vector2i(1, 0),  "local_pos": Vector2(200, 512), "asset_id": "brick_building_01",   "scale": Vector2(0.4, 0.4)},
]

const PROP_DATA := []

const ZONE_DATA := []

const NPC_SPAWNS := []

const EXTRACTION_POS := Vector2(100, 60)
const NIGHT_START_POSITION := Vector2(544.0, 300.0)

const PLAYER_SCRIPT = preload("res://scripts/player_2d.gd")
const NPC_SCRIPT = preload("res://scripts/npc_2d.gd")
