extends RefCounted

const IMPL = preload("res://scripts/world/velvet_strip_builder.gd")

static func build(world: Node3D) -> void:
	IMPL.build(world)
