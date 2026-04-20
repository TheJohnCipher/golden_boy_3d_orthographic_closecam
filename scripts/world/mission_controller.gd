extends RefCounted

# Mission state machine and interaction rules extracted from `world_3d.gd`.
static func handle_interaction(world) -> void:
	if world.mission_failed or world.level_complete:
		return
	if world.near_extraction and world.extraction_marker.visible and world.takedown_done:
		complete_level(world)
		return

	var nearest = get_nearest_interactable(world)
	if nearest == null:
		return

	if nearest.role == "contact":
		handle_contact_interaction(world, nearest)
		return

	if nearest.role == "target" and world.phase == "night":
		attempt_takedown(world, nearest)
		return

static func handle_contact_interaction(world, npc) -> void:
	if npc.interaction_used:
		return
	npc.interaction_used = true
	npc.set_marker_visible(false)

	match npc.contact_key:
		"alibi":
			world.contacts["alibi"] = true
			world.reputation += 8.0
			world.heat = max(world.heat - 4.0, 0.0)
			show_message(world, "First contact secure. You've got an ally.")
		"guest_pass":
			world.contacts["guest_pass"] = true
			world.reputation += 6.0
			show_message(world, "Second contact made. Routes are confirmed.")
		"route_intel":
			world.contacts["route_intel"] = true
			world.reputation += 4.0
			show_message(world, "Third contact complete. Escape route locked in.")

	refresh_objective(world)
	if all_contacts_met(world):
		show_message(world, "All contacts made. Press Tab to begin night phase.")

static func attempt_takedown(world, npc) -> void:
	if world.takedown_done:
		return
	if not npc.is_takedown_reachable(world.player):
		world.suspicion = min(world.suspicion + 8.0, 100.0)
		show_message(world, "Too exposed. Get behind Alden or use cover first.")
		return
	if any_watcher_sees_player(world, npc):
		world.suspicion = min(world.suspicion + 18.0, 100.0)
		show_message(world, "Someone has sight on you. Break line of sight first.")
		if world.suspicion >= 100.0:
			fail_mission(world, "The gala locks down around you.")
		return

	world.takedown_done = true
	world.money += 15000
	world.heat += 24.0
	world.reputation -= 6.0
	npc.visible = false
	npc.set_process(false)
	world.extraction_marker.visible = true
	refresh_objective(world)
	show_message(world, "Alden is down. Cut through the loading alley and reach the safehouse.")

static func begin_night(world):
	if world.phase == "night":
		return

	var tween = world.create_tween()
	tween.parallel().tween_property(world.environment.environment, "ambient_light_energy", 0.26, 2.0)
	tween.parallel().tween_property(world.environment.environment, "background_color", Color("0c1018"), 2.0)
	tween.parallel().tween_property(world.day_sun, "visible", false, 1.0)
	tween.parallel().tween_property(world.moon_light, "visible", true, 1.0)
	tween.parallel().tween_property(world.hud["title"], "modulate:a", 0.0, 0.5).set_delay(1.5)
	tween.parallel().tween_property(world.hud["objective"], "modulate:a", 0.0, 0.5).set_delay(1.5)
	await tween.finished

	world.phase = "night"
	world.suspicion = 0.0
	world.player.position = Vector3(8.5, 0.0, 17.0)
	apply_phase_visibility(world)
	refresh_objective(world)

	var tween2 = world.create_tween()
	tween2.tween_property(world.hud["title"], "modulate:a", 1.0, 0.5)
	tween2.parallel().tween_property(world.hud["objective"], "modulate:a", 1.0, 0.5)
	show_message(world, "Night phase active. Target is in the alley. Take them down and extract through the north door.")

static func apply_phase_visibility(world) -> void:
	var night = world.phase == "night"
	for light in world.point_lights:
		light.visible = night

	for npc in world.npc_root.get_children():
		var is_active = npc.active_phase == world.phase or npc.active_phase == "both"
		npc.visible = is_active
		npc.set_physics_process(is_active)
		if npc.role == "contact":
			npc.set_marker_visible(is_active and not npc.interaction_used)
		elif npc.role == "target":
			npc.set_marker_visible(is_active and not world.takedown_done)
		else:
			npc.set_marker_visible(false)

	for marker in world.marker_root.get_children():
		if marker.name.begins_with("DayRouteMarker"):
			marker.visible = not night

	world.extraction_marker.visible = night and world.takedown_done
	world.day_sun.visible = not night
	world.moon_light.visible = night

static func update_prompt(world) -> void:
	var prompt = ""
	if world.mission_failed:
		prompt = "Mission failed. Press R to restart this level."
	elif world.level_complete:
		prompt = "Level complete. Press R to restart and tune the blockout."
	elif world.near_extraction and world.extraction_marker.visible and world.takedown_done:
		prompt = "Press E to enter the safehouse and end the level."
	else:
		var nearest = get_nearest_interactable(world)
		if nearest != null:
			if nearest.role == "contact":
				prompt = "Press E to talk to %s." % nearest.npc_name
			elif nearest.role == "target":
				if nearest.is_takedown_reachable(world.player):
					prompt = "Press E to take down %s." % nearest.npc_name
				else:
					prompt = "Shadow %s and get behind him before you strike." % nearest.npc_name
		elif world.phase == "day" and all_contacts_met(world):
			prompt = "Press Tab to start the gala night."

	world.hud["prompt"].text = prompt
	world.hud["prompt_panel"].visible = prompt != ""

static func refresh_objective(world) -> void:
	if world.mission_failed:
		world.current_objective = "Mission failed. Restart and try a cleaner run."
		return
	if world.level_complete:
		world.current_objective = "You escaped cleanly. Use this blockout as the base for production polish."
		return
	if world.phase == "day":
		var remaining = []
		if not world.contacts["alibi"]:
			remaining.append("contact at west bench")
		if not world.contacts["guest_pass"]:
			remaining.append("contact at center plaza")
		if not world.contacts["route_intel"]:
			remaining.append("contact at east side")
		if remaining.is_empty():
			world.current_objective = "All contacts met. Press Tab to start night phase."
		else:
			world.current_objective = "Make contact: %s." % ", ".join(remaining)
	else:
		if not world.takedown_done:
			world.current_objective = "Night phase: locate target, take them down silently."
		else:
			world.current_objective = "Target down. Reach the green door at the north end."

static func show_message(world, text: String) -> void:
	world.message_text = text
	world.message_timer = 4.0

static func get_nearest_interactable(world):
	if world.player == null or not is_instance_valid(world.player) or not world.player.is_inside_tree():
		return null
	if world.npc_root == null or not is_instance_valid(world.npc_root):
		return null
	var player_position = world.player.global_position
	var best = null
	var best_distance = 99999.0
	for npc in world.npc_root.get_children():
		if npc == null or not is_instance_valid(npc) or not npc.is_inside_tree():
			continue
		if not npc.visible:
			continue
		var dist = npc.global_position.distance_to(player_position)
		if npc.role == "contact" and npc.can_interact(world.player):
			if dist < best_distance:
				best = npc
				best_distance = dist
		elif npc.role == "target" and world.phase == "night" and not world.takedown_done and dist <= 2.75:
			if dist < best_distance:
				best = npc
				best_distance = dist
	return best

static func any_watcher_sees_player(world, ignore_npc = null) -> bool:
	for npc in world.npc_root.get_children():
		if npc == ignore_npc:
			continue
		if not npc.visible:
			continue
		if npc.role in ["guard", "witness"] and npc.can_detect_player(world.player):
			return true
	return false

static func raise_suspicion(world, amount: float, source_name := "") -> void:
	if world.mission_failed or world.level_complete:
		return
	if world.takedown_done:
		amount *= 1.6
		if not world.night2_active:
			world.night2_active = true
			for npc in world.guard_npcs:
				npc.detect_radius *= 1.3
				npc.detect_rate *= 1.4
				npc.patrol_speed *= 1.2
				show_message(world, "Night 2: Guards on alert - faster, wider vision.")
	world.suspicion = min(world.suspicion + amount, 100.0)
	if source_name != "" and int(world.suspicion) % 20 == 0:
		show_message(world, "%s is getting a better look at you." % source_name)
	if world.suspicion >= 100.0:
		fail_mission(world, "The room turns on you. Your cover collapses.")

static func fail_mission(world, reason: String) -> void:
	if world.mission_failed or world.level_complete:
		return
	world.mission_failed = true
	world.current_objective = "Mission failed. Press R to restart."
	show_message(world, reason)

static func complete_level(world) -> void:
	if world.level_complete:
		return
	world.level_complete = true
	world.current_objective = "Level complete. Press R to run the blockout again."
	show_message(world, "Clean exit. This is now a real first level blockout.")

static func on_extraction_body_entered(world, body) -> void:
	if body == world.player:
		world.near_extraction = true

static func on_extraction_body_exited(world, body) -> void:
	if body == world.player:
		world.near_extraction = false

static func all_contacts_met(world) -> bool:
	return world.contacts["alibi"] and world.contacts["guest_pass"] and world.contacts["route_intel"]

static func format_money(value) -> String:
	var s = str(value)
	var out = ""
	while s.length() > 3:
		out = "," + s.substr(s.length() - 3, 3) + out
		s = s.substr(0, s.length() - 3)
	out = s + out
	return out
