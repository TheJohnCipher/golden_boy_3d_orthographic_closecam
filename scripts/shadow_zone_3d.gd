extends Area3D

# Shadow zones are invisible gameplay volumes placed by the world script around
# booths, alley clutter, sofas, vehicles, and similar cover pieces.
func _ready():
    body_entered.connect(_on_body_entered)
    body_exited.connect(_on_body_exited)

func _on_body_entered(body):
    # The player script keeps a counter so overlapping shadow volumes stack cleanly.
    if body and body.has_method("enter_shadow"):
        body.enter_shadow()

func _on_body_exited(body):
    if body and body.has_method("exit_shadow"):
        body.exit_shadow()
