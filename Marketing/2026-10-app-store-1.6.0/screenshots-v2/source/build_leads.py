from pathlib import Path
from PIL import Image, ImageDraw, ImageFont
import numpy as np
import json

ROOT=Path(__file__).resolve().parents[4]
OUT=ROOT/'Marketing/2026-10-app-store-1.6.0/screenshots-v2'
TODAY=ROOT/'Marketing/2026-10-today'
CARD=ROOT/'Marketing/2026-10-calorie-card'
SIZE=(1206,2622)
BG='#060709'
WHITE='#eeeeef'
FONT='/System/Library/Fonts/SFNS.ttf'

def font(size,weight=560):
 f=ImageFont.truetype(FONT,size)
 f.set_variation_by_axes([100,96,400,weight]);return f

def framed(theme):
 return TODAY/'stills'/f'iphone-18-pro-silver-theme-{theme:02}-dark-midnight-bg-dark-steps-off-sheen-mid-framed.png'

def header(canvas,parts,y=118,size=94):
 d=ImageDraw.Draw(canvas);f=font(size)
 total=sum(d.textlength(s,font=f) for s,c in parts)
 x=(SIZE[0]-total)/2
 for s,c in parts:
  d.text((x,y),s,font=f,fill=c,anchor='lt');x+=d.textlength(s,font=f)

def label(canvas,text,x,y):
 d=ImageDraw.Draw(canvas);d.text((x,y),text,font=font(39,470),fill='#b2b4ba',anchor='mt')

def flat(canvas,path,width,x,y):
 im=Image.open(path).convert('RGBA');im=im.resize((width,round(im.height*width/im.width)),Image.Resampling.LANCZOS)
 canvas.alpha_composite(im,(x,y))

def project(canvas,path,quad):
 """Project the entire original framed bitmap to a planar quadrilateral."""
 im=Image.open(path).convert('RGBA');w,h=im.size
 src=[(0,0),(w,0),(w,h),(0,h)]
 matrix=[];values=[]
 # Solve destination -> source homography for Pillow's sampling convention.
 for (x,y),(u,v) in zip(quad,src):
  matrix.extend([[x,y,1,0,0,0,-u*x,-u*y],[0,0,0,x,y,1,-v*x,-v*y]])
  values.extend([u,v])
 coeff=np.linalg.solve(np.array(matrix,dtype=float),np.array(values,dtype=float))
 layer=im.transform(SIZE,Image.Transform.PERSPECTIVE,coeff,Image.Resampling.BICUBIC)
 canvas.alpha_composite(layer)

def frame_capture(source,name):
 screen=Image.open(source).convert('RGBA');assert screen.size==(1206,2622)
 frame=Image.open(TODAY/'source/iphone-18-pro-silver-frame.png').convert('RGBA')
 mask=Image.new('L',screen.size);d=ImageDraw.Draw(mask)
 d.rounded_rectangle((0,0,1205,2621),radius=155,fill=255)
 result=Image.new('RGBA',frame.size)
 result.paste(screen,(72,69),mask);result.alpha_composite(frame)
 path=OUT/'source'/name;result.save(path);return path

def save(canvas,name,sources,composition):
 path=OUT/'en-US'/name;canvas.convert('RGB').save(path,optimize=True)
 return {'file':str(path.relative_to(ROOT)),'size':list(SIZE),'mode':'RGB','sources':[str(p.relative_to(ROOT)) for p in sources],'composition':composition}

manifest=[]
# 1. Hero. One line and one complete large current Apple-framed iPhone.
canvas=Image.new('RGBA',SIZE,BG)
header(canvas,[('Calorie ',WHITE),('balance.','#86b6e7')],y=104,size=96)
flat(canvas,framed(1),1160,23,255)
manifest.append(save(canvas,'01-calorie-balance.png',[framed(1)],'Centered single-line title. Phone fills 96.2% of canvas width. Original aspect ratio; bottom ends five pixels outside canvas.'))

# 2. Color choice. Three complete framed current devices projected in one
# direction and overlapped, following the original Custom colors composition.
canvas=Image.new('RGBA',SIZE,BG)
header(canvas,[('Your ',WHITE),('colors.','#b1a8ed')],y=106,size=96)
quad1=[(-20,350),(910,395),(910,2490),(-20,2550)]
quad2=[(165,320),(1125,365),(1125,2525),(165,2590)]
quad4=[(350,290),(1350,335),(1350,2560),(350,2630)]
for theme,quad in [(1,quad1),(2,quad2),(4,quad4)]:project(canvas,framed(theme),quad)
manifest.append(save(canvas,'02-your-colors.png',[framed(1),framed(2),framed(4)],'Three silver iPhones in controlled perspective. Theme1 left/back, Theme2 center, Theme4 front/right. Whole framed images transformed together. Deliberate side and bottom crops.'))

# 3. Now and Midnight. Actual captures of the same Theme1 profile and UI.
now_source=CARD/'source/iphone-18-pro-theme-01-dark-now-calorie-card-capture.png'
midnight_source=CARD/'source/iphone-18-pro-theme-01-dark-midnight-calorie-card-capture.png'
now=frame_capture(now_source,'theme-01-now-framed.png')
midnight=frame_capture(midnight_source,'theme-01-midnight-framed.png')
canvas=Image.new('RGBA',SIZE,BG)
header(canvas,[('Now ',WHITE),('to midnight.','#86b6e7')],y=104,size=94)
label(canvas,'Now',195,303)
label(canvas,'Midnight',912,485)
project(canvas,now,[(-400,395),(600,440),(600,2370),(-400,2430)])
project(canvas,midnight,[(350,590),(1350,545),(1350,2580),(350,2660)])
manifest.append(save(canvas,'03-now-to-midnight.png',[now_source,midnight_source,TODAY/'source/iphone-18-pro-silver-frame.png'],'Two overlapping current framed iPhones in opposing gentle perspective. Both balance numbers remain visible. Labels sit above their respective device.'))

(OUT/'source/manifest.json').write_text(json.dumps(manifest,indent=2))
sheet=Image.new('RGB',(1242,874),'#222427')
for n,m in enumerate(manifest):
 im=Image.open(ROOT/m['file']);im.thumbnail((402,874));sheet.paste(im,(n*420,0))
sheet.save(OUT/'review/contact-sheet-en-US.jpg',quality=96)
print('Created three English lead compositions at1206x2622, RGB without alpha.')
