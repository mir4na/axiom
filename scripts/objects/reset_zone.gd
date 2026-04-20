extends Area3D

func _ready() -> void:
	body_entered.connect(_on_body_entered)

func _on_body_entered(body: Node) -> void:
	if not body.is_in_group("player"):
		return
	var world := get_parent()
	if world != null and world.has_method("restart_current_level"):
		world.call_deferred("restart_current_level")
