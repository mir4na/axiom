extends SceneTree

func _init():
    var path = "res://scenes/player/player.tscn"
    var scene = load(path)
    var root = scene.instantiate()
    
    var skel = root.get_node("root/Skeleton3D")
    if skel:
        for b in skel.get_children():
            if b is BoneAttachment3D:
                # Reset the native transform scale to 1.0 to prevent Jolt scale errors during load
                b.transform = Transform3D.IDENTITY
                for child in b.get_children():
                    if child is Area3D:
                        # User wants top_level = false natively
                        child.set_as_top_level(false)
                        # Also reset rotation and scale if somehow skewed
                        child.transform = Transform3D(Basis.IDENTITY, child.transform.origin)
    
    var packed = PackedScene.new()
    packed.pack(root)
    ResourceSaver.save(packed, path)
    print("Fixed!")
    quit()
