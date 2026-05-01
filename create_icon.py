#!/usr/bin/env python3
from PIL import Image, ImageDraw, ImageFont
import json
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

dist_iconset_dir = 'dist/AppIcon.iconset'
asset_catalog_dir = 'Resources/Assets.xcassets'
appiconset_dir = os.path.join(asset_catalog_dir, 'AppIcon.appiconset')

os.makedirs(dist_iconset_dir, exist_ok=True)
os.makedirs(appiconset_dir, exist_ok=True)

master_1024 = image.resize((1024, 1024), Image.Resampling.LANCZOS)
master_1024.save(os.path.join(appiconset_dir, 'ios-marketing-1024.png'))

# Save the classic macOS iconset files used to build the icns.
image.save(os.path.join(dist_iconset_dir, 'icon_512x512.png'))
for size_val in [16, 32, 64, 128, 256]:
    resized = image.resize((size_val, size_val), Image.Resampling.LANCZOS)
    resized.save(os.path.join(dist_iconset_dir, f'icon_{size_val}x{size_val}.png'))

    retina_size = size_val * 2
    resized_retina = image.resize((retina_size, retina_size), Image.Resampling.LANCZOS)
    resized_retina.save(os.path.join(dist_iconset_dir, f'icon_{size_val}x{size_val}@2x.png'))

# Generate a universal Apple appiconset for iPhone, iPad, and macOS.
appicon_specs = [
    ('iphone-notification-20@2x.png', 40),
    ('iphone-notification-20@3x.png', 60),
    ('iphone-settings-29@2x.png', 58),
    ('iphone-settings-29@3x.png', 87),
    ('iphone-spotlight-40@2x.png', 80),
    ('iphone-spotlight-40@3x.png', 120),
    ('iphone-app-60@2x.png', 120),
    ('iphone-app-60@3x.png', 180),
    ('ipad-notification-20.png', 20),
    ('ipad-notification-20@2x.png', 40),
    ('ipad-settings-29.png', 29),
    ('ipad-settings-29@2x.png', 58),
    ('ipad-spotlight-40.png', 40),
    ('ipad-spotlight-40@2x.png', 80),
    ('ipad-app-76.png', 76),
    ('ipad-app-76@2x.png', 152),
    ('ipad-pro-app-83.5@2x.png', 167),
    ('mac-16.png', 16),
    ('mac-16@2x.png', 32),
    ('mac-32.png', 32),
    ('mac-32@2x.png', 64),
    ('mac-128.png', 128),
    ('mac-128@2x.png', 256),
    ('mac-256.png', 256),
    ('mac-256@2x.png', 512),
    ('mac-512.png', 512),
    ('mac-512@2x.png', 1024),
]

for filename, pixel_size in appicon_specs:
    resized = master_1024.resize((pixel_size, pixel_size), Image.Resampling.LANCZOS)
    resized.save(os.path.join(appiconset_dir, filename))

contents = {
    'images': [
        {'idiom': 'iphone', 'size': '20x20', 'scale': '2x', 'filename': 'iphone-notification-20@2x.png'},
        {'idiom': 'iphone', 'size': '20x20', 'scale': '3x', 'filename': 'iphone-notification-20@3x.png'},
        {'idiom': 'iphone', 'size': '29x29', 'scale': '2x', 'filename': 'iphone-settings-29@2x.png'},
        {'idiom': 'iphone', 'size': '29x29', 'scale': '3x', 'filename': 'iphone-settings-29@3x.png'},
        {'idiom': 'iphone', 'size': '40x40', 'scale': '2x', 'filename': 'iphone-spotlight-40@2x.png'},
        {'idiom': 'iphone', 'size': '40x40', 'scale': '3x', 'filename': 'iphone-spotlight-40@3x.png'},
        {'idiom': 'iphone', 'size': '60x60', 'scale': '2x', 'filename': 'iphone-app-60@2x.png'},
        {'idiom': 'iphone', 'size': '60x60', 'scale': '3x', 'filename': 'iphone-app-60@3x.png'},
        {'idiom': 'ipad', 'size': '20x20', 'scale': '1x', 'filename': 'ipad-notification-20.png'},
        {'idiom': 'ipad', 'size': '20x20', 'scale': '2x', 'filename': 'ipad-notification-20@2x.png'},
        {'idiom': 'ipad', 'size': '29x29', 'scale': '1x', 'filename': 'ipad-settings-29.png'},
        {'idiom': 'ipad', 'size': '29x29', 'scale': '2x', 'filename': 'ipad-settings-29@2x.png'},
        {'idiom': 'ipad', 'size': '40x40', 'scale': '1x', 'filename': 'ipad-spotlight-40.png'},
        {'idiom': 'ipad', 'size': '40x40', 'scale': '2x', 'filename': 'ipad-spotlight-40@2x.png'},
        {'idiom': 'ipad', 'size': '76x76', 'scale': '1x', 'filename': 'ipad-app-76.png'},
        {'idiom': 'ipad', 'size': '76x76', 'scale': '2x', 'filename': 'ipad-app-76@2x.png'},
        {'idiom': 'ipad', 'size': '83.5x83.5', 'scale': '2x', 'filename': 'ipad-pro-app-83.5@2x.png'},
        {'idiom': 'ios-marketing', 'size': '1024x1024', 'scale': '1x', 'filename': 'ios-marketing-1024.png'},
        {'idiom': 'mac', 'size': '16x16', 'scale': '1x', 'filename': 'mac-16.png'},
        {'idiom': 'mac', 'size': '16x16', 'scale': '2x', 'filename': 'mac-16@2x.png'},
        {'idiom': 'mac', 'size': '32x32', 'scale': '1x', 'filename': 'mac-32.png'},
        {'idiom': 'mac', 'size': '32x32', 'scale': '2x', 'filename': 'mac-32@2x.png'},
        {'idiom': 'mac', 'size': '128x128', 'scale': '1x', 'filename': 'mac-128.png'},
        {'idiom': 'mac', 'size': '128x128', 'scale': '2x', 'filename': 'mac-128@2x.png'},
        {'idiom': 'mac', 'size': '256x256', 'scale': '1x', 'filename': 'mac-256.png'},
        {'idiom': 'mac', 'size': '256x256', 'scale': '2x', 'filename': 'mac-256@2x.png'},
        {'idiom': 'mac', 'size': '512x512', 'scale': '1x', 'filename': 'mac-512.png'},
        {'idiom': 'mac', 'size': '512x512', 'scale': '2x', 'filename': 'mac-512@2x.png'},
    ],
    'info': {'version': 1, 'author': 'xcode'}
}

with open(os.path.join(asset_catalog_dir, 'Contents.json'), 'w', encoding='utf-8') as fh:
    json.dump({'info': {'version': 1, 'author': 'xcode'}}, fh, indent=2)
    fh.write('\n')

with open(os.path.join(appiconset_dir, 'Contents.json'), 'w', encoding='utf-8') as fh:
    json.dump(contents, fh, indent=2)
    fh.write('\n')

print('Icon images and asset catalog created successfully')
