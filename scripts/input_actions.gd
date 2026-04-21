extends RefCounted

const IMPL = preload("res://scripts/world/input_actions.gd")

static func ensure_defaults() -> void:
	IMPL.ensure_defaults()
