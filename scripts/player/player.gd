extends CharacterBody3D

@export var speed: float = 4.0
@export var sprint_speed: float = 7.0
@export var crouch_speed: float = 2.0
@export var acceleration: float = 4.0
@export var gravity: float = 9.8
@export var jump_power: float = 4.5
@export var mouse_sensitivity: float = 0.3
@export var normal_height: float = 1.68
@export var crouch_height: float = 0.9
@export var max_health: float = 100.0
@export var max_stamina: float = 100.0
@export var stamina_drain_rate: float = 26.0
@export var stamina_recover_rate: float = 18.0
@export var stamina_recover_delay: float = 0.7
@export var lightning_damage: float = 25.0
@export var lightning_radius: float = 2.4
@export var lightning_target_max_distance: float = 80.0
@export var lightning_strike_height: float = 26.0
@export var lightning_target_move_speed: float = 0.02
@export var lightning_target_control_radius: float = 22.0

const LIGHTNING_SKILL_ITEM_ID := "LightningSkill"
const KEY_ITEM_SCENE := preload("res://scenes/objects/key_item.tscn")
const SHOVEL_ITEM_SCENE := preload("res://scenes/objects/shovel.tscn")
const AXIOM_ITEM_SCENE := preload("res://scenes/objects/axiom_item.tscn")
const FLASHLIGHT_ITEM_SCENE := preload("res://scenes/objects/flashlight_item.tscn")
const GUN_ITEM_SCENE := preload("res://scenes/objects/gun_item.tscn")
const LIGHTNING_ITEM_SCENE := preload("res://scenes/objects/lightning_skill_item.tscn")

@onready var head: Node3D = $"root/Skeleton3D/BoneAttachment3D/Head"
@onready var camera: Camera3D = $"root/Skeleton3D/BoneAttachment3D/Head/Camera3D"
@onready var collision_shape: CollisionShape3D = $CollisionShape3D
@onready var interaction_ray: RayCast3D = $"root/Skeleton3D/BoneAttachment3D/Head/Camera3D/InteractionRay"
@onready var hud: CanvasLayer = $PlayerHUD
@onready var anim_player: AnimationPlayer = $AnimationPlayer
@onready var skeleton: Skeleton3D = $"root/Skeleton3D"

var _hitbox_pairs: Array = []
var _camera_collision_shape: SphereShape3D
var _camera_collision_query: PhysicsShapeQueryParameters3D
var _melee_hit_shape: SphereShape3D
var _flashlight_spot: SpotLight3D
var _self_melee_exclude: Array[RID] = []
var _gun_view_root: Node3D
var _gun_muzzle: Node3D
var _gun_shot_material: Material
var _gun_impact_material_enemy: Material
var _gun_impact_material_world: Material

var camera_x_rotation: float = 0.0
var _smoothed_head_y: float = 0.0
var _camera_origin_offset: Vector3 = Vector3.ZERO
var is_crouching: bool = false
var is_sprinting: bool = false
var last_interactable: Node3D = null
var _rewind_scroll_hold_time: float = 0.0
var cinematic_locked: bool = false
var health: float = 100.0
var stamina: float = 100.0
var _stamina_recover_cooldown: float = 0.0
var _health_regen_timer: float = 0.0
var _attack_locked: bool = false
var _attack_timer: float = 0.0
var _attack_name: String = ""
var _gun_clip_size: int = 12
var _gun_ammo: int = 12
var _gun_reload_duration: float = 1.25
var _gun_reload_timer: float = 0.0
var _gun_reloading: bool = false
var _gun_shot_cooldown: float = 0.18
var _gun_shot_timer: float = 0.0
var _gun_damage: float = 30.0
var _gun_range: float = 52.0
var _gun_recoil: float = 0.0
var mobility_locked: bool = false
var _lightning_targeting: bool = false
var _lightning_target_position: Vector3 = Vector3.ZERO
var _lightning_target_valid: bool = false
var _lightning_target_root: Node3D
var _lightning_target_ring: MeshInstance3D
var _lightning_target_core: MeshInstance3D
var _lightning_target_trace: MeshInstance3D

func _ready() -> void:
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	add_to_group("time_actor")
	add_to_group("player")
	health = max_health
	stamina = max_stamina
	_camera_origin_offset = to_local(camera.global_position)
	_smoothed_head_y = camera.global_position.y
	camera.set_as_top_level(true)
	_camera_collision_shape = SphereShape3D.new()
	_camera_collision_shape.radius = 0.15
	_camera_collision_query = PhysicsShapeQueryParameters3D.new()
	_camera_collision_query.shape = _camera_collision_shape
	_camera_collision_query.exclude = [self.get_rid()]
	_melee_hit_shape = SphereShape3D.new()
	_melee_hit_shape.radius = 0.95
	_self_melee_exclude = [get_rid()]
	_setup_flashlight()
	_setup_gun_view_model()
	_setup_lightning_target_indicator()
	_update_hud_status()
	
	_hitbox_pairs.clear()
	for child in skeleton.get_children():
		if child is BoneAttachment3D:
			for subchild in child.get_children():
				if subchild is Area3D and subchild.name.begins_with("Hitbox"):
					subchild.set_as_top_level(true)
					_hitbox_pairs.append([child, subchild])
					_self_melee_exclude.append(subchild.get_rid())

func _sync_hitboxes(delta: float) -> void:
	for pair in _hitbox_pairs:
		var attach: BoneAttachment3D = pair[0]
		var hitbox: Area3D = pair[1]
		var bone_pose = skeleton.get_bone_global_pose(attach.bone_idx)
		var t: Transform3D = skeleton.global_transform * bone_pose
		hitbox.global_transform = Transform3D(t.basis.orthonormalized(), t.origin)
	# Advanced anti-clip camera logic using Sphere Cast (thick ray)
	# Decouple raw target from raw bone to completely negate side-to-side animation jitter tracking
	var current_offset = _camera_origin_offset
	current_offset.z -= 0.22
	current_offset.y += 0.00
	
	# if is_crouching:
	# 	current_offset.y -= (normal_height - crouch_height)
	var raw_target_pos = to_global(current_offset)
	
	# Stabilize the camera's Y axis depending on the movement state
	var is_walking = is_on_floor() and velocity.length_squared() > 1.0 and not is_sprinting
	if is_walking:
		# Heavy stabilization for smooth aiming while walking
		_smoothed_head_y = lerpf(_smoothed_head_y, raw_target_pos.y, 5.0 * delta)
	else:
		# Natural bone following for running/jumping
		_smoothed_head_y = lerpf(_smoothed_head_y, raw_target_pos.y, 25.0 * delta)
		
	var target_pos = Vector3(raw_target_pos.x, _smoothed_head_y, raw_target_pos.z)
	var center_pos = global_position
	center_pos.y = target_pos.y
	
	var space_state = get_world_3d().direct_space_state
	_camera_collision_query.transform = Transform3D(Basis(), center_pos)
	_camera_collision_query.motion = target_pos - center_pos
	
	var result = space_state.cast_motion(_camera_collision_query)
	if result.size() == 2:
		var safe_fraction = result[0]
		camera.global_position = center_pos + _camera_collision_query.motion * safe_fraction
	else:
		camera.global_position = target_pos
		
	# Synchronize absolute rotations manually to avoid bone roll/pitch jitter
	camera.global_rotation.y = global_rotation.y
	camera.global_rotation.x = deg_to_rad(-camera_x_rotation)
	camera.global_rotation.z = 0.0



func _input(event: InputEvent) -> void:
	if cinematic_locked:
		if _lightning_targeting:
			_set_lightning_targeting(false)
		return
	if Input.is_action_just_pressed("ui_cancel"):
		if _lightning_targeting:
			_set_lightning_targeting(false)
			return
		Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)

	if GameState.rewind_mode_active:
		if event is InputEventKey and event.pressed and not event.echo:
			if event.keycode == KEY_SPACE:
				GameState.deactivate_rewind_mode(true)
			elif event.keycode == KEY_X and _can_use_axiom():
				GameState.cancel_rewind_mode()
		return

	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_R:
			if not _can_use_axiom():
				return
			if GameState.world_history.size() > 0:
				GameState.activate_rewind_mode()
			return
		elif event.keycode == KEY_X:
			if _can_use_axiom():
				GameState.add_mark_current()
				hud.show_mark_screenshot_effect()

	if event is InputEventMouseMotion and Input.get_mouse_mode() == Input.MOUSE_MODE_CAPTURED:
		if _lightning_targeting:
			_move_lightning_target_from_mouse(event.relative)
			return
		if GameState.time_direction == 1 and GameState.is_scrubbing_past:
			GameState.prune_timeline()
		rotate_y(deg_to_rad(-event.relative.x * mouse_sensitivity))
		var x_delta = event.relative.y * mouse_sensitivity
		camera_x_rotation = clamp(camera_x_rotation + x_delta, -90.0, 90.0)

	if event is InputEventKey and event.pressed:
		if event.keycode == KEY_1:
			GameState.select_slot(0)
		elif event.keycode == KEY_2:
			GameState.select_slot(1)
		elif event.keycode == KEY_3:
			GameState.select_slot(2)
	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_LEFT:
			if _lightning_targeting:
				_cast_lightning_at_target()
				return
			if _can_use_gun():
				_fire_gun()

func _physics_process(delta: float) -> void:
	if health > 0.0 and health < max_health:
		_health_regen_timer += delta
		while _health_regen_timer >= 1.0:
			_health_regen_timer -= 1.0
			health = minf(max_health, health + 1.0)
			_update_hud_status()
	else:
		_health_regen_timer = 0.0
	_update_flashlight_state()
	_update_gun_state(delta)
	_update_lightning_skill(delta)
	if _attack_timer > 0.0:
		_attack_timer = maxf(0.0, _attack_timer - delta)
		if _attack_timer <= 0.0:
			_attack_locked = false
			_attack_name = ""
	if cinematic_locked:
		velocity.x = lerpf(velocity.x, 0.0, acceleration * delta)
		velocity.z = lerpf(velocity.z, 0.0, acceleration * delta)
		if is_on_floor():
			velocity.y = 0.0
		else:
			velocity.y = max(velocity.y - gravity * delta, -30.0)
		move_and_slide()
		_sync_hitboxes(delta)
		_update_hud_status()
		return
	if mobility_locked and not GameState.rewind_mode_active:
		velocity.x = lerpf(velocity.x, 0.0, acceleration * delta)
		velocity.z = lerpf(velocity.z, 0.0, acceleration * delta)
		if is_on_floor():
			velocity.y = 0.0
		else:
			velocity.y = max(velocity.y - gravity * delta, -30.0)
		move_and_slide()
		_sync_hitboxes(delta)
		_update_hud_status()
		return
	if GameState.rewind_mode_active:
		var r_held = Input.is_key_pressed(KEY_R)
		var f_held = Input.is_key_pressed(KEY_F)
		if r_held or f_held:
			_rewind_scroll_hold_time += delta
			var speed = 1.0 + _rewind_scroll_hold_time * 6.0
			var steps_per_frame = int(speed * delta * 60.0)
			if steps_per_frame < 1:
				steps_per_frame = 1
			var dir_val = -1 if r_held else 1
			for _i in range(steps_per_frame):
				GameState.move_rewind_pointer(dir_val)
			hud.trigger_pointer_glitch()
		else:
			_rewind_scroll_hold_time = 0.0
		_sync_hitboxes(delta)
		_update_hud_status()
		return

	var dir = GameState.time_direction
	if dir == 1 and not GameState.is_scrubbing_past:
		var has_input = Input.is_key_pressed(KEY_W) or Input.is_key_pressed(KEY_A) or Input.is_key_pressed(KEY_S) or Input.is_key_pressed(KEY_D) or Input.is_key_pressed(KEY_SPACE)
		if has_input and GameState.is_scrubbing_past:
			GameState.prune_timeline()
		if _attack_locked:
			_handle_attack_movement(delta)
		else:
			_handle_movement(delta)
	_handle_interaction(delta)


func _handle_movement(delta: float) -> void:
	var movement_vector = Vector3.ZERO

	if Input.is_key_pressed(KEY_W):
		movement_vector -= global_transform.basis.z
	if Input.is_key_pressed(KEY_S):
		movement_vector += global_transform.basis.z
	if Input.is_key_pressed(KEY_A):
		movement_vector -= global_transform.basis.x
	if Input.is_key_pressed(KEY_D):
		movement_vector += global_transform.basis.x

	movement_vector = movement_vector.normalized()

	if anim_player:
		var current_anim = "idle"
		if is_on_floor():
			if movement_vector.length() > 0:
				current_anim = "run"
				# Differentiate walk vs run natively by animation speed
				if is_sprinting:
					anim_player.speed_scale = 1.0
				else:
					anim_player.speed_scale = 0.55
			else:
				current_anim = "idle"
				anim_player.speed_scale = 1.0
		else:
			if velocity.y > 0:
				current_anim = "air_jump"
			else:
				current_anim = "air_land"
			anim_player.speed_scale = 1.0
			
		if anim_player.has_animation(current_anim):
			if anim_player.current_animation != current_anim:
				anim_player.play(current_anim, 0.2)

	# var wants_crouch = Input.is_key_pressed(KEY_CTRL)
	var wants_sprint = Input.is_key_pressed(KEY_SHIFT) # and not wants_crouch
	var is_moving := movement_vector.length_squared() > 0.001

	# if wants_crouch and not is_crouching:
	# 	is_crouching = true
	# 	is_sprinting = false
	# 	collision_shape.shape.height = crouch_height
	# 	collision_shape.position.y = crouch_height * 0.5
	# elif not wants_crouch and is_crouching:
	# 	is_crouching = false
	# 	collision_shape.shape.height = normal_height
	# 	collision_shape.position.y = normal_height * 0.5

	var can_sprint := wants_sprint and is_moving and stamina > 0.0 and is_on_floor()
	is_sprinting = can_sprint
	if is_sprinting:
		stamina = maxf(0.0, stamina - stamina_drain_rate * delta)
		_stamina_recover_cooldown = stamina_recover_delay
	else:
		_stamina_recover_cooldown = maxf(0.0, _stamina_recover_cooldown - delta)
		if _stamina_recover_cooldown <= 0.0:
			stamina = minf(max_stamina, stamina + stamina_recover_rate * delta)

	var current_speed: float
	# if is_crouching:
	# 	current_speed = crouch_speed
	if is_sprinting:
		current_speed = sprint_speed
	else:
		current_speed = speed

	velocity.x = lerpf(velocity.x, movement_vector.x * current_speed, acceleration * delta)
	velocity.z = lerpf(velocity.z, movement_vector.z * current_speed, acceleration * delta)

	if is_on_floor():
		velocity.y = 0.0
	else:
		velocity.y = max(velocity.y - gravity * delta, -30.0)

	if Input.is_key_pressed(KEY_SPACE) and is_on_floor() and not is_crouching:
		velocity.y = jump_power

	move_and_slide()
	
	# Keep hitboxes in sync at all times
	_sync_hitboxes(delta)
	_update_hud_status()

func _handle_attack_movement(delta: float) -> void:
	velocity.x = lerpf(velocity.x, 0.0, acceleration * delta)
	velocity.z = lerpf(velocity.z, 0.0, acceleration * delta)
	if is_on_floor():
		velocity.y = 0.0
	else:
		velocity.y = max(velocity.y - gravity * delta, -30.0)
	move_and_slide()
	_sync_hitboxes(delta)
	_update_hud_status()

func _handle_interaction(delta: float) -> void:
	if not interaction_ray:
		return
	var collider = interaction_ray.get_collider()
	if collider and collider.has_method("interact"):
		var p_text = collider.get("prompt_text")
		if typeof(p_text) == TYPE_STRING:
			var is_dig = collider.has_method("get_equip_hint") and collider.get_equip_hint() == GameState.slots[GameState.selected_slot]
			if last_interactable != null and last_interactable != collider:
				if last_interactable.has_method("reset_minigame"):
					last_interactable.reset_minigame()
					hud.set_dig_progress(0, false)
				if last_interactable.has_method("set_highlight_enabled"):
					last_interactable.set_highlight_enabled(false)
			last_interactable = collider
			if collider.has_method("set_highlight_enabled"):
				collider.set_highlight_enabled(true)
			if collider.has_method("set_highlight_strength"):
				collider.set_highlight_strength(1.0)
			
			# Handle Continuous Hold Mechanic (like digging)
			if collider.has_method("progress_minigame"):
				if Input.is_key_pressed(KEY_E):
					var prog = collider.progress_minigame(delta)
					if prog >= 0:
						hud.set_dig_progress(prog, true)
					if prog >= 100.0:
						hud.set_dig_progress(0, false)
						hud.set_crosshair_active(false, false)
						p_text = ""
				else:
					collider.reset_minigame()
					hud.set_dig_progress(0, false)
					
			if p_text == "":
				hud.hide_prompt()
			else:
				hud.show_prompt(p_text)
			hud.set_crosshair_active(true, is_dig)
		else:
			if last_interactable != null:
				if is_instance_valid(last_interactable):
					if last_interactable.has_method("reset_minigame"):
						last_interactable.reset_minigame()
					if last_interactable.has_method("set_highlight_enabled"):
						last_interactable.set_highlight_enabled(false)
				last_interactable = null
			hud.hide_prompt()
			hud.set_dig_progress(0, false)
			hud.set_crosshair_active(false)
	else:
		if last_interactable != null:
			if is_instance_valid(last_interactable):
				if last_interactable.has_method("reset_minigame"):
					last_interactable.reset_minigame()
				if last_interactable.has_method("set_highlight_enabled"):
					last_interactable.set_highlight_enabled(false)
			last_interactable = null
		hud.hide_prompt()
		hud.set_dig_progress(0, false)
		hud.set_crosshair_active(false)

func _update_hud_status() -> void:
	if hud == null:
		return
	hud.set_health(health, max_health)
	hud.set_stamina(stamina, max_stamina)
	var weapon_visible: bool = _has_gun_selected() and not GameState.rewind_mode_active and not cinematic_locked
	if hud.has_method("set_weapon_hud_visible"):
		hud.call("set_weapon_hud_visible", weapon_visible)
	if hud.has_method("set_ammo"):
		hud.call("set_ammo", _gun_ammo, _gun_clip_size)
	if hud.has_method("set_reload_progress"):
		if weapon_visible and _gun_reloading:
			var ratio: float = 1.0
			if _gun_reload_duration > 0.0:
				ratio = 1.0 - (_gun_reload_timer / _gun_reload_duration)
			hud.call("set_reload_progress", clampf(ratio, 0.0, 1.0), true)
		else:
			hud.call("set_reload_progress", 0.0, false)

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_1:
			GameState.select_slot(0)
		elif event.keycode == KEY_2:
			GameState.select_slot(1)
		elif event.keycode == KEY_3:
			GameState.select_slot(2)
		elif event.keycode == KEY_Q:
			_drop_item()
		elif event.keycode == KEY_E:
			if last_interactable:
				if not last_interactable.has_method("progress_minigame"):
					last_interactable.interact()

func _drop_item() -> void:
	var item_name = GameState.get_selected_item()
	if item_name == "":
		return
	GameState.consume_selected()
	if item_name == "key_1" or item_name.begins_with("key"):
		_spawn_drop_item(KEY_ITEM_SCENE, item_name)
	elif item_name == "Shovel":
		_spawn_drop_item(SHOVEL_ITEM_SCENE)
	elif item_name == "Axiom":
		_spawn_drop_item(AXIOM_ITEM_SCENE)
	elif item_name == "Flashlight":
		_spawn_drop_item(FLASHLIGHT_ITEM_SCENE)
	elif item_name == "Gun":
		_spawn_drop_item(GUN_ITEM_SCENE)
	elif item_name == LIGHTNING_SKILL_ITEM_ID:
		_spawn_drop_item(LIGHTNING_ITEM_SCENE)

func _spawn_drop_item(scene: PackedScene, dropped_item_id: String = "") -> void:
	if scene == null:
		return
	var dropped: Node3D = scene.instantiate() as Node3D
	if dropped == null:
		return
	get_tree().root.add_child(dropped)
	dropped.global_position = head.global_position - head.global_transform.basis.z * 1.5
	if dropped_item_id != "" and _node_has_property(dropped, "key_id"):
		dropped.set("key_id", dropped_item_id)

func _node_has_property(node: Object, property_name: String) -> bool:
	for prop in node.get_property_list():
		if String(prop.get("name", "")) == property_name:
			return true
	return false

func _can_use_axiom() -> bool:
	return GameState.has_rewind_access()

func _has_gun_selected() -> bool:
	return GameState.has_selected_item("Gun")

func _has_lightning_skill_selected() -> bool:
	return GameState.has_selected_item(LIGHTNING_SKILL_ITEM_ID)

func _can_use_gun() -> bool:
	return _has_gun_selected() and not _lightning_targeting and not cinematic_locked and not GameState.is_time_blocked() and not _gun_reloading and _gun_shot_timer <= 0.0

func _can_reload_gun() -> bool:
	return _has_gun_selected() and not _gun_reloading and _gun_ammo < _gun_clip_size and not cinematic_locked and not GameState.is_time_blocked()

func _start_gun_reload() -> void:
	if not _can_reload_gun():
		return
	_gun_reloading = true
	_gun_reload_timer = _gun_reload_duration

func _fire_gun() -> void:
	if not _can_use_gun():
		return
	if _gun_ammo <= 0:
		_start_gun_reload()
		return
	_gun_ammo -= 1
	_gun_shot_timer = _gun_shot_cooldown
	_gun_recoil = minf(1.0, _gun_recoil + 0.42)
	var from: Vector3 = camera.global_position
	var direction: Vector3 = -camera.global_transform.basis.z.normalized()
	var to: Vector3 = from + direction * _gun_range
	var query: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(from, to)
	query.exclude = _self_melee_exclude
	query.collide_with_areas = false
	query.collide_with_bodies = true
	var hit: Dictionary = get_world_3d().direct_space_state.intersect_ray(query)
	var impact_position: Vector3 = to
	var impact_normal: Vector3 = Vector3.UP
	var hit_damage_target: bool = false
	if not hit.is_empty():
		impact_position = hit.get("position", to)
		impact_normal = hit.get("normal", Vector3.UP)
		var collider: Node = hit.get("collider") as Node
		var target: Node3D = _resolve_damage_target(collider)
		if target != null and target.has_method("take_damage"):
			target.call("take_damage", _gun_damage)
			hit_damage_target = true
	_spawn_bullet_tracer(_get_gun_muzzle_world_position(), impact_position)
	_spawn_bullet_impact(impact_position, impact_normal, hit_damage_target)
	if _gun_ammo <= 0:
		_start_gun_reload()

func _update_gun_state(delta: float) -> void:
	if GameState.rewind_mode_active:
		_update_gun_view_model(delta)
		return
	if _gun_shot_timer > 0.0:
		_gun_shot_timer = maxf(0.0, _gun_shot_timer - delta)
	if _gun_reloading:
		_gun_reload_timer = maxf(0.0, _gun_reload_timer - delta)
		if _gun_reload_timer <= 0.0:
			_gun_reloading = false
			_gun_ammo = _gun_clip_size
	_gun_recoil = maxf(0.0, _gun_recoil - delta * 4.6)
	_update_gun_view_model(delta)

func _setup_gun_view_model() -> void:
	var gun_view_scene: PackedScene = load("res://scenes/objects/gun_view_model.tscn") as PackedScene
	if gun_view_scene == null:
		return
	_gun_view_root = gun_view_scene.instantiate() as Node3D
	_gun_view_root.visible = false
	camera.add_child(_gun_view_root)
	_gun_muzzle = _gun_view_root.get_node_or_null("Muzzle") as Node3D
	var tracer_shader: Shader = load("res://shaders/bullet_tracer.gdshader") as Shader
	var impact_shader: Shader = load("res://shaders/bullet_impact.gdshader") as Shader
	var tracer_material := ShaderMaterial.new()
	tracer_material.shader = tracer_shader
	tracer_material.set_shader_parameter("tint_color", Color(1.0, 0.92, 0.64, 0.92))
	tracer_material.set_shader_parameter("glow_strength", 4.8)
	tracer_material.set_shader_parameter("pulse_speed", 11.0)
	_gun_shot_material = tracer_material
	var impact_enemy_material := ShaderMaterial.new()
	impact_enemy_material.shader = impact_shader
	impact_enemy_material.set_shader_parameter("tint_color", Color(1.0, 0.16, 0.12, 0.94))
	impact_enemy_material.set_shader_parameter("glow_strength", 6.8)
	impact_enemy_material.set_shader_parameter("pulse_speed", 19.0)
	_gun_impact_material_enemy = impact_enemy_material
	var impact_world_material := ShaderMaterial.new()
	impact_world_material.shader = impact_shader
	impact_world_material.set_shader_parameter("tint_color", Color(1.0, 0.72, 0.24, 0.9))
	impact_world_material.set_shader_parameter("glow_strength", 5.2)
	impact_world_material.set_shader_parameter("pulse_speed", 14.0)
	_gun_impact_material_world = impact_world_material

func _update_gun_view_model(delta: float) -> void:
	if _gun_view_root == null:
		return
	var active: bool = _has_gun_selected() and not GameState.is_time_blocked() and not cinematic_locked
	_gun_view_root.visible = active
	if not active:
		return
	var bob_x: float = sin(Time.get_ticks_msec() * 0.006) * 0.008
	var bob_y: float = sin(Time.get_ticks_msec() * 0.0042) * 0.006
	_gun_view_root.position = Vector3(0.28 + bob_x, -0.25 + bob_y + _gun_recoil * 0.04, -0.55 + _gun_recoil * 0.11)
	_gun_view_root.rotation_degrees = Vector3(-2.0 - _gun_recoil * 8.0, -3.5, 0.0)

func _get_gun_muzzle_world_position() -> Vector3:
	if _gun_muzzle != null and _gun_view_root != null and _gun_view_root.visible:
		return _gun_muzzle.global_position
	var forward: Vector3 = -camera.global_transform.basis.z.normalized()
	var right: Vector3 = camera.global_transform.basis.x.normalized()
	var up: Vector3 = camera.global_transform.basis.y.normalized()
	return camera.global_position + forward * 0.42 + right * 0.1 - up * 0.08

func _spawn_bullet_tracer(from: Vector3, to: Vector3) -> void:
	var parent: Node = get_tree().current_scene
	if parent == null:
		parent = get_parent()
	if parent == null:
		return
	var direction: Vector3 = to - from
	var distance: float = direction.length()
	if distance <= 0.001:
		return
	var tracer := MeshInstance3D.new()
	var tracer_mesh := BoxMesh.new()
	tracer_mesh.size = Vector3(0.03, 0.03, distance)
	tracer.mesh = tracer_mesh
	tracer.material_override = _gun_shot_material
	var look_basis: Basis = Basis.looking_at(direction.normalized(), Vector3.UP)
	tracer.global_transform = Transform3D(look_basis, from.lerp(to, 0.5))
	parent.add_child(tracer)
	var t: Tween = create_tween()
	t.tween_interval(0.06)
	t.finished.connect(tracer.queue_free, CONNECT_ONE_SHOT)

func _spawn_bullet_impact(position: Vector3, normal: Vector3, hit_enemy: bool) -> void:
	var parent: Node = get_tree().current_scene
	if parent == null:
		parent = get_parent()
	if parent == null:
		return
	var flash := MeshInstance3D.new()
	var flash_mesh := SphereMesh.new()
	flash_mesh.radius = 0.06
	flash_mesh.height = 0.12
	flash.mesh = flash_mesh
	flash.material_override = _gun_impact_material_enemy if hit_enemy else _gun_impact_material_world
	var forward: Vector3 = normal.normalized()
	if forward.length_squared() <= 0.0001:
		forward = Vector3.UP
	var up_axis: Vector3 = Vector3.UP
	if absf(forward.dot(up_axis)) > 0.98:
		up_axis = Vector3.FORWARD
	flash.global_transform = Transform3D(Basis.looking_at(forward, up_axis), position + forward * 0.02)
	flash.scale = Vector3(0.5, 0.5, 0.5)
	parent.add_child(flash)
	var flash_tween: Tween = create_tween().set_parallel(true)
	flash_tween.tween_property(flash, "scale", Vector3(1.8, 1.8, 1.8), 0.06).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	flash_tween.chain().tween_property(flash, "scale", Vector3.ZERO, 0.12).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	flash_tween.finished.connect(flash.queue_free, CONNECT_ONE_SHOT)

func _setup_lightning_target_indicator() -> void:
	_lightning_target_root = Node3D.new()
	_lightning_target_root.name = "LightningTarget"
	var parent: Node = get_tree().current_scene
	if parent == null:
		parent = get_parent()
	if parent == null:
		return
	parent.add_child(_lightning_target_root)
	_lightning_target_ring = MeshInstance3D.new()
	var ring_mesh: CylinderMesh = CylinderMesh.new()
	ring_mesh.top_radius = 1.2
	ring_mesh.bottom_radius = 1.2
	ring_mesh.height = 0.05
	_lightning_target_ring.mesh = ring_mesh
	var ring_mat: StandardMaterial3D = StandardMaterial3D.new()
	ring_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	ring_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	ring_mat.albedo_color = Color(0.02, 0.02, 0.03, 0.72)
	ring_mat.emission_enabled = true
	ring_mat.emission = Color(0.08, 0.08, 0.12, 1.0)
	ring_mat.emission_energy_multiplier = 3.6
	_lightning_target_ring.material_override = ring_mat
	_lightning_target_root.add_child(_lightning_target_ring)
	_lightning_target_core = MeshInstance3D.new()
	var core_mesh: CylinderMesh = CylinderMesh.new()
	core_mesh.top_radius = 0.2
	core_mesh.bottom_radius = 0.2
	core_mesh.height = 0.04
	_lightning_target_core.mesh = core_mesh
	var core_mat: StandardMaterial3D = StandardMaterial3D.new()
	core_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	core_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	core_mat.albedo_color = Color(0.04, 0.04, 0.06, 0.92)
	core_mat.emission_enabled = true
	core_mat.emission = Color(0.1, 0.1, 0.14, 1.0)
	core_mat.emission_energy_multiplier = 5.0
	_lightning_target_core.material_override = core_mat
	_lightning_target_root.add_child(_lightning_target_core)
	_lightning_target_trace = MeshInstance3D.new()
	var trace_mesh: BoxMesh = BoxMesh.new()
	trace_mesh.size = Vector3(0.16, 0.04, 1.0)
	_lightning_target_trace.mesh = trace_mesh
	var trace_shader: Shader = load("res://shaders/bullet_tracer.gdshader") as Shader
	var trace_mat: ShaderMaterial = ShaderMaterial.new()
	trace_mat.shader = trace_shader
	trace_mat.set_shader_parameter("tint_color", Color(0.08, 0.08, 0.12, 0.94))
	trace_mat.set_shader_parameter("glow_strength", 3.9)
	trace_mat.set_shader_parameter("pulse_speed", 8.8)
	_lightning_target_trace.material_override = trace_mat
	_lightning_target_trace.visible = false
	parent.add_child(_lightning_target_trace)
	_lightning_target_root.visible = false

func _update_lightning_skill(delta: float) -> void:
	if _lightning_target_root == null or not is_instance_valid(_lightning_target_root):
		return
	var can_target: bool = _has_lightning_skill_selected() and not GameState.is_time_blocked() and not cinematic_locked
	if not can_target:
		if _lightning_targeting:
			_set_lightning_targeting(false)
		return
	if not _lightning_targeting:
		_set_lightning_targeting(true)
	_update_lightning_target_position()
	_lightning_target_ring.rotate_y(delta * 1.8)
	var pulse: float = 0.9 + sin(Time.get_ticks_msec() * 0.016) * 0.12
	_lightning_target_ring.scale = Vector3.ONE * pulse
	_lightning_target_core.scale = Vector3.ONE * (0.8 + sin(Time.get_ticks_msec() * 0.021) * 0.16)
	_update_lightning_trace_line()

func _set_lightning_targeting(active: bool) -> void:
	if _lightning_target_root == null or not is_instance_valid(_lightning_target_root):
		return
	if _lightning_targeting == active:
		return
	_lightning_targeting = active
	_lightning_target_root.visible = active
	if _lightning_target_trace != null and is_instance_valid(_lightning_target_trace):
		_lightning_target_trace.visible = active and _lightning_target_valid
	if active:
		if Input.get_mouse_mode() != Input.MOUSE_MODE_CAPTURED:
			Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
		_initialize_lightning_target_position()
		_update_lightning_target_position()
	else:
		if Input.get_mouse_mode() != Input.MOUSE_MODE_CAPTURED:
			Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)

func _update_lightning_target_position() -> void:
	if camera == null or _lightning_target_root == null:
		_lightning_target_valid = false
		return
	var query_from: Vector3 = _lightning_target_position + Vector3(0.0, 40.0, 0.0)
	var query_to: Vector3 = _lightning_target_position + Vector3(0.0, -40.0, 0.0)
	var query: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(query_from, query_to)
	query.exclude = [get_rid()]
	query.collide_with_areas = false
	query.collide_with_bodies = true
	var hit: Dictionary = get_world_3d().direct_space_state.intersect_ray(query)
	if hit.is_empty():
		_lightning_target_valid = false
		_lightning_target_root.visible = false
		if _lightning_target_trace != null and is_instance_valid(_lightning_target_trace):
			_lightning_target_trace.visible = false
		return
	var hit_position: Variant = hit.get("position", global_position)
	if typeof(hit_position) != TYPE_VECTOR3:
		_lightning_target_valid = false
		_lightning_target_root.visible = false
		if _lightning_target_trace != null and is_instance_valid(_lightning_target_trace):
			_lightning_target_trace.visible = false
		return
	_lightning_target_position = hit_position as Vector3
	_lightning_target_position.y -= 0.02
	_lightning_target_valid = true
	_lightning_target_root.global_position = _lightning_target_position
	_lightning_target_root.visible = _lightning_targeting
	if _lightning_target_trace != null and is_instance_valid(_lightning_target_trace):
		_lightning_target_trace.visible = _lightning_targeting

func _initialize_lightning_target_position() -> void:
	if camera == null:
		return
	var ray_origin: Vector3 = camera.global_position
	var ray_direction: Vector3 = -camera.global_transform.basis.z.normalized()
	var ray_end: Vector3 = ray_origin + ray_direction * minf(lightning_target_max_distance, lightning_target_control_radius)
	var query: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(ray_origin, ray_end)
	query.exclude = [get_rid()]
	query.collide_with_areas = false
	query.collide_with_bodies = true
	var hit: Dictionary = get_world_3d().direct_space_state.intersect_ray(query)
	if not hit.is_empty():
		var hit_position: Variant = hit.get("position", global_position + ray_direction * 8.0)
		if typeof(hit_position) == TYPE_VECTOR3:
			_lightning_target_position = hit_position as Vector3
			_clamp_lightning_target_radius()
			return
	_lightning_target_position = global_position + ray_direction * 8.0
	_clamp_lightning_target_radius()

func _move_lightning_target_from_mouse(relative: Vector2) -> void:
	if camera == null:
		return
	var right: Vector3 = camera.global_transform.basis.x.normalized()
	var forward: Vector3 = -camera.global_transform.basis.z.normalized()
	right.y = 0.0
	forward.y = 0.0
	if right.length_squared() <= 0.0001:
		right = Vector3.RIGHT
	else:
		right = right.normalized()
	if forward.length_squared() <= 0.0001:
		forward = Vector3.FORWARD
	else:
		forward = forward.normalized()
	var move: Vector3 = (right * relative.x + forward * -relative.y) * lightning_target_move_speed
	_lightning_target_position += move
	_clamp_lightning_target_radius()
	_update_lightning_target_position()

func _clamp_lightning_target_radius() -> void:
	var anchor: Vector3 = global_position
	anchor.y = _lightning_target_position.y
	var offset: Vector3 = _lightning_target_position - anchor
	offset.y = 0.0
	var max_radius: float = minf(lightning_target_max_distance, lightning_target_control_radius)
	if offset.length() > max_radius:
		offset = offset.normalized() * max_radius
	_lightning_target_position.x = anchor.x + offset.x
	_lightning_target_position.z = anchor.z + offset.z

func _update_lightning_trace_line() -> void:
	if _lightning_target_trace == null or not is_instance_valid(_lightning_target_trace):
		return
	if not _lightning_targeting or not _lightning_target_valid:
		_lightning_target_trace.visible = false
		return
	var start: Vector3 = global_position + Vector3(0.0, 0.06, 0.0)
	var end: Vector3 = _lightning_target_position + Vector3(0.0, 0.06, 0.0)
	var dir: Vector3 = end - start
	dir.y = 0.0
	var len: float = dir.length()
	if len <= 0.12:
		_lightning_target_trace.visible = false
		return
	_lightning_target_trace.visible = true
	var basis: Basis = Basis.looking_at(dir.normalized(), Vector3.UP)
	_lightning_target_trace.global_transform = Transform3D(basis, start.lerp(end, 0.5))
	_lightning_target_trace.scale = Vector3(1.0, 1.0, len)

func _cast_lightning_at_target() -> void:
	if not _lightning_targeting:
		return
	if not _lightning_target_valid:
		return
	if not _has_lightning_skill_selected():
		return
	var cast_point: Vector3 = _lightning_target_position
	_spawn_lightning_strike_effect(cast_point)
	_apply_lightning_strike_damage(cast_point)
	GameState.consume_selected_item(LIGHTNING_SKILL_ITEM_ID)
	_set_lightning_targeting(false)

func _spawn_lightning_strike_effect(position: Vector3) -> void:
	var parent: Node = get_tree().current_scene
	if parent == null:
		parent = get_parent()
	if parent == null:
		return
	var root: Node3D = Node3D.new()
	parent.add_child(root)
	root.global_position = position
	var beam: MeshInstance3D = MeshInstance3D.new()
	var beam_mesh: CylinderMesh = CylinderMesh.new()
	beam_mesh.top_radius = 0.15
	beam_mesh.bottom_radius = 0.34
	beam_mesh.height = lightning_strike_height
	beam.mesh = beam_mesh
	beam.position = Vector3(0.0, lightning_strike_height * 0.5, 0.0)
	var beam_mat: StandardMaterial3D = StandardMaterial3D.new()
	beam_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	beam_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	beam_mat.albedo_color = Color(0.86, 0.96, 1.0, 0.9)
	beam_mat.emission_enabled = true
	beam_mat.emission = Color(0.78, 0.95, 1.0, 1.0)
	beam_mat.emission_energy_multiplier = 9.5
	beam.material_override = beam_mat
	root.add_child(beam)
	var flash: OmniLight3D = OmniLight3D.new()
	flash.light_color = Color(0.8, 0.94, 1.0, 1.0)
	flash.light_energy = 17.0
	flash.omni_range = 16.0
	flash.position = Vector3(0.0, 1.3, 0.0)
	root.add_child(flash)
	var ground_flash: MeshInstance3D = MeshInstance3D.new()
	var flash_mesh: CylinderMesh = CylinderMesh.new()
	flash_mesh.top_radius = lightning_radius * 0.72
	flash_mesh.bottom_radius = lightning_radius * 0.72
	flash_mesh.height = 0.04
	ground_flash.mesh = flash_mesh
	ground_flash.position = Vector3(0.0, 0.03, 0.0)
	var ground_mat: StandardMaterial3D = StandardMaterial3D.new()
	ground_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	ground_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	ground_mat.albedo_color = Color(0.72, 0.9, 1.0, 0.72)
	ground_mat.emission_enabled = true
	ground_mat.emission = Color(0.78, 0.95, 1.0, 1.0)
	ground_mat.emission_energy_multiplier = 6.2
	ground_flash.material_override = ground_mat
	root.add_child(ground_flash)
	var burst: Tween = create_tween().set_parallel(true)
	burst.tween_property(beam_mat, "albedo_color:a", 0.0, 0.22).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	burst.parallel().tween_property(ground_mat, "albedo_color:a", 0.0, 0.2).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	burst.parallel().tween_property(flash, "light_energy", 0.0, 0.24).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	burst.parallel().tween_property(beam, "scale", Vector3(2.1, 1.0, 2.1), 0.2).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	await burst.finished
	root.queue_free()

func _apply_lightning_strike_damage(position: Vector3) -> void:
	var shape: SphereShape3D = SphereShape3D.new()
	shape.radius = lightning_radius
	var query: PhysicsShapeQueryParameters3D = PhysicsShapeQueryParameters3D.new()
	query.shape = shape
	query.transform = Transform3D(Basis(), position + Vector3(0.0, 0.65, 0.0))
	query.exclude = [get_rid()]
	query.collide_with_areas = false
	query.collide_with_bodies = true
	var hits: Array[Dictionary] = get_world_3d().direct_space_state.intersect_shape(query, 32)
	var damaged: Dictionary = {}
	for hit in hits:
		var collider: Node = hit.get("collider") as Node
		var target: Node3D = _resolve_damage_target(collider)
		if target == null:
			continue
		var key: int = target.get_instance_id()
		if damaged.has(key):
			continue
		damaged[key] = true
		target.call("take_damage", lightning_damage)

func _resolve_damage_target(start: Node) -> Node3D:
	var target: Node = start
	while target != null:
		if target == self:
			return null
		if target is Node3D and target.has_method("take_damage"):
			return target as Node3D
		target = target.get_parent()
	return null

func set_cinematic_lock(active: bool) -> void:
	cinematic_locked = active
	if active:
		velocity.x = 0.0
		velocity.z = 0.0

func set_mobility_lock(active: bool) -> void:
	mobility_locked = active
	if active:
		velocity.x = 0.0
		velocity.z = 0.0

func apply_knockback(direction: Vector3, horizontal_strength: float, vertical_strength: float) -> void:
	var launch_direction: Vector3 = direction
	launch_direction.y = 0.0
	if launch_direction.length_squared() <= 0.0001:
		launch_direction = -global_transform.basis.z
		launch_direction.y = 0.0
	launch_direction = launch_direction.normalized()
	velocity.x = launch_direction.x * horizontal_strength
	velocity.z = launch_direction.z * horizontal_strength
	velocity.y = maxf(velocity.y, vertical_strength)

func set_cinematic_pose(target_position: Vector3, target_yaw: float, target_pitch: float) -> void:
	global_position = target_position
	rotation.y = target_yaw
	camera_x_rotation = target_pitch
	velocity = Vector3.ZERO
	_sync_hitboxes(1.0 / 60.0)

func take_damage(amount: float) -> void:
	health = maxf(0.0, health - amount)
	_update_hud_status()
	if health <= 0.0:
		var world := get_parent()
		if world != null and world.has_method("restart_current_level"):
			world.call_deferred("restart_current_level")

func _setup_flashlight() -> void:
	_flashlight_spot = SpotLight3D.new()
	_flashlight_spot.light_color = Color(1.0, 0.96, 0.82, 1.0)
	_flashlight_spot.light_energy = 2.8
	_flashlight_spot.spot_range = 22.0
	_flashlight_spot.spot_angle = 34.0
	_flashlight_spot.spot_attenuation = 0.55
	_flashlight_spot.shadow_enabled = true
	_flashlight_spot.visible = false
	camera.add_child(_flashlight_spot)
	_flashlight_spot.position = Vector3(0.18, -0.08, -0.22)

func _update_flashlight_state() -> void:
	if _flashlight_spot == null:
		return
	_flashlight_spot.visible = GameState.has_selected_item("Flashlight")
