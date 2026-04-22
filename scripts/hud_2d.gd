extends CanvasLayer

@onready var title      = $Title
@onready var objective  = $Objective
@onready var money      = $Money
@onready var message    = $Message
@onready var suspicion  = $SuspicionText
@onready var prompt_box = $PromptPanel
@onready var prompt_lbl = $PromptPanel/Prompt
@onready var phase_hint = $PhaseHint
@onready var bar_fill   = $SuspicionBar/Fill
@onready var bar_bg     = $SuspicionBar

var mission : Node # Reference to MissionManager

func setup(p_mission: Node) -> void:
	mission = p_mission
	mission.state_changed.connect(update_ui)
	update_ui()

func update_ui() -> void:
	objective.text = mission.current_objective
	money.text     = "$" + str(mission.money)
	
	# Suspicion logic
	var is_night = mission.phase == "night"
	bar_bg.visible = is_night
	suspicion.visible = is_night
	if is_night:
		suspicion.text = "SUSPICION: " + str(int(mission.suspicion))
		# Update the visual bar width (assuming max width is 140)
		bar_fill.size.x = (mission.suspicion / 100.0) * 140.0
		bar_fill.color = Color(1.0, 0.28, 0.28) if mission.suspicion > 60.0 else Color(0.85, 0.55, 0.30)
	
	phase_hint.visible = (mission.phase == "day" and not mission.is_failed)

func show_temporary_message(txt: String) -> void:
	message.text = txt
	message.visible = true
	await get_tree().create_timer(4.0).timeout
	if message.text == txt: # Only hide if no newer message overrode it
		message.visible = false

func set_prompt(txt: String) -> void:
	if txt == "":
		prompt_box.visible = false
	else:
		prompt_lbl.text = txt
		prompt_box.visible = true
