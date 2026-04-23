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
	if not mission.is_connected("state_changed", update_ui):
		mission.state_changed.connect(update_ui)
	if is_node_ready():
		update_ui()

func _ready() -> void:
	if mission:
		update_ui()

func update_ui() -> void:
	if mission == null or not is_node_ready() or title == null:
		return
		
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
	if not is_node_ready() or not is_inside_tree():
		return

	var tree = get_tree()
	if tree == null:
		return

	message.text = txt
	message.visible = true

	var timer = tree.create_timer(4.0)
	if timer == null:
		return

	await timer.timeout
	if is_instance_valid(message) and message.text == txt:
		message.visible = false

func set_prompt(txt: String) -> void:
	if not is_node_ready() or prompt_box == null:
		return
		
	if txt == "":
		prompt_box.visible = false
	else:
		prompt_lbl.text = txt
		prompt_box.visible = true
