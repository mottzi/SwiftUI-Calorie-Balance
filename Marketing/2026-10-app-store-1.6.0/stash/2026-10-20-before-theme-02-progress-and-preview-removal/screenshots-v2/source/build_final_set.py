"""Build the focused four-scene App Store set after the original hardware fix."""
from pathlib import Path
from PIL import Image,ImageDraw,ImageFont
import json,runpy,hashlib
ROOT=Path(__file__).resolve().parents[4]
OUT=ROOT/'Marketing/2026-10-app-store-1.6.0/screenshots-v2'
TODAY=ROOT/'Marketing/2026-10-today'
runpy.run_path(str(OUT/'source/restore_original_perspective.py'))
color_rows=json.loads((OUT/'final/manifest.json').read_text())
TITLES={
'en-US': [['Calorie ','balance'],['Custom ','colors'],['Your ','progress'],['Your ','week']],
'de-DE': [['','Kalorienbilanz'],['Eigene ','Farben'],['Dein ','Fortschritt'],['Deine ','Woche']],
'fr-FR': [['Bilan ','calorique'],['Vos ','couleurs'],['Vos ','progrès'],['Votre ','semaine']],
'es-ES': [['Balance ','calórico'],['Tus ','colores'],['Tu ','progreso'],['Tu ','semana']]}
SLUGS=['01-calorie-balance.png','02-custom-colors.png','03-progress.png','04-your-week.png']
W,H=1206,2622

def font(size=96):
 f=ImageFont.truetype('/System/Library/Fonts/SFNS.ttf',size);f.set_variation_by_axes([100,96,400,450]);return f

def header(canvas,parts,accent):
 d=ImageDraw.Draw(canvas);f=font();width=sum(d.textlength(s,font=f) for s in parts);assert width<=W-100
 x=(W-width)/2
 for text,color in zip(parts,['#dedee0',accent]):d.text((x,104),text,font=f,fill=color,anchor='lt');x+=d.textlength(text,font=f)
 return width

def frame_progress():
 source=ROOT/'Marketing/2026-10-app-store-1.6.0/captures/progress-en-US.png'
 screen=Image.open(source).convert('RGBA');assert screen.size==(1206,2622)
 frame=Image.open(TODAY/'source/iphone-18-pro-silver-frame.png').convert('RGBA')
 mask=Image.new('L',screen.size);ImageDraw.Draw(mask).rounded_rectangle((0,0,1205,2621),radius=155,fill=255)
 result=Image.new('RGBA',frame.size);result.paste(screen,(72,69),mask);result.alpha_composite(frame)
 path=OUT/'source/current-progress-framed.png';result.save(path)
 return path,source
progress,progress_native=frame_progress()
source_hero=TODAY/'stills/iphone-18-pro-silver-theme-01-dark-midnight-bg-dark-steps-off-sheen-mid-framed.png'
source_week=TODAY/'stills/iphone-18-pro-silver-theme-02-dark-midnight-bg-dark-steps-off-sheen-mid-framed.png'
scene_source={0:source_hero,2:progress,3:source_week}
manifest=[]
for locale,titles in TITLES.items():
 folder=OUT/'final'/locale;folder.mkdir(parents=True,exist_ok=True)
 for n in range(4):
  path=folder/SLUGS[n]
  if n==1:
   row=next(x for x in color_rows if x['locale']==locale);row['scene']=2
   row['heading_font']='SF Pro Display variable, weight450, size96'
   manifest.append(row);continue
  canvas=Image.new('RGB',(W,H),'#060709')
  original=Image.open(scene_source[n]).convert('RGBA')
  width=1160;phone=original.resize((width,round(original.height*width/original.width)),Image.Resampling.LANCZOS)
  canvas.paste(phone,(23,255),phone)
  text_width=header(canvas,titles[n],'#b1a8ed' if n==3 else '#86b6e7')
  canvas.save(path,optimize=True)
  sources=[str(scene_source[n].relative_to(ROOT))]
  if n==2:sources.extend([str(progress_native.relative_to(ROOT)),str((TODAY/'source/iphone-18-pro-silver-frame.png').relative_to(ROOT))])
  manifest.append({'locale':locale,'scene':n+1,'title':''.join(titles[n]),'file':str(path.relative_to(ROOT)),'width':W,'height':H,'mode':'RGB','app_ui_locale':'en-US','source_paths':sources,'heading_font':'SF Pro Display variable, weight450, size96','heading_width':text_width,'device_width':1160,'device_position':[23,255],'device_aspect_ratio_preserved':True})
 # Clean review contact sheets, separated by18px gutters.
 sheet=Image.new('RGB',(1662,874),'#242528')
 for n,name in enumerate(SLUGS):
  preview=Image.open(folder/name);preview.thumbnail((402,874));sheet.paste(preview,(n*420,0))
 sheet.save(OUT/'review'/f'final-set-{locale}.jpg',quality=96)
manifest.sort(key=lambda x:(list(TITLES).index(x['locale']),x['scene']))
(OUT/'final/manifest.json').write_text(json.dumps(manifest,ensure_ascii=False,indent=2))
qa=[]
for row in manifest:
 p=ROOT/row['file'];im=Image.open(p);im.load();assert im.size==(1206,2622) and im.mode=='RGB'
 qa.append({'file':row['file'],'size':list(im.size),'mode':im.mode,'sha256':hashlib.sha256(p.read_bytes()).hexdigest()})
assert len(qa)==16
(OUT/'review/final-set-qa.json').write_text(json.dumps({'passed':True,'files':qa,'image_count':16,'scene_count':4,'locale_count':4,'no_alpha':True,'all_sizes':[1206,2622],'original_hardware_mask_qa':True},indent=2))
print('PASS16 final RGB PNGs,4scenesx4locales,1206x2622. Contact sheets and manifest regenerated.')
