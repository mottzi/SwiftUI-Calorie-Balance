from pathlib import Path
import json,hashlib,shutil
root=Path('/Users/berken/Development/Swift/Count.kcal/Marketing/2026-10-app-store-1.6.0')
out=root/'screenshots-v2';stash=root/'stash/2026-10-20-before-theme-02-progress-and-preview-removal'
stash.mkdir(parents=True,exist_ok=True)
old_manifest=json.loads((out/'final/manifest.json').read_text())
# Freeze approved PNG bytes, including the owner's corrected custom-color scale.
rows=[]
for row in old_manifest:
 if row.get('scene') in [1,2]:
  source=Path('/Users/berken/Development/Swift/Count.kcal')/row['file']
  target=out/'source/approved-first-two'/row['locale']/source.name
  target.parent.mkdir(parents=True,exist_ok=True);shutil.copy2(source,target)
  row=dict(row);row['approved_sha256']=hashlib.sha256(source.read_bytes()).hexdigest();row['approved_source']=str(target.relative_to(root));rows.append(row)
(out/'source/approved-first-two-manifest.json').write_text(json.dumps(rows,ensure_ascii=False,indent=2))
# Keep the old build recipe beside the stashed exports.
old_script=stash/'screenshots-v2/source/build_final_set.py';old_script.parent.mkdir(parents=True,exist_ok=True);shutil.copy2(out/'source/build_final_set.py',old_script)
move_paths=[root/'preview',root/'preview-v2',root/'captures/progress-en-US.png',root/'captures/dashboard-scroll-en-US.mp4',out/'source/current-progress-framed.png',out/'source/manifest.json',out/'review',out/'final/manifest.json',out/'alternatives',out/'en-US']
for locale in ['en-US','de-DE','fr-FR','es-ES']:
 move_paths += [out/'final'/locale/'03-progress.png',out/'final'/locale/'04-your-week.png']
records=[]
for source in move_paths:
 if not source.exists():continue
 rel=source.relative_to(root);target=stash/rel
 assert not target.exists(),target
 for p in ([source] if source.is_file() else sorted(x for x in source.rglob('*') if x.is_file())):
  digest=hashlib.sha256()
  with p.open('rb') as f:
   while chunk:=f.read(1024*1024):digest.update(chunk)
  records.append({'original':str(p.relative_to(root)),'stashed':str((stash/p.relative_to(root)).relative_to(root)),'bytes':p.stat().st_size,'sha256':digest.hexdigest()})
 target.parent.mkdir(parents=True,exist_ok=True);shutil.move(str(source),str(target))
(out/'review').mkdir(exist_ok=True)
(stash/'stash-manifest.json').write_text(json.dumps({'reason':'Superseded four-image set and all App Preview production retained before the three-image Theme2 Progress revision.','files':records},indent=2))
print(f'Stashed{len(records)}files, byte hashes recorded. Approved8first-two PNGs frozen and unchanged.')
