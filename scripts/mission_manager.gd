extends Node

signal state_changed
signal mission_failed(reason: String)
signal mission_completed
signal message_requested(text: String)
signal difficulty_spiked

var phase              := "day"
var contacts           := {"alibi": false, "guest_pass": false, "route_intel": false}
var suspicion          := 0.0
var money              := 0
var takedown_done      := false
var night2_active      := false
var is_failed          := false
var is_complete       := false
var current_objective  := ""

func _ready() -> void:
	refresh_objective()

func add_contact(key: String, npc_name: String) -> void:
	if contacts.has(key) and not contacts[key]:
		contacts[key] = true
		message_requested.emit("Contact secure: " + npc_name)
		refresh_objective()
		state_changed.emit()

func raise_suspicion(amount: float, source_name := "") -> void:
	if is_failed or is_complete: return
	
	if takedown_done and not night2_active:
		night2_active = true
		difficulty_spiked.emit()
		message_requested.emit("Night 2: Guards on alert - faster, wider vision.")

	var prev_bucket := int(suspicion / 20.0)
	suspicion = min(suspicion + (amount * (1.6 if takedown_done else 1.0)), 100.0)
	var curr_bucket := int(suspicion / 20.0)
	
	if source_name != "" and curr_bucket > prev_bucket and curr_bucket in [1,2,3,4]:
		message_requested.emit("%s is getting a look at you." % source_name)
	
	if suspicion >= 100.0:
		is_failed = true
		mission_failed.emit("Cover blown. The gala turns hostile.")
	
	state_changed.emit()

func set_takedown_done() -> void:
	takedown_done = true
	message_requested.emit("Target neutralized. Get to the extraction point!")
	refresh_objective()
	state_changed.emit()

func start_night() -> void:
	phase = "night"
	suspicion = 0.0
	refresh_objective()
	state_changed.emit()

func refresh_objective() -> void:
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

func all_contacts_met() -> bool:
	for k in contacts:
		if not contacts[k]: return false
	return true

func complete_mission() -> void:
	is_complete = true
	is_failed = false
	message_requested.emit("Extraction successful. Mission Complete!")
	state_changed.emit()
	mission_completed.emit()

# ── 6. Save/Load System (JSON Serialization) ──
func get_save_data() -> Dictionary:
	return {
		"phase": phase,
		"contacts": contacts,
		"suspicion": suspicion,
		"takedown_done": takedown_done,
		"night2_active": night2_active,
		"is_failed": is_failed,
		"is_complete": is_complete
	}

func load_save_data(data: Dictionary) -> void:
	if data.has("phase"): phase = data["phase"]
	if data.has("contacts"): contacts = data["contacts"]
	if data.has("suspicion"): suspicion = data["suspicion"]
	if data.has("takedown_done"): takedown_done = data["takedown_done"]
	if data.has("night2_active"): night2_active = data["night2_active"]
	if data.has("is_failed"): is_failed = data["is_failed"]
	if data.has("is_complete"): is_complete = data["is_complete"]
	refresh_objective()
	state_changed.emit()

func save_to_file(path: String = "user://save_game.json") -> void:
	var file = FileAccess.open(path, FileAccess.WRITE)
	if file:
		var json_string = JSON.stringify(get_save_data())
		file.store_string(json_string)
		file.close()

func load_from_file(path: String = "user://save_game.json") -> void:
	if not FileAccess.file_exists(path): return
	var file = FileAccess.open(path, FileAccess.READ)
	if file:
		var json_string = file.get_as_text()
		file.close()
		var data = JSON.parse_string(json_string)
		if data is Dictionary:
			load_save_data(data)