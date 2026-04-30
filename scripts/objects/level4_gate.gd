extends Interactable

signal gate_opened

@export var required_key: String = "key_3"
@export var level_four_scene_path: String = "res://scenes/levels/level_04.tscn"

@onready var _collision: CollisionShape3D = $CollisionShape3D
@onready var _mesh: MeshInstance3D = $MeshInstance3D
@onready var _aura: MeshInstance3D = $Aura
@onready var _glow: OmniLight3D = $Glow

var _enabled: bool = true
var _opening: bool = false

func _ready() -> void:
	_setup_highlight()
	_update_prompt()

func _process(_delta: float) -> void:
	_update_prompt()

func interact() -> void:
	if not _enabled or _opening:
		return
	if GameState.has_selected_item(required_key):
		GameState.consume_selected_item(required_key)
		_opening = true
		prompt_text = ""
		var tween: Tween = create_tween().set_parallel(true)
		tween.tween_property(_mesh, "scale", Vector3(1.0, 0.08, 1.0), 0.45).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
		tween.tween_property(_glow, "light_energy", 0.0, 0.45).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
		await tween.finished
		gate_opened.emit()
		return
	if GameState.has_item(required_key):
		_show_prompt("Select keycard slot first")
	else:
		_show_prompt("Keycard required")

func set_interactable_enabled(enabled: bool) -> void:
	_enabled = enabled
	visible = enabled
	if _collision != null:
		_collision.disabled = not enabled
	if _aura != null:
		_aura.visible = enabled
	if _glow != null:
		_glow.visible = enabled
	_update_prompt()

func set_highlight_enabled(enabled: bool) -> void:
	if _aura != null:
		_aura.visible = enabled and _enabled

func set_highlight_strength(strength: float) -> void:
	if _aura != null and _aura.material_override is ShaderMaterial:
		(_aura.material_override as ShaderMaterial).set_shader_parameter("highlight_strength", strength)
	if _glow != null:
		_glow.light_energy = 1.4 + strength * 2.0

func _update_prompt() -> void:
	if not _enabled:
		prompt_text = ""
		return
	if GameState.has_selected_item(required_key):
		prompt_text = "Press E to unlock Level 4 gate"
	elif GameState.has_item(required_key):
		prompt_text = "Select keycard slot, then press E"
	else:
		prompt_text = "Requires keycard"

func _setup_highlight() -> void:
	if _aura == null:
		return
	var shader: Shader = load("res://shaders/objective_highlight.gdshader") as Shader
	if shader == null:
		return
	var material := ShaderMaterial.new()
	material.shader = shader
	material.set_shader_parameter("glow_color", Color(0.22, 1.0, 0.64, 1.0))
	material.set_shader_parameter("highlight_strength", 0.9)
	_aura.material_override = material

func _show_prompt(text: String) -> void:
	var players: Array[Node] = get_tree().get_nodes_in_group("player")
	if players.is_empty():
		return
	var hud: Node = players[0].get_node_or_null("PlayerHUD")
	if hud != null and hud.has_method("show_prompt"):
		hud.call("show_prompt", text)
