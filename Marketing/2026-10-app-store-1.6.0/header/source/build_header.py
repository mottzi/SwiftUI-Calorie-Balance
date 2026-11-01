#!/usr/bin/env python3
"""Lay out original Count.kcal UI cutouts without altering their content."""
from pathlib import Path
from PIL import Image, ImageFilter, ImageEnhance
import hashlib, json, math

ROOT=Path(__file__).resolve().parents[4]
OUT=ROOT/'Marketing/2026-10-app-store-1.6.0/header'
TODAY=ROOT/'Marketing/2026-10-today/captures'
MAIN=ROOT/'Marketing/2026-10-calorie-card/stills/calorie-card-theme-01-dark-midnight-transparent.png'
SIZE=(3840,1646)
BG=(8,10,15)
CROP=(46,795,1160,1458)

def themed(theme):
 return TODAY/f'iphone-18-pro-theme-{theme:02}-dark-midnight-bg-dark-steps-off-sheen-mid-capture.png'

def read(path,crop=None):
 im=Image.open(path).convert('RGBA')
 return im.crop(crop) if crop else im

def layer(canvas,im,width,x,y,brightness=1,shadow=True):
 im=im.resize((width,round(im.height*width/im.width)),Image.Resampling.LANCZOS)
 if brightness!=1:
  rgb=ImageEnhance.Brightness(im.convert('RGB')).enhance(brightness)
  rgb.putalpha(im.getchannel('A'));im=rgb
 if shadow:
  sh=Image.new('RGBA',SIZE)
  alpha=im.getchannel('A').point(lambda p:round(p*.8))
  black=Image.new('RGBA',im.size,(0,0,0,0));black.putalpha(alpha)
  sh.alpha_composite(black,(x,y+45));sh=sh.filter(ImageFilter.GaussianBlur(65))
  canvas.alpha_composite(sh)
 canvas.alpha_composite(im,(x,y))
 return {'x':x,'y':y,'width':im.width,'height':im.height,'brightness':brightness}

canvas=Image.new('RGBA',SIZE,BG)
# A subdued radial lift separates the card silhouette from the near-black field.
glow=Image.new('RGBA',SIZE)
px=glow.load()
for y in range(SIZE[1]):
 for x in range(SIZE[0]):
  radius=((x-1920)/2100)**2+((y-1100)/1300)**2
  a=round(8*math.exp(-radius*2.4))
  px[x,y]=(25,35,55,a)
canvas.alpha_composite(glow)
placements=[]
for theme,x in [(2,-650),(4,2890)]:
 p=themed(theme)
 placements.append({'source':str(p.relative_to(ROOT)),'theme':theme,'crop':list(CROP),**layer(canvas,read(p,CROP),1600,x,350,.62)})
placements.append({'source':str(MAIN.relative_to(ROOT)),'theme':1,'crop':None,**layer(canvas,read(MAIN),2260,790,154)})
path=OUT/'count-kcal-product-page-header-3840x1646.png'
canvas.convert('RGB').save(path,optimize=True)
proof=canvas.convert('RGB');proof.thumbnail((1920,823));proof.save(OUT/'review-1920.jpg',quality=95)
manifest={'file':str(path.relative_to(ROOT)),'width':SIZE[0],'height':SIZE[1],'mode':'RGB','alpha':False,'background':'#080A0F','placements_back_to_front':placements,'source_sha256':{x['source']:hashlib.sha256((ROOT/x['source']).read_bytes()).hexdigest() for x in placements}}
(OUT/'manifest.json').write_text(json.dumps(manifest,indent=2)+'\n')
print(json.dumps({'file':str(path),'dimensions':Image.open(path).size,'mode':Image.open(path).mode,'bytes':path.stat().st_size}))
