extends Interactable

@export var required_key: String = "key_1"

@onready var _collision: CollisionShape3D = $CollisionShape3D
@onready var _mesh: MeshInstance3D = $MeshInstance3D

func _ready() -> void:
	prompt_text = "Press E to Unlock Door"

func interact() -> void:
	if GameState.slots[GameState.selected_slot] == required_key:
		queue_free()
	else:
		var players = get_tree().get_nodes_in_group("player")
		if players.size() > 0:
			var hud = players[0].get_node("PlayerHUD")
			hud.show_prompt("Requires active key in hand!")
