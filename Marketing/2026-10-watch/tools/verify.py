from pathlib import Path
import subprocess,json
root=Path(__file__).resolve().parents[1]
for f in sorted((root/'video').glob('*.mp4')):
 d=json.loads(subprocess.check_output(['ffprobe','-v','error','-show_entries','stream=width,height,avg_frame_rate,nb_frames','-show_entries','format=duration','-of','json',str(f)]))
 assert d['format']['duration']=='10.000000',(f,d)
 assert d['streams'][0]['nb_frames']=='300',(f,d)
 assert d['streams'][0]['avg_frame_rate']=='30/1',(f,d)
 # Inspect actual decoded pictures at the seam and the opposite state.
 w=d['streams'][0]['width']
 crop='crop=832:992:2424:574,' if w==3840 else 'crop=416:496:72:192,' if w==560 else ''
 raw=subprocess.check_output(['ffmpeg','-v','error','-i',str(f),'-vf',"select='eq(n,0)+eq(n,150)+eq(n,299)',"+crop+"scale=208:248,format=rgb24",'-fps_mode','passthrough','-f','rawvideo','-'])
 n=208*248*3;assert len(raw)==3*n
 first,mid,last=raw[:n],raw[n:2*n],raw[2*n:]
 seam=sum(abs(x-y) for x,y in zip(first,last))/n
 phase=sum(abs(x-y) for x,y in zip(first,mid))/n
 assert seam<.6,(f,'seam',seam)
 assert phase>5,(f,'no state change',phase)
 print(f.name,d['streams'][0]['width'],d['streams'][0]['height'],'10 s, 30 fps','seam',round(seam,4),'phase change',round(phase,2),flush=True)
(root/'source/verification.txt').write_text('All five videos verified: 10 seconds, 300 frames at 30 fps, distinct Now and Midnight states, matching loop endpoints.\n')
