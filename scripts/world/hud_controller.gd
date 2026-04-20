extends RefCounted

# Runtime HUD creation, layout, and text refresh.
static func create_hud(world) -> void:
	world.ui_root = Control.new()
	world.ui_root.name = "HUD"
	world.add_child(world.ui_root)
	world.ui_root.set_anchors_preset(Control.PRESET_FULL_RECT)

	var title = Label.new()
	title.text = "ALLEY"
	title.add_theme_font_size_override("font_size", 11)
	title.add_theme_color_override("font_color", Color("68d4ff"))
	world.ui_root.add_child(title)
	world.hud["title"] = title

	var objective = Label.new()
	objective.autowrap_mode = TextServer.AUTOWRAP_WORD
	objective.add_theme_font_size_override("font_size", 12)
	objective.add_theme_color_override("font_color", Color("e6ecff"))
	world.ui_root.add_child(objective)
	world.hud["objective"] = objective

	var stats = Label.new()
	stats.autowrap_mode = TextServer.AUTOWRAP_WORD
	stats.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	stats.add_theme_font_size_override("font_size", 10)
	stats.add_theme_color_override("font_color", Color("7a8999"))
	world.ui_root.add_child(stats)
	world.hud["stats"] = stats

	var message = Label.new()
	message.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	message.add_theme_font_size_override("font_size", 13)
	message.add_theme_color_override("font_color", Color("fff3c6"))
	world.ui_root.add_child(message)
	world.hud["message"] = message

	var prompt_panel = ColorRect.new()
	prompt_panel.color = Color(0.02, 0.03, 0.05, 0.58)
	world.ui_root.add_child(prompt_panel)
	world.hud["prompt_panel"] = prompt_panel

	var prompt = Label.new()
	prompt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	prompt.add_theme_font_size_override("font_size", 11)
	prompt.add_theme_color_override("font_color", Color("8a9aaa"))
	world.ui_root.add_child(prompt)
	world.hud["prompt"] = prompt

	layout_hud(world)
	var viewport = world.get_viewport()
	var resize_callable = Callable(world, "_on_viewport_size_changed")
	if viewport != null and not viewport.size_changed.is_connected(resize_callable):
		viewport.size_changed.connect(resize_callable)

static func on_viewport_size_changed(world) -> void:
	layout_hud(world)

static func layout_hud(world) -> void:
	if world.ui_root == null or not is_instance_valid(world.ui_root):
		return

	var title = world.hud.get("title") as Label
	var objective = world.hud.get("objective") as Label
	var stats = world.hud.get("stats") as Label
	var message = world.hud.get("message") as Label
	var prompt_panel = world.hud.get("prompt_panel") as ColorRect
	var prompt = world.hud.get("prompt") as Label
	if title == null or objective == null or stats == null or message == null or prompt_panel == null or prompt == null:
		return

	var viewport_size = world.get_viewport().get_visible_rect().size
	if viewport_size.x <= 1.0 or viewport_size.y <= 1.0:
		return

	var margin = clampf(viewport_size.y * 0.012, 8.0, 18.0)
	var objective_width = clampf(viewport_size.x * 0.42, 280.0, 640.0)
	var objective_height = clampf(viewport_size.y * 0.085, 32.0, 88.0)
	var stats_width = clampf(viewport_size.x * 0.18, 170.0, 280.0)
	var stats_height = clampf(viewport_size.y * 0.11, 54.0, 104.0)
	var message_width = clampf(viewport_size.x * 0.45, 320.0, 760.0)
	var message_height = clampf(viewport_size.y * 0.05, 28.0, 56.0)
	var prompt_width = clampf(viewport_size.x * 0.55, 300.0, 780.0)
	var prompt_height = clampf(viewport_size.y * 0.035, 24.0, 36.0)

	title.position = Vector2(margin, margin)
	objective.position = Vector2(margin, margin + 16.0)
	objective.size = Vector2(objective_width, objective_height)

	stats.position = Vector2(viewport_size.x - margin - stats_width, margin)
	stats.size = Vector2(stats_width, stats_height)

	message.position = Vector2((viewport_size.x - message_width) * 0.5, margin + 2.0)
	message.size = Vector2(message_width, message_height)

	prompt_panel.position = Vector2((viewport_size.x - prompt_width) * 0.5, viewport_size.y - margin - prompt_height)
	prompt_panel.size = Vector2(prompt_width, prompt_height)

	var prompt_label_height = max(16.0, prompt_height - 8.0)
	prompt.position = prompt_panel.position + Vector2(14.0, (prompt_height - prompt_label_height) * 0.5)
	prompt.size = Vector2(prompt_width - 28.0, prompt_label_height)

static func update_hud(world) -> void:
	world.hud["objective"].text = world.current_objective
	world.hud["stats"].text = "Phase: %s\nReputation: %d\nSuspicion: %d\nHeat: %d\nMoney: $%s\nHidden: %s" % [
		world.phase.capitalize(),
		int(round(world.reputation)),
		int(round(world.suspicion)),
		int(round(world.heat)),
		world._format_money(world.money),
		"Yes" if world.player and world.player.is_hidden() else "No"
	]
	world.hud["message"].text = world.message_text
