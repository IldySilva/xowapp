from PIL import Image
import sys

img = Image.open(sys.argv[1]).convert("RGBA")
width, height = img.size
pixels = img.load()

# find center
cx, cy = width // 2, height // 2
if pixels[cx, cy][3] != 0:
    print(f"Center pixel is not transparent! Alpha: {pixels[cx, cy][3]}")
    sys.exit(0)

# Expand out from center to find bounds of the screen hole
min_x, max_x = cx, cx
min_y, max_y = cy, cy

while min_x > 0 and pixels[min_x - 1, cy][3] == 0:
    min_x -= 1
while max_x < width - 1 and pixels[max_x + 1, cy][3] == 0:
    max_x += 1
while min_y > 0 and pixels[cx, min_y - 1][3] == 0:
    min_y -= 1
while max_y < height - 1 and pixels[cx, max_y + 1][3] == 0:
    max_y += 1

print(f"Screen Hole Bounds: x={min_x}, y={min_y}, w={max_x - min_x + 1}, h={max_y - min_y + 1}")
print(f"Frame Size: w={width}, h={height}")

