extends Node3D

@export var bob_speed: float = 0.85
@export var bob_height: float = 1.35
@export var drift_amount: float = 0.55
@export var spin_speed: float = 0.5

var _time: float = 0.0
var _float_nodes: Array[Node3D] = []
var _spin_nodes: Array[Node3D] = []
var _dream_houses: Array[Node3D] = []
var _base_positions: Dictionary = {}
var _phase_map: Dictionary = {}
var _drift_axis_map: Dictionary = {}

func _ready() -> void:
	randomize()
	_collect_houses()
	_apply_house_palette()
	_collect_nodes()

func _process(delta: float) -> void:
	if GameState.is_time_blocked():
		return
	_time += delta
	_animate_floaters()
	_animate_spinners(delta)

func _collect_nodes() -> void:
	_float_nodes.clear()
	_spin_nodes.clear()
	_base_positions.clear()
	_phase_map.clear()
	_drift_axis_map.clear()
	var float_group: Array[Node] = get_tree().get_nodes_in_group("dream_float")
	for entry: Node in float_group:
		var node3d: Node3D = entry as Node3D
		if node3d == null:
			continue
		_float_nodes.append(node3d)
		_base_positions[node3d] = node3d.position
		_phase_map[node3d] = randf_range(0.0, TAU)
		var axis: Vector3 = Vector3(randf_range(-1.0, 1.0), 0.0, randf_range(-1.0, 1.0))
		if axis.length_squared() <= 0.0001:
			axis = Vector3(1.0, 0.0, 0.0)
		_drift_axis_map[node3d] = axis.normalized()
	var spin_group: Array[Node] = get_tree().get_nodes_in_group("dream_spin")
	for entry: Node in spin_group:
		var node3d: Node3D = entry as Node3D
		if node3d == null:
			continue
		_spin_nodes.append(node3d)

func _collect_houses() -> void:
	_dream_houses.clear()
	var house_group: Array[Node] = get_tree().get_nodes_in_group("dream_house")
	for entry: Node in house_group:
		var node3d: Node3D = entry as Node3D
		if node3d == null:
			continue
		_dream_houses.append(node3d)

func _apply_house_palette() -> void:
	for house: Node3D in _dream_houses:
		if house == null or not is_instance_valid(house):
			continue
		_apply_material_color(house.get_node_or_null("Shell/Walls"), Color(0.9, 0.84, 0.76, 1.0))
		_apply_material_color(house.get_node_or_null("Partitions/CenterWall"), Color(0.9, 0.84, 0.76, 1.0))
		_apply_material_color(house.get_node_or_null("Partitions/BedroomDivider"), Color(0.9, 0.84, 0.76, 1.0))
		_apply_material_color(house.get_node_or_null("Partitions/KitchenWall"), Color(0.9, 0.84, 0.76, 1.0))
		_apply_material_color(house.get_node_or_null("Roof"), Color(0.24, 0.2, 0.26, 1.0))
		_apply_mesh_albedo(house.get_node_or_null("FrontDoor/Mesh"), Color(0.38, 0.22, 0.1, 1.0))
		_apply_mesh_albedo(house.get_node_or_null("MasterDoor/Mesh"), Color(0.38, 0.22, 0.1, 1.0))
		_apply_mesh_albedo(house.get_node_or_null("GuestDoor/Mesh"), Color(0.38, 0.22, 0.1, 1.0))

func _apply_material_color(node: Node, color: Color) -> void:
	if node == null:
		return
	if node is CSGShape3D:
		var shape: CSGShape3D = node as CSGShape3D
		var source_material: Material = shape.material
		var standard: StandardMaterial3D = source_material as StandardMaterial3D
		if standard == null:
			return
		var duplicate_material: StandardMaterial3D = standard.duplicate() as StandardMaterial3D
		duplicate_material.albedo_color = color
		shape.material = duplicate_material

func _apply_mesh_albedo(node: Node, color: Color) -> void:
	if node == null:
		return
	if node is MeshInstance3D:
		var mesh_instance: MeshInstance3D = node as MeshInstance3D
		var source_material: Material = mesh_instance.material_override
		if source_material == null and mesh_instance.mesh != null:
			source_material = mesh_instance.mesh.surface_get_material(0)
		var standard: StandardMaterial3D = source_material as StandardMaterial3D
		if standard == null:
			return
		var duplicate_material: StandardMaterial3D = standard.duplicate() as StandardMaterial3D
		duplicate_material.albedo_color = color
		mesh_instance.material_override = duplicate_material

func _animate_floaters() -> void:
	for node3d: Node3D in _float_nodes:
		if node3d == null or not is_instance_valid(node3d):
			continue
		var base_position: Vector3 = node3d.position
		var base_position_variant: Variant = _base_positions.get(node3d, node3d.position)
		if typeof(base_position_variant) == TYPE_VECTOR3:
			base_position = base_position_variant
		var phase: float = 0.0
		var phase_variant: Variant = _phase_map.get(node3d, 0.0)
		if typeof(phase_variant) == TYPE_FLOAT or typeof(phase_variant) == TYPE_INT:
			phase = float(phase_variant)
		var axis: Vector3 = Vector3.RIGHT
		var axis_variant: Variant = _drift_axis_map.get(node3d, Vector3.RIGHT)
		if typeof(axis_variant) == TYPE_VECTOR3:
			axis = axis_variant
		var vertical_wave: float = sin(_time * bob_speed + phase) * bob_height
		var drift_wave: float = sin(_time * (bob_speed * 0.64) + phase * 1.7) * drift_amount
		node3d.position = base_position + Vector3(0.0, vertical_wave, 0.0) + axis * drift_wave

func _animate_spinners(delta: float) -> void:
	for node3d: Node3D in _spin_nodes:
		if node3d == null or not is_instance_valid(node3d):
			continue
		node3d.rotate_y(delta * spin_speed)
		node3d.rotate_x(delta * spin_speed * 0.22)
