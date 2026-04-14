extends Interactable

var is_open: bool = false
@export var slide_distance: float = 2.4
@export var open_duration: float = 1.0

func _ready() -> void:
	prompt_text = "Press E to open door"

func interact() -> void:
	if is_open:
		return
	_open_door()

func _open_door() -> void:
	is_open = true
	prompt_text = ""
	var tween = create_tween()
	# Slide the door up into the ceiling or wall by slide_distance
	tween.tween_property(self, "position", position + Vector3(0, slide_distance, 0), open_duration)
