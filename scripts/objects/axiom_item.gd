extends Interactable

func _ready() -> void:
	prompt_text = "Press E to pick up Axiom"

func interact() -> void:
	GameState.equip_axiom()
	queue_free()
