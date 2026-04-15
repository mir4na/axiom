extends SceneTree
func _init():
    var packed = load("res://assets/godot-3d-mannequin-0.3.0/assets/3d/mannequiny/mannequiny-0.3.0.glb")
    var scene = packed.instantiate()
    var mesh_inst = scene.find_child("body_001", true, false)
    if mesh_inst:
        var mesh = mesh_inst.mesh
        print("MESH RID: ", mesh.get_rid())
        print("MESH PATH: ", mesh.resource_path)
        print("MESH CLASS: ", mesh.get_class())
        var skin = mesh_inst.skin
        print("SKIN PATH: ", skin.resource_path)
    quit()
