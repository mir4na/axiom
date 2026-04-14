extends Interactable

func _ready() -> void:
	prompt_text = "Press E to dig"

func get_equip_hint() -> String:
	return "Shovel"

func interact() -> void:
	if GameState.slots[GameState.selected_slot] == "Shovel":
		GameState.consume_selected()
		
		var shovel_scene = load("res://scenes/objects/shovel.tscn")
		var s = shovel_scene.instantiate()
		get_tree().root.add_child(s)
		
		s.global_position = global_position + Vector3(0, 0.05, 0)
		s.rotation_degrees = Vector3(90, 45, 0)
		
		queue_free()
