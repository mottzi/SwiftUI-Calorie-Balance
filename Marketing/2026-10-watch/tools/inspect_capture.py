from pathlib import Path
import subprocess,json
root=Path(__file__).resolve().parents[1]
raw=root/'captures/watch-native-auto.mov'
probe=json.loads(subprocess.check_output(['ffprobe','-v','error','-show_entries','format=duration','-show_entries','stream=width,height','-of','json',str(raw)]))
print(probe)
video=subprocess.check_output(['ffmpeg','-v','error','-i',str(raw),'-vf','fps=60,crop=380:300:18:100,scale=76:60,format=gray','-f','rawvideo','-'])
n=76*60;frames=[video[i:i+n] for i in range(0,len(video),n)]; moving=[]
for i in range(1,len(frames)):
 diff=sum(abs(x-y) for x,y in zip(frames[i-1],frames[i]))/n
 if i/60>4 and diff>.08:moving.append((i/60,diff))
groups=[]
for t,d in moving:
 if not groups or t-groups[-1][-1][0]>.7:groups.append([])
 groups[-1].append((t,d))
events=[{'start':g[0][0],'end':g[-1][0],'peak':max(d for _,d in g)} for g in groups]
print('Motion events:',events)
(root/'source/motion-events.json').write_text(json.dumps(events,indent=2))
assert len(events)>=2,events
forward=int(round((events[0]['start']-.16)*60))
back=int(round((events[1]['start']-.16)*60))
(root/'source/cut-frames.json').write_text(json.dumps({'forward':forward,'back':back,'length':84},indent=2))
now_time=events[0]['start']-.6
mid_time=(events[0]['end']+events[1]['start'])/2
for sec,name in [(now_time,'now'),(mid_time,'midnight')]:
 subprocess.run(['ffmpeg','-y','-v','error','-i',str(raw),'-vf',f'fps=60,select=eq(n\\,{round(sec*60)})','-frames:v','1','-update','1',str(root/f'captures/watch-{name}.png')],check=True)
