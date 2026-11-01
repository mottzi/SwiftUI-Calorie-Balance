"""Build review-only customization and Home Screen widget candidates.

Native capture pixels only pass through the established Apple frame,
rounded-screen mask and uniform device resize. Active finals stay untouched.
"""
from pathlib import Path
from PIL import Image, ImageDraw
import argparse
import hashlib
import json
import numpy as np
from build_final_set import font, heading_geometry, front_body, sha, ROOT, OUT, TODAY, W, H

DESTINATION = OUT / 'review/new-scenes-2026-10-22'
CAPTURES = OUT.parent / 'captures'
FRAME = TODAY / 'source/iphone-18-pro-silver-frame.png'
TITLES = {
    'en-US': [['Make it ', 'yours'], ['At a ', 'glance']],
    'de-DE': [['Ganz dein ', 'Stil'], ['Auf einen ', 'Blick']],
    'fr-FR': [['À votre ', 'image'], ["En un coup d'", 'œil']],
    'es-ES': [['A tu ', 'gusto'], ['De un ', 'vistazo']],
}
SCENES = [('01-visual-customization.png', '#b1a8ed'),
          ('02-home-screen-widgets.png', '#86b6e7')]
NATIVE_SETTINGS_NOTES = [
    'The Body weight row is partially clipped beneath the native toolbar.',
    'All nine theme samples are visible; the native viewport hides the footer laurels.',
    'These native viewport details are preserved without retouching.',
]
BACKGROUND = '#060709'
BOUNDS = [60, 323, 1146, 2562]


def final_hashes():
    return {str(p.relative_to(ROOT)): sha(p) for p in sorted((OUT/'final').rglob('*')) if p.is_file()}


def framed_capture(source):
    screen = Image.open(source).convert('RGBA')
    assert screen.size == (W, H), f'Native capture must be {W}x{H}: {source}'
    frame = Image.open(FRAME).convert('RGBA')
    mask = Image.new('L', screen.size)
    ImageDraw.Draw(mask).rounded_rectangle((0, 0, W-1, H-1), radius=155, fill=255)
    framed = Image.new('RGBA', frame.size)
    framed.paste(screen, (72, 69), mask)
    # Prove the mask paste preserved the central native screenshot pixels.
    assert np.array_equal(np.asarray(framed)[224:2536, 227:1123], np.asarray(screen)[155:2467,155:1051])
    framed.alpha_composite(frame)
    return framed


def heading(canvas, parts, accent):
    draw, f, geometry = ImageDraw.Draw(canvas), font(), heading_geometry(parts)
    x = (W-geometry['width'])/2
    for part, color in zip(parts, ['#dedee0', accent]):
        draw.text((x,geometry['baseline']), part, font=f, fill=color, anchor='ls')
        x += draw.textlength(part,font=f)
    return geometry


def render(customization, widgets, widgets_only=False):
    before = final_hashes()
    approved_settings = {str(p.relative_to(ROOT)): sha(p) for p in DESTINATION.glob('*/01-visual-customization.png')}
    if widgets_only:
        assert len(approved_settings) == 5, 'Four approved Settings PNGs and their framed source must exist'
        assert widgets is not None, 'Widget capture required'
    DESTINATION.mkdir(parents=True,exist_ok=True)
    (DESTINATION/'source').mkdir(exist_ok=True)
    sources = [customization.resolve()] + ([widgets.resolve()] if widgets else [])
    source_hashes = {str(p.relative_to(ROOT)): sha(p) for p in sources}
    bodies, source_crops = [], []
    for n, source in enumerate(sources):
        assert source.exists(), source
        framed = framed_capture(source)
        if not widgets_only or n != 0:
            framed.save(DESTINATION/'source'/SCENES[n][0])
        body, crop = front_body(framed)
        assert body.size == (1086,2239)
        bodies.append(body)
        source_crops.append(crop)
    manifest, files = [], []
    for locale, titles in TITLES.items():
        folder = DESTINATION/locale
        folder.mkdir(exist_ok=True)
        for n, ((name,accent),body,parts,source) in enumerate(zip(SCENES,bodies,titles,sources),start=1):
            canvas = Image.new('RGB',(W,H),BACKGROUND)
            canvas.paste(body,(60,323),body)
            geometry = heading(canvas,parts,accent)
            path = folder/name
            if widgets_only and n == 1:
                assert np.array_equal(np.asarray(canvas), np.asarray(Image.open(path).convert('RGB'))), 'Approved Settings pixels differ'
            else:
                canvas.save(path,optimize=True)
            decoded = Image.open(path)
            decoded.load()
            assert decoded.size == (W,H) and decoded.mode == 'RGB'
            pixels = np.asarray(decoded)
            visible = np.any(pixels[240:] != [6,7,9],axis=2)
            ys,xs = np.where(visible)
            bounds = [int(xs.min()),int(ys.min()+240),int(xs.max()+1),int(ys.max()+241)]
            assert bounds == BOUNDS,(path,bounds)
            assert np.all(pixels[2562:] == [6,7,9])
            row = {'locale':locale,'review_only':True,'scene':n,'title':''.join(parts),
                   'file':str(path.relative_to(ROOT)),'width':W,'height':H,'mode':'RGB',
                   'source_capture':str(source.relative_to(ROOT)),'source_capture_sha256':sha(source),
                   'frame':str(FRAME.relative_to(ROOT)),'frame_sha256':sha(FRAME),
                   'source_frame_crop':source_crops[n-1],'device_size':[1086,2239],
                   'device_bounds_exclusive':bounds,'device_margins':{'left':60,'right':60,'bottom':60},
                   'heading_font':'SF Pro Display variable, weight450, size96','heading_top':104,
                   'heading_anchor':'ls','heading_geometry':geometry,'heading_accent':accent,
                   'native_ui_retouching':False,'app_ui_locale':'en-US'}
            if n == 1:
                row['native_viewport_notes'] = NATIVE_SETTINGS_NOTES
            else:
                row['native_widgets'] = [
                    {'content':'Calorie bar','family':'systemMedium','position':'top'},
                    {'content':'Nutrients','family':'systemMedium','position':'second'},
                    {'content':'Calorie ring','family':'systemSmall','position':'bottom left'},
                ]
                row['native_home_screen_icons'] = ['Health','Fitness','Count.kcal','Watch']
                row['native_home_screen_dock_apps'] = ['Safari','Messages','Maps','Photos']
            manifest.append(row)
            files.append({'file':row['file'],'sha256':sha(path),'size':[W,H],'mode':'RGB',
                          'measured_device_bounds_exclusive':bounds,'heading_width':geometry['width'],
                          'heading_fragment_baselines':geometry['fragment_baselines']})
        if len(sources) < 2:
            continue
        sheet = Image.new('RGB',(822,874),'#242528')
        full = Image.new('RGB',(2430,2622),'#242528')
        for n,(name,_) in enumerate(SCENES):
            preview = Image.open(folder/name)
            full.paste(preview,(n*1224,0))
            preview.thumbnail((402,874))
            sheet.paste(preview,(n*420,0))
        sheet.save(DESTINATION/f'candidate-pair-{locale}.jpg',quality=96)
        full.save(DESTINATION/f'candidate-pair-{locale}-full.png',optimize=True)
    for name,_ in SCENES[:len(sources)]:
        locale_bodies = [hashlib.sha256(Image.open(DESTINATION/locale/name).crop((0,240,W,H)).tobytes()).hexdigest() for locale in TITLES]
        assert len(set(locale_bodies)) == 1, f'Native body differs across locales: {name}'
    assert source_hashes == {str(p.relative_to(ROOT)): sha(p) for p in sources}, 'Native capture changed during rendering'
    after = final_hashes()
    assert before == after,'Active final files changed during review render'
    if approved_settings:
        assert approved_settings == {str(p.relative_to(ROOT)): sha(p) for p in DESTINATION.glob('*/01-visual-customization.png')}, 'Approved Settings files changed'
    (DESTINATION/'manifest.json').write_text(json.dumps(manifest,ensure_ascii=False,indent=2))
    (DESTINATION/'qa.json').write_text(json.dumps({'passed':True,'review_only':True,'image_count':len(files),
        'scene_count':len(sources),'locale_count':4,'files':files,'all_sizes':[W,H],'all_RGB_without_alpha':True,
        'device_bounds_exclusive':BOUNDS,'minimum_visible_margin':60,'native_capture_files_unchanged':True,
        'native_pixels_preserved_before_frame_and_scale':True,'localized_device_bodies_identical':True,'source_capture_hashes':source_hashes,'shared_baselines':True,
        'native_customization_viewport_notes':NATIVE_SETTINGS_NOTES,
        'approved_settings_files_unchanged':bool(approved_settings),'approved_settings_hashes':approved_settings,
        'widget_update_only':widgets_only,
        'active_final_files_unchanged':True,'active_final_hashes':after},indent=2))
    print(f'PASS: {len(files)} review-only PNGs, {len(sources)} scenes x 4 locales. Device bounds {BOUNDS}. Active finals unchanged.')
    print(DESTINATION/'candidate-pair-en-US.jpg' if len(sources) == 2 else DESTINATION/'en-US'/SCENES[0][0])


if __name__ == '__main__':
    parser = argparse.ArgumentParser()
    parser.add_argument('--customization-capture',type=Path,default=CAPTURES/'2026-10-22-customization-native-polished.png')
    parser.add_argument('--widgets-capture',type=Path,default=CAPTURES/'2026-10-22-widgets-full-dock-native.png')
    parser.add_argument('--check-headings',action='store_true')
    parser.add_argument('--customization-only',action='store_true')
    parser.add_argument('--widgets-only',action='store_true',help='Preserve approved Settings file bytes and update only widgets')
    args = parser.parse_args()
    if args.check_headings:
        print(json.dumps({locale:[heading_geometry(parts) for parts in titles] for locale,titles in TITLES.items()},ensure_ascii=False,indent=2))
    else:
        render(args.customization_capture,None if args.customization_only else args.widgets_capture,args.widgets_only)
