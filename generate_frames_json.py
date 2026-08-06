import os
import json
import glob
from PIL import Image

def get_true_screen_bounds(path):
    img = Image.open(path).convert("RGBA")
    width, height = img.size
    pixels = img.load()
    
    # Create a 2D boolean array: True if pixel is transparent (alpha < 10)
    is_transparent = [[pixels[x,y][3] < 10 for y in range(height)] for x in range(width)]
    
    # Flood fill from the edges to mark EXTERIOR transparent pixels as False
    stack = []
    for x in range(width):
        stack.append((x, 0))
        stack.append((x, height - 1))
    for y in range(height):
        stack.append((0, y))
        stack.append((width - 1, y))
        
    while stack:
        x, y = stack.pop()
        if 0 <= x < width and 0 <= y < height and is_transparent[x][y]:
            is_transparent[x][y] = False
            stack.append((x+1, y))
            stack.append((x-1, y))
            stack.append((x, y+1))
            stack.append((x, y-1))
            
    # Bounding box of the remaining interior transparent pixels
    min_x, max_x = width, 0
    min_y, max_y = height, 0
    found = False
    
    for x in range(width):
        for y in range(height):
            if is_transparent[x][y]:
                found = True
                if x < min_x: min_x = x
                if x > max_x: max_x = x
                if y < min_y: min_y = y
                if y > max_y: max_y = y
                
    if not found:
        return None
        
    return {
        "x": min_x,
        "y": min_y,
        "w": max_x - min_x + 1,
        "h": max_y - min_y + 1,
        "frame_w": width,
        "frame_h": height
    }

results = {}
for path in glob.glob("frames/**/*.png", recursive=True):
    try:
        bounds = get_true_screen_bounds(path)
        if bounds:
            results[path] = bounds
    except Exception as e:
        print(f"Error processing {path}: {e}")

with open("assets/frames.json", "w") as f:
    json.dump(results, f, indent=2)
print(f"Generated frames.json for {len(results)} frames")
