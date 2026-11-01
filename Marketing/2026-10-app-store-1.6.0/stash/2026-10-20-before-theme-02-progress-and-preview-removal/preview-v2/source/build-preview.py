#!/usr/bin/env python3
"""Build the four localized v2 App Previews using only native app capture."""
import argparse
import json
from pathlib import Path
import subprocess

ROOT = Path(__file__).resolve().parents[1]
REPO = ROOT.parents[2]
WORK = ROOT / 'work'
OUT = ROOT / 'exports'
REVIEW = ROOT / 'review'
for folder in (WORK, OUT, REVIEW):
    folder.mkdir(exist_ok=True)

def run(command):
    subprocess.run([str(x) for x in command], check=True)

def ffmpeg(command):
    run(['ffmpeg', '-hide_banner', '-loglevel', 'error', '-y', '-filter_complex_threads', 2, *command])

parser = argparse.ArgumentParser()
parser.add_argument('--locale', nargs='+', default=['en-US', 'de-DE', 'fr-FR', 'es-ES'])
args = parser.parse_args()
run(['swift', ROOT / 'source/make-video-captions.swift', WORK / 'captions'])
native = REPO / 'Marketing/2026-10-calorie-card/source/iphone-18-pro-theme-01-dark-now-midnight-native-slow.mov'
scroll = REPO / 'Marketing/2026-10-app-store-1.6.0/captures/dashboard-scroll-en-US.mp4'
captures = REPO / 'Marketing/2026-10-today/captures'
scenes = [
    (native, 3, 8.25),
    (scroll, 2.8, 6.25),
    (captures / 'iphone-18-pro-theme-02-dark-midnight-bg-dark-steps-off-sheen-mid-capture.png', 0, 4.25),
    (captures / 'iphone-18-pro-theme-04-dark-midnight-bg-dark-steps-off-sheen-mid-capture.png', 0, 4),
]
for locale in args.locale:
    slug = locale.lower()
    locale_work = WORK / locale
    locale_work.mkdir(exist_ok=True)
    locale_review = REVIEW if locale == 'en-US' else REVIEW / locale
    locale_review.mkdir(exist_ok=True)
    clips = []
    for index, (source, start, duration) in enumerate(scenes, 1):
        clip = locale_work / f'scene-{index:02d}.mp4'
        clips.append(clip)
        inputs = ['-loop', 1, '-framerate', 30, '-i', source] if source.suffix == '.png' else ['-ss', start, '-i', source]
        source_metadata = json.loads(subprocess.check_output(['ffprobe', '-v', 'error', '-show_streams', '-of', 'json', str(source)], text=True))['streams'][0]
        source_primaries = source_metadata.get('color_primaries', 'bt709')
        graph = f'[0:v]fps=30,scale=886:1926:flags=lanczos:out_color_matrix=bt709:out_range=tv,crop=886:1920:0:0,format=yuv444p,colorspace=all=bt709:ispace=bt709:iprimaries={source_primaries}:itrc=iec61966-2-1:range=tv:format=yuv420p,setsar=1,setpts=PTS-STARTPTS[v];[1:v]scale=886:116:out_color_matrix=bt709:out_range=tv,format=yuv444p,colorspace=all=bt709:ispace=bt709:iprimaries=bt709:itrc=iec61966-2-1:range=tv:format=yuv420p[caption];[v][caption]overlay=0:0,format=yuv420p[out]'
        ffmpeg([*inputs, '-i', WORK / f'captions/{locale}/caption-{index:02d}.png', '-filter_complex', graph, '-map', '[out]', '-t', duration, '-an', '-c:v', 'libx264', '-preset', 'fast', '-threads', 4, '-crf', 15, '-profile:v', 'high', '-level:v', '4.0', '-pix_fmt', 'yuv420p', '-g', 60, '-bf', 2, '-refs', 2, '-video_track_timescale', 30000, clip])
        print(f'{locale}: rendered scene {index}', flush=True)

    output = OUT / f'count-kcal-iphone-app-preview-v2-{slug}-886x1920.mp4'
    inputs = []
    for clip in clips:
        inputs += ['-i', clip]
    graph = ';'.join([
        '[0:v][1:v]xfade=transition=fade:duration=0.25:offset=8[v1]',
        '[v1][2:v]xfade=transition=fade:duration=0.25:offset=14[v2]',
        '[v2][3:v]xfade=transition=fade:duration=0.25:offset=18,format=yuv420p[out]'])
    ffmpeg([*inputs, '-f', 'lavfi', '-i', 'anullsrc=r=48000:cl=stereo', '-filter_complex', graph, '-map', '[out]', '-map', '4:a', '-af', 'atrim=duration=21.98', '-t', 22, '-c:v', 'libx264', '-preset', 'slow', '-threads', 4, '-b:v', '10M', '-minrate', '10M', '-maxrate', '10M', '-bufsize', '20M', '-x264-params', 'nal-hrd=cbr:force-cfr=1', '-profile:v', 'high', '-level:v', '4.0', '-pix_fmt', 'yuv420p', '-r', 30, '-g', 60, '-bf', 2, '-refs', 2, '-color_primaries', 'bt709', '-color_trc', 'bt709', '-colorspace', 'bt709', '-c:a', 'aac_at', '-aac_at_mode', 'cbr', '-b:a', '256k', '-ar', 48000, '-ac', 2, '-movflags', '+faststart', '-video_track_timescale', 30000, output])

    image_space = 'colorspace=space=bt709:primaries=bt709:trc=srgb:range=pc:format=yuv444p,format=rgb24'
    poster = OUT / f'count-kcal-iphone-app-preview-v2-{slug}-poster-05s.png'
    ffmpeg(['-ss', 5, '-i', output, '-vf', image_space, '-frames:v', 1, '-update', 1, poster])
    frames = [15, 75, 150, 225, 255, 315, 375, 435, 495, 555, 615, 645]
    selection = '+'.join(f'eq(n,{n})' for n in frames)
    sheet = REVIEW / f'count-kcal-iphone-app-preview-v2-{slug}-contact-sheet.png'
    ffmpeg(['-i', output, '-vf', f"select='{selection}',{image_space},scale=222:-1,tile=4x3:padding=10:margin=10:color=0x111216", '-frames:v', 1, '-update', 1, sheet])
    for moment in (0, 5, 11, 16, 21):
        ffmpeg(['-ss', moment, '-i', output, '-vf', image_space, '-frames:v', 1, '-update', 1, locale_review / f'frame-{moment:02d}s.png'])

    metadata = subprocess.check_output(['ffprobe', '-v', 'error', '-show_format', '-show_streams', '-of', 'json', str(output)], text=True)
    (OUT / f'count-kcal-iphone-app-preview-v2-{slug}-ffprobe.json').write_text(metadata)
    data = json.loads(metadata)
    video, audio = data['streams']
    assert (video['width'], video['height'], video['r_frame_rate'], video['avg_frame_rate'], video['nb_frames'], video['profile'], video['level'], video['pix_fmt']) == (886, 1920, '30/1', '30/1', '660', 'High', 40, 'yuv420p')
    assert video['codec_name'] == 'h264' and video['field_order'] == 'progressive'
    assert video['color_space'] == 'bt709' and video['color_transfer'] == 'bt709' and video['color_primaries'] == 'bt709'
    assert audio['codec_name'] == 'aac' and audio['channels'] == 2 and audio['sample_rate'] == '48000'
    assert 240000 < int(audio['bit_rate']) < 280000 and audio['disposition']['default'] == 1
    assert 22 <= float(data['format']['duration']) < 22.02 and int(data['format']['size']) < 500_000_000
    ffmpeg(['-i', output, '-f', 'null', '-'])
    print(f'Full decode and delivery assertions passed. {output}', flush=True)
