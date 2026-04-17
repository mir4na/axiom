extends AnimatableBody3D

signal opened
signal closed

var is_open: bool = false
var is_moving: bool = false
var original_position: Vector3

@export var slide_distance: float = 2.4
@export var open_duration: float = 1.0

func _ready() -> void:
	original_position = position

func interact() -> void:
	if is_moving:
		return
	if is_open:
		_close_door()
	else:
		_open_door()

func _open_door() -> void:
	is_moving = true
	var tween = create_tween()
	tween.tween_property(self, "position", original_position + Vector3(0, slide_distance, 0), open_duration)
	await tween.finished
	is_open = true
	is_moving = false
	opened.emit()

func _close_door() -> void:
	is_moving = true
	var tween = create_tween()
	tween.tween_property(self, "position", original_position, open_duration)
	await tween.finished
	is_open = false
	is_moving = false
	closed.emit()
