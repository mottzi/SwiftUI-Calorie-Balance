from pathlib import Path
import subprocess,concurrent.futures,json
root=Path(__file__).resolve().parents[1]
def run(cmd):subprocess.run(cmd,check=True)
# Normalize the variable-rate simulator recording before selecting frames.
# Replay the captured forward transition in reverse for an exact looping seam.
cuts=json.loads((root/'source/cut-frames.json').read_text())
f0=cuts['forward']; r0=cuts['back']; n=cuts['length']
loop=f'[0:v]fps=60,split=2[a][b];[a]trim=start_frame={f0}:end_frame={f0+n},setpts=2*(PTS-STARTPTS),fps=30,tpad=start_mode=clone:start_duration=1.1:stop_mode=clone:stop_duration=1.1[f];[b]trim=start_frame={f0}:end_frame={f0+n},reverse,setpts=2*(PTS-STARTPTS),fps=30,tpad=start_mode=clone:start_duration=1.1:stop_mode=clone:stop_duration=1.1[r];[f][r]concat=n=2:v=1:a=0,format=yuv420p[v]'
run(['ffmpeg','-y','-v','error','-i',str(root/'captures/watch-native-auto.mov'),'-filter_complex',loop,'-map','[v]','-an','-c:v','libx264','-preset','fast','-crf','14','-threads','4','-movflags','+faststart',str(root/'video/watch-screen-now-midnight-loop.mp4')])
print('Native screen loop rendered.',flush=True)
rgb=subprocess.check_output(['ffmpeg','-v','error','-i',str(root/'video/watch-screen-now-midnight-loop.mp4'),'-vf','format=rgb24,crop=1:1:208:20','-f','rawvideo','-'])
blue_frames=[i//3 for i in range(0,len(rgb),3) if rgb[i+2]>rgb[i]]
mode_a=min(blue_frames)/30
mode_b=(max(blue_frames)+1)/30
print('Mode captions:',mode_a,mode_b,flush=True)
def render(theme):
 args=['ffmpeg','-y','-v','error','-loop','1','-i',str(root/f'source/background-{theme}.png'),'-i',str(root/'video/watch-screen-now-midnight-loop.mp4'),'-loop','1','-i',str(root/'source/screen-mask.png'),'-loop','1','-i',str(root/'source/apple-watch-s11-46-black.png'),'-loop','1','-i',str(root/f'source/badge-{theme}-now.png'),'-loop','1','-i',str(root/f'source/badge-{theme}-midnight.png')]
 filters=f"[0:v]format=rgba[bg];[1:v]format=rgba[s];[2:v]alphaextract[m];[s][m]alphamerge,scale=832:992:flags=lanczos[screen];[3:v]scale=1120:1760:flags=lanczos[frame];[bg][screen]overlay=x=2424:y=574:shortest=1[a];[a][frame]overlay=x=2280:y=190:shortest=1[b];[b][4:v]overlay=enable='lt(t,{mode_a})+gte(t,{mode_b})':shortest=1[c];[c][5:v]overlay=enable='gte(t,{mode_a})*lt(t,{mode_b})':shortest=1,format=yuv420p[v]"
 run(args+['-filter_complex_threads','2','-filter_complex',filters,'-map','[v]','-t','10','-r','30','-an','-c:v','libx264','-preset','fast','-crf','17','-threads','4','-movflags','+faststart',str(root/f'video/count-kcal-watch-{theme}-hero-4k.mp4')])
 print(theme+' 4K hero rendered.',flush=True)
 bg='#edf2f6' if theme=='light' else '#07131f'
 filters=f"color=c={bg}:s=560x880:r=30:d=10,format=rgba[bg];[0:v]format=rgba[s];[1:v]alphaextract[m];[s][m]alphamerge[screen];[bg][screen]overlay=x=72:y=192:shortest=1[a];[a][2:v]overlay=shortest=1,format=yuv420p[v]"
 run(['ffmpeg','-y','-v','error','-i',str(root/'video/watch-screen-now-midnight-loop.mp4'),'-loop','1','-i',str(root/'source/screen-mask.png'),'-loop','1','-i',str(root/'source/apple-watch-s11-46-black.png'),'-filter_complex',filters,'-map','[v]','-t','10','-r','30','-an','-c:v','libx264','-preset','fast','-crf','15','-threads','2','-movflags','+faststart',str(root/f'video/watch-framed-{theme}-loop.mp4')])
 print(theme+' framed loop rendered.',flush=True)
with concurrent.futures.ThreadPoolExecutor(max_workers=2) as pool:list(pool.map(render,['light','dark']))
