extends Node

# -- Colour palette --
const C_ALLEY     := Color("#0d1016")
const C_BACK_HALL := Color("#111520")
const C_WEST      := Color("#100e18")
const C_MAIN_HALL := Color("#1a1225")
const C_EAST      := Color("#100e18")
const C_FOYER     := Color("#141a24")
const C_PLAZA     := Color("#0e1218")
const C_TRIM      := Color("#1c2030")
const C_GOLD      := Color("#c8a84e")
const C_NEON_PINK := Color("#ff44a0")
const C_NEON_CYAN := Color("#44d8ff")
const C_NEON_AMB  := Color("#ffbf44")

# -- Room rectangles --
const R_ALLEY     := Rect2(100,  20, 440,  65)
const R_BACK_HALL := Rect2(100,  85, 440,  65)
const R_WEST      := Rect2( 20, 150, 100, 200)
const R_MAIN_HALL := Rect2(120, 150, 360, 220)
const R_EAST      := Rect2(480, 150, 100, 200)
const R_FOYER     := Rect2(200, 370, 240,  90)
const R_PLAZA     := Rect2(100, 460, 440, 140)

# -- Wall colors --
const C_WALL_TOP   := Color("#1c2030")
const C_WALL_FACE  := Color("#0a0c12")

# -- Projection --
const ISO_Y_SCALE  := 0.65
const WALL_FACE_H  := 18.0 / ISO_Y_SCALE

# -- NPC spawns --
const NPC_SPAWNS := [
	{"role": "contact", "name": "Mara", "key": "alibi", "phase": "day", "pos": Vector2(320, 412), "patrol": []},
	{"role": "contact", "name": "Jules", "key": "guest_pass", "phase": "day", "pos": Vector2(60, 250), "patrol": []},
	{"role": "contact", "name": "Nico", "key": "route_intel", "phase": "day", "pos": Vector2(575, 250), "patrol": []},
	{"role": "guard", "name": "Guard1", "key": "", "phase": "night", "pos": Vector2(320, 200), "patrol": [Vector2(320, 200), Vector2(320, 300)]},
	{"role": "witness", "name": "Witness1", "key": "", "phase": "night", "pos": Vector2(200, 250), "patrol": [Vector2(200, 250), Vector2(400, 250)]},
	{"role": "civilian", "name": "Guest B", "key": "", "phase": "day", "pos": Vector2(165, 230), "patrol": []},
	{"role": "target", "name": "Alden", "key": "", "phase": "night", "pos": Vector2(320, 280), "patrol": [Vector2(150, 280), Vector2(450, 280)]}
]

# -- Extraction --
const EXTRACTION_POS := Vector2(460, 46)
const NIGHT_START_POSITION := Vector2(220.0, 112.0)

# -- Visual Assets --
const PLAYER_SCRIPT = preload("res://scripts/player_2d.gd")
const NPC_SCRIPT = preload("res://scripts/npc_2d.gd")