extends Interactable

func _ready() -> void:
	prompt_text = "Press E to pick up Shovel"

func interact() -> void:
	if GameState.add_item("Shovel"):
		queue_free()
