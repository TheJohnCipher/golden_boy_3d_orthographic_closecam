extends RefCounted

# AI state management with line-of-sight memory and reaction states.
# Each NPC (guard, witness, target) maintains:
# - suspicion_level: cumulative detection confidence
# - reaction_state: investigate, alert, returning, normal
# - los_memory: recent sightings that decay over time

class NPCState:
	var npc_ref = null
	var suspicion_level: float = 0.0  # 0-100
	var reaction_state: String = "normal"  # normal, investigate, alert, returning
	var los_memory: Array = []  # Array of {position: Vector3, time: float}
	var memory_duration: float = 8.0
	var return_to_patrol_timer: float = 0.0
	
	func _init(npc) -> void:
		npc_ref = npc
	
	func update(delta: float) -> void:
		# Decay suspicion over time
		suspicion_level = max(0.0, suspicion_level - (delta * 2.0))
		
		# Clean up old memory entries
		var current_time = Time.get_ticks_msec() / 1000.0
		los_memory = los_memory.filter(func(entry): return current_time - entry.time < memory_duration)
		
		# Update state machine
		_update_reaction_state(delta)
	
	func record_sighting(position: Vector3) -> void:
		suspicion_level = min(100.0, suspicion_level + 12.0)
		var entry = {
			"position": position,
			"time": Time.get_ticks_msec() / 1000.0
		}
		los_memory.append(entry)
	
	func trigger_alert() -> void:
		suspicion_level = 100.0
		reaction_state = "alert"
		return_to_patrol_timer = 0.0
	
	func get_recent_sighting() -> Vector3:
		if los_memory.is_empty():
			return Vector3.ZERO
		return los_memory[-1].position
	
	func _update_reaction_state(delta: float) -> void:
		match reaction_state:
			"normal":
				if suspicion_level > 45.0:
					reaction_state = "investigate"
			
			"investigate":
				if suspicion_level > 80.0:
					reaction_state = "alert"
				elif suspicion_level < 15.0:
					reaction_state = "normal"
			
			"alert":
				if suspicion_level < 30.0:
					reaction_state = "returning"
					return_to_patrol_timer = 4.0
			
			"returning":
				return_to_patrol_timer -= delta
				if return_to_patrol_timer <= 0.0:
					reaction_state = "normal"

# Global NPC state tracker
static var npc_states: Dictionary = {}

static func get_npc_state(npc) -> NPCState:
	if npc == null:
		return null
	var npc_id = npc.get_instance_id()
	if not npc_states.has(npc_id):
		npc_states[npc_id] = NPCState.new(npc)
	return npc_states[npc_id]

static func update_all_states(delta: float) -> void:
	for state in npc_states.values():
		state.update(delta)

static func record_detection(npc, player_position: Vector3) -> void:
	var state = get_npc_state(npc)
	if state == null:
		return
	state.record_sighting(player_position)

static func trigger_npc_alert(npc) -> void:
	var state = get_npc_state(npc)
	if state == null:
		return
	state.trigger_alert()
	_alert_nearby_guards(npc, 15.0)

static func _alert_nearby_guards(source_npc, radius: float) -> void:
	if source_npc.world_ref == null:
		return
	for guard in source_npc.world_ref.guard_npcs:
		if guard == source_npc or guard == null:
			continue
		var distance = source_npc.global_position.distance_to(guard.global_position)
		if distance <= radius:
			trigger_npc_alert(guard)

static func get_reaction_state(npc) -> String:
	var state = get_npc_state(npc)
	return state.reaction_state if state else "normal"

static func get_suspicion(npc) -> float:
	var state = get_npc_state(npc)
	return state.suspicion_level if state else 0.0

static func clear_state(npc) -> void:
	var npc_id = npc.get_instance_id()
	npc_states.erase(npc_id)
