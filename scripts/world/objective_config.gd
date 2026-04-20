extends Node

@export var scoop_objective: String = "Pick up the scoop"
@export var dig_objective: String = "Bury the old stuff"
@export var rest_objective: String = "Rest on the sofa"
@export var check_outside_objective: String = "Check outside"
@export var guest_key_objective: String = "Take the key from the kitchen"
@export var guest_unlock_objective: String = "Open the guest room door"
@export var guest_axiom_objective: String = "Take the Axiom"

func get_objective_text(key: String, fallback: String = "") -> String:
	match key:
		"scoop":
			return scoop_objective
		"dig":
			return dig_objective
		"rest":
			return rest_objective
		"check_outside":
			return check_outside_objective
		"guest_key":
			return guest_key_objective
		"guest_unlock":
			return guest_unlock_objective
		"guest_axiom":
			return guest_axiom_objective
	return fallback
