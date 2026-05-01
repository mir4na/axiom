extends Node3D

@export var object_count: int = 140
@export var spawn_extent: Vector3 = Vector3(56.0, 26.0, 56.0)
@export var min_scale: float = 0.6
@export var max_scale: float = 4.0
@export var bob_speed: float = 0.55
@export var bob_height: float = 0.65
@export var spin_speed: float = 0.35
@export var camera_orbit_speed: float = 0.09
@export var camera_orbit_radius: float = 42.0
@export var camera_orbit_height: float = 22.0

@onready var _camera: Camera3D = $MenuCamera
@onready var _objects_root: Node3D = $Objects

var _rng: RandomNumberGenerator = RandomNumberGenerator.new()
var _time: float = 0.0
var _floaters: Array[Node3D] = []
var _base_positions: Dictionary = {}
var _phase_map: Dictionary = {}
var _palette: Array[Color] = [
	Color(0.92, 0.28, 0.24, 1.0),
	Color(0.24, 0.42, 0.92, 1.0),
	Color(0.26, 0.78, 0.46, 1.0),
	Color(0.96, 0.74, 0.26, 1.0),
	Color(0.92, 0.44, 0.78, 1.0),
	Color(0.32, 0.88, 0.94, 1.0),
	Color(0.88, 0.88, 0.9, 1.0)
]

func _ready() -> void:
	_rng.randomize()
	_spawn_abstract_objects()

func _process(delta: float) -> void:
	_time += delta
	for floater in _floaters:
		if floater == null or not is_instance_valid(floater):
			continue
		var base_pos: Vector3 = _base_positions.get(floater, floater.position)
		var phase: float = float(_phase_map.get(floater, 0.0))
		floater.position = base_pos + Vector3(0.0, sin(_time * bob_speed + phase) * bob_height, 0.0)
		floater.rotate_y(delta * spin_speed)
		# Mild secondary motion so it feels dreamlike, not static.
		floater.rotate_x(delta * spin_speed * 0.18)
	if _camera != null and is_instance_valid(_camera):
		var angle: float = _time * camera_orbit_speed
		var orbit_pos: Vector3 = Vector3(cos(angle) * camera_orbit_radius, camera_orbit_height + sin(_time * 0.27) * 2.2, sin(angle) * camera_orbit_radius)
		_camera.global_position = orbit_pos
		_camera.look_at(Vector3.ZERO, Vector3.UP)

func _spawn_abstract_objects() -> void:
	if _objects_root == null:
		return
	for child in _objects_root.get_children():
		child.queue_free()
	_floaters.clear()
	_base_positions.clear()
	_phase_map.clear()
	for _i in range(maxi(0, object_count)):
		var mesh_instance: MeshInstance3D = MeshInstance3D.new()
		mesh_instance.mesh = _make_random_mesh()
		mesh_instance.material_override = _make_random_material()
		mesh_instance.position = Vector3(
			_rng.randf_range(-spawn_extent.x, spawn_extent.x),
			_rng.randf_range(-spawn_extent.y, spawn_extent.y),
			_rng.randf_range(-spawn_extent.z, spawn_extent.z)
		)
		mesh_instance.rotation = Vector3(
			_rng.randf_range(-PI, PI),
			_rng.randf_range(-PI, PI),
			_rng.randf_range(-PI, PI)
		)
		var scale_value: float = _rng.randf_range(min_scale, max_scale)
		mesh_instance.scale = Vector3.ONE * scale_value
		_objects_root.add_child(mesh_instance)
		_register_floater(mesh_instance)

func _register_floater(node3d: Node3D) -> void:
	if node3d == null:
		return
	_floaters.append(node3d)
	_base_positions[node3d] = node3d.position
	_phase_map[node3d] = _rng.randf_range(0.0, TAU)

func _make_random_mesh() -> Mesh:
	match _rng.randi_range(0, 6):
		0:
			var box := BoxMesh.new()
			box.size = Vector3(_rng.randf_range(0.8, 3.6), _rng.randf_range(0.8, 3.6), _rng.randf_range(0.8, 3.6))
			return box
		1:
			var sphere := SphereMesh.new()
			sphere.radius = _rng.randf_range(0.45, 1.9)
			sphere.height = sphere.radius * 2.0
			return sphere
		2:
			var capsule := CapsuleMesh.new()
			capsule.radius = _rng.randf_range(0.35, 1.15)
			capsule.height = _rng.randf_range(1.1, 3.2)
			return capsule
		3:
			var cyl := CylinderMesh.new()
			cyl.top_radius = _rng.randf_range(0.25, 1.25)
			cyl.bottom_radius = _rng.randf_range(0.25, 1.25)
			cyl.height = _rng.randf_range(0.8, 4.0)
			return cyl
		4:
			var prism := PrismMesh.new()
			prism.size = Vector3(_rng.randf_range(0.8, 3.0), _rng.randf_range(0.8, 3.0), _rng.randf_range(0.8, 3.0))
			return prism
		5:
			var torus := TorusMesh.new()
			torus.inner_radius = _rng.randf_range(0.22, 0.72)
			torus.outer_radius = _rng.randf_range(0.85, 1.9)
			return torus
		_:
			var plane := PlaneMesh.new()
			plane.size = Vector2(_rng.randf_range(0.9, 4.2), _rng.randf_range(0.9, 4.2))
			return plane

func _make_random_material() -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	var color: Color = _palette[_rng.randi_range(0, _palette.size() - 1)]
	mat.albedo_color = color
	mat.roughness = _rng.randf_range(0.18, 0.9)
	mat.metallic = _rng.randf_range(0.0, 0.38)
	mat.emission_enabled = true
	mat.emission = color.lerp(Color.WHITE, 0.24)
	mat.emission_energy_multiplier = _rng.randf_range(0.2, 0.9)
	return mat
