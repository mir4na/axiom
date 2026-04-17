extends Interactable

@export var is_dropped: bool = false
var is_picked_up: bool = false
var _highlight_enabled: bool = false
var _base_handle_color: Color = Color(0.4, 0.2, 0.1, 1)
var _base_blade_color: Color = Color(0.7, 0.7, 0.7, 1)

@onready var handle: CSGCylinder3D = $Handle
@onready var blade: CSGBox3D = $Blade

func _ready() -> void:
	if is_dropped:
		prompt_text = ""
	else:
		prompt_text = "Press E to pick up Shovel"
	if handle.material != null:
		_base_handle_color = handle.material.albedo_color
	if blade.material != null:
		_base_blade_color = blade.material.albedo_color

func interact() -> void:
	if is_dropped or is_picked_up:
		return
		
	is_picked_up = true
	if GameState.add_item("Shovel"):
		prompt_text = ""
		var tween = create_tween()
		tween.set_parallel(true)
		tween.tween_property(self, "position", position + Vector3(0, 1.5, 0), 0.4)
		tween.tween_property(self, "rotation_degrees", rotation_degrees + Vector3(0, 360, 0), 0.4)
		tween.tween_property(self, "scale", Vector3.ZERO, 0.4)
		await tween.finished
		queue_free()

func set_highlight_enabled(enabled: bool) -> void:
	_highlight_enabled = enabled
	if not enabled:
		_apply_highlight(0.0)

func set_highlight_strength(strength: float) -> void:
	if not _highlight_enabled:
		return
	_apply_highlight(strength)

func _apply_highlight(strength: float) -> void:
	var glow_color := Color(0.82, 0.98, 0.62, 1.0)
	if handle.material != null:
		handle.material.emission_enabled = strength > 0.01
		handle.material.emission = glow_color
		handle.material.emission_energy_multiplier = 0.5 + strength * 1.8
		handle.material.albedo_color = _base_handle_color.lerp(glow_color, strength * 0.3)
	if blade.material != null:
		blade.material.emission_enabled = strength > 0.01
		blade.material.emission = glow_color
		blade.material.emission_energy_multiplier = 0.8 + strength * 2.4
		blade.material.albedo_color = _base_blade_color.lerp(glow_color, strength * 0.45)
