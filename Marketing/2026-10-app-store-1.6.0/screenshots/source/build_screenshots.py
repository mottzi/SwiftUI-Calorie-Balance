#!/usr/bin/env python3
"""Compose App Store images from original current Count.kcal captures.
Run with the bundled workspace Python, which includes Pillow.
No app UI is synthesized or retouched. Resize, crop and alpha composite only.
"""
from PIL import Image, ImageDraw, ImageFont, ImageOps
from pathlib import Path
import json, csv

ROOT = Path(__file__).resolve().parents[4]
OUT = ROOT/'Marketing/2026-10-app-store-1.6.0/screenshots'
TODAY = ROOT/'Marketing/2026-10-today'
CARD = ROOT/'Marketing/2026-10-calorie-card'
W,H = 1206,2622
BG = '#080a0f'
WHITE = '#f5f5f7'
FONT = '/System/Library/Fonts/SFNS.ttf'
COPY = {
'en-US': ["Your day.\nIn balance.","Now.\nAnd at midnight.","Macros.\nAt a glance.","Your week.\nIn one view.","Progress.\nDay by day.","Your colors.\nYour choice."],
'de-DE': ["Dein Tag.\nIn Balance.","Jetzt.\nUnd um Mitternacht.","Deine Makros.\nAuf einen Blick.","Deine Woche.\nIm Überblick.","Dein Fortschritt.\nTag für Tag.","Deine Farben.\nDein Stil."],
'fr-FR': ["Votre journée.\nEn équilibre.","Maintenant.\nEt à minuit.","Vos macros.\nEn un coup d'œil.","Votre semaine.\nD'un seul regard.","Vos progrès.\nJour après jour.","Vos couleurs.\nVotre style."],
'es-ES': ["Tu día.\nEn equilibrio.","Ahora.\nY a medianoche.","Tus macros.\nDe un vistazo.","Tu semana.\nDe un vistazo.","Tu progreso.\nDía a día.","Tus colores.\nTu estilo."]}
LABELS={'en-US':['Now','Midnight'], 'de-DE':['Jetzt','Mitternacht'], 'fr-FR':['Maintenant','Minuit'], 'es-ES':['Ahora','Medianoche']}
SLUGS = ['balance','now-and-midnight','macros','weekly-balance','progress','themes']

def font(size,weight=650):
 f=ImageFont.truetype(FONT,size)
 f.set_variation_by_axes([100,96,400,weight])
 return f

def native(theme):
 return TODAY/'captures'/f'iphone-18-pro-theme-{theme:02}-dark-midnight-bg-dark-steps-off-sheen-mid-capture.png'

def framed(theme):
 return TODAY/'stills'/f'iphone-18-pro-silver-theme-{theme:02}-dark-midnight-bg-dark-steps-off-sheen-mid-framed.png'

def paste(canvas,path,width,x=None,y=0,crop=None):
 im=Image.open(path).convert('RGBA')
 if crop: im=im.crop(crop)
 im=im.resize((width,round(im.height*width/im.width)),Image.Resampling.LANCZOS)
 canvas.alpha_composite(im,(round((W-width)/2) if x is None else x,y))
 return im.size

def headline(canvas,text):
 d=ImageDraw.Draw(canvas)
 size=100
 while max(d.textlength(line,font=font(size)) for line in text.split('\n'))>1050:
  size-=1
 f=font(size)
 for n,line in enumerate(text.split('\n')):
  d.text((80,83+n*105),line,font=f,fill=WHITE,anchor='lt',stroke_width=0)
 return size

def build(locale,n):
 canvas=Image.new('RGBA',(W,H),BG)
 sources=[]
 if n==0:
  p=framed(1);paste(canvas,p,1100,y=350);sources=[p]
 elif n==1:
  d=ImageDraw.Draw(canvas)
  for mode,label,y in zip(['now','midnight'],LABELS[locale],[635,1625]):
   p=CARD/'stills'/f'calorie-card-theme-01-dark-{mode}-transparent.png'
   paste(canvas,p,1140,y=y);sources.append(p)
   d.text((80,y-90),label,font=font(43,560),fill='#b8bcc6',anchor='lt')
 elif n==2:
  canvas=Image.new('RGBA',(W,H),'#111216')
  p=OUT/'source'/'progress-capture.png'
  # One continuous, unretouched crop of the actual scrolled dashboard.
  # Both the complete nutrient card and complete Progress card remain visible.
  paste(canvas,p,1206,y=470,crop=(0,745,1206,2550));sources=[p]
 elif n==3:
  p=framed(2);paste(canvas,p,1290,y=350);sources=[p]
 elif n==4:
  p=OUT/'source'/'progress-capture.png'
  if not p.exists(): return None
  # A native scrolled capture is supplied for this image. Use its entire UI.
  frame=Image.open(TODAY/'source/iphone-18-pro-silver-frame.png').convert('RGBA')
  screen=Image.open(p).convert('RGBA')
  screen=screen.resize((1206,2622),Image.Resampling.LANCZOS)
  # Native frame opening at x72,y69. The original frame overlays the screen.
  composite=Image.new('RGBA',frame.size)
  mask=Image.new('L',(1206,2622));md=ImageDraw.Draw(mask)
  md.rounded_rectangle((0,0,1205,2621),radius=155,fill=255)
  composite.paste(screen,(72,69),mask);composite.alpha_composite(frame)
  composite.save(OUT/'source'/'progress-framed.png')
  paste(canvas,OUT/'source'/'progress-framed.png',1100,y=350);sources=[p,TODAY/'source/iphone-18-pro-silver-frame.png']
 elif n==5:
  # Three original calorie cards, each filling 94% of the canvas width.
  # Direct crops keep every pixel of UI faithful to its current source.
  for theme,y in zip([1,2,4],[475,1175,1875]):
   p=native(theme);paste(canvas,p,1140,y=y,crop=(46,795,1160,1458));sources.append(p)
 size=headline(canvas,COPY[locale][n])
 directory=OUT/locale;directory.mkdir(exist_ok=True)
 path=directory/f'{n+1:02}-{SLUGS[n]}.png'
 canvas.convert('RGB').save(path,optimize=True)
 large_dir=OUT/'iphone-large'/locale;large_dir.mkdir(parents=True,exist_ok=True)
 ImageOps.fit(canvas.convert('RGB'),(1320,2868),method=Image.Resampling.LANCZOS).save(large_dir/path.name,optimize=True)
 return {'locale':locale,'order':n+1,'file':str(path.relative_to(ROOT)),'width':W,'height':H,'mode':'RGB','large_file':str((large_dir/path.name).relative_to(ROOT)),'large_width':1320,'large_height':2868,'header':COPY[locale][n],'header_font_size':size,'sources':[str(x.relative_to(ROOT)) for x in sources]}

def contacts():
 for locale in COPY:
  paths=sorted((OUT/locale).glob('*.png'))
  cw,ch=301,700
  sheet=Image.new('RGB',(len(paths)*cw,ch),BG);d=ImageDraw.Draw(sheet)
  for i,p in enumerate(paths):
   im=Image.open(p);im.thumbnail((cw,655))
   sheet.paste(im,(i*cw,0))
   d.text((i*cw+15,669),p.stem,font=font(16,500),fill='white')
  sheet.save(OUT/'review'/f'contact-sheet-{locale}.jpg',quality=94)

if __name__=='__main__':
 manifest=[]
 for locale in COPY:
  for n in range(6):
   result=build(locale,n)
   if result:manifest.append(result)
 (OUT/'source'/'copy.json').write_text(json.dumps(COPY,ensure_ascii=False,indent=2))
 (OUT/'manifest.json').write_text(json.dumps(manifest,ensure_ascii=False,indent=2))
 contacts()
 print(f'Created {len(manifest)} RGB images at {W} x {H}, plus {len(manifest)} at 1320 x 2868.')
