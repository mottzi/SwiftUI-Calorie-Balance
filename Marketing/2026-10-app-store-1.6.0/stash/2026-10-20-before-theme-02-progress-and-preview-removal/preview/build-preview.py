#!/usr/bin/env python3
"""Render the editable, 24-second App Store preview from native app capture.

Usage: python3 build-preview.py --scroll path/to/native-scroll.mov --scroll-start 0
No third-party Python packages are needed. Requires ffmpeg, ffprobe and Swift.
"""
import argparse
import json
import subprocess
from pathlib import Path

HERE = Path(__file__).resolve().parent
REPO = HERE.parents[2]
WORK = HERE / 'work'
OUT = HERE / 'exports'
FPS = 30

def run(args):
    print(' '.join(map(str, args)), flush=True)
    subprocess.run(list(map(str, args)), check=True)

def ffmpeg(args):
    run(['ffmpeg', '-hide_banner', '-loglevel', 'warning', '-y', '-filter_complex_threads', '2', *args])

parser = argparse.ArgumentParser()
parser.add_argument('--scroll', type=Path, required=True)
parser.add_argument('--scroll-start', type=float, default=0)
parser.add_argument('--locale', nargs='+', default=['en-US', 'de-DE', 'fr-FR', 'es-ES'])
args = parser.parse_args()
OUT.mkdir(exist_ok=True)
WORK.mkdir(exist_ok=True)
run(['swift', HERE / 'make-overlays.swift', WORK / 'overlays'])

native = REPO / 'Marketing/2026-10-calorie-card/source/iphone-18-pro-theme-01-dark-now-midnight-native-slow.mov'
theme2 = REPO / 'Marketing/2026-10-today/captures/iphone-18-pro-theme-02-dark-midnight-bg-dark-steps-off-sheen-mid-capture.png'
theme4 = REPO / 'Marketing/2026-10-today/captures/iphone-18-pro-theme-04-dark-midnight-bg-dark-steps-off-sheen-mid-capture.png'
scenes = [(native, 0.5, 4.25), (native, 3, 6.25), (args.scroll.resolve(), args.scroll_start, 6.25), (theme2, 0, 4.25), (theme4, 0, 4)]

for locale in args.locale:
    scene_dir = WORK / locale
    scene_dir.mkdir(exist_ok=True)
    clips = []
    for n, (source, start, duration) in enumerate(scenes, 1):
        output = scene_dir / f'scene-{n:02d}.mp4'
        clips.append(output)
        inputs = ['-loop', '1', '-framerate', FPS, '-i', source] if source.suffix == '.png' else ['-ss', start, '-i', source]
        caption = WORK / 'overlays' / locale / f'caption-{n:02d}.png'
        # Scale uniformly to width, then remove only the six-pixel excess height.
        # Caption hides the system status/navigation area; native app content stays intact.
        filters = '[0:v]fps=30,scale=886:1926:flags=lanczos,crop=886:1920:0:0,setsar=1,setpts=PTS-STARTPTS[v];[v][1:v]overlay=0:0,format=yuv420p[out]'
        ffmpeg([*inputs, '-i', caption, '-filter_complex', filters, '-map', '[out]', '-t', duration, '-an', '-c:v', 'libx264', '-preset', 'fast', '-threads', '4', '-crf', 15, '-profile:v', 'high', '-level:v', '4.0', '-pix_fmt', 'yuv420p', '-g', 60, '-bf', 2, '-refs', 2, '-video_track_timescale', 30000, output])
    output = OUT / f'count-kcal-iphone-app-preview-{locale.lower()}-886x1920.mp4'
    inputs = []
    for clip in clips:
        inputs += ['-i', clip]
    graph = ';'.join([
        '[0:v][1:v]xfade=transition=fade:duration=0.25:offset=4[v1]',
        '[v1][2:v]xfade=transition=fade:duration=0.25:offset=10[v2]',
        '[v2][3:v]xfade=transition=fade:duration=0.25:offset=16[v3]',
        '[v3][4:v]xfade=transition=fade:duration=0.25:offset=20,format=yuv420p[out]'])
    ffmpeg([*inputs, '-f', 'lavfi', '-i', 'anullsrc=r=48000:cl=stereo', '-filter_complex', graph, '-map', '[out]', '-map', '5:a', '-t', 24, '-c:v', 'libx264', '-preset', 'slow', '-threads', '4', '-b:v', '10M', '-minrate', '10M', '-maxrate', '10M', '-bufsize', '20M', '-x264-params', 'nal-hrd=cbr:force-cfr=1', '-profile:v', 'high', '-level:v', '4.0', '-pix_fmt', 'yuv420p', '-r', FPS, '-g', 60, '-bf', 2, '-refs', 2, '-color_primaries', 'bt709', '-color_trc', 'bt709', '-colorspace', 'bt709', '-c:a', 'aac_at', '-aac_at_mode', 'cbr', '-b:a', '256k', '-ar', 48000, '-ac', 2, '-movflags', '+faststart', '-video_track_timescale', 30000, output])
    # Poster is an exact frame from the exported preview at Apple's default 5 seconds.
    ffmpeg(['-ss', 5, '-i', output, '-frames:v', 1, '-update', 1, OUT / f'count-kcal-iphone-app-preview-{locale.lower()}-poster-05s.png'])
    ffmpeg(['-i', output, '-vf', 'fps=1/2,scale=222:-1,tile=4x3:padding=10:margin=10:color=0x111216', '-frames:v', 1, '-update', 1, OUT / f'count-kcal-iphone-app-preview-{locale.lower()}-contact-sheet.jpg'])
    metadata = subprocess.check_output(['ffprobe', '-v', 'error', '-show_format', '-show_streams', '-of', 'json', str(output)], text=True)
    (OUT / f'count-kcal-iphone-app-preview-{locale.lower()}-ffprobe.json').write_text(metadata)
    data = json.loads(metadata)
    video = next(s for s in data['streams'] if s['codec_type'] == 'video')
    audio = next(s for s in data['streams'] if s['codec_type'] == 'audio')
    assert (video['width'], video['height'], video['codec_name'], video['pix_fmt'], video['r_frame_rate']) == (886, 1920, 'h264', 'yuv420p', '30/1')
    assert 15 <= float(data['format']['duration']) <= 30
    assert int(data['format']['size']) < 500_000_000
    assert audio['codec_name'] == 'aac' and audio['channels'] == 2 and audio['sample_rate'] == '48000'
    assert 240000 <= int(audio['bit_rate']) <= 280000
    print(f'Validated {output.name}', flush=True)
