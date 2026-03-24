#!/usr/bin/env python3
from PIL import Image, ImageDraw, ImageFont
import os

# Create a 512x512 blue chat bubble icon with "DayChat" text
size = 512
image = Image.new('RGBA', (size, size), (0, 0, 0, 0))
draw = ImageDraw.Draw(image)

# Draw enhanced shadow/depth layer for 3D effect (more prominent drop shadow)
shadow_color = (0, 0, 0, 80)  # Darker shadow
x0_shadow, y0_shadow = 85, 125
x1_shadow, y1_shadow = 437, 385
draw.rounded_rectangle([x0_shadow + 12, y0_shadow + 12, x1_shadow + 12, y1_shadow + 12], radius=35, fill=shadow_color)
# Add second shadow layer for more depth
shadow_color_light = (0, 0, 0, 40)
draw.rounded_rectangle([x0_shadow + 6, y0_shadow + 6, x1_shadow + 6, y1_shadow + 6], radius=35, fill=shadow_color_light)

# Draw main chat bubble body - more oval shaped with less rounding
bubble_color_main = (52, 152, 219, 255)  # Bright blue
x0, y0 = 80, 120
x1, y1 = 432, 380
radius = 35  # Reduced radius for more oval shape

# Draw main rounded rectangle body (more oval-like)
draw.rounded_rectangle([x0, y0, x1, y1], radius=radius, fill=bubble_color_main)

# Draw triangle for chat bubble tail with deeper shadow
tail_points = [(145, y1), (205, y1 + 65), (225, y1)]
draw.polygon(tail_points, fill=bubble_color_main)

# Draw enhanced shadow for tail
tail_shadow_dark = [(151, y1 + 12), (211, y1 + 77), (231, y1 + 12)]
draw.polygon(tail_shadow_dark, fill=shadow_color)
tail_shadow_light = [(148, y1 + 6), (208, y1 + 71), (228, y1 + 6)]
draw.polygon(tail_shadow_light, fill=shadow_color_light)

# Draw "DayChat" text in white with shadow for depth
text = "DayChat"
try:
    font_size = 80
    # Try Arial Rounded MT Bold first, fall back to Helvetica
    try:
        font = ImageFont.truetype("/System/Library/Fonts/Arial Rounded MT Bold.ttf", font_size)
    except:
        font = ImageFont.truetype("/System/Library/Fonts/Arial.ttf", font_size)
except:
    try:
        font = ImageFont.truetype("/System/Library/Fonts/Helvetica.ttc", font_size)
    except:
        font = ImageFont.load_default()

# Draw text shadow with more depth
text_shadow_color = (0, 0, 0, 60)
bbox = draw.textbbox((0, 0), text, font=font)
text_width = bbox[2] - bbox[0]
text_height = bbox[3] - bbox[1]
text_x = (size - text_width) // 2
text_y = (size - text_height) // 2 + 20

draw.text((text_x + 5, text_y + 5), text, fill=text_shadow_color, font=font)

# Draw main text
text_color = (255, 255, 255, 255)  # White
draw.text((text_x, text_y), text, fill=text_color, font=font)

# Save the 512x512 image
os.makedirs('dist/AppIcon.iconset', exist_ok=True)
image.save('dist/AppIcon.iconset/icon_512x512.png')

# Create smaller versions for the icon set
for size_val in [16, 32, 64, 128, 256]:
    resized = image.resize((size_val, size_val), Image.Resampling.LANCZOS)
    resized.save(f'dist/AppIcon.iconset/icon_{size_val}x{size_val}.png')
    
    # Also create @2x versions for retina displays
    retina_size = size_val * 2
    resized_retina = image.resize((retina_size, retina_size), Image.Resampling.LANCZOS)
    resized_retina.save(f'dist/AppIcon.iconset/icon_{size_val}x{size_val}@2x.png')

print("Icon images created successfully")
