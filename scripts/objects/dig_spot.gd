extends Interactable

var dig_progress: float = 0.0
var is_digging: bool = false

func _ready() -> void:
	prompt_text = "Hold E to dig"

func get_equip_hint() -> String:
	return "Shovel"

func interact() -> void:
	pass

func progress_minigame(delta: float) -> float:
	if GameState.slots[GameState.selected_slot] == "Shovel":
		if not is_digging:
			is_digging = true
			prompt_text = "Keep Holding E!"
			return 0.0
		else:
			dig_progress += 40.0 * delta # Takes 2.5 seconds of holding
			if dig_progress >= 100.0:
				_finish_dig()
			return dig_progress
	return -1.0

func _finish_dig() -> void:
	GameState.consume_selected()
	var shovel_scene = load("res://scenes/objects/shovel.tscn")
	var s = shovel_scene.instantiate()
	s.global_position = global_position + Vector3(0, 0.05, 0)
	s.rotation_degrees = Vector3(90, 45, 0)
	s.is_dropped = true
	get_tree().root.add_child(s)
	queue_free()

func reset_minigame() -> void:
	if is_digging:
		is_digging = false
		dig_progress = 0.0
		prompt_text = "Hold E to dig"
