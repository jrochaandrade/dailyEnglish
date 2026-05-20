import pip
import sys

def install(package):
    pip.main(['install', package])

try:
    from PIL import Image, ImageDraw
except ImportError:
    install('pillow')
    from PIL import Image, ImageDraw

# Create 64x64 tileset (4 tiles of 32x32: grass, path, water, tree/wall)
tileset = Image.new('RGBA', (64, 64))
d = ImageDraw.Draw(tileset)

# 1. Grass (0,0) - index 1
d.rectangle([0,0,31,31], fill=(104, 159, 56))
d.rectangle([4,4,6,6], fill=(85, 139, 47))
d.rectangle([20,15,22,17], fill=(85, 139, 47))
d.rectangle([10,24,14,26], fill=(85, 139, 47))

# 2. Path (32,0) - index 2
d.rectangle([32,0,63,31], fill=(215, 204, 200))
d.rectangle([40,10,43,12], fill=(161, 136, 127))
d.rectangle([50,20,55,22], fill=(161, 136, 127))

# 3. Water (0,32) - index 3
d.rectangle([0,32,31,63], fill=(66, 165, 245))
d.rectangle([10,40,15,41], fill=(144, 202, 249))
d.rectangle([20,50,26,51], fill=(144, 202, 249))

# 4. Wall/Tree (32,32) - index 4
d.rectangle([32,32,63,63], fill=(46, 125, 50))
d.ellipse([38,38,58,58], fill=(27, 94, 32))

tileset.save('assets/images/tileset.png')

# Player sprite (32x32)
player = Image.new('RGBA', (32, 32), (0,0,0,0))
dp = ImageDraw.Draw(player)
# Head
dp.ellipse([8,4,24,20], fill=(255, 204, 153))
# Body
dp.rectangle([10,20,22,30], fill=(33, 150, 243))
# Eyes
dp.rectangle([12,10,14,12], fill=(0,0,0))
dp.rectangle([18,10,20,12], fill=(0,0,0))
player.save('assets/images/player.png')

# Enemy sprite (32x32)
enemy = Image.new('RGBA', (32, 32), (0,0,0,0))
de = ImageDraw.Draw(enemy)
# Body
de.ellipse([6,6,26,26], fill=(156, 39, 176))
# Eye
de.ellipse([10,12,22,20], fill=(255,255,255))
de.ellipse([14,14,18,18], fill=(0,0,0))
enemy.save('assets/images/enemy.png')

print("Assets generated successfully!")
