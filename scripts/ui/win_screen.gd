extends Control

@onready var _next_btn: Button = $Panel/VBox/NextButton

func _ready() -> void:
	if not GameState.has_next_level():
		_next_btn.text = "BACK TO MENU"

func _on_next_pressed() -> void:
	var main := get_tree().get_first_node_in_group("main") as Node3D
	if main and main.has_method("go_to_next_level"):
		main.go_to_next_level()

func _on_menu_pressed() -> void:
	var main := get_tree().get_first_node_in_group("main") as Node3D
	if main and main.has_method("go_to_main_menu"):
		main.go_to_main_menu()
