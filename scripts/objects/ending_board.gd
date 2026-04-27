extends Interactable

signal board_activated

@onready var _collision_shape: CollisionShape3D = get_node_or_null("CollisionShape3D") as CollisionShape3D
@onready var _aura: MeshInstance3D = get_node_or_null("Aura") as MeshInstance3D
@onready var _glow_light: OmniLight3D = get_node_or_null("GlowLight") as OmniLight3D
@onready var _message_label: Label3D = get_node_or_null("Message") as Label3D
@onready var _focus: Marker3D = get_node_or_null("Focus") as Marker3D

var _enabled: bool = false
var _highlight_enabled: bool = false
var _triggered: bool = false

func _ready() -> void:
	if _aura != null:
		_aura.visible = false
	if _glow_light != null:
		_glow_light.visible = false
		_glow_light.light_energy = 0.0
	if _message_label != null:
		_message_label.visible = false
	set_interactable_enabled(false)

func interact() -> void:
	if not _enabled or _triggered:
		return
	_triggered = true
	set_interactable_enabled(false)
	board_activated.emit()

func set_interactable_enabled(enabled: bool) -> void:
	_enabled = enabled
	prompt_text = "Press E to inspect board" if enabled else ""
	if _collision_shape != null:
		_collision_shape.disabled = not enabled
	set_highlight_enabled(enabled)
	if enabled:
		set_highlight_strength(1.0)

func set_board_text(text: String) -> void:
	if _message_label != null:
		_message_label.text = text

func set_message_visible(visible: bool) -> void:
	if _message_label != null:
		_message_label.visible = visible

func get_focus_position() -> Vector3:
	if _focus != null and is_instance_valid(_focus):
		return _focus.global_position
	return global_position + Vector3(0.0, 1.5, 0.0)

func set_highlight_enabled(enabled: bool) -> void:
	_highlight_enabled = enabled and _enabled
	if _aura != null:
		_aura.visible = _highlight_enabled
	if _glow_light != null:
		_glow_light.visible = _highlight_enabled
	if not _highlight_enabled:
		_apply_highlight(0.0)

func set_highlight_strength(strength: float) -> void:
	if not _highlight_enabled:
		return
	_apply_highlight(strength)

func _apply_highlight(strength: float) -> void:
	if _aura != null:
		_aura.scale = Vector3.ONE * (1.0 + strength * 0.06)
	if _glow_light != null:
		_glow_light.light_energy = 0.55 + strength * 1.35
