extends RefCounted

# World scaling utility for realistic human proportions.
# Applies consistent scale factors across player, buildings, streets, and gameplay.

# Scale factors (apply to all X,Z coordinates and related gameplay values)
const WORLD_SCALE_XZ := 1.8  # Make streets/distances larger (1.8x)
const WORLD_SCALE_Y := 1.5   # Make buildings taller
const PLAYER_SPEED_SCALE := 0.25  # Slow down walk speed from 8.4 to ~2.0 m/s
const DETECTION_RANGE_SCALE := 1.2  # NPCs detect slightly further in larger world

static func scale_position(pos: Vector3) -> Vector3:
	"""Scale XZ dimensions, keep Y as-is for most gameplay."""
	return Vector3(pos.x * WORLD_SCALE_XZ, pos.y, pos.z * WORLD_SCALE_XZ)

static func scale_position_with_height(pos: Vector3) -> Vector3:
	"""Scale all dimensions including height (for architecture)."""
	return Vector3(pos.x * WORLD_SCALE_XZ, pos.y * WORLD_SCALE_Y, pos.z * WORLD_SCALE_XZ)

static func scale_size(size: Vector3, scale_height: bool = false) -> Vector3:
	"""Scale box dimensions. Optionally include height."""
	var scaled = Vector3(size.x * WORLD_SCALE_XZ, size.y, size.z * WORLD_SCALE_XZ)
	if scale_height:
		scaled.y *= WORLD_SCALE_Y
	return scaled

static func scale_float_xz(value: float) -> float:
	"""Scale a single floating point value (for detection ranges, etc.)."""
	return value * WORLD_SCALE_XZ
