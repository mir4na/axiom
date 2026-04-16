extends SceneTree

func _init():
    var scene_path = "res://scenes/world/world.tscn"
    var packed_scene = load(scene_path)
    if not packed_scene:
        print("Failed to load scene")
        quit()
        return

    var root = packed_scene.instantiate()
    
    var sun = root.get_node_or_null("Sun")
    if sun:
        # Posisikan matahari rendah di ufuk barat (-15 derajat pitch, 45 derajat yaw)
        sun.transform.basis = Basis.from_euler(Vector3(deg_to_rad(-15), deg_to_rad(45), 0))
        # Ubah warna jadi oranye senja
        sun.light_color = Color(1.0, 0.6, 0.25)
        sun.light_energy = 1.5
        sun.shadow_enabled = true
        
    var env_node = root.get_node_or_null("WorldEnvironment")
    if env_node and env_node.environment:
        var env = env_node.environment
        if env.sky and env.sky.sky_material:
            # Godot's ProceduralSkyMaterial or PhysicalSkyMaterial
            var mat = env.sky.sky_material
            # Wait, if we just rotated the sun, ProceduralSky will automatically update to sunset!
            # If they don't have ProceduralSky, modifying the color helps.
            pass

    # Save the modified scene
    var new_packed = PackedScene.new()
    new_packed.pack(root)
    ResourceSaver.save(new_packed, scene_path)
    print("Sunset applied!")
    quit()
