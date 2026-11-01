"""Rebuild native assets, CoreGraphics storyboards, posters and silent videos."""
from pathlib import Path
from PIL import Image, ImageDraw, ImageFont
import argparse, hashlib, json, shutil, subprocess
import numpy as np

HERE = Path(__file__).resolve().parent
COLLECTION = HERE.parent
ROOT = COLLECTION.parents[1]
CONFIG = HERE/'motion-config.json'
CFG = json.loads(CONFIG.read_text())
BINARY = HERE/'.build/render-film'
FFMPEG = '/opt/homebrew/bin/ffmpeg'
FFPROBE = '/opt/homebrew/bin/ffprobe'
PREFIX = 'count-kcal-your-day-together'


def sha(p):
    return hashlib.sha256(Path(p).read_bytes()).hexdigest()


def prepare():
    manifest = {'theme':2,'appearance':'dark','calorie_mode':'Midnight','steps':False,
                'native_readings':{'burned_kcal':2600,'eaten_kcal':2000,'today_kg':79.7},
                'native_ui_reconstructed':False,'sources':[]}
    for key, original in CFG['sourceAssets'].items():
        source = ROOT/original
        dest = COLLECTION/CFG['assets'][key]
        dest.parent.mkdir(parents=True,exist_ok=True)
        if not dest.exists() or sha(dest)!=sha(source):
            shutil.copy2(source,dest)
        manifest['sources'].append({'role':key,'original':str(source.relative_to(ROOT)),
            'local':str(dest.relative_to(COLLECTION)),'sha256':sha(source),'copy_byte_identical':sha(source)==sha(dest)})
    original = Image.open(COLLECTION/CFG['assets']['phone']).convert('RGBA')
    crop = original.getchannel('A').getbbox()
    original = original.crop(crop)
    stamp = HERE/'assets/poses-stamp.json'
    key = {'source_sha256':sha(COLLECTION/CFG['assets']['phone']),'version':2,'count':61,'crop':list(crop)}
    if not stamp.exists() or json.loads(stamp.read_text())!=key:
        sw,sh = original.size
        start = np.array([(65,15),(1015,68),(1015,2172),(65,2225)],float)
        end = np.array([(12,12),(1068,20),(1068,2220),(12,2228)],float)
        for i in range(CFG['assets']['poseCount']):
            p = i/(CFG['assets']['poseCount']-1)
            quad = start+(end-start)*p
            matrix,values = [],[]
            for (x,y),(u,v) in zip(quad,[(0,0),(sw,0),(sw,sh),(0,sh)]):
                matrix.extend([[x,y,1,0,0,0,-u*x,-u*y],[0,0,0,x,y,1,-v*x,-v*y]])
                values.extend([u,v])
            coeff = np.linalg.solve(np.array(matrix,float),np.array(values,float))
            projected = original.transform((1080,2240),Image.Transform.PERSPECTIVE,coeff,Image.Resampling.BICUBIC)
            bounds = projected.getchannel('A').getbbox()
            body = projected.crop(bounds)
            h = 2240; w = round(body.width*h/body.height)
            assert w<=1080,(i,w)
            body = body.resize((w,h),Image.Resampling.LANCZOS)
            tile = Image.new('RGBA',(1080,2240))
            tile.alpha_composite(body,((1080-w)//2,0))
            tile.save(COLLECTION/(CFG['assets']['posePattern']%i),compress_level=4)
        stamp.write_text(json.dumps(key,indent=2))
    manifest['phone_crop_exclusive'] = list(crop)
    manifest['perspective'] = 'One uniform homography of the complete native framed image per pose. No fabricated sidewall.'
    manifest['pose_count'] = 61
    (COLLECTION/'qa/asset-provenance.json').write_text(json.dumps(manifest,indent=2))


def compile_renderer():
    BINARY.parent.mkdir(exist_ok=True)
    source = HERE/'render-film.swift'
    if not BINARY.exists() or BINARY.stat().st_mtime<source.stat().st_mtime:
        subprocess.run(['swiftc','-O',str(source),'-o',str(BINARY)],check=True)


def render_png(variant,path,time,width=None,dark=True):
    width = width or CFG['layouts'][variant]['width']
    subprocess.run([str(BINARY),str(CONFIG),variant,'poster-dark' if dark else 'poster',str(path),str(width),str(time)],check=True)


def storyboards():
    out = COLLECTION/'review/storyboard'
    out.mkdir(parents=True,exist_ok=True)
    times = [0,1.8,3.6,5.5,7.0,9.8]
    for variant in ['wide','portrait']:
        for t in times:
            render_png(variant,out/f'{variant}-{t:04.1f}s.png',t)
        thumb_width = 600 if variant=='wide' else 270
        thumb_height = round(thumb_width*CFG['layouts'][variant]['height']/CFG['layouts'][variant]['width'])
        sheet = Image.new('RGB',(3*thumb_width+32,2*(thumb_height+40)+16),'#17181c')
        d = ImageDraw.Draw(sheet)
        f = ImageFont.truetype('/System/Library/Fonts/SFNS.ttf',18)
        for n,t in enumerate(times):
            preview = Image.open(out/f'{variant}-{t:04.1f}s.png').convert('RGB')
            preview.thumbnail((thumb_width,thumb_height),Image.Resampling.LANCZOS)
            x=(n%3)*(thumb_width+16); y=(n//3)*(thumb_height+40)
            sheet.paste(preview,(x,y+30));d.text((x+8,y+4),f'{t:.1f} s',font=f,fill='#c3c3cb')
        sheet.save(COLLECTION/'review'/f'{variant}-storyboard-contact-sheet.jpg',quality=95)
    print('Storyboards ready:',out,flush=True)


def posters():
    out = COLLECTION/'stills'
    render_png('wide',out/f'{PREFIX}-poster-transparent.png',3.6,3600,False)
    render_png('wide',out/f'{PREFIX}-poster-dark.png',3.6,3600,True)
    render_png('wide',out/f'{PREFIX}-final-hold-transparent.png',7.0,3600,False)
    render_png('wide',out/f'{PREFIX}-final-hold-dark.png',7.0,3600,True)
    render_png('portrait',out/f'{PREFIX}-poster-portrait.png',3.6,2160,True)
    render_png('portrait',out/f'{PREFIX}-final-hold-portrait.png',7.0,2160,True)


def encode(variant):
    layout=CFG['layouts'][variant];w,h=layout['width'],layout['height']
    transparent=COLLECTION/'videos'/f'{PREFIX}-loop-transparent.webm'
    dark=COLLECTION/'videos'/f'{PREFIX}-{"loop-dark-bg" if variant=="wide" else "portrait-dark-bg"}.mp4'
    renderer=subprocess.Popen([str(BINARY),str(CONFIG),variant,'frames','-',str(w)],stdout=subprocess.PIPE)
    command=[FFMPEG,'-hide_banner','-loglevel','warning','-y','-f','rawvideo','-pixel_format','rgba','-video_size',f'{w}x{h}','-framerate',str(CFG['fps']),'-i','pipe:0',
        '-f','lavfi','-i',f'color=c={CFG["background"]}:s={w}x{h}:r={CFG["fps"]}:d={CFG["duration"]}']
    if variant=='wide':
        command += ['-filter_complex','[0:v]split=2[alpha][forbg];[1:v][forbg]overlay=shortest=1:format=auto[dark]',
            '-map','[alpha]','-an','-c:v','libvpx-vp9','-pix_fmt','yuva420p','-b:v','0','-crf','30','-deadline','good','-cpu-used','4','-row-mt','1','-auto-alt-ref','0','-metadata:s:v:0','alpha_mode=1',str(transparent),
            '-map','[dark]']
    else:
        command += ['-filter_complex','[1:v][0:v]overlay=shortest=1:format=auto[dark]','-map','[dark]']
    command += ['-an','-c:v','libx264','-pix_fmt','yuv420p','-crf','18','-preset','medium','-movflags','+faststart','-color_primaries','bt709','-color_trc','bt709','-colorspace','bt709',str(dark)]
    result=subprocess.run(command,stdin=renderer.stdout)
    renderer.stdout.close();renderer_status=renderer.wait()
    assert result.returncode==0 and renderer_status==0,(result.returncode,renderer_status)


def probe():
    rows=[]
    for path in sorted((COLLECTION/'videos').glob('*')):
        data=json.loads(subprocess.check_output([FFPROBE,'-v','quiet','-show_streams','-show_format','-of','json',str(path)]))
        streams=data['streams'];video=[s for s in streams if s['codec_type']=='video']
        assert len(video)==1 and not [s for s in streams if s['codec_type']=='audio']
        v=video[0];assert abs(float(data['format']['duration'])-10)<0.08
        assert v['r_frame_rate']=='30/1'
        rows.append({'file':str(path.relative_to(COLLECTION)),'sha256':sha(path),'bytes':path.stat().st_size,'probe':data})
    (COLLECTION/'qa/ffprobe.json').write_text(json.dumps(rows,indent=2))
    print('Validated',len(rows),'silent ten-second video exports.',flush=True)


if __name__=='__main__':
    parser=argparse.ArgumentParser();parser.add_argument('--storyboards-only',action='store_true');parser.add_argument('--videos-only',action='store_true');parser.add_argument('--posters-only',action='store_true');args=parser.parse_args()
    prepare();compile_renderer()
    if args.videos_only:
        encode('wide');encode('portrait');probe()
    elif args.posters_only:
        posters()
    elif args.storyboards_only:
        storyboards()
    else:
        storyboards();posters();encode('wide');encode('portrait');probe()
