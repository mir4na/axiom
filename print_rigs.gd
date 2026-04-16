extends SceneTree

func _init():
    print("--- HAZMAT BONES ---")
    var h_scene = load("res://assets/Hazmat/Hazmat_Character.fbx")
    var h_inst = h_scene.instantiate()
    _print_bones(h_inst)
    
    print("--- PLAYER BONES ---")
    var p_scene = load("res://scenes/player/player.tscn")
    var p_inst = p_scene.instantiate()
    var p_skel = p_inst.get_node("Skeleton3D")
    if p_skel and p_skel is Skeleton3D:
        for i in range(p_skel.get_bone_count()):
            print(p_skel.get_bone_name(i))
    else:
        var alt_skel = p_inst.find_child("Skeleton*", true, false)
        if alt_skel:
            for i in range(alt_skel.get_bone_count()):
                print(alt_skel.get_bone_name(i))
                
    quit()

func _print_bones(node):
    if node is Skeleton3D:
        for i in range(node.get_bone_count()):
            print(node.get_bone_name(i))
    for child in node.get_children():
        _print_bones(child)
