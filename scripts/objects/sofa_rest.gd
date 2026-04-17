extends StaticBody3D

signal rest_requested

var prompt_text: String = "Press E to rest"
var _enabled: bool = false

func interact() -> void:
	if not _enabled:
		return
	rest_requested.emit()

func set_interactable_enabled(enabled: bool) -> void:
	_enabled = enabled
	prompt_text = "Press E to rest" if enabled else ""
