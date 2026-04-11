extends Interactable

@export var key_id: String = "key_1"

func _ready() -> void:
	prompt_text = "Press E to pick up Key"

func interact() -> void:
	var collected = GameState.add_item(key_id)
	if collected:
		queue_free()
