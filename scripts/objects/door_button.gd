extends Interactable

signal locked_interaction(button: Node)

@export var door_path: NodePath
@export var locked: bool = false
@export var required_item_id: String = ""
@export var consume_required_item: bool = true
@export_multiline var fail_message: String = "You need a key to open this door."

var _door = null
var _prompt_override_until: float = 0.0
var _persistent_highlight: bool = false
var _highlight_enabled: bool = false

@onready var _mesh: MeshInstance3D = get_node_or_null("MeshInstance3D") as MeshInstance3D

func _ready() -> void:
	if door_path:
		_door = get_node(door_path)
	_setup_highlight_material()
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
		if required_item_id != "" and GameState.has_selected_item(required_item_id):
			if consume_required_item:
				GameState.consume_selected_item(required_item_id)
			locked = false
			_prompt_override_until = 0.0
		else:
			_prompt_override_until = Time.get_ticks_msec() * 0.001 + 1.8
			locked_interaction.emit(self)
			_update_prompt()
			return
	_door.interact()

func set_persistent_highlight(enabled: bool) -> void:
	_persistent_highlight = enabled
	set_highlight_enabled(enabled)

func set_highlight_enabled(enabled: bool) -> void:
	_highlight_enabled = enabled or _persistent_highlight
	if not _highlight_enabled:
		_apply_highlight(0.0)

func set_highlight_strength(strength: float) -> void:
	if not _highlight_enabled:
		return
	_apply_highlight(strength)

func _setup_highlight_material() -> void:
	if _mesh == null:
		return
	var base_material: StandardMaterial3D = _mesh.material_override as StandardMaterial3D
	if base_material == null:
		base_material = StandardMaterial3D.new()
		base_material.albedo_color = Color(0.18, 0.08, 0.08, 1.0)
	var highlight_material: StandardMaterial3D = base_material.duplicate() as StandardMaterial3D
	_mesh.material_override = highlight_material

func _apply_highlight(strength: float) -> void:
	if _mesh == null:
		return
	var material: StandardMaterial3D = _mesh.material_override as StandardMaterial3D
	if material == null:
		return
	material.emission_enabled = strength > 0.001
	material.emission = Color(1.0, 0.24, 0.18, 1.0)
	material.emission_energy_multiplier = 0.6 + strength * 4.0
