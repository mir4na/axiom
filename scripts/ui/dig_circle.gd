extends Control

var progress: float = 0.0

func set_progress(val: float, is_vis: bool) -> void:
	visible = is_vis
	progress = val
	queue_redraw()

func _draw() -> void:
	if visible:
		draw_arc(size/2, 30.0, 0, PI*2, 32, Color(0, 0, 0, 0.5), 8.0, true)
		if progress > 0:
			draw_arc(size/2, 30.0, -PI/2, -PI/2 + (progress/100.0) * PI*2, 32, Color(1, 0.9, 0.2, 1.0), 8.0, true)
