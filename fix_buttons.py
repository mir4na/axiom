import re

with open("scenes/objects/house.tscn", "r") as f:
    content = f.read()

# Fix SubResources
content = re.sub(
    r'(\[sub_resource type="BoxShape3D" id="ButtonCol"\]\n)size = Vector3\(0\.1, 0\.1, 0\.1\)',
    r'\g<1>size = Vector3(0.2, 0.2, 0.2)',
    content
)
content = re.sub(
    r'(\[sub_resource type="BoxMesh" id="ButtonMesh"\]\nmaterial = SubResource\("MatButton"\)\n)size = Vector3\(0\.1, 0\.1, 0\.1\)',
    r'\g<1>size = Vector3(0.15, 0.15, 0.15)',
    content
)

# 1. FrontDoorOut
content = re.sub(
    r'(\[node name="FrontDoorBtnOut" type="StaticBody3D" parent="\." unique_id=\w+\]\n)transform = Transform3D\(.*?\)\n(.*?)(\[node name="Mesh" type="MeshInstance3D" parent="FrontDoorBtnOut" unique_id=\w+\]\n)transform = Transform3D\(.*?\)\n',
    r'\g<1>transform = Transform3D(1, 0, 0, 0, 1, 0, 0, 0, 1, -0.6, 1.2, 9.0)\n\g<2>\g<3>',
    content, flags=re.DOTALL
)

# 2. FrontDoorIn
content = re.sub(
    r'(\[node name="FrontDoorBtnIn" type="StaticBody3D" parent="\." unique_id=\w+\]\n)transform = Transform3D\(.*?\)\n(.*?)(\[node name="Mesh" type="MeshInstance3D" parent="FrontDoorBtnIn" unique_id=\w+\]\n)transform = Transform3D\(.*?\)\n',
    r'\g<1>transform = Transform3D(1, 0, 0, 0, 1, 0, 0, 0, 1, -0.6, 1.2, 8.6)\n\g<2>\g<3>',
    content, flags=re.DOTALL
)

# 3. MasterDoorOut (door at 4.0, z=-3.0. Out is Z=-2.8)
content = re.sub(
    r'(\[node name="MasterDoorBtnOut" type="StaticBody3D" parent="\." unique_id=\w+\]\n)transform = Transform3D\(.*?\)\n(.*?)(\[node name="Mesh" type="MeshInstance3D" parent="MasterDoorBtnOut" unique_id=\w+\]\n)transform = Transform3D\(.*?\)\n',
    r'\g<1>transform = Transform3D(1, 0, 0, 0, 1, 0, 0, 0, 1, 3.6, 1.2, -2.8)\n\g<2>\g<3>',
    content, flags=re.DOTALL
)

# 4. MasterDoorIn (In is Z=-3.2)
content = re.sub(
    r'(\[node name="MasterDoorBtnIn" type="StaticBody3D" parent="\." unique_id=\w+\]\n)transform = Transform3D\(.*?\)\n(.*?)(\[node name="Mesh" type="MeshInstance3D" parent="MasterDoorBtnIn" unique_id=\w+\]\n)transform = Transform3D\(.*?\)\n',
    r'\g<1>transform = Transform3D(1, 0, 0, 0, 1, 0, 0, 0, 1, 3.6, 1.2, -3.2)\n\g<2>\g<3>',
    content, flags=re.DOTALL
)

# 5. GuestDoorOut (door at z=3.5, Out in living room z=3.7)
content = re.sub(
    r'(\[node name="GuestDoorBtnOut" type="StaticBody3D" parent="\." unique_id=\w+\]\n)transform = Transform3D\(.*?\)\n(.*?)(\[node name="Mesh" type="MeshInstance3D" parent="GuestDoorBtnOut" unique_id=\w+\]\n)transform = Transform3D\(.*?\)\n',
    r'\g<1>transform = Transform3D(1, 0, 0, 0, 1, 0, 0, 0, 1, 3.6, 1.2, 3.7)\n\g<2>\g<3>',
    content, flags=re.DOTALL
)

# 6. GuestDoorIn (In is Z=3.3)
content = re.sub(
    r'(\[node name="GuestDoorBtnIn" type="StaticBody3D" parent="\." unique_id=\w+\]\n)transform = Transform3D\(.*?\)\n(.*?)(\[node name="Mesh" type="MeshInstance3D" parent="GuestDoorBtnIn" unique_id=\w+\]\n)transform = Transform3D\(.*?\)\n',
    r'\g<1>transform = Transform3D(1, 0, 0, 0, 1, 0, 0, 0, 1, 3.6, 1.2, 3.3)\n\g<2>\g<3>',
    content, flags=re.DOTALL
)

with open("scenes/objects/house.tscn", "w") as f:
    f.write(content)
