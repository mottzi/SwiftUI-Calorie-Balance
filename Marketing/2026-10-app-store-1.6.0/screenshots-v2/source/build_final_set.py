"""Render the approved calendar scene and equally sized, bottom-aligned devices.

Front devices have 60px visible hardware margins on both sides and below.
The original Affinity colors composition retains its intentional right bleed.
Only the complete composition receives a uniform scale, preserving perspective.
"""
from pathlib import Path
from PIL import Image, ImageDraw, ImageFont
import json, hashlib, argparse
import numpy as np

ROOT = Path(__file__).resolve().parents[4]
COLLECTION = ROOT / 'Marketing/2026-10-app-store-1.6.0'
OUT = COLLECTION / 'screenshots-v2'
TODAY = ROOT / 'Marketing/2026-10-today'
SOURCE = COLLECTION / 'captures/progress-theme-02-calendar-en-US.png'
APPROVED = OUT / 'source/approved-first-two-manifest.json'
ORIGINAL = ROOT / 'Marketing/archive/legacy-app-store/iphone-65/exports/iphone-65-02-customize.png'
TITLES = {'en-US': ['Your ', 'progress'], 'de-DE': ['Dein ', 'Fortschritt'],
          'fr-FR': ['Vos ', 'progrès'], 'es-ES': ['Tu ', 'progreso']}
SLUGS = ['01-calorie-balance.png', '02-custom-colors.png', '03-progress.png']
W, H = 1206, 2622
FONT_SIZE, FONT_WEIGHT, HEADING_TOP = 96, 450, 104
ACCENT = '#b1a8ed'
MARGIN = 60


def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def font():
    f = ImageFont.truetype('/System/Library/Fonts/SFNS.ttf', FONT_SIZE)
    f.set_variation_by_axes([100, 96, 400, FONT_WEIGHT])
    return f


def heading_geometry(parts):
    f = font()
    baseline = HEADING_TOP - f.getbbox(''.join(parts), anchor='ls')[1]
    width = sum(f.getlength(s) for s in parts)
    assert width <= W - 100
    return {'width': width, 'baseline': baseline,
            'fragment_baselines': [baseline] * len(parts),
            'fragment_tops': [baseline + f.getbbox(s, anchor='ls')[1] for s in parts]}


def header(canvas, parts):
    d, f, g = ImageDraw.Draw(canvas), font(), heading_geometry(parts)
    x = (W - g['width']) / 2
    for text, color in zip(parts, ['#dedee0', ACCENT]):
        d.text((x, g['baseline']), text, font=f, fill=color, anchor='ls')
        x += d.textlength(text, font=f)
    return g


def frame_progress():
    screen = Image.open(SOURCE).convert('RGBA')
    assert screen.size == (W, H)
    frame_path = TODAY / 'source/iphone-18-pro-silver-frame.png'
    frame = Image.open(frame_path).convert('RGBA')
    mask = Image.new('L', screen.size)
    ImageDraw.Draw(mask).rounded_rectangle((0, 0, W-1, H-1), radius=155, fill=255)
    result = Image.new('RGBA', frame.size)
    result.paste(screen, (72, 69), mask)
    result.alpha_composite(frame)
    path = OUT / 'source/current-progress-theme-02-calendar-framed.png'
    result.save(path)
    return result, path, frame_path


def original_colors():
    """Use the established screen masks and original destination homographies."""
    original = Image.open(ORIGINAL).convert('RGB')
    result = original.copy()
    combined = np.zeros((original.height, original.width), dtype=bool)
    sources = []
    for i, theme in enumerate([1, 2, 4]):
        mask_path = OUT / 'source' / f'legacy-aperture-{i+1}.png'
        mask = Image.open(mask_path).convert('L')
        source = TODAY / 'captures' / f'iphone-18-pro-theme-{theme:02}-dark-midnight-bg-dark-steps-off-sheen-mid-capture.png'
        capture = Image.open(source).convert('RGB')
        quad = [(x+404*i, y) for x, y in [(192,440),(1070,596),(1070,2486),(192,2663)]]
        matrix, values = [], []
        for (x,y), (u,v) in zip(quad, [(0,0),(capture.width,0),(capture.width,capture.height),(0,capture.height)]):
            matrix.extend([[x,y,1,0,0,0,-u*x,-u*y], [0,0,0,x,y,1,-v*x,-v*y]])
            values.extend([u,v])
        coeff = np.linalg.solve(np.asarray(matrix, float), np.asarray(values, float))
        projected = capture.transform(original.size, Image.Transform.PERSPECTIVE, coeff, Image.Resampling.BICUBIC)
        result.paste(projected, (0,0), mask)
        combined |= np.asarray(mask) > 0
        sources.append({'theme': theme, 'capture': str(source.relative_to(ROOT)),
                        'capture_sha256': sha(source), 'plane': quad,
                        'mask': str(mask_path.relative_to(ROOT)), 'mask_sha256': sha(mask_path)})
    assert np.array_equal(np.asarray(result)[~combined], np.asarray(original)[~combined])
    # No title or padding enters the uniformly scaled body. The rightmost
    # display already extends beyond the source canvas in the Affinity export.
    body_box = (82, 424, 1284, 2687)
    return result.crop(body_box), body_box, sources


def front_body(image):
    box = image.getchannel('A').getbbox()
    body = image.crop(box)
    width = W - 2*MARGIN
    height = round(body.height * width / body.width)
    return body.resize((width, height), Image.Resampling.LANCZOS), box


def build():
    assert SOURCE.exists(), SOURCE
    rows = json.loads(APPROVED.read_text())
    for row in rows:
        assert sha(COLLECTION / row['approved_source']) == row['approved_sha256']
    progress, progress_path, frame_path = frame_progress()
    hero_path = TODAY / 'stills/iphone-18-pro-silver-theme-01-dark-midnight-bg-dark-steps-off-sheen-mid-framed.png'
    hero, hero_crop = front_body(Image.open(hero_path).convert('RGBA'))
    progress, progress_crop = front_body(progress)
    assert hero.size == progress.size
    phone_height = hero.height
    top = H - MARGIN - phone_height
    color_source, color_crop, color_sources = original_colors()
    color_scale = phone_height / color_source.height
    colors = color_source.resize((round(color_source.width * color_scale), phone_height), Image.Resampling.LANCZOS)
    manifest, qa = [], []
    for locale, parts in TITLES.items():
        folder = OUT / 'final' / locale
        folder.mkdir(parents=True, exist_ok=True)
        assert all(p.name in SLUGS for p in folder.glob('*.png')), 'Unexpected fourth screenshot'
        for scene, body in [(1,hero),(2,colors),(3,progress)]:
            canvas = Image.new('RGB', (W,H), 'black' if scene == 2 else '#060709')
            canvas.paste(body, (MARGIN,top), body if scene != 2 else None)
            if scene < 3:
                old = next(r for r in rows if r['locale'] == locale and r['scene'] == scene)
                approved = Image.open(COLLECTION / old['approved_source']).convert('RGB')
                canvas.paste(approved.crop((0,0,W,240)), (0,0))
                assert np.array_equal(np.asarray(canvas)[:240], np.asarray(approved)[:240])
                title = old['title']
                heading = {'heading_pixels_preserved_from_approved': True}
            else:
                title = ''.join(parts)
                heading = {'heading_anchor': 'ls', 'heading_geometry': header(canvas,parts), 'heading_accent': ACCENT}
            path = folder / SLUGS[scene-1]
            canvas.save(path, optimize=True)
            bounds = [MARGIN,top,W if scene == 2 else W-MARGIN,H-MARGIN]
            metadata = {'locale': locale, 'scene': scene, 'title': title, 'file': str(path.relative_to(ROOT)),
                        'width': W, 'height': H, 'mode': 'RGB', 'app_ui_locale': 'en-US',
                        'heading_font': 'SF Pro Display variable, weight450, size96', 'heading_top': HEADING_TOP,
                        'device_bounds_exclusive': bounds, 'hardware_height': phone_height,
                        'device_margins': {'left': MARGIN, 'right': 0 if scene == 2 else MARGIN, 'bottom': MARGIN},
                        'device_position': [MARGIN,top], 'device_size_before_canvas_clip': list(body.size),
                        'device_aspect_ratio_preserved': True, **heading}
            if scene == 2:
                metadata.update({'original_hardware': str(ORIGINAL.relative_to(ROOT)), 'original_hardware_sha256': sha(ORIGINAL),
                                 'sources': color_sources, 'source_body_crop': color_crop, 'composition_scale': color_scale,
                                 'hardware_pixels_unchanged_before_uniform_resize': True,
                                 'intentional_right_bleed': True,
                                 'right_bleed_reason': 'Original Affinity export crops the third phone. Keep that edge outside the canvas to avoid an exposed square cut.',
                                 'right_canvas_clip_pixels': MARGIN + colors.width-W})
            else:
                source_paths = [hero_path] if scene == 1 else [SOURCE,frame_path]
                metadata.update({'theme': 1 if scene == 1 else 2,
                                 'source_paths': [str(p.relative_to(ROOT)) for p in source_paths],
                                 'source_sha256': [sha(p) for p in source_paths],
                                 'framed_source_crop': hero_crop if scene == 1 else progress_crop})
                if scene == 3:
                    metadata.update({'capture_ui_order': ['Calendar','Progress','Calories'],
                                     'source_capture_sha256': sha(SOURCE),
                                     'framed_source': str(progress_path.relative_to(ROOT)),
                                     'calendar_candidate_approved': True})
            manifest.append(metadata)
            decoded = Image.open(path)
            decoded.load()
            assert decoded.size == (W,H) and decoded.mode == 'RGB'
            # Pixel bounds include hardware/UI only, below the untouched heading.
            array = np.asarray(decoded)
            background = np.array([0,0,0] if scene == 2 else [6,7,9])
            visible = np.any(array[240:] != background, axis=2)
            ys,xs = np.where(visible)
            measured = [int(xs.min()),int(ys.min()+240),int(xs.max()+1),int(ys.max()+241)]
            assert measured == bounds, (scene,measured,bounds)
            assert np.all(array[H-MARGIN:] == background)
            qa.append({'file': str(path.relative_to(ROOT)), 'size': [W,H], 'mode': 'RGB',
                       'sha256': sha(path), 'measured_visible_body_bounds_exclusive': measured,
                       'margins': metadata['device_margins'], 'hardware_height': phone_height})
        sheet = Image.new('RGB',(1242,874),'#242528')
        for n,name in enumerate(SLUGS):
            preview = Image.open(folder/name)
            preview.thumbnail((402,874))
            sheet.paste(preview,(n*420,0))
        sheet.save(OUT/'review'/f'final-set-{locale}.jpg',quality=96)
    assert len(qa) == 12
    (OUT/'final/manifest.json').write_text(json.dumps(manifest, ensure_ascii=False, indent=2))
    (OUT/'review/final-set-qa.json').write_text(json.dumps({'passed':True,'files':qa,'image_count':12,
        'scene_count':3,'locale_count':4,'no_alpha':True,'all_sizes':[W,H],
        'minimum_margin':MARGIN,'front_phones_identical_scale':True,'all_visible_body_heights_identical':True,
        'all_bottom_margins_equal_left_margin':True,'original_colors_perspective_preserved':True,
        'colors_intentional_right_bleed':True,'colors_right_margin_exception':'0px. Original third phone remains cropped at canvas edge.',
        'first_two_heading_pixels_unchanged':True,'progress_heading_shared_baseline':True,
        'progress_theme':2,'source_capture':str(SOURCE.relative_to(ROOT))},indent=2))
    print(f'PASS: 12 RGB PNGs. Visible body height {phone_height}px, top {top}px, bottom/left 60px. Front right60px; original colors right bleed0px.')


if __name__ == '__main__':
    parser = argparse.ArgumentParser()
    parser.add_argument('--check-heading',action='store_true')
    args = parser.parse_args()
    if args.check_heading:
        print(json.dumps({locale:heading_geometry(parts) for locale,parts in TITLES.items()},indent=2))
    else:
        build()
