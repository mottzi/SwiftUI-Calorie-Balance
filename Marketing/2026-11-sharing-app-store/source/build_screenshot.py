"""Place a Sharing capture in the existing App Store hardware and typography."""
from pathlib import Path
import argparse
import hashlib
import json
from PIL import Image, ImageDraw, ImageFont, ImageOps

HERE = Path(__file__).resolve().parents[1]
LIBRARY = HERE.parent
FRAME = LIBRARY / '2026-10-today/source/iphone-18-pro-silver-frame.png'
PREVIOUS = LIBRARY / '2026-10-app-store-1.6.0/screenshots-v2/final/en-US'
SIZE = (1206, 2622)


def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def build(capture):
    source = Image.open(capture).convert('RGBA')
    screen = ImageOps.contain(source, SIZE, Image.Resampling.LANCZOS)
    fitted = Image.new('RGBA', SIZE, 'black')
    fitted.alpha_composite(screen, ((SIZE[0] - screen.width) // 2,
                                    (SIZE[1] - screen.height) // 2))
    mask = Image.new('L', SIZE)
    ImageDraw.Draw(mask).rounded_rectangle((0, 0, 1205, 2621), radius=155, fill=255)
    frame = Image.open(FRAME).convert('RGBA')
    framed = Image.new('RGBA', frame.size)
    framed.paste(fitted, (72, 69), mask)
    framed.alpha_composite(frame)
    framed.save(HERE / 'source/sharing-overview-framed.png')
    crop = framed.getchannel('A').getbbox()
    body = framed.crop(crop)
    body = body.resize((1086, round(body.height * 1086 / body.width)), Image.Resampling.LANCZOS)
    position = (60, SIZE[1] - 60 - body.height)
    assert position == (60, 323) and body.size == (1086, 2239)
    poster = Image.new('RGB', SIZE, '#060709')
    poster.paste(body, position, body)
    font = ImageFont.truetype('/System/Library/Fonts/SFNS.ttf', 96)
    font.set_variation_by_axes([100, 96, 400, 450])
    parts = ['Share with ', 'friends']
    title = ''.join(parts)
    baseline = 104 - font.getbbox(title, anchor='ls')[1]
    width = sum(font.getlength(s) for s in parts)
    x = (SIZE[0] - width) / 2
    draw = ImageDraw.Draw(poster)
    for part, color in zip(parts, ['#dedee0', '#8cbced']):
        draw.text((x, baseline), part, font=font, fill=color, anchor='ls')
        x += draw.textlength(part, font=font)
    output = HERE / 'exports/en-US/04-sharing-overview.png'
    output.parent.mkdir(parents=True, exist_ok=True)
    poster.save(output, optimize=True)
    preview = poster.copy()
    preview.thumbnail((402, 874), Image.Resampling.LANCZOS)
    preview.save(HERE / 'review/04-sharing-overview-preview.png')
    sheet = Image.new('RGB', (1662, 874), '#242528')
    for i, path in enumerate([PREVIOUS / '01-calorie-balance.png',
                              PREVIOUS / '02-custom-colors.png',
                              PREVIOUS / '03-progress.png', output]):
        thumb = Image.open(path).convert('RGB')
        thumb.thumbnail((402, 874), Image.Resampling.LANCZOS)
        sheet.paste(thumb, (i * 420, 0))
    sheet.save(HERE / 'review/four-screenshot-set.jpg', quality=95)
    metadata = {
        'date': '2026-11-07', 'status': 'finished', 'published': False,
        'content': 'Sharing overview with synthetic Alice under Me and five people: Lea, Jonas, Maya, Noah, and Emma. Includes calorie balance rings, streaks, and Invite. Emma uses standard theme 4, blue and gold.',
        'composition_provenance': str(HERE / 'source/composition-provenance.json'),
        'is_single_unmodified_screenshot': False,
        'title': title, 'position': 4, 'locale': 'en-US',
        'file': str(output), 'size': list(SIZE), 'mode': 'RGB',
        'capture': str(capture), 'capture_size': list(source.size),
        'capture_sha256': sha(capture), 'frame': str(FRAME), 'frame_sha256': sha(FRAME),
        'device_bounds_exclusive': [60, 323, 1146, 2562],
        'heading_font': 'SF Pro Display variable, weight450, size96',
        'heading_top': 104, 'heading_baseline': baseline,
        'operation': 'Uniformly fit the supplied screen capture inside the existing silver frame. Match the approved front-phone size, position, margins, and heading typography.',
        'sha256': sha(output),
    }
    (HERE / 'manifest.json').write_text(json.dumps(metadata, indent=2) + '\n')
    reopened = Image.open(output)
    assert reopened.size == SIZE and reopened.mode == 'RGB'
    print(output)


if __name__ == '__main__':
    parser = argparse.ArgumentParser()
    parser.add_argument('capture', type=Path)
    build(parser.parse_args().capture.resolve())
