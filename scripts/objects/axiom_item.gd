extends Interactable

func _ready() -> void:
	prompt_text = "Press E to pick up Axiom"

func interact() -> void:
	if GameState.add_item("Axiom"):
		queue_free()
