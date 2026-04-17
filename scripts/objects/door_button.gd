extends Interactable

signal locked_interaction(button: Node)

@export var door_path: NodePath
@export var locked: bool = false
@export var required_item_id: String = ""
@export var consume_required_item: bool = true
@export_multiline var fail_message: String = "You need a key to open this door."

var _door = null
var _prompt_override_until: float = 0.0

func _ready() -> void:
	if door_path:
		_door = get_node(door_path)
	_update_prompt()

func _process(_delta: float) -> void:
	_update_prompt()

func _update_prompt() -> void:
	if _prompt_override_until > Time.get_ticks_msec() * 0.001:
		prompt_text = fail_message
		return
	if _door == null:
		prompt_text = "Press E"
		return
	if locked:
		prompt_text = "Press E to open door"
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
	if locked:
		if required_item_id != "" and GameState.has_item(required_item_id):
			if consume_required_item:
				GameState.consume_item(required_item_id)
			locked = false
			_prompt_override_until = 0.0
		else:
			_prompt_override_until = Time.get_ticks_msec() * 0.001 + 1.8
			locked_interaction.emit(self)
			_update_prompt()
			return
	_door.interact()
