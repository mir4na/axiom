extends SceneTree

func _init():
    var scene = load("res://assets/Hazmat/Hazmat_Character.fbx")
    var inst = scene.instantiate()
    _print_tree(inst, "")
    quit()

func _print_tree(node, indent):
    print(indent + node.name + " (" + node.get_class() + ")")
    for child in node.get_children():
        _print_tree(child, indent + "  ")
