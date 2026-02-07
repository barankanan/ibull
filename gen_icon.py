from PIL import Image, ImageDraw

size = 1024
bg = (255, 255, 255, 255)
color = (97, 11, 239, 255)  # #610BEF

img = Image.new('RGBA', (size, size), bg)
draw = ImageDraw.Draw(img)

circle_radius = 220
circle_center = (size // 2, size // 2 - 160)
draw.ellipse([
    circle_center[0] - circle_radius, circle_center[1] - circle_radius,
    circle_center[0] + circle_radius, circle_center[1] + circle_radius
], outline=color, width=70)

stem_top = (circle_center[0], circle_center[1] + circle_radius - 10)
stem_bottom = (circle_center[0], stem_top[1] + 340)
draw.line([stem_top, stem_bottom], fill=color, width=70)

arm_start = (circle_center[0], stem_top[1] + 160)
arm_end = (arm_start[0] + 190, arm_start[1] + 160)
arm_width = 70
draw.polygon([
    (arm_start[0] - arm_width / 2, arm_start[1] - arm_width / 2),
    (arm_start[0] + arm_width / 2, arm_start[1] + arm_width / 2),
    (arm_end[0] + arm_width / 2, arm_end[1] + arm_width / 2),
    (arm_end[0] - arm_width / 2, arm_end[1] - arm_width / 2),
], fill=color)

img.save('/Users/barankananogullari/Desktop/ibul2026/ibul_app/assets/icons/app_icon.png')
