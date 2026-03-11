"""
App Analyzer - App Icon Generator (1024x1024)
Security-themed: shield + checkmark + magnifying glass + scan lines
Deep navy-to-purple gradient background, modern & clean
"""

from PIL import Image, ImageDraw, ImageChops
import math

SIZE = 1024
CENTER = SIZE // 2
CORNER = 224


def lerp_color(c1, c2, t):
    return tuple(int(c1[i] + (c2[i] - c1[i]) * t) for i in range(len(c1)))


def min_alpha(img, mask):
    """Intersect image alpha with a grayscale mask."""
    r, g, b, a = img.split()
    a = ImageChops.darker(a, mask)
    img.putalpha(a)
    return img


# ============================================================
# 1. ROUNDED RECT BACKGROUND WITH GRADIENT
# ============================================================
img = Image.new("RGBA", (SIZE, SIZE), (0, 0, 0, 0))

bg = Image.new("RGBA", (SIZE, SIZE), (0, 0, 0, 0))
bg_draw = ImageDraw.Draw(bg)

c_top = (12, 18, 55)
c_mid = (25, 35, 90)
c_bot = (65, 25, 110)

for y in range(SIZE):
    t = y / SIZE
    if t < 0.5:
        c = lerp_color(c_top, c_mid, t * 2)
    else:
        c = lerp_color(c_mid, c_bot, (t - 0.5) * 2)
    bg_draw.line([(0, y), (SIZE, y)], fill=(*c, 255))

rr_mask = Image.new("L", (SIZE, SIZE), 0)
ImageDraw.Draw(rr_mask).rounded_rectangle([0, 0, SIZE, SIZE], radius=CORNER, fill=255)
bg.putalpha(rr_mask)
img = Image.alpha_composite(img, bg)

# ============================================================
# 2. RADIAL GLOW (subtle center highlight)
# ============================================================
glow = Image.new("RGBA", (SIZE, SIZE), (0, 0, 0, 0))
glow_draw = ImageDraw.Draw(glow)
for r in range(380, 0, -2):
    alpha = int(16 * (1 - r / 380))
    glow_draw.ellipse(
        [CENTER - r, CENTER - r - 50, CENTER + r, CENTER + r - 50],
        fill=(80, 120, 255, alpha),
    )
glow = min_alpha(glow, rr_mask)
img = Image.alpha_composite(img, glow)

# ============================================================
# 3. SHIELD SHAPE
# ============================================================
shield_cx = CENTER
shield_cy = CENTER + 15
shield_w = 460
shield_h = 540

s_top = shield_cy - shield_h * 0.48
s_bot = shield_cy + shield_h * 0.50

shield_points = [
    (shield_cx, s_top),
    (shield_cx + shield_w * 0.47, s_top + shield_h * 0.02),
    (shield_cx + shield_w * 0.50, s_top + shield_h * 0.15),
    (shield_cx + shield_w * 0.46, s_top + shield_h * 0.45),
    (shield_cx + shield_w * 0.28, s_top + shield_h * 0.72),
    (shield_cx, s_bot),
    (shield_cx - shield_w * 0.28, s_top + shield_h * 0.72),
    (shield_cx - shield_w * 0.46, s_top + shield_h * 0.45),
    (shield_cx - shield_w * 0.50, s_top + shield_h * 0.15),
    (shield_cx - shield_w * 0.47, s_top + shield_h * 0.02),
]

# Shield outer glow
for offset in range(22, 0, -1):
    alpha = int(5 * (22 - offset))
    scaled = [(shield_cx + (px - shield_cx) * (1 + offset * 0.005),
               shield_cy + (py - shield_cy) * (1 + offset * 0.005))
              for px, py in shield_points]
    g = Image.new("RGBA", (SIZE, SIZE), (0, 0, 0, 0))
    ImageDraw.Draw(g).polygon(scaled, fill=(60, 140, 255, alpha))
    img = Image.alpha_composite(img, g)

# Shield gradient fill
shield_mask = Image.new("L", (SIZE, SIZE), 0)
ImageDraw.Draw(shield_mask).polygon(shield_points, fill=255)

shield_grad = Image.new("RGBA", (SIZE, SIZE), (0, 0, 0, 0))
sg_draw = ImageDraw.Draw(shield_grad)

sg_top = (35, 120, 235)
sg_mid = (45, 95, 205)
sg_bot = (70, 55, 175)

for y in range(SIZE):
    t = y / SIZE
    if t < 0.5:
        c = lerp_color(sg_top, sg_mid, t * 2)
    else:
        c = lerp_color(sg_mid, sg_bot, (t - 0.5) * 2)
    sg_draw.line([(0, y), (SIZE, y)], fill=(*c, 215))

shield_grad = min_alpha(shield_grad, shield_mask)
img = Image.alpha_composite(img, shield_grad)

# Shield border
draw = ImageDraw.Draw(img)
draw.polygon(shield_points, outline=(110, 185, 255, 200), width=4)

# Inner shield outline
inner_scale = 0.82
inner_pts = [(shield_cx + (px - shield_cx) * inner_scale,
              shield_cy + (py - shield_cy) * inner_scale)
             for px, py in shield_points]
draw.polygon(inner_pts, outline=(110, 185, 255, 70), width=2)

# ============================================================
# 4. SCAN LINES (analysis motif)
# ============================================================
scan_overlay = Image.new("RGBA", (SIZE, SIZE), (0, 0, 0, 0))
scan_draw = ImageDraw.Draw(scan_overlay)

scan_top = int(shield_cy - shield_h * 0.36)
scan_bot = int(shield_cy + shield_h * 0.32)

for y in range(scan_top, scan_bot, 16):
    t = (y - scan_top) / max(1, scan_bot - scan_top)
    alpha = int(18 + 14 * math.sin(t * math.pi * 3))
    scan_draw.line([(0, y), (SIZE, y)], fill=(140, 210, 255, alpha), width=1)

scan_mask = Image.new("L", (SIZE, SIZE), 0)
ImageDraw.Draw(scan_mask).polygon(inner_pts, fill=255)
scan_overlay = min_alpha(scan_overlay, scan_mask)
img = Image.alpha_composite(img, scan_overlay)
draw = ImageDraw.Draw(img)

# ============================================================
# 5. CHECKMARK (security verified)
# ============================================================
check_cy = shield_cy + 15
check_start = (shield_cx - 100, check_cy + 10)
check_mid = (shield_cx - 25, check_cy + 85)
check_end = (shield_cx + 120, check_cy - 75)

# Glow behind checkmark
for w in range(30, 0, -1):
    alpha = int(6 * (30 - w))
    draw.line([check_start, check_mid], fill=(80, 255, 170, alpha), width=w + 22)
    draw.line([check_mid, check_end], fill=(80, 255, 170, alpha), width=w + 22)

# Outer stroke
draw.line([check_start, check_mid], fill=(200, 255, 230, 255), width=24)
draw.line([check_mid, check_end], fill=(200, 255, 230, 255), width=24)

# Bright core
draw.line([check_start, check_mid], fill=(255, 255, 255, 255), width=14)
draw.line([check_mid, check_end], fill=(255, 255, 255, 255), width=14)

# Round joints and caps
for pt in [check_start, check_mid, check_end]:
    draw.ellipse([pt[0] - 7, pt[1] - 7, pt[0] + 7, pt[1] + 7],
                 fill=(255, 255, 255, 255))

# ============================================================
# 6. MAGNIFYING GLASS (bottom-right)
# ============================================================
mg_cx = shield_cx + 165
mg_cy = shield_cy + 150
mg_r = 50

# Glow
for r in range(32, 0, -1):
    alpha = int(4 * (32 - r))
    draw.ellipse([mg_cx - mg_r - r, mg_cy - mg_r - r,
                  mg_cx + mg_r + r, mg_cy + mg_r + r],
                 fill=(70, 170, 255, alpha))

# Glass fill
glass = Image.new("RGBA", (SIZE, SIZE), (0, 0, 0, 0))
ImageDraw.Draw(glass).ellipse(
    [mg_cx - mg_r + 4, mg_cy - mg_r + 4, mg_cx + mg_r - 4, mg_cy + mg_r - 4],
    fill=(35, 90, 190, 55))
img = Image.alpha_composite(img, glass)
draw = ImageDraw.Draw(img)

# Glass ring
draw.ellipse([mg_cx - mg_r, mg_cy - mg_r, mg_cx + mg_r, mg_cy + mg_r],
             outline=(255, 255, 255, 230), width=7)

# Handle
hx1, hy1 = mg_cx + int(mg_r * 0.65), mg_cy + int(mg_r * 0.65)
hx2, hy2 = mg_cx + mg_r + 36, mg_cy + mg_r + 36
draw.line([(hx1, hy1), (hx2, hy2)], fill=(255, 255, 255, 220), width=9)
draw.ellipse([hx2 - 5, hy2 - 5, hx2 + 5, hy2 + 5], fill=(255, 255, 255, 220))

# Shine
draw.arc([mg_cx - mg_r + 14, mg_cy - mg_r + 12, mg_cx - 8, mg_cy - 8],
         200, 310, fill=(255, 255, 255, 90), width=3)

# ============================================================
# 7. SPARKLE DOTS (polish)
# ============================================================
sparkles = [
    (185, 205, 5), (835, 185, 4), (165, 755, 3),
    (845, 785, 4), (285, 155, 3), (755, 235, 3),
    (225, 835, 3), (785, 850, 3),
]
for sx, sy, sr in sparkles:
    for r in range(sr + 8, 0, -1):
        alpha = int(12 * (sr + 8 - r))
        draw.ellipse([sx - r, sy - r, sx + r, sy + r],
                     fill=(170, 215, 255, min(alpha, 70)))
    draw.ellipse([sx - sr, sy - sr, sx + sr, sy + sr],
                 fill=(215, 235, 255, 190))

# ============================================================
# FINAL: Re-apply rounded mask and save
# ============================================================
final = Image.new("RGBA", (SIZE, SIZE), (0, 0, 0, 0))
img = min_alpha(img, rr_mask)
final = Image.alpha_composite(final, img)

output = "/home/user/App-Organizer/AppAnalyzer/AppAnalyzer/Assets.xcassets/AppIcon.appiconset/AppIcon.png"
final.save(output, "PNG")
print(f"Icon saved: {output}")
print(f"Size: {final.size[0]}x{final.size[1]}")
