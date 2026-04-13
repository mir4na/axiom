import re

with open("scenes/levels/level_01.tscn", "r") as f:
    lvl = f.read()

# Make a copy for world.tscn, stripping glitch and floating rock layers
world = re.sub(r'\[node name="RockLayer.*?material = SubResource\("MatRock"\)', '', lvl, flags=re.DOTALL)
world = re.sub(r'\[node name="GlitchFragments".*', '', world, flags=re.DOTALL)
world = world.replace('Level01', 'World')

with open("scenes/world/world.tscn", "w") as f:
    f.write(world.strip() + "\n")

print("world.tscn successfully generated.")
