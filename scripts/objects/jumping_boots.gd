extends Interactable

signal collected(multiplier: float)

@export var item_id: String = "JumpBoots"
@export var jump_multiplier: float = 3.0

@onready var _collision: CollisionShape3D = $CollisionShape3D
@onready var _mesh: MeshInstance3D = $MeshInstance3D
@onready var _aura: MeshInstance3D = $Aura
@onready var _glow: OmniLight3D = $Glow

var _picked: bool = false
var _highlight_enabled: bool = false
var _persistent_highlight: bool = true

func _ready() -> void:
	prompt_text = "Press E to equip Jumping Boots"
	_setup_highlight()
	set_highlight_enabled(true)

func interact() -> void:
	if _picked:
		return
	var added: bool = GameState.add_item(item_id)
	if not added:
		added = GameState.add_item_first_free_slot(item_id)
	if not added:
		_show_prompt("Inventory is full")
		return
	GameState.select_item(item_id)
	_picked = true
	prompt_text = ""
	if _collision != null:
		_collision.disabled = true
	_persistent_highlight = false
	set_highlight_enabled(false)
	collected.emit(jump_multiplier)
	var tween: Tween = create_tween().set_parallel(true)
	tween.tween_property(self, "position", position + Vector3(0.0, 0.9, 0.0), 0.3)
	tween.tween_property(self, "rotation_degrees", rotation_degrees + Vector3(0.0, 360.0, 0.0), 0.3)
	tween.tween_property(self, "scale", Vector3.ZERO, 0.3)
	await tween.finished
	queue_free()

func set_highlight_enabled(enabled: bool) -> void:
	_highlight_enabled = (enabled or _persistent_highlight) and visible and not _picked
	if _aura != null:
		_aura.visible = _highlight_enabled
	if _glow != null:
		_glow.visible = _highlight_enabled
	if not _highlight_enabled:
		_apply_highlight(0.0)

func set_highlight_strength(strength: float) -> void:
	if not _highlight_enabled:
		return
	_apply_highlight(strength)

func _setup_highlight() -> void:
	if _aura == null:
		return
	var shader: Shader = load("res://shaders/objective_highlight.gdshader") as Shader
	if shader == null:
		return
	var material := ShaderMaterial.new()
	material.shader = shader
	material.set_shader_parameter("glow_color", Color(0.25, 0.78, 1.0, 1.0))
	_aura.material_override = material
	_aura.visible = false
	if _glow != null:
		_glow.visible = false

func _apply_highlight(strength: float) -> void:
	if _aura != null and _aura.material_override is ShaderMaterial:
		(_aura.material_override as ShaderMaterial).set_shader_parameter("highlight_strength", strength)
	if _glow != null:
		_glow.light_energy = 0.8 + strength * 2.2

func _show_prompt(text: String) -> void:
	var players: Array[Node] = get_tree().get_nodes_in_group("player")
	if players.is_empty():
		return
	var hud: Node = players[0].get_node_or_null("PlayerHUD")
	if hud != null and hud.has_method("show_prompt"):
		hud.call("show_prompt", text)
