extends Interactable

var _picked_up: bool = false
var _highlight_enabled: bool = false
var _persistent_highlight: bool = true

@onready var _collision: CollisionShape3D = $CollisionShape3D
@onready var _bow_aura: MeshInstance3D = $BowAura
@onready var _glow_light: OmniLight3D = $GlowLight

func _ready() -> void:
	prompt_text = "Press E to pick up Bow"
	_setup_aura_materials()
	if _collision != null and _collision.disabled:
		set_interactable_enabled(false)
	else:
		set_interactable_enabled(true)

func interact() -> void:
	if _picked_up:
		return
	if not GameState.add_item("Bow"):
		return
	_picked_up = true
	prompt_text = ""
	if _collision != null:
		_collision.disabled = true
	_persistent_highlight = false
	set_highlight_enabled(false)
	_play_pickup_feedback()
	var tween: Tween = create_tween()
	tween.set_parallel(true)
	tween.tween_property(self, "position", position + Vector3(0.0, 1.0, 0.0), 0.35)
	tween.tween_property(self, "rotation_degrees", rotation_degrees + Vector3(0.0, 360.0, 0.0), 0.35)
	tween.tween_property(self, "scale", Vector3.ZERO, 0.35)
	await tween.finished
	queue_free()

func set_interactable_enabled(enabled: bool) -> void:
	visible = enabled
	prompt_text = "Press E to pick up Bow" if enabled else ""
	if _collision != null:
		_collision.disabled = not enabled
	_persistent_highlight = enabled
	set_highlight_enabled(enabled)
	if enabled:
		set_highlight_strength(1.0)

func set_highlight_enabled(enabled: bool) -> void:
	_highlight_enabled = (enabled or _persistent_highlight) and visible and not _picked_up
	if _bow_aura != null:
		_bow_aura.visible = false
	if _glow_light != null:
		_glow_light.visible = false

func set_highlight_strength(strength: float) -> void:
	pass

func _apply_highlight(strength: float) -> void:
	pass

func _setup_aura_materials() -> void:
	if _bow_aura != null:
		_bow_aura.visible = false
	if _glow_light != null:
		_glow_light.visible = false

func _play_pickup_feedback() -> void:
	var players: Array = get_tree().get_nodes_in_group("player")
	if players.is_empty():
		return
	var hud_node: Node = players[0].get_node_or_null("PlayerHUD")
	if hud_node != null and hud_node.has_method("play_slot_pickup_effect"):
		hud_node.call("play_slot_pickup_effect", GameState.selected_slot)
