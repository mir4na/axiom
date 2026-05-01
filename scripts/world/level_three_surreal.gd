extends Node3D

const LEVEL_FOUR_SCENE_PATH := "res://scenes/levels/level_04.tscn"
const BROKEN_HOUSE_SCENE := preload("res://scenes/objects/broken_house.tscn")
const HOUSE_SCENE := preload("res://scenes/objects/house.tscn")
const DRAGON_PROP_SCENE := preload("res://scenes/objects/dragon_2.tscn")
const DRAGON_ALT_PROP_SCENE := preload("res://scenes/objects/dragon.tscn")
const PLATFORM_PROP_SCENE := preload("res://scenes/objects/platform.tscn")
const SURREAL_PLATFORM_SCENE := preload("res://scenes/objects/surreal_platform.tscn")
const ENEMY_SCENE := preload("res://scenes/objects/enemy.tscn")
const ELECTRIC_ORB_SCENE := preload("res://scenes/objects/electric_orb.tscn")
const SHOVEL_SCENE := preload("res://scenes/objects/shovel.tscn")
const ROSE_SCENE := preload("res://scenes/characters/rose.tscn")
const HAZMAT_SCENE := preload("res://scenes/characters/hazmat.tscn")

enum Stage {
	TAKE_BOOTS,
	TRIGGER_REWIND,
	REACH_ARENA,
	FIGHT_DRAGON,
	TAKE_KEYCARD,
	TAME_DRAGON,
	USE_GATE,
	DONE
}

@export var bob_speed: float = 0.8
@export var bob_height: float = 0.55
@export var spin_speed: float = 0.24
@export_range(1, 4, 1) var floating_update_slices: int = 2
@export var extra_float_mesh_count: int = 8
@export var extra_float_prop_count: int = 16
@export var surreal_field_center: Vector3 = Vector3(36.0, 34.0, -10.0)
@export var surreal_field_extent: Vector3 = Vector3(58.0, 26.0, 44.0)

@onready var _world: Node = $World
@onready var _player: CharacterBody3D = $World/Player
@onready var _boots = $World/Platforms/BootsPlatform/BootsHouse/JumpingBoots
@onready var _boots_platform: Node3D = $World/Platforms/BootsPlatform
@onready var _boots_house: Node3D = $World/Platforms/BootsPlatform/BootsHouse
@onready var _boots_trace_marker: Marker3D = get_node_or_null("World/Platforms/BootsPlatform/BootsTraceMarker") as Marker3D
@onready var _dragon_guard = $World/DragonGuard
@onready var _dragon_keycard = $World/DragonKeycard
@onready var _level_gate = $World/Level4Gate
@onready var _bridge_root: Node3D = $World/Platforms/BridgePlatforms
@onready var _surreal_shapes_root: Node3D = $World/SurrealShapes
@onready var _fall_death_zone: Area3D = get_node_or_null("World/LevelFallDeathZone") as Area3D
@onready var _anomaly_trigger: Area3D = $World/AnomalyEncounter/Trigger
@onready var _anomaly_enemies_root: Node3D = $World/AnomalyEncounter/Enemies
@onready var _dragon_arena_trigger: Area3D = get_node_or_null("World/DragonEncounter/ArenaTrigger") as Area3D
@onready var _dragon_fight_camera: Camera3D = get_node_or_null("World/DragonEncounter/FightCamera") as Camera3D
@onready var _dragon_spawn_marker: Marker3D = get_node_or_null("World/DragonEncounter/DragonSpawnMarker") as Marker3D
@onready var _dragon_ride_release_area: Area3D = get_node_or_null("World/DragonEncounter/RideReleaseArea") as Area3D
@onready var _dragon_escape_target: Marker3D = get_node_or_null("World/DragonEncounter/DragonEscapeTarget") as Marker3D
@onready var _dragon_mount_socket: Marker3D = get_node_or_null("World/DragonGuard/ModelRoot/RideSocket") as Marker3D

@export var dragon_ride_speed: float = 23.0
@export var dragon_ride_vertical_speed: float = 14.0
@export var dragon_ride_turn_speed: float = 1.9

var _stage: Stage = Stage.TAKE_BOOTS
var _base_jump_power: float = 4.5
var _ride_running: bool = false
var _collapse_started: bool = false
var _time: float = 0.0
var _floating_nodes: Array[Node3D] = []
var _base_positions: Dictionary = {}
var _phase_map: Dictionary = {}
var _rng: RandomNumberGenerator = RandomNumberGenerator.new()
var _floating_update_bucket: int = 0
var _anomaly_enemies: Array[Node3D] = []
var _anomaly_encounter_started: bool = false
var _dragon_intro_played: bool = false
var _dragon_fight_running: bool = false
var _dragon_arena_position: Vector3 = Vector3.ZERO
var _dragon_riding: bool = false
var _dragon_escape_running: bool = false

func _ready() -> void:
	GameState.current_level_index = 2
	GameState.set_rewind_disabled(false)
	GameState.recording_enabled = true
	GameState.axiom_unlocked = true
	GameState.axiom_equipped = true
	GameState.axiom_equipped_changed.emit()
	GameState.ui_updated.emit()
	_rng.randomize()
	if _player != null:
		_base_jump_power = _player.jump_power
	_spawn_surreal_field()
	_collect_floaters()
	_set_bridge_enabled(false)
	_set_bridge_preview_visible(true)
	_set_dragon_keycard_pickup_enabled(false)
	if _dragon_guard != null and _dragon_guard.has_method("set_mount_enabled"):
		_dragon_guard.call("set_mount_enabled", false)
	if _dragon_guard != null:
		_dragon_arena_position = _dragon_guard.global_position
		if _dragon_guard.has_method("reset_dragon_state"):
			_dragon_guard.call("reset_dragon_state")
		if _dragon_guard.has_method("set_combat_enabled"):
			_dragon_guard.call("set_combat_enabled", false)
		else:
			_dragon_guard.visible = false
	if _level_gate != null and _level_gate.has_method("set_interactable_enabled"):
		_level_gate.call("set_interactable_enabled", false)
	if _boots != null and _boots.has_signal("collected"):
		_boots.collected.connect(_on_boots_collected)
	if _dragon_guard != null:
		if _dragon_guard.has_signal("defeated"):
			_dragon_guard.defeated.connect(_on_dragon_defeated)
		if _dragon_guard.has_signal("mount_requested"):
			_dragon_guard.mount_requested.connect(_on_dragon_mount_requested)
	if _level_gate != null and _level_gate.has_signal("gate_opened"):
		_level_gate.gate_opened.connect(_on_gate_opened)
	if not GameState.is_connected("rewind_mode_changed", Callable(self, "_on_rewind_mode_changed")):
		GameState.rewind_mode_changed.connect(_on_rewind_mode_changed)
	if not GameState.is_connected("inventory_changed", Callable(self, "_on_inventory_changed")):
		GameState.inventory_changed.connect(_on_inventory_changed)
	_setup_anomaly_encounter()
	_setup_dragon_arena_encounter()
	_setup_dragon_ride_release_trigger()
	_setup_fall_death_zone()
	_show_objective("Take the jumping boots")
	_show_subtitle("Find the boots and prepare for a long jump.", 2.0)

func _process(delta: float) -> void:
	if _dragon_riding:
		_update_dragon_ride(delta)
	if _stage == Stage.TAKE_BOOTS:
		_update_boots_objective_trace()
	else:
		_clear_hint_marker()
	if GameState.is_time_blocked():
		return
	_time += delta
	var slices: int = maxi(1, floating_update_slices)
	for i in range(_floating_update_bucket, _floating_nodes.size(), slices):
		var node3d: Node3D = _floating_nodes[i]
		if node3d == null or not is_instance_valid(node3d):
			continue
		var base_position: Vector3 = _base_positions.get(node3d, node3d.position)
		var phase: float = float(_phase_map.get(node3d, 0.0))
		node3d.position = base_position + Vector3(0.0, sin(_time * bob_speed + phase) * bob_height, 0.0)
		node3d.rotate_y(delta * spin_speed)
	_floating_update_bucket = (_floating_update_bucket + 1) % slices

func _collect_floaters() -> void:
	_floating_nodes.clear()
	_base_positions.clear()
	_phase_map.clear()
	if _bridge_root != null:
		for child in _bridge_root.get_children():
			_register_floater(child as Node3D)
	var group_nodes: Array[Node] = get_tree().get_nodes_in_group("surreal_float")
	for entry in group_nodes:
		_register_floater(entry as Node3D)

func _register_floater(node3d: Node3D) -> void:
	if node3d == null:
		return
	if _floating_nodes.has(node3d):
		return
	_floating_nodes.append(node3d)
	_base_positions[node3d] = node3d.position
	_phase_map[node3d] = randf_range(0.0, TAU)

func _spawn_surreal_field() -> void:
	if _surreal_shapes_root == null:
		return
	for i in range(extra_float_mesh_count):
		var mesh_node := MeshInstance3D.new()
		mesh_node.mesh = _make_random_mesh()
		mesh_node.material_override = _make_random_mesh_material()
		mesh_node.global_position = _random_surreal_position()
		mesh_node.rotation = Vector3(_rng.randf_range(-PI, PI), _rng.randf_range(-PI, PI), _rng.randf_range(-PI, PI))
		var uniform_scale: float = _rng.randf_range(0.7, 2.8)
		mesh_node.scale = Vector3.ONE * uniform_scale
		mesh_node.add_to_group("surreal_float")
		_surreal_shapes_root.add_child(mesh_node)
	for i in range(extra_float_prop_count):
		var prop: Node3D = _instantiate_random_prop()
		if prop == null:
			continue
		prop.global_position = _random_surreal_position()
		prop.rotation = Vector3(_rng.randf_range(-PI, PI), _rng.randf_range(-PI, PI), _rng.randf_range(-PI, PI))
		var prop_scale: float = _rng.randf_range(0.22, 1.08)
		prop.scale = Vector3.ONE * prop_scale
		_disable_collisions_recursive(prop)
		_deactivate_runtime_nodes_recursive(prop)
		prop.add_to_group("surreal_float")
		_surreal_shapes_root.add_child(prop)

func _make_random_mesh() -> Mesh:
	var pick: int = _rng.randi_range(0, 4)
	if pick == 0:
		var sphere := SphereMesh.new()
		sphere.radius = _rng.randf_range(0.8, 3.6)
		sphere.height = sphere.radius * 2.0
		return sphere
	if pick == 1:
		var torus := TorusMesh.new()
		torus.inner_radius = _rng.randf_range(0.35, 1.5)
		torus.outer_radius = torus.inner_radius + _rng.randf_range(0.45, 2.2)
		torus.rings = 28
		torus.ring_segments = 22
		return torus
	if pick == 2:
		var prism := PrismMesh.new()
		prism.size = Vector3(_rng.randf_range(1.0, 4.5), _rng.randf_range(1.4, 6.4), _rng.randf_range(1.0, 4.5))
		return prism
	if pick == 3:
		var box := BoxMesh.new()
		box.size = Vector3(_rng.randf_range(0.9, 5.0), _rng.randf_range(0.9, 5.0), _rng.randf_range(0.9, 5.0))
		return box
	var capsule := CapsuleMesh.new()
	capsule.radius = _rng.randf_range(0.45, 1.9)
	capsule.height = _rng.randf_range(1.4, 5.8)
	return capsule

func _make_random_mesh_material() -> StandardMaterial3D:
	var palette: Array[Color] = [
		Color(0.82, 0.22, 0.18, 1.0),
		Color(0.12, 0.24, 0.72, 1.0),
		Color(0.2, 0.68, 0.32, 1.0),
		Color(0.92, 0.82, 0.18, 1.0),
		Color(0.95, 0.95, 0.95, 1.0),
		Color(0.76, 0.4, 0.16, 1.0)
	]
	var material := StandardMaterial3D.new()
	material.albedo_color = palette[_rng.randi_range(0, palette.size() - 1)]
	material.roughness = _rng.randf_range(0.3, 0.82)
	material.metallic = _rng.randf_range(0.02, 0.22)
	return material

func _random_surreal_position() -> Vector3:
	return surreal_field_center + Vector3(
		_rng.randf_range(-surreal_field_extent.x, surreal_field_extent.x),
		_rng.randf_range(-surreal_field_extent.y, surreal_field_extent.y),
		_rng.randf_range(-surreal_field_extent.z, surreal_field_extent.z)
	)

func _instantiate_random_prop() -> Node3D:
	var pick: int = _rng.randi_range(0, 10)
	if pick == 0:
		return _make_car_prop()
	if pick == 1 and BROKEN_HOUSE_SCENE != null:
		return BROKEN_HOUSE_SCENE.instantiate() as Node3D
	if pick == 2 and HOUSE_SCENE != null:
		return HOUSE_SCENE.instantiate() as Node3D
	if pick == 3 and DRAGON_PROP_SCENE != null:
		return DRAGON_PROP_SCENE.instantiate() as Node3D
	if pick == 4 and DRAGON_ALT_PROP_SCENE != null:
		return DRAGON_ALT_PROP_SCENE.instantiate() as Node3D
	if pick == 5 and ENEMY_SCENE != null:
		return ENEMY_SCENE.instantiate() as Node3D
	if pick == 6 and ELECTRIC_ORB_SCENE != null:
		return ELECTRIC_ORB_SCENE.instantiate() as Node3D
	if pick == 7 and ROSE_SCENE != null:
		return ROSE_SCENE.instantiate() as Node3D
	if pick == 8 and HAZMAT_SCENE != null:
		return HAZMAT_SCENE.instantiate() as Node3D
	if pick == 9 and SHOVEL_SCENE != null:
		return SHOVEL_SCENE.instantiate() as Node3D
	if pick == 10 and SURREAL_PLATFORM_SCENE != null:
		return SURREAL_PLATFORM_SCENE.instantiate() as Node3D
	if PLATFORM_PROP_SCENE != null:
		return PLATFORM_PROP_SCENE.instantiate() as Node3D
	return null

func _make_car_prop() -> Node3D:
	var car_root := Node3D.new()
	car_root.name = "DreamCar"
	var body_colors: Array[Color] = [
		Color(0.78, 0.14, 0.12, 1.0),
		Color(0.92, 0.92, 0.9, 1.0),
		Color(0.1, 0.16, 0.38, 1.0),
		Color(0.84, 0.56, 0.12, 1.0)
	]
	var body_mat := StandardMaterial3D.new()
	body_mat.albedo_color = body_colors[_rng.randi_range(0, body_colors.size() - 1)]
	body_mat.roughness = 0.48
	body_mat.metallic = 0.1
	var cabin_mat := StandardMaterial3D.new()
	cabin_mat.albedo_color = Color(0.75, 0.86, 0.96, 1.0)
	cabin_mat.roughness = 0.22
	cabin_mat.metallic = 0.02
	var wheel_mat := StandardMaterial3D.new()
	wheel_mat.albedo_color = Color(0.1, 0.1, 0.1, 1.0)
	wheel_mat.roughness = 0.96
	var body := CSGBox3D.new()
	body.size = Vector3(3.6, 0.9, 1.9)
	body.material = body_mat
	car_root.add_child(body)
	var cabin := CSGBox3D.new()
	cabin.position = Vector3(0.2, 0.72, 0.0)
	cabin.size = Vector3(1.85, 0.75, 1.65)
	cabin.material = cabin_mat
	car_root.add_child(cabin)
	var wheel_offsets: Array[Vector3] = [
		Vector3(-1.2, -0.62, 0.84),
		Vector3(1.2, -0.62, 0.84),
		Vector3(-1.2, -0.62, -0.84),
		Vector3(1.2, -0.62, -0.84)
	]
	for offset in wheel_offsets:
		var wheel := CSGCylinder3D.new()
		wheel.position = offset
		wheel.rotation_degrees = Vector3(90.0, 0.0, 0.0)
		wheel.radius = 0.4
		wheel.height = 0.33
		wheel.material = wheel_mat
		car_root.add_child(wheel)
	return car_root

func _disable_collisions_recursive(node: Node) -> void:
	if node is CollisionShape3D:
		(node as CollisionShape3D).disabled = true
	elif node is Area3D:
		var area := node as Area3D
		area.monitoring = false
		area.monitorable = false
	elif node is PhysicsBody3D:
		var body := node as PhysicsBody3D
		body.collision_layer = 0
		body.collision_mask = 0
	for child in node.get_children():
		_disable_collisions_recursive(child)

func _deactivate_runtime_nodes_recursive(node: Node) -> void:
	if node == null:
		return
	if node is RigidBody3D:
		(node as RigidBody3D).freeze = true
	if node is CharacterBody3D:
		(node as CharacterBody3D).velocity = Vector3.ZERO
	if node is AnimationPlayer:
		(node as AnimationPlayer).active = false
	if node is GPUParticles3D:
		(node as GPUParticles3D).emitting = false
	node.process_mode = Node.PROCESS_MODE_DISABLED
	for child in node.get_children():
		_deactivate_runtime_nodes_recursive(child)

func _setup_anomaly_encounter() -> void:
	_anomaly_enemies.clear()
	if _anomaly_enemies_root != null:
		for child in _anomaly_enemies_root.get_children():
			var enemy_node: Node3D = child as Node3D
			if enemy_node == null:
				continue
			_anomaly_enemies.append(enemy_node)
			if enemy_node.has_method("reset_enemy_state"):
				enemy_node.call("reset_enemy_state")
			if enemy_node.has_method("set_encounter_enabled"):
				enemy_node.call("set_encounter_enabled", false)
			else:
				enemy_node.visible = false
	if _anomaly_trigger != null:
		var entered: Callable = Callable(self, "_on_anomaly_trigger_body_entered")
		if not _anomaly_trigger.is_connected("body_entered", entered):
			_anomaly_trigger.body_entered.connect(entered)
		_anomaly_trigger.monitoring = true
		_anomaly_trigger.monitorable = true

func _on_anomaly_trigger_body_entered(body: Node) -> void:
	if _anomaly_encounter_started:
		return
	if body == null or not body.is_in_group("player"):
		return
	_anomaly_encounter_started = true
	if _anomaly_trigger != null:
		_anomaly_trigger.monitoring = false
	_activate_anomaly_enemies()

func _activate_anomaly_enemies() -> void:
	for enemy_node in _anomaly_enemies:
		if enemy_node == null or not is_instance_valid(enemy_node):
			continue
		if enemy_node.has_method("reset_enemy_state"):
			enemy_node.call("reset_enemy_state")
		if enemy_node.has_method("set_encounter_enabled"):
			enemy_node.call("set_encounter_enabled", true)
		else:
			enemy_node.visible = true

func _setup_dragon_arena_encounter() -> void:
	if _dragon_arena_trigger == null:
		return
	var entered: Callable = Callable(self, "_on_dragon_arena_body_entered")
	if not _dragon_arena_trigger.is_connected("body_entered", entered):
		_dragon_arena_trigger.body_entered.connect(entered)
	_dragon_arena_trigger.monitoring = true
	_dragon_arena_trigger.monitorable = true

func _setup_dragon_ride_release_trigger() -> void:
	if _dragon_ride_release_area == null:
		return
	var entered: Callable = Callable(self, "_on_dragon_ride_release_area_body_entered")
	if not _dragon_ride_release_area.is_connected("body_entered", entered):
		_dragon_ride_release_area.body_entered.connect(entered)
	_dragon_ride_release_area.monitoring = true
	_dragon_ride_release_area.monitorable = true

func _setup_fall_death_zone() -> void:
	if _fall_death_zone == null:
		return
	var entered: Callable = Callable(self, "_on_fall_death_zone_body_entered")
	if not _fall_death_zone.is_connected("body_entered", entered):
		_fall_death_zone.body_entered.connect(entered)
	_fall_death_zone.monitoring = true
	_fall_death_zone.monitorable = true

func _on_fall_death_zone_body_entered(body: Node) -> void:
	if body == null or _player == null:
		return
	if body != _player and not body.is_in_group("player"):
		return
	if _player.has_method("take_damage"):
		_player.call("take_damage", 9999.0)

func _update_boots_objective_trace() -> void:
	if _world == null or _boots == null or not is_instance_valid(_boots):
		return
	if _boots.has_method("set_highlight_enabled"):
		_boots.call("set_highlight_enabled", true)
	if _boots.has_method("set_highlight_strength"):
		var pulse: float = 0.55 + (sin(_time * 1.35) * 0.5 + 0.5) * 0.7
		_boots.call("set_highlight_strength", pulse)
	if _world.has_method("_update_hint_marker"):
		var target_pos: Vector3 = _boots.global_position
		var marker_pos: Vector3 = target_pos + Vector3(0.0, 1.1, 0.0)
		if _boots_trace_marker != null:
			marker_pos = _boots_trace_marker.global_position
		_world.call("_update_hint_marker", marker_pos, "BOOTS", target_pos)

func _clear_hint_marker() -> void:
	if _world == null:
		return
	var marker_variant: Variant = _world.get("_hint_marker")
	if marker_variant is CanvasItem:
		(marker_variant as CanvasItem).visible = false
	var label_variant: Variant = _world.get("_hint_label")
	if label_variant is Label:
		(label_variant as Label).visible = false

func _set_dragon_keycard_pickup_enabled(enabled: bool) -> void:
	if _dragon_keycard == null:
		return
	_dragon_keycard.visible = true
	var shape: CollisionShape3D = _dragon_keycard.get_node_or_null("CollisionShape3D") as CollisionShape3D
	if shape != null:
		shape.disabled = not enabled
	_dragon_keycard.set("prompt_text", "Press E to pick up Keycard" if enabled else "")
	if _dragon_keycard.has_method("set_highlight_enabled"):
		_dragon_keycard.call("set_highlight_enabled", enabled)
	if enabled and _dragon_keycard.has_method("set_highlight_strength"):
		_dragon_keycard.call("set_highlight_strength", 1.0)

func _on_dragon_arena_body_entered(body: Node) -> void:
	if _dragon_intro_played or _dragon_fight_running:
		return
	if _stage != Stage.REACH_ARENA:
		return
	if body == null or not body.is_in_group("player"):
		return
	_dragon_intro_played = true
	_dragon_fight_running = true
	call_deferred("_play_dragon_arena_cinematic")

func _play_dragon_arena_cinematic() -> void:
	if _player == null or _dragon_guard == null:
		_dragon_fight_running = false
		return
	if GameState.rewind_mode_active:
		GameState.cancel_rewind_mode()
	_player.set_cinematic_lock(true)
	_player.set_mobility_lock(true)
	_player.visible = false
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	var player_camera: Camera3D = _player.get_node_or_null("root/Skeleton3D/BoneAttachment3D/Head/Camera3D") as Camera3D
	if _dragon_fight_camera != null:
		_dragon_fight_camera.make_current()
	if _dragon_guard.has_method("reset_dragon_state"):
		_dragon_guard.call("reset_dragon_state")
	if _dragon_guard.has_method("set_combat_enabled"):
		_dragon_guard.call("set_combat_enabled", false)
	else:
		_dragon_guard.visible = true
	_dragon_guard.visible = true
	if _dragon_spawn_marker != null:
		_dragon_guard.global_position = _dragon_spawn_marker.global_position
	var end_position: Vector3 = _dragon_arena_position if _dragon_arena_position != Vector3.ZERO else _dragon_guard.global_position
	var emerge: Tween = create_tween().set_parallel(true)
	emerge.tween_property(_dragon_guard, "global_position", end_position, 1.3).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	emerge.tween_property(_dragon_guard, "rotation_degrees", _dragon_guard.rotation_degrees + Vector3(0.0, 200.0, 0.0), 1.25).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	await emerge.finished
	if _dragon_guard.has_method("set_combat_enabled"):
		_dragon_guard.call("set_combat_enabled", true)
	_stage = Stage.FIGHT_DRAGON
	_show_objective("Defeat the dragon")
	_show_subtitle("Use Bow for heavy damage. Gun damage is low.", 2.3)
	if player_camera != null:
		player_camera.make_current()
	_player.visible = true
	_player.set_cinematic_lock(false)
	_player.set_mobility_lock(false)
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	_dragon_fight_running = false

func _on_dragon_ride_release_area_body_entered(body: Node) -> void:
	if not _dragon_riding:
		return
	if body == null or not body.is_in_group("player"):
		return
	_release_dragon_ride()

func _update_dragon_ride(delta: float) -> void:
	if _dragon_guard == null or _player == null:
		return
	var turn_input: float = 0.0
	if Input.is_key_pressed(KEY_D):
		turn_input += 1.0
	if Input.is_key_pressed(KEY_A):
		turn_input -= 1.0
	if absf(turn_input) > 0.001:
		_dragon_guard.rotate_y(turn_input * dragon_ride_turn_speed * delta)
	var move_input: float = 0.0
	if Input.is_key_pressed(KEY_W):
		move_input += 1.0
	if Input.is_key_pressed(KEY_S):
		move_input -= 1.0
	var vertical_input: float = 0.0
	if Input.is_key_pressed(KEY_SPACE):
		vertical_input += 1.0
	if Input.is_key_pressed(KEY_CTRL):
		vertical_input -= 1.0
	var forward: Vector3 = -_dragon_guard.global_transform.basis.z.normalized()
	var velocity: Vector3 = forward * (move_input * dragon_ride_speed) + Vector3.UP * (vertical_input * dragon_ride_vertical_speed)
	_dragon_guard.global_position += velocity * delta
	_sync_player_to_dragon_mount()

func _sync_player_to_dragon_mount() -> void:
	if _player == null:
		return
	if _dragon_mount_socket != null:
		_player.global_position = _dragon_mount_socket.global_position
	else:
		_player.global_position = _dragon_guard.global_position + Vector3(0.0, 2.2, -0.3)
	_player.rotation.y = _dragon_guard.global_rotation.y

func _on_boots_collected(multiplier: float) -> void:
	if _player != null:
		_player.jump_power = _base_jump_power * multiplier
	if _stage != Stage.TAKE_BOOTS:
		return
	_stage = Stage.TRIGGER_REWIND
	_clear_hint_marker()
	_show_objective("Activate rewind to stabilize the route")
	_show_subtitle("The platform is collapsing. Rewind now.", 2.1)
	_set_bridge_enabled(false)
	_set_bridge_preview_visible(false)
	if not _collapse_started:
		_collapse_started = true
		call_deferred("_collapse_boots_platform")

func _collapse_boots_platform() -> void:
	if _boots_platform == null:
		return
	_set_platform_walkable(_boots_platform, true)
	var start_position: Vector3 = _boots_platform.position
	var end_position: Vector3 = start_position + Vector3(0.0, -18.0, 0.0)
	var tween: Tween = create_tween().set_parallel(true)
	tween.tween_property(_boots_platform, "position", end_position, 1.8).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	tween.tween_property(_boots_platform, "rotation_degrees", _boots_platform.rotation_degrees + Vector3(0.0, 14.0, 6.0), 1.8).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	await get_tree().create_timer(0.35).timeout
	_set_platform_walkable(_boots_platform, false)
	if _boots_house != null:
		_set_collisions_recursive_enabled(_boots_house, false)
		_boots_house.visible = false
	await tween.finished

func _on_rewind_mode_changed(active: bool) -> void:
	if not active:
		return
	if _stage != Stage.TRIGGER_REWIND:
		return
	_stage = Stage.REACH_ARENA
	_set_bridge_enabled(true)
	_show_objective("Reach the arena at the center platform")
	_show_subtitle("The route is back. Reach the keycard arena.", 1.9)

func _on_dragon_defeated(_dragon: Node3D) -> void:
	if _stage != Stage.FIGHT_DRAGON:
		return
	_grant_dragon_keycard()
	_stage = Stage.TAME_DRAGON
	if _dragon_guard != null and _dragon_guard.has_method("set_mount_enabled"):
		_dragon_guard.call("set_mount_enabled", true)
	_show_objective("Ride the dragon")
	_show_subtitle("Interact with the dragon to start flying.", 2.0)

func _on_inventory_changed() -> void:
	if _stage == Stage.USE_GATE and _level_gate != null and _level_gate.has_method("set_highlight_strength"):
		_level_gate.call("set_highlight_strength", 0.95)

func _on_dragon_mount_requested(_dragon: Node3D) -> void:
	if _stage != Stage.TAME_DRAGON:
		return
	if _ride_running or _dragon_riding:
		return
	_start_dragon_ride()

func _start_dragon_ride() -> void:
	if _player == null or _dragon_guard == null:
		return
	if GameState.rewind_mode_active:
		GameState.cancel_rewind_mode()
	_ride_running = true
	_dragon_riding = true
	_player.set_mobility_lock(true)
	if _player.has_method("set_item_usage_locked"):
		_player.call("set_item_usage_locked", true)
	_sync_player_to_dragon_mount()
	_show_objective("Fly to the distant ruins platform")
	_show_subtitle("Use W A S D to steer, Space/Ctrl to move up and down.", 2.4)
	_ride_running = false

func _release_dragon_ride() -> void:
	if not _dragon_riding:
		return
	_dragon_riding = false
	if _player != null:
		_player.set_mobility_lock(false)
		if _player.has_method("set_item_usage_locked"):
			_player.call("set_item_usage_locked", false)
	if _dragon_ride_release_area != null:
		_dragon_ride_release_area.monitoring = false
	_stage = Stage.USE_GATE
	if _level_gate != null and _level_gate.has_method("set_interactable_enabled"):
		_level_gate.call("set_interactable_enabled", true)
	_show_objective("Use the portal box")
	_show_subtitle("The dragon left. Enter the box to reach the next world.", 2.1)
	if not _dragon_escape_running:
		_dragon_escape_running = true
		call_deferred("_fly_dragon_away")

func _fly_dragon_away() -> void:
	if _dragon_guard == null:
		_dragon_escape_running = false
		return
	if _dragon_escape_target == null:
		_dragon_guard.visible = false
		_dragon_escape_running = false
		return
	var tween: Tween = create_tween().set_parallel(true)
	tween.tween_property(_dragon_guard, "global_position", _dragon_escape_target.global_position, 2.9).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(_dragon_guard, "rotation_degrees", _dragon_guard.rotation_degrees + Vector3(-8.0, 220.0, 0.0), 2.9).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	await tween.finished
	if _dragon_guard.has_method("set_combat_enabled"):
		_dragon_guard.call("set_combat_enabled", false)
	else:
		_dragon_guard.visible = false
	_dragon_escape_running = false

func _grant_dragon_keycard() -> void:
	if _dragon_keycard != null:
		_dragon_keycard.visible = false
	if GameState.has_item("key_3"):
		GameState.select_item("key_3")
		return
	if GameState.add_item_first_free_slot("key_3"):
		GameState.select_item("key_3")
		return
	if GameState.selected_slot >= 0 and GameState.selected_slot < GameState.slots.size():
		GameState.slots[GameState.selected_slot] = "key_3"
		GameState.inventory_changed.emit()
		GameState.select_item("key_3")

func _on_gate_opened() -> void:
	if _stage != Stage.USE_GATE:
		return
	if _player != null and _player.has_method("set_item_usage_locked"):
		_player.call("set_item_usage_locked", false)
	if _player != null:
		_player.set_mobility_lock(false)
	_stage = Stage.DONE
	_show_objective("")
	_transition_to_level_four()

func _transition_to_level_four() -> void:
	var screen_fx: CanvasLayer = get_node_or_null("/root/ScreenFX") as CanvasLayer
	GameState.current_level_index = 3
	if screen_fx != null and screen_fx.has_method("fade_to_scene"):
		await screen_fx.fade_to_scene(LEVEL_FOUR_SCENE_PATH, true)
	elif screen_fx != null and screen_fx.has_method("reboot_to_scene"):
		await screen_fx.reboot_to_scene(LEVEL_FOUR_SCENE_PATH, true)
	else:
		get_tree().change_scene_to_file(LEVEL_FOUR_SCENE_PATH)

func _set_bridge_enabled(enabled: bool) -> void:
	if _bridge_root == null:
		return
	for child in _bridge_root.get_children():
		var platform: Node3D = child as Node3D
		if platform == null:
			continue
		_set_platform_walkable(platform, enabled)

func _set_bridge_preview_visible(visible: bool) -> void:
	if _bridge_root == null:
		return
	for child in _bridge_root.get_children():
		var platform: Node3D = child as Node3D
		if platform == null:
			continue
		_set_platform_preview(platform, visible)

func _set_platform_walkable(platform: Node3D, enabled: bool) -> void:
	if platform == null:
		return
	platform.visible = enabled
	for node in platform.get_children():
		if node is CollisionShape3D:
			(node as CollisionShape3D).disabled = not enabled
		elif node is MeshInstance3D:
			(node as MeshInstance3D).visible = enabled
		elif node is Area3D:
			(node as Area3D).monitoring = enabled
			(node as Area3D).monitorable = enabled
			for area_child in node.get_children():
				if area_child is CollisionShape3D:
					(area_child as CollisionShape3D).disabled = not enabled

func _set_collisions_recursive_enabled(node: Node, enabled: bool) -> void:
	if node == null:
		return
	if node is CollisionShape3D:
		(node as CollisionShape3D).disabled = not enabled
	elif node is Area3D:
		(node as Area3D).monitoring = enabled
		(node as Area3D).monitorable = enabled
	elif node is PhysicsBody3D:
		var body: PhysicsBody3D = node as PhysicsBody3D
		if not enabled:
			body.collision_layer = 0
			body.collision_mask = 0
	for child in node.get_children():
		_set_collisions_recursive_enabled(child, enabled)

func _set_platform_preview(platform: Node3D, enabled: bool) -> void:
	if platform == null:
		return
	platform.visible = true
	for node in platform.get_children():
		if node is CollisionShape3D:
			(node as CollisionShape3D).disabled = true
		elif node is MeshInstance3D:
			(node as MeshInstance3D).visible = enabled
		elif node is Area3D:
			(node as Area3D).monitoring = false
			(node as Area3D).monitorable = false
			for area_child in node.get_children():
				if area_child is CollisionShape3D:
					(area_child as CollisionShape3D).disabled = true

func _show_objective(text: String) -> void:
	if _world != null and _world.has_method("_show_objective"):
		if text.is_empty():
			_world.call("_hide_objective", false)
		else:
			_world.call("_show_objective", text)

func _show_subtitle(text: String, duration: float) -> void:
	if _world != null and _world.has_method("_show_subtitle"):
		_world.call_deferred("_show_subtitle", text, duration, "")
