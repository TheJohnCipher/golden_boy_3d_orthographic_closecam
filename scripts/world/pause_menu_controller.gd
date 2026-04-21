extends RefCounted

# Pause menu overlay with input rebinding and options.
# Creates and manages pause UI, handles menu navigation and option changes.

const INPUT_REBIND_MANAGER = preload("res://scripts/world/input_rebind_manager.gd")

static func create_pause_menu(world) -> void:
	if world.ui_root == null:
		return
	
	var pause_overlay = ColorRect.new()
	pause_overlay.name = "PauseOverlay"
	pause_overlay.color = Color(0.0, 0.0, 0.0, 0.7)
	pause_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	world.ui_root.add_child(pause_overlay)
	world.pause_overlay = pause_overlay
	
	var pause_container = VBoxContainer.new()
	pause_container.name = "PauseContainer"
	pause_container.alignment = BoxContainer.ALIGNMENT_CENTER
	pause_container.add_theme_constant_override("separation", 8)
	pause_overlay.add_child(pause_container)
	pause_container.set_anchors_preset(Control.PRESET_CENTER)
	pause_container.custom_minimum_size = Vector2(300, 300)
	
	var title = Label.new()
	title.text = "PAUSED"
	title.add_theme_font_size_override("font_size", 20)
	title.add_theme_color_override("font_color", Color("68d4ff"))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	pause_container.add_child(title)
	
	# Resume button
	var resume_button = Button.new()
	resume_button.text = "Resume"
	resume_button.add_theme_font_size_override("font_size", 14)
	resume_button.custom_minimum_size = Vector2(200, 40)
	pause_container.add_child(resume_button)
	resume_button.pressed.connect(func(): _resume_game(world))
	
	# Restart button
	var restart_button = Button.new()
	restart_button.text = "Restart Level"
	restart_button.add_theme_font_size_override("font_size", 14)
	restart_button.custom_minimum_size = Vector2(200, 40)
	pause_container.add_child(restart_button)
	restart_button.pressed.connect(func(): _restart_level(world))
	
	pause_overlay.hide()
	world.pause_menu_container = pause_container

static func toggle_pause(world) -> void:
	if world.pause_overlay == null:
		create_pause_menu(world)
	
	if world.pause_overlay.visible:
		_resume_game(world)
	else:
		_show_pause_menu(world)

static func _show_pause_menu(world) -> void:
	world.pause_overlay.show()
	world.get_tree().paused = true

static func _resume_game(world) -> void:
	world.pause_overlay.hide()
	world.get_tree().paused = false

static func _restart_level(world) -> void:
	world.get_tree().paused = false
	world.get_tree().reload_current_scene()
