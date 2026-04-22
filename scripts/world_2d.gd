extends Node2D

const GameConstants = preload("res://scripts/game_constants.gd")
# Constants are now handled via GameConstants class

# ── Light proxy so mission_controller tweens work in 2D ──────────────────────
class LightProxy extends Node:
	var light_energy : float = 0.0
	var visible      : bool  = true

# ── Mission state (same contract as world_3d) ─────────────────────────────────
var player             = null
var phase              := "day"
var contacts           := {"alibi": false, "guest_pass": false, "route_intel": false}
var contact_npcs       : Array = []
var guard_npcs         : Array = []
var civilian_npcs      : Array = []
var target_npc                 = null
var extraction_area            = null
var extraction_marker          = null
var near_extraction    := false
var takedown_done      := false
var mission_failed     := false
var level_complete     := false
var suspicion          := 0.0
var heat               := 8.0
var reputation         := 30.0
var money              := 0
var current_objective  := ""
var message_text       := ""
var message_timer      := 0.0
var night2_active      := false
var phase_transition_in_progress := false

# 2D-specific: null so mission_controller's _apply_environment_profile no-ops
var environment        = null
var day_sun  : LightProxy
var moon_light : LightProxy
var point_lights       : Array = []
var npc_root   : Node2D
var marker_root : Node2D
var hud                := {}

var _camera    : Camera2D
var _night_tint : ColorRect
var _hud_layer : CanvasLayer
var _pillars   : Array[Vector2] = []
var _neon_strips : Array        = []   # [ [from, to, Color], … ]

var night_start_position := GameConstants.NIGHT_START_POSITION

# =============================================================================
func _ready() -> void:
	_init_input_map()
	_init_roots()
	_init_lights()
	_build_level_geometry()
	_spawn_player_node()
	_spawn_npc_nodes()
	_create_extraction()
	_create_shadow_zones()
	_setup_hud()
	_configure_window()
	_apply_iso_view()
	_apply_phase_visibility()
	_refresh_objective()
	_show_message(
		"Golden Boy. The Velvet Strip gala. Work the contacts. Execute the extraction.")
	queue_redraw()

# ── Oblique projection ───────────────────────────────────────────────────────
func _apply_iso_view() -> void:
	# Pure Y-scale: X stays horizontal, Y compressed 35%.
	# CanvasLayer (HUD) ignores parent transform so it stays flat.
	transform = Transform2D(
		Vector2(1.0, 0.0),
		Vector2(0.0, GameConstants.ISO_Y_SCALE),
		Vector2.ZERO
	)

# ── Wall face helper (draws visible south face of a horizontal wall) ──────────
func _wall_face(x0: float, x1: float, y: float, h := GameConstants.WALL_FACE_H) -> void:
	draw_colored_polygon(PackedVector2Array([
		Vector2(x0, y), Vector2(x1, y),
		Vector2(x1, y + h), Vector2(x0, y + h)
	]), GameConstants.C_WALL_FACE)

# ── Window ────────────────────────────────────────────────────────────────────
func _configure_window() -> void:
	var win := get_viewport().get_window()
	win.content_scale_mode = Window.CONTENT_SCALE_MODE_VIEWPORT
	win.content_scale_size = Vector2i(480, 270)
	var scr := DisplayServer.window_get_current_screen()
	win.size     = DisplayServer.screen_get_size(scr)
	win.position = DisplayServer.screen_get_position(scr)
	win.mode     = Window.MODE_FULLSCREEN

# ── Roots & lights ────────────────────────────────────────────────────────────
func _init_roots() -> void:
	npc_root    = Node2D.new(); npc_root.name    = "NPCs";    add_child(npc_root)
	marker_root = Node2D.new(); marker_root.name = "Markers"; add_child(marker_root)

func _init_lights() -> void:
	day_sun    = LightProxy.new()
	moon_light = LightProxy.new()
	day_sun.light_energy    = 1.8;  day_sun.set_meta("base_energy", 1.8)
	moon_light.light_energy = 0.0;  moon_light.set_meta("base_energy", 0.32)
	day_sun.visible    = true
	moon_light.visible = false
	add_child(day_sun)
	add_child(moon_light)

# ── Background _draw  (painter's order: north → south) ───────────────────────
func _draw() -> void:
	var night := phase == "night"
	var t     := float(Time.get_ticks_msec()) * 0.001

	# Solid compound fill (everything outside rooms)
	draw_rect(Rect2(12, 12, 616, 601), Color("#08090c"))

	# --- Draw Room Layout (North to South) ---
	_draw_alley(night, t)
	_draw_back_hall()
	_draw_wing(GameConstants.R_WEST, 1)
	_draw_wing(GameConstants.R_EAST, 2)
	_draw_main_hall(night, t)
	_draw_foyer()
	_draw_plaza(night, t)

	# --- Draw Neon Decoration & Structural Pillars ---
	for strip in _neon_strips:
		draw_line(strip[0], strip[1], strip[2], 1.5)
	
	for p in _pillars:
		draw_circle(p, 9.0, GameConstants.C_WALL_TOP)

	if night:
		_draw_suspicion_bar()

# ── Alley detail ──────────────────────────────────────────────────────────────
func _draw_alley(night: bool, t: float) -> void:
	# Sidewalk border along north wall
	draw_rect(Rect2(100, 20, 440, 8), Color("#0c0e10"))
	# Brick wall (north boundary - horizontal course lines)
	for row in range(5):
		var wy := 13.0 + row * 1.5
		draw_line(Vector2(100, wy), Vector2(540, wy), Color(0.12, 0.10, 0.09, 0.9), 1.0)
	# Brick column joints (offset alternating rows)
	for row in range(5):
		var wy := 13.0 + row * 1.5
		var off := 8.0 if (row % 2 == 0) else 4.0
		var bx := 100.0 + off
		while bx < 540.0:
			draw_line(Vector2(bx, wy), Vector2(bx, wy + 1.5), Color(0.08, 0.06, 0.06, 0.8), 0.6)
			bx += 16.0

	# Road centre dashed line
	var cy := 52.0
	var dash := 100.0
	while dash < 540.0:
		draw_line(Vector2(dash, cy), Vector2(dash + 12.0, cy), Color(0.25, 0.22, 0.10, 0.6), 1.0)
		dash += 22.0

	# Puddle near dumpster
	draw_circle(Vector2(490, 60), 9.0, Color(0.06, 0.09, 0.14, 0.7))
	draw_circle(Vector2(490, 60), 5.0, Color(0.12, 0.18, 0.28, 0.5))
	# Neon reflection in puddle
	draw_line(Vector2(483, 58), Vector2(498, 58), Color(GameConstants.C_NEON_PINK.r, GameConstants.C_NEON_PINK.g, GameConstants.C_NEON_PINK.b, 0.35), 1.2)

	# Manhole cover
	draw_circle(Vector2(280, 52), 7.0, Color(0.10, 0.10, 0.11))
	draw_arc(Vector2(280, 52), 7.0, 0.0, TAU, 12, Color(0.18, 0.18, 0.20), 1.2)
	draw_line(Vector2(273, 52), Vector2(287, 52), Color(0.18, 0.18, 0.20), 0.8)
	draw_line(Vector2(280, 45), Vector2(280, 59), Color(0.18, 0.18, 0.20), 0.8)

	# Dumpster (detailed)
	var dr := Rect2(474, 22, 28, 24)
	draw_rect(dr, Color("#0f1010"))
	draw_rect(dr, Color("#1c1e1c"), false, 0.8)
	# Lid
	draw_rect(Rect2(474, 22, 28, 6), Color("#161816"))
	draw_line(Vector2(488, 22), Vector2(488, 28), Color(0.25, 0.28, 0.25, 0.6), 0.7)
	# Rust streaks
	draw_line(Vector2(479, 30), Vector2(479, 44), Color(0.35, 0.15, 0.05, 0.4), 0.6)
	draw_line(Vector2(494, 32), Vector2(493, 44), Color(0.30, 0.13, 0.04, 0.3), 0.5)

	# Wooden crate (planks)
	var cr := Rect2(106, 26, 20, 20)
	draw_rect(cr, Color("#1a1208"))
	draw_rect(cr, Color("#281c0c"), false, 0.7)
	# Plank lines
	draw_line(Vector2(106, 33), Vector2(126, 33), Color(0.25, 0.18, 0.08, 0.7), 0.6)
	draw_line(Vector2(106, 39), Vector2(126, 39), Color(0.25, 0.18, 0.08, 0.7), 0.6)
	# Cross brace
	draw_line(Vector2(116, 26), Vector2(116, 46), Color(0.30, 0.22, 0.10, 0.5), 0.6)

	# Drainpipe
	draw_line(Vector2(432, 20), Vector2(432, 85), GameConstants.C_NEON_CYAN.darkened(0.6), 2.8)
	draw_line(Vector2(432, 20), Vector2(432, 85), Color(0.3, 0.3, 0.35, 0.3), 1.0)

	# Fire escape (east wall of alley)
	_draw_fire_escape(Vector2(538, 20), Vector2(538, 85))

	# Street lamps
	for lx: float in [180.0, 460.0]:
		# Pole
		draw_line(Vector2(lx, 20), Vector2(lx, 60), Color(0.22, 0.22, 0.26), 1.5)
		# Arm
		draw_line(Vector2(lx, 30), Vector2(lx + 8.0, 30), Color(0.22, 0.22, 0.26), 1.2)
		# Lamp head
		draw_circle(Vector2(lx + 8.0, 30), 4.0, Color(0.18, 0.18, 0.20))
		var lamp_col := Color(1.0, 0.92, 0.65, 0.9) if night else Color(0.9, 0.85, 0.60, 0.5)
		draw_circle(Vector2(lx + 8.0, 30), 2.5, lamp_col)
		if night:
			draw_circle(Vector2(lx + 8.0, 30), 18.0, Color(1.0, 0.92, 0.65, 0.04 + 0.01 * sin(t * 1.7)))

# ── Back hall detail ──────────────────────────────────────────────────────────
func _draw_back_hall() -> void:
	_draw_grid(GameConstants.R_BACK_HALL, 22.0, Color(0.10, 0.12, 0.16, 0.3))
	# Door frames at openings (alley side)
	_draw_door_frame(Vector2(220, 85), Vector2(420, 85))
	# Door frames at main hall side
	_draw_door_frame(Vector2(200, 150), Vector2(400, 150))
	# Wall sconces
	for sx: float in [145.0, 395.0, 495.0]:
		draw_circle(Vector2(sx, 100), 4.5, Color(0.18, 0.16, 0.14))
		draw_circle(Vector2(sx, 100), 2.5, Color(0.9, 0.75, 0.45, 0.8))
		draw_circle(Vector2(sx, 100), 12.0, Color(0.9, 0.75, 0.45, 0.04))
	# Service lockers along south wall
	for lx in range(5):
		var lxp := 130.0 + lx * 40.0
		draw_rect(Rect2(lxp, 138, 32, 12), Color("#0e1018"))
		draw_rect(Rect2(lxp, 138, 32, 12), Color(0.18, 0.20, 0.26, 0.5), false, 0.6)
		draw_circle(Vector2(lxp + 28, 144), 1.5, Color("#c8a84e"))

# ── Main hall detail ──────────────────────────────────────────────────────────
func _draw_main_hall(night: bool, t: float) -> void:
	# Marble checkerboard (two close dark purples)
	var ca := Color(0.14, 0.09, 0.18)
	var cb := Color(0.16, 0.11, 0.22)
	var ts  := 20.0
	var mx  := GameConstants.R_MAIN_HALL.position.x
	var my  := GameConstants.R_MAIN_HALL.position.y
	var cols := int(GameConstants.R_MAIN_HALL.size.x / ts)
	var rows := int(GameConstants.R_MAIN_HALL.size.y / ts)
	for row in range(rows):
		for col in range(cols):
			var tc := ca if (row + col) % 2 == 0 else cb
			draw_rect(Rect2(mx + col * ts, my + row * ts, ts, ts), tc)
	_draw_grid(GameConstants.R_MAIN_HALL, ts, Color(0.08, 0.06, 0.12, 0.6))

	# Ornate border inlay around perimeter of main hall
	draw_rect(GameConstants.R_MAIN_HALL.grow(-8.0), Color(0.0, 0.0, 0.0, 0.0), false)
	draw_rect(GameConstants.R_MAIN_HALL.grow(-8.0), Color(GameConstants.C_GOLD.r, GameConstants.C_GOLD.g, GameConstants.C_GOLD.b, 0.25), false, 0.8)
	draw_rect(GameConstants.R_MAIN_HALL.grow(-12.0), Color(GameConstants.C_GOLD.r, GameConstants.C_GOLD.g, GameConstants.C_GOLD.b, 0.15), false, 0.5)

	# Venue sign (above neon strip, in main hall north)
	draw_string(ThemeDB.fallback_font, Vector2(196, 174), "G O L D E N  B O Y",
			HORIZONTAL_ALIGNMENT_LEFT, -1, 9, GameConstants.C_GOLD.lightened(0.1))
	draw_string(ThemeDB.fallback_font, Vector2(197, 175), "G O L D E N  B O Y",
			HORIZONTAL_ALIGNMENT_LEFT, -1, 9, GameConstants.C_GOLD.darkened(0.1))
	draw_string(ThemeDB.fallback_font, Vector2(196, 175), "G O L D E N  B O Y",
			HORIZONTAL_ALIGNMENT_LEFT, -1, 9, GameConstants.C_GOLD)

	# Chandelier (ceiling feature, center of main hall)
	var cc := GameConstants.R_MAIN_HALL.get_center() + Vector2(0, -20)
	draw_circle(cc, 18.0, Color(0.15, 0.12, 0.20, 0.8))
	draw_arc(cc, 18.0, 0.0, TAU, 20, GameConstants.C_GOLD.darkened(0.2), 1.5)
	for i in range(8):
		var a := TAU * float(i) / 8.0
		draw_line(cc, cc + Vector2(cos(a), sin(a)) * 16.0, GameConstants.C_GOLD.darkened(0.3), 0.7)
	draw_circle(cc, 7.0, Color(0.12, 0.10, 0.18))
	draw_arc(cc, 7.0, 0.0, TAU, 12, GameConstants.C_GOLD, 1.2)
	draw_circle(cc, 3.0, GameConstants.C_GOLD.lightened(0.2))
	if night:
		draw_circle(cc, 35.0, Color(GameConstants.C_NEON_AMB.r, GameConstants.C_NEON_AMB.g, GameConstants.C_NEON_AMB.b, 0.07 + 0.01 * sin(t * 0.9)))

	# Bar counter (along east side of main hall, inside)
	draw_rect(Rect2(458, 160, 16, 160), Color("#1a1018"))
	draw_rect(Rect2(458, 160, 16, 160), Color("#2e1e28"), false, 0.8)
	# Bar top trim
	draw_line(Vector2(458, 160), Vector2(458, 320), GameConstants.C_GOLD.darkened(0.4), 1.2)
	# Bar stools (circles along bar front)
	for sy in [185.0, 215.0, 245.0, 275.0, 305.0]:
		draw_circle(Vector2(450, sy), 5.0, Color("#241820"))
		draw_arc(  Vector2(450, sy), 5.0, 0.0, TAU, 10, Color("#3a2830"), 0.8)

	# Cocktail tables with chairs (4 tables in open area)
	for tpos: Vector2 in [Vector2(175, 220), Vector2(175, 310), Vector2(320, 190), Vector2(320, 340)]:
		_draw_table_with_chairs(tpos)

	# Wall sconces on west wall of main hall
	for sy: float in [190.0, 260.0, 330.0]:
		draw_circle(Vector2(130, sy), 3.5, Color(0.18, 0.15, 0.12))
		draw_circle(Vector2(130, sy), 2.0, Color(0.9, 0.75, 0.45, 0.7))
		if night:
			draw_circle(Vector2(130, sy), 14.0, Color(0.9, 0.75, 0.45, 0.04))

	# Door frames at hall ↔ foyer
	_draw_door_frame(Vector2(260, 370), Vector2(380, 370))

func _draw_table_with_chairs(center: Vector2) -> void:
	# Table
	draw_circle(center, 10.0, Color("#1c1420"))
	draw_arc(   center, 10.0, 0.0, TAU, 14, Color("#2e2030"), 0.8)
	draw_circle(center,  3.0, GameConstants.C_GOLD.darkened(0.5))
	# Chairs (4 cardinal positions)
	for a_deg: float in [0.0, 90.0, 180.0, 270.0]:
		var a  := deg_to_rad(a_deg)
		var cp := center + Vector2(cos(a), sin(a)) * 15.0
		draw_circle(cp, 4.5, Color("#241828"))
		draw_arc(   cp, 4.5, 0.0, TAU, 10, Color("#382438"), 0.7)

# ── Wing lounge detail ────────────────────────────────────────────────────────
func _draw_wing(r: Rect2, side: int) -> void:
	# Floor stripe
	_draw_grid(r, 18.0, Color(0.09, 0.08, 0.13, 0.3))

	var cx := r.get_center().x
	# Lounge benches (upholstered)
	for by: float in [195.0, 270.0, 310.0]:
		var bx := r.position.x + 4.0 if side == 1 else r.position.x + 16.0
		var bw := 68.0
		draw_rect(Rect2(bx, by, bw, 14), Color("#1e1418"))
		draw_rect(Rect2(bx, by, bw, 14), Color("#2c1c24"), false, 0.6)
		# Cushion seams
		for sc in range(1, 4):
			draw_line(Vector2(bx + sc * bw / 4.0, by + 2), Vector2(bx + sc * bw / 4.0, by + 12), Color(0.22, 0.14, 0.20, 0.6), 0.5)
		# Cushion highlight
		draw_rect(Rect2(bx + 2, by + 2, bw - 4, 4), Color(0.28, 0.18, 0.26, 0.4))

	# Wall art frames
	for fy: float in [165.0, 295.0]:
		var fx := r.position.x + 6.0
		var fw := r.size.x - 12.0
		draw_rect(Rect2(fx, fy, fw, 20), Color("#0e0c10"))
		draw_rect(Rect2(fx, fy, fw, 20), GameConstants.C_GOLD.darkened(0.5), false, 0.8)
		draw_line(Vector2(fx + 4, fy + 5), Vector2(fx + fw - 4, fy + 15), Color(GameConstants.C_NEON_PINK.r, GameConstants.C_NEON_PINK.g, GameConstants.C_NEON_PINK.b, 0.4), 0.7)
		draw_line(Vector2(fx + 4, fy + 15), Vector2(fx + fw - 4, fy + 5), Color(GameConstants.C_NEON_CYAN.r, GameConstants.C_NEON_CYAN.g, GameConstants.C_NEON_CYAN.b, 0.3), 0.7)

	# Corner plants
	for ppy: float in [158.0, 340.0]:
		var ppx := cx
		draw_circle(Vector2(ppx, ppy + 8), 6.0, Color(0.10, 0.12, 0.10))      # pot
		draw_circle(Vector2(ppx, ppy),     9.0, Color(0.08, 0.18, 0.09, 0.9)) # foliage
		draw_circle(Vector2(ppx - 3, ppy - 3), 5.0, Color(0.10, 0.20, 0.10, 0.7))
		draw_circle(Vector2(ppx + 4, ppy - 2), 5.0, Color(0.09, 0.16, 0.09, 0.7))

# ── Foyer detail ──────────────────────────────────────────────────────────────
func _draw_foyer() -> void:
	# Concentric inlay rectangles
	for i in range(4):
		var shrink := float(i) * 8.0
		var col    := Color(GameConstants.C_GOLD.r, GameConstants.C_GOLD.g, GameConstants.C_GOLD.b, 0.06 + float(i) * 0.03)
		draw_rect(GameConstants.R_FOYER.grow(-shrink), col, false, 0.7)

	# Reception desk
	draw_rect(Rect2(248, 380, 96, 20), Color("#1a1318"))
	draw_rect(Rect2(248, 380, 96, 20), Color("#2a1f28"), false, 0.7)
	draw_line(Vector2(248, 380), Vector2(344, 380), GameConstants.C_GOLD.darkened(0.4), 0.8)

	# Foyer lamps (two floor lamps)
	for lx: float in [215.0, 425.0]:
		draw_line(Vector2(lx, 380), Vector2(lx, 420), Color(0.28, 0.24, 0.20), 1.2)
		draw_circle(Vector2(lx, 380), 5.0, Color(0.18, 0.15, 0.12))
		draw_circle(Vector2(lx, 380), 3.0, Color(0.9, 0.78, 0.5, 0.7))

	# Stone tile grid
	_draw_grid(GameConstants.R_FOYER, 16.0, Color(0.10, 0.12, 0.16, 0.3))

	# Door frames
	_draw_door_frame(Vector2(260, 460), Vector2(380, 460))

# ── Plaza outdoor detail ──────────────────────────────────────────────────────
func _draw_plaza(night: bool, t: float) -> void:
	# Stone paver grid
	_draw_grid(GameConstants.R_PLAZA, 20.0, Color(0.11, 0.13, 0.17, 0.4))

	# Central fountain
	var fc := Vector2(320, 530)
	draw_circle(fc, 22.0, Color(0.08, 0.10, 0.14))      # basin outer
	draw_circle(fc, 18.0, Color(0.06, 0.09, 0.16))      # water
	draw_circle(fc, 18.0, Color(0.14, 0.20, 0.35, 0.5)) # water surface sheen
	draw_circle(fc,  5.0, Color(0.10, 0.12, 0.18))      # central column
	draw_arc(fc, 22.0, 0.0, TAU, 20, Color(0.22, 0.20, 0.26), 1.2) # rim
	draw_arc(fc, 18.0, 0.0, TAU, 18, Color(0.18, 0.25, 0.40, 0.4), 0.8)
	# Water ripples
	var rphase := fmod(t * 0.8, 1.0)
	for ri in range(3):
		var rr := (float(ri) / 3.0 + rphase) * 16.0
		draw_arc(fc, rr, 0.0, TAU, 14, Color(0.3, 0.5, 0.8, 0.15 * (1.0 - rr / 16.0)), 0.5)

	# Plaza trees (4 corners)
	for tpos: Vector2 in [Vector2(130, 475), Vector2(510, 475), Vector2(130, 580), Vector2(510, 580)]:
		draw_circle(tpos + Vector2(2, 3), 11.0, Color(0.0, 0.0, 0.0, 0.25)) # shadow
		draw_circle(tpos, 10.0, Color(0.06, 0.15, 0.07))
		draw_circle(tpos + Vector2(-3, -3), 7.0, Color(0.08, 0.18, 0.08))
		draw_circle(tpos + Vector2( 3, -2), 6.0, Color(0.07, 0.16, 0.07))
		draw_circle(tpos, 4.0, Color(0.10, 0.20, 0.10))
		# Trunk
		draw_circle(tpos + Vector2(0, 5), 2.5, Color(0.15, 0.10, 0.06))

	# Outdoor benches (more detailed)
	for bdata: Array in [[Vector2(225, 492), true], [Vector2(415, 492), true],
						  [Vector2(225, 568), false],[Vector2(415, 568), false]]:
		var bp   : Vector2 = bdata[0]
		var horiz: bool    = bdata[1]
		var bw := 45.0; var bh := 10.0
		if not horiz:
			var tmp := bw; bw = bh; bh = tmp
		draw_rect(Rect2(bp.x - bw/2, bp.y - bh/2, bw, bh), Color("#0e1016"))
		draw_rect(Rect2(bp.x - bw/2, bp.y - bh/2, bw, bh), Color("#1c2030"), false, 0.7)
		# Bench slats
		if horiz:
			for sx in range(1, 4):
				draw_line(Vector2(bp.x - bw/2 + sx * bw / 4.0, bp.y - bh/2),
						  Vector2(bp.x - bw/2 + sx * bw / 4.0, bp.y + bh/2),
						  Color(0.18, 0.22, 0.30, 0.5), 0.5)

	# Outdoor lamp posts
	for lpx: float in [160.0, 480.0]:
		var lpy := 490.0
		draw_line(Vector2(lpx, lpy), Vector2(lpx, lpy + 80), Color(0.20, 0.20, 0.24), 1.8)
		draw_circle(Vector2(lpx, lpy), 5.5, Color(0.16, 0.16, 0.20))
		var lc := Color(1.0, 0.92, 0.65, 0.85) if night else Color(0.85, 0.80, 0.55, 0.45)
		draw_circle(Vector2(lpx, lpy), 3.5, lc)
		if night:
			draw_circle(Vector2(lpx, lpy), 24.0, Color(1.0, 0.92, 0.65, 0.04))

# ── Fire escape ───────────────────────────────────────────────────────────────
func _draw_fire_escape(top: Vector2, bottom: Vector2) -> void:
	var fc := Color(0.18, 0.18, 0.22, 0.8)
	var steps := 4
	var seg   := (bottom.y - top.y) / float(steps)
	for i in range(steps):
		var sy := top.y + float(i) * seg
		var ex := top.x - 10.0 * float(i % 2)
		draw_line(Vector2(top.x, sy), Vector2(ex, sy + seg), fc, 1.0)
		draw_line(Vector2(ex, sy + seg), Vector2(ex - 8, sy + seg), fc, 1.2)
	# Vertical rails
	draw_line(top, bottom, fc, 0.7)
	draw_line(top - Vector2(8, 0), bottom - Vector2(8, 0), fc, 0.7)

# ── Door frame marker ─────────────────────────────────────────────────────────
func _draw_door_frame(a: Vector2, b: Vector2) -> void:
	var fc := Color(GameConstants.C_GOLD.r, GameConstants.C_GOLD.g, GameConstants.C_GOLD.b, 0.5)
	draw_circle(a, 2.0, fc)
	draw_circle(b, 2.0, fc)
	draw_line(a, b, Color(GameConstants.C_GOLD.r, GameConstants.C_GOLD.g, GameConstants.C_GOLD.b, 0.18), 0.8)

# ── Suspicion bar ─────────────────────────────────────────────────────────────
func _draw_suspicion_bar() -> void:
	var bar_x := 330.0
	var bar_y := 252.0
	var bar_w := 140.0
	var fill  := (suspicion / 100.0) * bar_w
	var bc    := Color(1.0, 0.28, 0.28) if suspicion > 60.0 else Color(0.85, 0.55, 0.30)
	# Background track
	draw_rect(Rect2(bar_x - 1, bar_y - 1, bar_w + 2, 8), Color(0.08, 0.04, 0.04))
	draw_rect(Rect2(bar_x, bar_y, bar_w, 6), Color(0.14, 0.07, 0.07))
	# Fill
	if fill > 0.0:
		draw_rect(Rect2(bar_x, bar_y, fill, 6), bc)
		# Shimmer on bar
		draw_rect(Rect2(bar_x, bar_y, fill, 2), Color(bc.r, bc.g, bc.b, 0.4))
	# Border
	draw_rect(Rect2(bar_x - 1, bar_y - 1, bar_w + 2, 8), Color(0.35, 0.12, 0.12), false, 0.8)

func _draw_grid(r: Rect2, cell: float, c: Color) -> void:
	var x := r.position.x
	while x <= r.end.x:
		draw_line(Vector2(x, r.position.y), Vector2(x, r.end.y), c, 0.5)
		x += cell
	var y := r.position.y
	while y <= r.end.y:
		draw_line(Vector2(r.position.x, y), Vector2(r.end.x, y), c, 0.5)
		y += cell

func _draw_arrow(pos: Vector2, dir: Vector2, c: Color) -> void:
	var tip   := pos + dir * 14.0
	var left  := pos + dir.rotated(deg_to_rad(140)) * 9.0
	var right := pos + dir.rotated(deg_to_rad(-140)) * 9.0
	# Glow
	draw_line(pos, tip,   Color(c.r, c.g, c.b, 0.25), 4.0)
	draw_line(tip, left,  Color(c.r, c.g, c.b, 0.25), 4.0)
	draw_line(tip, right, Color(c.r, c.g, c.b, 0.25), 4.0)
	# Sharp line
	draw_line(pos, tip,   c, 1.5)
	draw_line(tip, left,  c, 1.5)
	draw_line(tip, right, c, 1.5)

# ── Player ────────────────────────────────────────────────────────────────────
func _show_message(txt: String) -> void:
	message_text = txt
	message_timer = 4.0

func _refresh_objective() -> void:
	if phase == "day":
		var count = 0
		for k in contacts: if contacts[k]: count += 1
		current_objective = "Day: Meet contacts (%d/3)" % count
		if count == 3: current_objective += " - [TAB] to start Night"
	else:
		if not takedown_done:
			current_objective = "Night: Eliminate Alden"
		else:
			current_objective = "Night: Reach Extraction (Alley)"

func _apply_phase_visibility() -> void:
	for npc in contact_npcs: npc.visible = (phase == "day")
	for npc in civilian_npcs: npc.visible = (phase == "day")
	if target_npc: target_npc.visible = (phase == "night")
	for npc in guard_npcs: npc.visible = (phase == "night")
	if extraction_marker: extraction_marker.visible = (phase == "night" and takedown_done)

func _all_contacts_met() -> bool:
	for k in contacts:
		if not contacts[k]: return false
	return true

func _fail_mission(reason: String) -> void:
	mission_failed = true
	_show_message("MISSION FAILED: " + reason)
	if player: player.set_physics_process(false)

# ── NPCs ──────────────────────────────────────────────────────────────────────
func _update_prompt() -> void:
	hud.prompt_panel.visible = false
	if mission_failed or level_complete: return
	for npc in npc_root.get_children():
		if npc.can_interact(player) or npc.is_takedown_reachable(player):
			hud.prompt.text = "[ E ] " + ("Talk to " if npc.role == "contact" else "Takedown ") + npc.npc_name
			hud.prompt_panel.visible = true
			return
	if near_extraction and takedown_done:
		hud.prompt.text = "[ E ] Extract"; hud.prompt_panel.visible = true

# ── Extraction zone ───────────────────────────────────────────────────────────
func _create_extraction() -> void:
	var area := Area2D.new()
	area.name = "ExtractionZone"
	area.collision_layer = 0
	area.collision_mask  = 1
	var cs := CollisionShape2D.new()
	var sh := RectangleShape2D.new()
	sh.size = Vector2(60.0, 48.0)
	cs.shape = sh
	area.add_child(cs)
	area.position = GameConstants.EXTRACTION_POS
	area.body_entered.connect(_on_extract_entered)
	area.body_exited.connect(_on_extract_exited)
	add_child(area)
	extraction_area = area

	# Visual marker (visibility toggled by mission_controller)
	extraction_marker          = Node2D.new()
	extraction_marker.name     = "ExtractionMarker"
	extraction_marker.position = GameConstants.EXTRACTION_POS
	extraction_marker.visible  = false
	add_child(extraction_marker)

func _on_extract_entered(body) -> void:
	if body == player:
		near_extraction = true

func _on_extract_exited(body) -> void:
	if body == player:
		near_extraction = false

# ── Shadow zones ──────────────────────────────────────────────────────────────
func _create_shadow_zones() -> void:
	for data: Array in [
		[GameConstants.R_WEST,                              "ShadowWest"],
		[GameConstants.R_EAST,                              "ShadowEast"],
		[Rect2(100, 20, 122, 65),                         "ShadowAlleyLeft"],
		[Rect2(418, 20, 122, 65),                         "ShadowAlleyRight"],
		[Rect2(120, 150, 40, 220),                        "ShadowMainLeft"],
		[Rect2(420, 150, 60, 220),                        "ShadowMainRight"],
	]:
		var area := Area2D.new()
		area.name            = data[1]
		area.collision_layer = 0
		area.collision_mask  = 1
		var cs := CollisionShape2D.new()
		var sh := RectangleShape2D.new()
		sh.size  = (data[0] as Rect2).size
		cs.shape = sh
		area.position = (data[0] as Rect2).get_center()
		area.add_child(cs)
		area.body_entered.connect(_on_shadow_entered)
		area.body_exited.connect(_on_shadow_exited)
		add_child(area)

func _on_shadow_entered(body) -> void:
	if body == player:
		player.enter_shadow()

func _on_shadow_exited(body) -> void:
	if body == player:
		player.exit_shadow()

# ── Game loop ─────────────────────────────────────────────────────────────────
func _process(delta: float) -> void:
	if message_timer > 0.0:
		message_timer -= delta
		if message_timer <= 0.0:
			message_text = ""
	_update_hud_elements()
	_update_prompt()
	queue_redraw()   # needed for extraction pulse, suspicion bar, night pools

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("interact"):
		_handle_interaction()

	elif event.is_action_pressed("phase_switch"):
		if phase == "day" and not phase_transition_in_progress:
			if _all_contacts_met():
				phase_transition_in_progress = true
				await _begin_night()
				phase_transition_in_progress = false
			else:
				_show_message(
					"Talk to all three contacts before starting the night.")

	elif event.is_action_pressed("restart_level") and (mission_failed or level_complete):
		get_tree().reload_current_scene()

	elif event.is_action_pressed("toggle_fullscreen"):
		var win := get_viewport().get_window()
		if win.mode in [Window.MODE_FULLSCREEN, Window.MODE_EXCLUSIVE_FULLSCREEN]:
			win.mode = Window.MODE_WINDOWED
		else:
			win.mode = Window.MODE_FULLSCREEN

	elif event.is_action_pressed("pause"):
		_show_message("Paused. Press Esc to resume.")

# ── Night phase transition ────────────────────────────────────────────────────
func _begin_night() -> void:
	# Fade out title + objective, fade in night tint
	var tw := create_tween()
	tw.set_parallel(true)
	tw.tween_property(hud["title"],     "modulate:a", 0.0, 0.5).set_delay(0.4)
	tw.tween_property(hud["objective"], "modulate:a", 0.0, 0.5).set_delay(0.4)
	tw.tween_property(_night_tint,      "color",
		Color(0.0, 0.03, 0.12, 0.58), 1.2)
	await tw.finished

	phase     = "night"
	suspicion = 0.0
	player.position = night_start_position
	_apply_phase_visibility()
	_refresh_objective()
	queue_redraw()

	# Fade title + objective back in
	var tw2 := create_tween()
	tw2.set_parallel(true)
	tw2.tween_property(hud["title"],     "modulate:a", 1.0, 0.5)
	tw2.tween_property(hud["objective"], "modulate:a", 1.0, 0.5)
	_show_message(
		"Night phase. Alden is in the main hall. Get behind him and strike. Extract through the alley.")

# ── Mission helpers called by NPCs ────────────────────────────────────────────
func raise_suspicion(amount: float, source_name := "") -> void:
	if mission_failed or level_complete:
		return
	if takedown_done:
		amount *= 1.6
		if not night2_active:
			night2_active = true
			for npc in guard_npcs:
				npc.detect_radius *= 1.3
				npc.detect_rate *= 1.4
				npc.patrol_speed *= 1.2
			_show_message("Night 2: Guards on alert - faster, wider vision.")

	var previous_suspicion: float = float(suspicion)
	suspicion = min(suspicion + amount, 100.0)
	var previous_bucket := int(floor(previous_suspicion / 20.0))
	var current_bucket := int(floor(suspicion / 20.0))
	if source_name != "" and current_bucket > previous_bucket and current_bucket >= 1 and current_bucket < 5:
		_show_message("%s is getting a look at you." % source_name)
	if suspicion >= 100.0:
		_fail_mission("Cover blown. The gala turns hostile.")

# =============================================================================
# CONSOLIDATED LOGIC
# =============================================================================
func _init_input_map() -> void:
	var map = {
		"move_left": KEY_A, "move_right": KEY_D, "move_forward": KEY_W, "move_back": KEY_S,
		"interact": KEY_E, "phase_switch": KEY_TAB, "restart_level": KEY_R,
		"toggle_fullscreen": KEY_F11, "pause": KEY_P, "toggle_mouse_capture": KEY_ESCAPE
	}
	for act in map:
		if not InputMap.has_action(act):
			InputMap.add_action(act)
			var ev = InputEventKey.new(); ev.keycode = map[act]
			InputMap.action_add_event(act, ev)

func _build_level_geometry() -> void:
	# Camera setup
	var camera = Camera2D.new(); camera.position_smoothing_enabled = true
	camera.zoom = Vector2(1.8, 1.8); add_child(camera); _camera = camera
	
	# Tint & HUD Layers
	var tint_layer = CanvasLayer.new(); tint_layer.layer = 0; add_child(tint_layer)
	_night_tint = ColorRect.new(); _night_tint.size = Vector2(1000, 1000)
	_night_tint.position = Vector2(-500, -500); _night_tint.color = Color(0,0,0,0)
	tint_layer.add_child(_night_tint)
	_hud_layer = CanvasLayer.new(); _hud_layer.layer = 1; add_child(_hud_layer)
	
	# Walls & Pillars
	_pillars = [Vector2(195, 210), Vector2(365, 210), Vector2(195, 315), Vector2(365, 315)]
	for p in _pillars: 
		_add_phys_circle(p, 9.0)
		
	_neon_strips = [
		[Vector2(120, 165), Vector2(480, 165), GameConstants.C_NEON_PINK],
		[Vector2(120, 358), Vector2(480, 358), GameConstants.C_NEON_CYAN],
		[Vector2(100, 88), Vector2(540, 88), GameConstants.C_NEON_AMB]
	]
	
	var wall_rects = [
		Rect2(20, 12, 600, 7), Rect2(20, 606, 600, 7), 
		Rect2(12, 12, 7, 601), Rect2(621, 12, 7, 601)
	]
	for w in wall_rects: 
		_add_phys_rect(w)

func _add_phys_rect(rect: Rect2) -> void:
	var b = StaticBody2D.new(); b.position = rect.get_center()
	var cs = CollisionShape2D.new(); var sh = RectangleShape2D.new()
	sh.size = rect.size; cs.shape = sh; b.add_child(cs); add_child(b)

func _add_phys_circle(pos: Vector2, r: float) -> void:
	var b = StaticBody2D.new(); b.position = pos
	var cs = CollisionShape2D.new(); var sh = CircleShape2D.new()
	sh.radius = r; cs.shape = sh; b.add_child(cs); add_child(b)

func _spawn_player_node() -> void:
	player = GameConstants.PLAYER_SCRIPT.new(); player.world_ref = self
	var cs = CollisionShape2D.new(); var sh = CircleShape2D.new()
	sh.radius = 6.0; cs.shape = sh; player.add_child(cs)
	player.position = Vector2(320.0, 530.0); add_child(player)
	_camera.reparent(player); _camera.position = Vector2.ZERO

func _spawn_npc_nodes() -> void:
	for s in GameConstants.NPC_SPAWNS:
		var npc = GameConstants.NPC_SCRIPT.new(); npc.world_ref = self
		npc.setup(s.role, s.name, s.key, s.phase)
		npc.position = s.pos; npc.patrol_points.assign(s.patrol)
		npc.suspicion_detected.connect(raise_suspicion)
		var cs = CollisionShape2D.new(); var sh = CircleShape2D.new()
		sh.radius = 5.0; cs.shape = sh; npc.add_child(cs)
		npc_root.add_child(npc)
		match s.role:
			"contact": contact_npcs.append(npc)
			"guard", "witness": guard_npcs.append(npc)
			"civilian": civilian_npcs.append(npc)
			"target": target_npc = npc

func _setup_hud() -> void:
	hud.title = _create_label("GOLDEN BOY", 16, Vector2(150, 6), GameConstants.C_GOLD)
	hud.objective = _create_label("", 7, Vector2(6, 256), Color("#aabbcc"))
	hud.money = _create_label("$0", 7, Vector2(6, 8), Color("#44bb66"))
	hud.message = _create_label("", 8, Vector2(70, 128), Color("#ffffff"))
	hud.suspicion = _create_label("", 7, Vector2(330, 248), Color("#ff8866"))
	hud.prompt_panel = Control.new(); hud.prompt = _create_label("", 8, Vector2(90, 228), Color("#ffdd88"))
	hud.prompt_panel.add_child(hud.prompt); hud.prompt_panel.visible = false
	hud.phase_hint = _create_label("[ TAB ] Start Night", 6, Vector2(6, 264), Color(0.4, 0.4, 0.5))
	for node in [hud.title, hud.objective, hud.money, hud.message, hud.suspicion, hud.prompt_panel, hud.phase_hint]: 
		_hud_layer.add_child(node)

func _create_label(t: String, s: int, p: Vector2, c: Color) -> Label:
	var l = Label.new(); l.text = t; l.position = p
	l.add_theme_font_size_override("font_size", s); l.add_theme_color_override("font_color", c)
	return l

func _update_hud_elements() -> void:
	hud.objective.text = current_objective
	hud.money.text = "$" + str(money)
	hud.message.text = message_text; hud.message.visible = message_text != ""
	hud.suspicion.text = "SUSPICION: " + str(int(suspicion)) if phase == "night" else ""
	hud.phase_hint.visible = (phase == "day" and not mission_failed)

func _handle_contact_logic(npc) -> void:
	if npc.interaction_used: return
	npc.interaction_used = true; npc.set_marker_visible(false)
	contacts[npc.contact_key] = true; _refresh_objective()
	_show_message("Contact secure: " + npc.npc_name)

func _handle_interaction() -> void:
	if mission_failed or level_complete: return
	for npc in npc_root.get_children():
		if npc.can_interact(player):
			_handle_contact_logic(npc); return
		if npc.is_takedown_reachable(player):
			takedown_done = true; npc.visible = false; _refresh_objective()
			_show_message("Target neutralized. Get to the extraction point!"); return
	if near_extraction and takedown_done:
		level_complete = true; _show_message("Extraction successful. Mission Complete!")
