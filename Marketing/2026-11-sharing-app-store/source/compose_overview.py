"""Assemble the native synthetic profile and existing sample-person rows.

This is a marketing composition of two Simulator B captures, not a single
unmodified screenshot. No real connection or account appears in the export.
"""
from pathlib import Path
import hashlib
import json
import shutil
from PIL import Image, ImageDraw, ImageFont

ROOT = Path(__file__).resolve().parents[1]
OLD_ROWS = Path('/Users/berken/Development/Swift/Count.kcal-Marketing/redesign/assets/sharing-people-crop.png')
ROWS = ROOT / 'captures/sharing-sample-people-2026-11-06.png'
QA = ROOT / 'captures/sharing-overview-qa-native.png'
if not ROWS.exists():
    shutil.copy2(OLD_ROWS, ROWS)
native = Image.open(QA).convert('RGB')
people = Image.open(ROWS).convert('RGB')
assert native.size == (1170, 2532) and people.size == (1090, 1035)

# Extend the editable marketing composition with one synthetic row. Reuse
# the native row geometry, ring paths, flame, chevron, and caption treatment.
# Map standard theme 8 to standard theme 4 while keeping neutral pixels fixed.
row = people.crop((0, 516, 1090, 774))
source_colors = [[155, 244, 255], [114, 199, 255], [221, 95, 255]]
target_colors = [[91, 244, 255], [158, 181, 255], [219, 93, 255]]
augmented = [list(map(float, values)) + [float(i == j) for j in range(3)]
             for i, values in enumerate(source_colors)]
for column in range(3):
    pivot = augmented[column][column]
    augmented[column] = [value / pivot for value in augmented[column]]
    for i in range(3):
        if i != column:
            factor = augmented[i][column]
            augmented[i] = [a - factor*b for a, b in zip(augmented[i], augmented[column])]
inverse = [values[3:] for values in augmented]
transform = [[sum(target_colors[i][k] * inverse[k][j] for k in range(3))
              for j in range(3)] for i in range(3)]
def map_pixel(pixel):
    if max(pixel) - min(pixel) <= 5:
        return pixel
    return tuple(max(0, min(255, round(sum(channel * coefficient
                 for channel, coefficient in zip(pixel, coefficients)))))
                 for coefficients in transform)
row.putdata([map_pixel(pixel) for pixel in row.getdata()])
draw = ImageDraw.Draw(row)
background = (28, 28, 30)

def text_font(size, weight):
    font = ImageFont.truetype('/System/Library/Fonts/SFNS.ttf', size)
    font.set_variation_by_axes([100, 17, 400, weight])
    return font

draw.rectangle((270, 19, 700, 84), fill=background)
draw.text((276, 72), 'Emma', font=text_font(51, 600), fill=(129, 196, 255), anchor='ls')
draw.rectangle((270, 90, 840, 147), fill=background)
body = text_font(51, 400)
start = 276
digit_width = max(body.getlength(digit) for digit in '0123456789')
for digit in '320':
    draw.text((start + (digit_width-body.getlength(digit))/2, 138), digit,
              font=body, fill='white', anchor='ls')
    start += digit_width
draw.text((start, 138), ' kcal', font=body, fill='white', anchor='ls')
start += draw.textlength(' kcal', font=body)
draw.text((start, 138), ' deficit', font=body, fill=(142, 142, 147), anchor='ls')
draw.rectangle((811, 76, 899, 151), fill=background)
draw.text((883, 136), '6', font=text_font(51, 600), fill='white', anchor='rs')
# A last row has no divider; the group mask supplies its rounded bottom edge.
draw.rectangle((275, 234, 1036, 240), fill=background)
row.save(ROOT / 'captures/sharing-emma-theme-04-composed.png')
expanded = Image.new('RGB', (1090, 1293), 'black')
ImageDraw.Draw(expanded).rectangle((8, 0, 1081, 1271), fill=background)
expanded.paste(people, (0, 0))
# Fill only the former black corner cutouts. Keep Noah's entire ring intact.
for y in range(940, 1032):
    for x in range(8, 1082):
        if all(value <= bg for value, bg in zip(expanded.getpixel((x, y)), background)):
            expanded.putpixel((x, y), background)
expanded.paste(row, (0, 1032))
# Restore the standard divider between Noah and Emma.
ImageDraw.Draw(expanded).rectangle((276, 1011, 1033, 1013), fill=(57, 57, 59))
people = expanded
result = Image.new('RGB', native.size, 'black')
result.paste(native.crop((0, 0, 1170, 893)), (0, 0))
# The original crop starts at the second list row. Round its newly exposed
# top corners to match the app's normal first-row group boundary.
mask = Image.new('L', people.size, 0)
ImageDraw.Draw(mask).rounded_rectangle((8, 0, 1081, 1271), radius=98, fill=255)
result.paste(people, (40, 893), mask)
# Preserve the native Invite button; move it below the five-row group.
result.paste(native.crop((400, 1740, 770, 1940)), (400, 2258))
output = ROOT / 'captures/sharing-overview-composed.png'
result.save(output, optimize=True)
provenance = {
    'description': 'Native Sharing overview header, synthetic Alice profile and Invite control from Simulator B on 7 November; four synthetic sample rows from the prepared 6 November capture plus Emma, an added marketing row using standard theme 4. The rows replace the fixture empty state. Real account and connection rows are excluded.',
    'is_single_unmodified_screenshot': False,
    'sources': [{'path': str(p), 'sha256': hashlib.sha256(p.read_bytes()).hexdigest()} for p in [QA, ROWS]],
    'native_header_crop': [0, 0, 1170, 893],
    'sample_rows_position': [40, 893],
    'invite_crop': [400, 1740, 770, 1940],
    'invite_position': [400, 2258],
    'me': 'Alice',
    'people': ['Lea', 'Jonas', 'Maya', 'Noah', 'Emma'],
    'added_row': {'name': 'Emma', 'theme_number': 4, 'burned_srgb': '#5B9EDB', 'consumed_srgb': '#F4B55D', 'balance': '320 kcal deficit', 'streak_days': 6, 'source': 'Native Maya row geometry with theme mapping and SF Pro Text labels; composed marketing data, not a new app capture.'},
    'all_people_synthetic': True,
    'values_and_text_redrawn': 'Only the added Emma row name, balance and streak count. Existing rows preserved.',
    'output': str(output),
}
(ROOT / 'source/composition-provenance.json').write_text(json.dumps(provenance, indent=2) + '\n')
print(output)
