"""Import the genuine CC BY iPhone 17 Pro mesh into flat SceneKit buffers.

Geometry and node transforms come from the GLB unchanged, followed by the
upstream Y=pi orientation and one uniform normalization. Screen UVs use the
upstream mirrorX correction. This does not construct a substitute phone.
"""
from pathlib import Path
from PIL import Image,ImageDraw,ImageFilter
import json,struct,shutil,hashlib
import numpy as np

HERE=Path(__file__).resolve().parent
INPUT=Path('/private/tmp/count-kcal-phone-mockup-studio/source/iphone_17_pro.glb')
DEST=HERE/'model'
DEST.mkdir(exist_ok=True)
local=DEST/'iphone_17_pro.glb'
if INPUT.exists() and not local.exists():shutil.copy2(INPUT,local)
data=local.read_bytes();length,kind=struct.unpack_from('<II',data,12)
g=json.loads(data[20:20+length]);bin_offset=20+length;bin_length,bin_kind=struct.unpack_from('<II',data,bin_offset);blob=data[bin_offset+8:bin_offset+8+bin_length]
DTS={5126:'<f4',5125:'<u4',5123:'<u2',5122:'<i2',5121:'u1',5120:'i1'}
COMPS={'SCALAR':1,'VEC2':2,'VEC3':3,'VEC4':4,'MAT4':16}

def accessor(index):
 a=g['accessors'][index];v=g['bufferViews'][a['bufferView']];dtype=np.dtype(DTS[a['componentType']]);n=COMPS[a['type']]
 offset=v.get('byteOffset',0)+a.get('byteOffset',0);stride=v.get('byteStride',dtype.itemsize*n)
 result=np.ndarray((a['count'],n),dtype=dtype,buffer=blob,offset=offset,strides=(stride,dtype.itemsize)).copy()
 if a.get('normalized'):
  if dtype.kind=='u':result=result.astype(float)/np.iinfo(dtype).max
  elif dtype.kind=='i':result=np.maximum(-1,result.astype(float)/np.iinfo(dtype).max)
 return result

def node_matrix(n):
 if 'matrix' in n:return np.array(n['matrix'],float).reshape((4,4),order='F')
 x,y,z,w=n.get('rotation',[0,0,0,1]);m=np.array([[1-2*(y*y+z*z),2*(x*y-z*w),2*(x*z+y*w),0],[2*(x*y+z*w),1-2*(x*x+z*z),2*(y*z-x*w),0],[2*(x*z-y*w),2*(y*z+x*w),1-2*(x*x+y*y),0],[0,0,0,1]],float)
 m[:3,:3] = m[:3,:3]@np.diag(n.get('scale',[1,1,1]));m[:3,3]=n.get('translation',[0,0,0]);return m

parts=[]
def visit(index,parent):
 n=g['nodes'][index];world=parent@node_matrix(n)
 if 'mesh' in n:
  for primitive in g['meshes'][n['mesh']]['primitives']:
   assert primitive.get('mode',4)==4
   attrs=primitive['attributes'];p=accessor(attrs['POSITION']);ones=np.ones((len(p),1));positions=(world@np.concatenate([p,ones],axis=1).T).T[:,:3]
   normals=accessor(attrs['NORMAL']) if 'NORMAL' in attrs else np.tile([0,0,1],(len(p),1))
   normals=(np.linalg.inv(world[:3,:3]).T@normals.T).T;normals/=np.maximum(np.linalg.norm(normals,axis=1,keepdims=True),1e-10)
   uv=accessor(attrs['TEXCOORD_0']) if 'TEXCOORD_0' in attrs else np.zeros((len(p),2))
   indices=accessor(primitive['indices']).reshape(-1) if 'indices' in primitive else np.arange(len(p))
   parts.append({'name':n.get('name','mesh'),'positions':positions,'normals':normals,'uv':uv,'indices':indices,'material':primitive.get('material',0)})
 for child in n.get('children',[]):visit(child,world)
orientation=np.diag([-1,1,-1,1])
for index in g['scenes'][g.get('scene',0)]['nodes']:visit(index,orientation)
allp=np.concatenate([p['positions'] for p in parts]);lo=allp.min(0);hi=allp.max(0);center=(lo+hi)/2;scale=3/(hi[1]-lo[1])
material_images={}
for i,im in enumerate(g.get('images',[])):
 v=g['bufferViews'][im['bufferView']];content=blob[v.get('byteOffset',0):v.get('byteOffset',0)+v['byteLength']]
 ext='.jpg' if im.get('mimeType')=='image/jpeg' else '.png';f=DEST/f'texture-{i:02d}{ext}';f.write_bytes(content);material_images[i]=f.name
rows=[]
for i,part in enumerate(parts):
 p=(part['positions']-center)*scale;n=part['normals'];uv=part['uv'].copy();material=g['materials'][part['material']]
 if material.get('name')=='OLED':
  # GLTF image coordinates have origin at the top. SceneKit's sampled UVs
  # are converted explicitly; the real screen keeps its native mesh UVs.
  uv[:,0]=1-uv[:,0]
  # SceneKit image sampling already matches the model vertical UV direction.
 interleaved=np.concatenate([p,n,uv],axis=1).astype('<f4');vertices=DEST/f'mesh-{i:02d}-vertices.bin';indices=DEST/f'mesh-{i:02d}-indices.bin'
 vertices.write_bytes(interleaved.tobytes());indices.write_bytes(part['indices'].astype('<u4').tobytes())
 rows.append({'name':part['name'],'vertices':vertices.name,'indices':indices.name,'vertexCount':len(p),'indexCount':len(part['indices']),'material':part['material']})
materials=[]
for m in g['materials']:
 p=m.get('pbrMetallicRoughness',{});record={'name':m.get('name','material'),'color':p.get('baseColorFactor',[1,1,1,1]),'metalness':p.get('metallicFactor',1),'roughness':p.get('roughnessFactor',1),'alphaMode':m.get('alphaMode','OPAQUE')}
 if 'baseColorTexture' in p:
  texture=g['textures'][p['baseColorTexture']['index']];record['texture']=material_images[texture['source']]
 materials.append(record)
manifest={'source':'iphone_17_pro.glb','source_sha256':hashlib.sha256(data).hexdigest(),'author':'Ranguel','license':'CC BY 4.0','model':'iPhone 17 Pro','normalizationHeight':3,'uniformScale':scale,'sourceBounds':[lo.tolist(),hi.tolist()],'meshes':rows,'materials':materials,'screenMaterial':'OLED','upstreamRootRotation':[0,3.141592653589793,0],'upstreamScreenMirrorX':True}
(DEST/'scene.json').write_text(json.dumps(manifest,indent=2))
# Soft studio strips for genuine metal reflections, not a painted device edge.
w,h=2048,1024;environment=Image.new('RGB',(w,h),(33,35,41));d=ImageDraw.Draw(environment)
d.rectangle((320,130,500,820),fill=(245,246,250));d.rectangle((1170,180,1450,850),fill=(170,178,195));d.rectangle((1710,40,1860,700),fill=(236,238,245));environment=environment.filter(ImageFilter.GaussianBlur(34));environment.save(DEST/'studio-environment.png')
print('Prepared',len(rows),'genuine mesh primitives; normalized bounds',((hi-lo)*scale).tolist())
