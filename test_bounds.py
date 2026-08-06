from PIL import Image
import sys
import glob

def get_ratio(path):
    img = Image.open(path).convert("RGBA")
    width, height = img.size
    pixels = img.load()
    cx, cy = width // 2, height // 2
    if pixels[cx, cy][3] != 0: return None
    min_x, max_x = cx, cx
    min_y, max_y = cy, cy
    while min_x > 0 and pixels[min_x - 1, cy][3] == 0: min_x -= 1
    while max_x < width - 1 and pixels[max_x + 1, cy][3] == 0: max_x += 1
    while min_y > 0 and pixels[cx, min_y - 1][3] == 0: min_y -= 1
    while max_y < height - 1 and pixels[cx, max_y + 1][3] == 0: max_y += 1
    return ((max_x - min_x + 1) / width, (max_y - min_y + 1) / height)

for path in glob.glob("frames/**/*.png", recursive=True)[:10]:
    r = get_ratio(path)
    if r: print(f"{path}: w_ratio={r[0]:.3f}, h_ratio={r[1]:.3f}")
