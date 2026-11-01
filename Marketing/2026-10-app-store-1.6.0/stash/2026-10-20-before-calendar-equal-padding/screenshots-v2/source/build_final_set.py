"""Build the three-image set while preserving the two approved exports exactly.

Requires the new native Theme2 Progress-at-top capture. Superseded media are
retained under the collection's clearly named stash directory. This script
never calls the earlier color compositor or changes the approved PNG bytes.
"""
from pathlib import Path
from PIL import Image,ImageDraw,ImageFont
import json,hashlib,shutil,argparse
ROOT=Path(__file__).resolve().parents[4]
COLLECTION=ROOT/'Marketing/2026-10-app-store-1.6.0'
OUT=COLLECTION/'screenshots-v2'
TODAY=ROOT/'Marketing/2026-10-today'
SOURCE=COLLECTION/'captures/progress-theme-02-top-en-US.png'
APPROVED=OUT/'source/approved-first-two-manifest.json'
TITLES={'en-US':['Your ','progress'],'de-DE':['Dein ','Fortschritt'],'fr-FR':['Vos ','progrès'],'es-ES':['Tu ','progreso']}
SLUGS=['01-calorie-balance.png','02-custom-colors.png','03-progress.png']
W,H=1206,2622
FONT_SIZE=96
FONT_WEIGHT=450
HEADING_TOP=104
ACCENT='#b1a8ed'

def sha(path):return hashlib.sha256(path.read_bytes()).hexdigest()

def font():
 f=ImageFont.truetype('/System/Library/Fonts/SFNS.ttf',FONT_SIZE)
 f.set_variation_by_axes([100,96,400,FONT_WEIGHT]);return f

def heading_geometry(parts):
 f=font();full=''.join(parts)
 # Align glyph baselines, then position the full line's highest glyph at y104.
 # Separate 'lt' anchors incorrectly raised lowercase 'progress' by18px.
 baseline=HEADING_TOP-f.getbbox(full,anchor='ls')[1]
 widths=[f.getlength(s) for s in parts];width=sum(widths)
 assert width<=W-100
 return {'width':width,'baseline':baseline,'fragment_baselines':[baseline]*len(parts),'fragment_tops':[baseline+f.getbbox(s,anchor='ls')[1] for s in parts]}

def header(canvas,parts):
 d=ImageDraw.Draw(canvas);f=font();g=heading_geometry(parts);x=(W-g['width'])/2
 for text,color in zip(parts,['#dedee0',ACCENT]):
  d.text((x,g['baseline']),text,font=f,fill=color,anchor='ls');x+=d.textlength(text,font=f)
 return g

def approved_rows():
 rows=json.loads(APPROVED.read_text());assert len(rows)==8
 for row in rows:
  target=ROOT/row['file'];backup=COLLECTION/row['approved_source']
  assert sha(backup)==row['approved_sha256'],backup
  if not target.exists():
   target.parent.mkdir(parents=True,exist_ok=True);shutil.copy2(backup,target)
  assert sha(target)==row['approved_sha256'],f'Approved image changed: {target}'
 return rows

def frame_progress():
 screen=Image.open(SOURCE).convert('RGBA');assert screen.size==(1206,2622)
 frame_path=TODAY/'source/iphone-18-pro-silver-frame.png'
 frame=Image.open(frame_path).convert('RGBA')
 mask=Image.new('L',screen.size);ImageDraw.Draw(mask).rounded_rectangle((0,0,1205,2621),radius=155,fill=255)
 result=Image.new('RGBA',frame.size);result.paste(screen,(72,69),mask);result.alpha_composite(frame)
 path=OUT/'source/current-progress-theme-02-top-framed.png';result.save(path)
 return path,frame_path

def build():
 if not SOURCE.exists():raise SystemExit(f'Waiting for authorized new native capture: {SOURCE}')
 rows=approved_rows();manifest=[dict(r) for r in rows];framed,frame_path=frame_progress()
 for locale,parts in TITLES.items():
  folder=OUT/'final'/locale;folder.mkdir(parents=True,exist_ok=True)
  assert not (folder/'04-your-week.png').exists(),'Superseded fourth screenshot must remain stashed.'
  canvas=Image.new('RGB',(W,H),'#060709');original=Image.open(framed).convert('RGBA')
  phone=original.resize((1160,round(original.height*1160/original.width)),Image.Resampling.LANCZOS)
  canvas.paste(phone,(23,255),phone);geometry=header(canvas,parts)
  path=folder/'03-progress.png';canvas.save(path,optimize=True)
  manifest.append({'locale':locale,'scene':3,'title':''.join(parts),'file':str(path.relative_to(ROOT)),'width':W,'height':H,'mode':'RGB','app_ui_locale':'en-US','theme':2,'capture_ui_order':['Progress','Calories','Nutrients below viewport'],'capture_scroll_position':'top','source_capture_sha256':sha(SOURCE),'source_paths':[str(SOURCE.relative_to(ROOT)),str(frame_path.relative_to(ROOT))],'heading_font':'SF Pro Display variable, weight450, size96','heading_top':HEADING_TOP,'heading_anchor':'ls','heading_geometry':geometry,'heading_accent':ACCENT,'device_width':1160,'device_position':[23,255],'device_aspect_ratio_preserved':True})
  # Three full images, separated by18px gutters, with no extra review labels.
  sheet=Image.new('RGB',(1242,874),'#242528')
  for n,name in enumerate(SLUGS):
   preview=Image.open(folder/name);preview.thumbnail((402,874));sheet.paste(preview,(n*420,0))
  sheet.save(OUT/'review'/f'final-set-{locale}.jpg',quality=96)
 manifest.sort(key=lambda x:(list(TITLES).index(x['locale']),x['scene']))
 (OUT/'final/manifest.json').write_text(json.dumps(manifest,ensure_ascii=False,indent=2))
 qa=[]
 for row in manifest:
  path=ROOT/row['file'];im=Image.open(path);im.load();assert im.size==(W,H) and im.mode=='RGB'
  qa.append({'file':row['file'],'size':list(im.size),'mode':im.mode,'sha256':sha(path)})
 approved_rows() # Verify that the first two PNGs stayed byte-identical.
 assert len(qa)==12
 (OUT/'review/final-set-qa.json').write_text(json.dumps({'passed':True,'files':qa,'image_count':12,'scene_count':3,'locale_count':4,'no_alpha':True,'all_sizes':[W,H],'approved_first_eight_pngs_byte_identical':True,'custom_colors_parent_scale_preserved':True,'progress_theme':2,'heading_shared_baseline':True,'source_capture':str(SOURCE.relative_to(ROOT))},indent=2))
 print('PASS:12 final RGB PNGs,3scenes x4locales,1206x2622. First8approved PNGs byte-identical.')

if __name__=='__main__':
 parser=argparse.ArgumentParser();parser.add_argument('--check-heading',action='store_true');args=parser.parse_args()
 if args.check_heading:print(json.dumps({locale:heading_geometry(parts) for locale,parts in TITLES.items()},indent=2))
 else:build()
