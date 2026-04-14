import re

with open('/home/mir4na/ameame/csui/game-dev/axiom/axiom/scenes/objects/house.tscn', 'r') as f:
    lines = f.readlines()

new_lines = []
for i, line in enumerate(lines):
    new_lines.append(line)
    if 'type="CSGCombiner3D"' in line:
        if i + 1 < len(lines) and 'use_collision = true' not in lines[i+1]:
            new_lines.append("use_collision = true\n")

with open('/home/mir4na/ameame/csui/game-dev/axiom/axiom/scenes/objects/house.tscn', 'w') as f:
    f.writelines(new_lines)
