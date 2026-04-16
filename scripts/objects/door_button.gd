extends Interactable

@export var door_path: NodePath

var _door = null

func _ready() -> void:
	if door_path:
		_door = get_node(door_path)
	_update_prompt()

func _process(_delta: float) -> void:
	_update_prompt()

func _update_prompt() -> void:
	if _door == null:
		prompt_text = "Press E"
		return
	if _door.is_moving:
		prompt_text = "..."
	elif _door.is_open:
		prompt_text = "Press E to close door"
	else:
		prompt_text = "Press E to open door"

func interact() -> void:
	if _door == null or _door.is_moving:
		return
	_door.interact()
