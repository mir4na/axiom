extends Area3D

const SCREEN_TRIGGER_DISTANCE := 60.0

var _triggered: bool = false
@onready var _player: Node3D = get_tree().get_first_node_in_group("player")

func _process(_delta: float) -> void:
	if _triggered or not _player:
		return
	
	var cam: Camera3D = get_viewport().get_camera_3d()
	if not cam:
		return

	if cam.is_position_behind(global_position) or cam.is_position_behind(_player.global_position):
		return

	var door_screen_pos: Vector2 = cam.unproject_position(global_position)
	var player_screen_pos: Vector2 = cam.unproject_position(_player.global_position)

	if door_screen_pos.distance_to(player_screen_pos) < SCREEN_TRIGGER_DISTANCE:
		var space_state = get_world_3d().direct_space_state
		var query = PhysicsRayQueryParameters3D.create(cam.global_position, global_position)
		query.exclude = [self.get_rid()]
		
		var result = space_state.intersect_ray(query)
		if result.is_empty():
			_triggered = true
			GameState.complete_level()
