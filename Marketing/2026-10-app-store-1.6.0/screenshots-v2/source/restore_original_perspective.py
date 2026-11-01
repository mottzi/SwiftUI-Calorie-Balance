"""Keep the original three-dimensional product rendering pixel-for-pixel.
Replace only its visible app-screen apertures with original current captures.
"""
from pathlib import Path
from PIL import Image,ImageDraw,ImageFont,ImageOps
import numpy as np,json
ROOT=Path(__file__).resolve().parents[4]
OUT=ROOT/'Marketing/2026-10-app-store-1.6.0/screenshots-v2'
ORIGINAL=ROOT/'Marketing/archive/legacy-app-store/iphone-65/exports/iphone-65-02-customize.png'
TODAY=ROOT/'Marketing/2026-10-today/captures'
im=Image.open(ORIGINAL).convert('RGB');a=np.asarray(im).astype(int);W,H=im.size
r,g,b=a[:,:,0],a[:,:,1],a[:,:,2]
valid=(a.min(axis=2)>7)&((b>=r-1)|((a.max(axis=2)-a.min(axis=2))>=30))
combined=np.zeros((H,W),dtype=bool)
result=im.copy();manifest=[]
# The left screen-plane corners are extrapolated beyond rounded corners.
# Every subsequent phone is the same original render shifted404px right.
base_quad=[(192,440),(1070,596),(1070,2486),(192,2663)]
for i,(xmin,xmax,seedx,theme) in enumerate([(175,580,300,1),(578,984,705,2),(981,1284,1110,4)]):
 crop=Image.fromarray(valid[445:2660,xmin:xmax].astype('uint8')).copy()
 ImageDraw.floodfill(crop,(seedx-xmin,155),2)
 comp=np.asarray(crop)==2
 for ry in range(comp.shape[0]):
  xs=np.flatnonzero(comp[ry])
  if len(xs):comp[ry,xs[0]:xs[-1]+1]=True
 mask=np.zeros((H,W),dtype=bool);mask[445:2660,xmin:xmax]=comp
 # The old center phone's warm gray bar reaches the occluded screen edge.
 # Bridge that color-classification gap using the neighboring aperture edge.
 if i<2:
  for y in range(580,2530):
   xs=np.flatnonzero(mask[y])
   if len(xs) and xs[-1] < (485+404*i):
    mask[y,xs[0]:486+404*i]=True
 else:
  for y in range(501,2601):
   xs=np.flatnonzero(mask[y])
   if len(xs):mask[y,xs[0]:W]=True
 mask_image=Image.fromarray((mask*255).astype('uint8'))
 mask_image.save(OUT/'source'/f'legacy-aperture-{i+1}.png')
 source=TODAY/f'iphone-18-pro-theme-{theme:02}-dark-midnight-bg-dark-steps-off-sheen-mid-capture.png'
 capture=Image.open(source).convert('RGB');sw,sh=capture.size
 quad=[(x+404*i,y) for x,y in base_quad]
 matrix=[];values=[]
 for (x,y),(u,v) in zip(quad,[(0,0),(sw,0),(sw,sh),(0,sh)]):
  matrix.extend([[x,y,1,0,0,0,-u*x,-u*y],[0,0,0,x,y,1,-v*x,-v*y]]);values.extend([u,v])
 coefficients=np.linalg.solve(np.asarray(matrix,float),np.asarray(values,float))
 projected=capture.transform((W,H),Image.Transform.PERSPECTIVE,coefficients,Image.Resampling.BICUBIC)
 result.paste(projected,(0,0),mask_image);combined|=mask
 manifest.append({'theme':theme,'capture':str(source.relative_to(ROOT)),'plane':quad,'mask':str((OUT/'source'/f'legacy-aperture-{i+1}.png').relative_to(ROOT))})
# Hardware QA runs before the deliberately replaced heading band.
new=np.asarray(result);assert np.array_equal(new[~combined],np.asarray(im)[~combined])
hardware_unchanged=True
# Retain the untouched hardware/UI composition for all finalized locale titles.
base=result.copy()
# Keep the original blank heading region and its original title placement.
d=ImageDraw.Draw(result);d.rectangle((0,100,W,315),fill='black')
f=ImageFont.truetype('/System/Library/Fonts/SFNS.ttf',96);f.set_variation_by_axes([100,96,400,450])
parts=[('Your ','#eeeeef'),('colors.','#b7b0ef')];x=(W-sum(d.textlength(s,font=f) for s,c in parts))/2
for s,c in parts:d.text((x,194),s,font=f,fill=c,anchor='lt');x+=d.textlength(s,font=f)
(OUT/'alternatives').mkdir(exist_ok=True)
native=OUT/'alternatives/02-your-colors-original-hardware-1284x2778.png';result.save(native,optimize=True)
adapted=OUT/'alternatives/02-your-colors-original-hardware-1206x2622.png';ImageOps.fit(result,(1206,2622),method=Image.Resampling.LANCZOS).save(adapted,optimize=True)
# Original/updated comparison, same size and pose, no extra file labels.
sheet=Image.new('RGB',(1302,1389),'#242528');sheet.paste(im.resize((642,1389),Image.Resampling.LANCZOS),(0,0));sheet.paste(result.resize((642,1389),Image.Resampling.LANCZOS),(660,0));sheet.save(OUT/'review/original-hardware-comparison.jpg',quality=96)
overlay=np.asarray(im).copy();overlay[combined]=(overlay[combined]*.3+np.array([255,0,170])*.7).astype('uint8');Image.fromarray(overlay).resize((642,1389)).save(OUT/'review/legacy-aperture-overlay.png')
(OUT/'alternatives/original-hardware-manifest.json').write_text(json.dumps({'original':str(ORIGINAL.relative_to(ROOT)),'native':str(native.relative_to(ROOT)),'adapted':str(adapted.relative_to(ROOT)),'hardware_pixels_unchanged_outside_apertures':hardware_unchanged,'sources':manifest},indent=2))
print('Created native1284x2778 and adapted1206x2622. Hardware pixels outside masks are identical to original, except heading band.')

# Final titles use the original calm centered typography and no punctuation.
locale_titles={
 'en-US':[('Custom ','#dedee0'),('colors','#b9b3e5')],
 'de-DE':[('Eigene ','#dedee0'),('Farben','#b9b3e5')],
 'fr-FR':[('Vos ','#dedee0'),('couleurs','#b9b3e5')],
 'es-ES':[('Tus ','#dedee0'),('colores','#b9b3e5')]
}
# Match the other slides' visible device height while retaining the original
# three-phone perspective. Apply one uniform scale to the complete composition.
output_size=(1206,2622)
body_scale=1.03
body_size=(round(W*body_scale),round(H*body_scale))
body_position=((output_size[0]-body_size[0])//2,-154)
body=base.copy();ImageDraw.Draw(body).rectangle((0,100,W,315),fill='black')
body=body.resize(body_size,Image.Resampling.LANCZOS)
final_manifest=[]
for locale,title_parts in locale_titles.items():
 final=Image.new('RGB',output_size,'black');final.paste(body,body_position)
 fd=ImageDraw.Draw(final)
 fx=(output_size[0]-sum(fd.textlength(s,font=f) for s,c in title_parts))/2
 for text,color in title_parts:
  fd.text((fx,104),text,font=f,fill=color,anchor='lt');fx+=fd.textlength(text,font=f)
 folder=OUT/'final'/locale;folder.mkdir(parents=True,exist_ok=True)
 path=folder/'02-custom-colors.png'
 final.save(path,optimize=True)
 final_manifest.append({'locale':locale,'title':''.join(s for s,c in title_parts),'file':str(path.relative_to(ROOT)),'width':1206,'height':2622,'mode':'RGB','app_ui_locale':'en-US','original_hardware':str(ORIGINAL.relative_to(ROOT)),'sources':manifest,'hardware_pixels_unchanged_before_final_resize':hardware_unchanged,'composition_scale':body_scale,'composition_size':body_size,'composition_position':body_position,'device_aspect_ratio_preserved':True,'heading_top':104})
(OUT/'final/manifest.json').write_text(json.dumps(final_manifest,ensure_ascii=False,indent=2))
locale_sheet=Image.new('RGB',(1662,874),'#242528')
for n,m in enumerate(final_manifest):
 t=Image.open(ROOT/m['file']);t.thumbnail((402,874));locale_sheet.paste(t,(n*420,0))
locale_sheet.save(OUT/'review/final-colors-four-locales.jpg',quality=96)
print('Final original-hardware colors slide produced for all4locales.')
