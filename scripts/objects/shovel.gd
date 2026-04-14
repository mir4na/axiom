extends Interactable

@export var is_dropped: bool = false
var is_picked_up: bool = false

func _ready() -> void:
	if is_dropped:
		prompt_text = ""
	else:
		prompt_text = "Press E to pick up Shovel"

func interact() -> void:
	if is_dropped or is_picked_up:
		return
		
	is_picked_up = true
	if GameState.add_item("Shovel"):
		prompt_text = ""
		var tween = create_tween()
		tween.set_parallel(true)
		tween.tween_property(self, "position", position + Vector3(0, 1.5, 0), 0.4)
		tween.tween_property(self, "rotation_degrees", rotation_degrees + Vector3(0, 360, 0), 0.4)
		tween.tween_property(self, "scale", Vector3.ZERO, 0.4)
		await tween.finished
		queue_free()
