"""Bake the bundled Quaternius glTFs into shared vertex animation data.

Run with Python + NumPy. Originals remain unchanged. Only body-part meshes are
included in civilian crowds; props/weapons are excluded. No runtime dependencies.
"""
import base64, gzip, json, math
from pathlib import Path
import numpy as np

ROOT=Path(__file__).resolve().parents[1]
ASSETS=ROOT/'assets/characters/crowd'
CLIPS=['Walk','Idle_Neutral','Idle','Wave','Interact']
FRAMES=24
WIDTH=1024
MODELS={
 'men':['Beach','Casual_2','Casual_Hoodie','Farmer','Punk','Suit','Worker'],
 'women':['Casual','Formal','Punk','Suit','Worker'],
}
TYPES={5120:'i1',5121:'u1',5122:'<i2',5123:'<u2',5125:'<u4',5126:'<f4'}
SIZES={'SCALAR':1,'VEC2':2,'VEC3':3,'VEC4':4,'MAT4':16}

def quat_matrix(q):
 x,y,z,w=q
 return np.array([[1-2*(y*y+z*z),2*(x*y-z*w),2*(x*z+y*w)],
 [2*(x*y+z*w),1-2*(x*x+z*z),2*(y*z-x*w)],
 [2*(x*z-y*w),2*(y*z+x*w),1-2*(x*x+y*y)]])

def slerp(a,b,t):
 dot=float(a@b)
 if dot<0:b=-b;dot=-dot
 if dot>.9995:
  q=a+(b-a)*t
  return q/np.linalg.norm(q)
 angle=math.acos(np.clip(dot,-1,1))
 return (math.sin((1-t)*angle)*a+math.sin(t*angle)*b)/math.sin(angle)

def bake(path,sex):
 g=json.loads(path.read_text())
 buffers=[base64.b64decode(b['uri'].split(',',1)[1]) for b in g['buffers']]
 cache={}
 def accessor(i):
  if i in cache:return cache[i]
  a=g['accessors'][i];v=g['bufferViews'][a['bufferView']]
  dtype=np.dtype(TYPES[a['componentType']]);n=SIZES[a['type']]
  out=np.ndarray((a['count'],n),dtype=dtype,buffer=buffers[v['buffer']],
   offset=v.get('byteOffset',0)+a.get('byteOffset',0),strides=(v.get('byteStride',n*dtype.itemsize),dtype.itemsize)).copy()
  if a.get('normalized') and a['componentType']!=5126:out=out/np.iinfo(dtype).max
  cache[i]=out
  return out
 nodes=g['nodes'];parents={}
 for i,node in enumerate(nodes):
  for child in node.get('children',[]):parents[child]=i
 parts=[];offset=0;part_count=0
 for node in nodes:
  if 'mesh' not in node or not any(node.get('name','').endswith('_'+part) for part in ['Body','Head','Legs','Pants','Feet']):continue
  part_count+=1
  skin=g['skins'][node['skin']]
  inverses=accessor(skin['inverseBindMatrices']).reshape(-1,4,4).transpose(0,2,1)
  for primitive in g['meshes'][node['mesh']]['primitives']:
   a=primitive['attributes']
   used,local_indices=np.unique(accessor(primitive['indices']).ravel(),return_inverse=True)
   p=accessor(a['POSITION'])[used];n=accessor(a['NORMAL'])[used]
   material=g['materials'][primitive['material']]
   rgba=material.get('pbrMetallicRoughness',{}).get('baseColorFactor',[1,1,1,1])[:3]
   # Alpha is a clothing-tint mask, not transparency.
   tint=0.0 if any(s in material.get('name','').lower() for s in ['skin','hair','eye']) else 1.0
   colors=np.tile(rgba+[tint],(len(p),1))
   indices=local_indices+offset
   parts.append((p,n,accessor(a['JOINTS_0'])[used].astype(int),accessor(a['WEIGHTS_0'])[used],skin['joints'],inverses,colors,indices))
   offset+=len(p)
 assert part_count==4, f'{path}: expected head, body, legs/pants and feet'
 def pose(animation,time):
  trs=[{k:np.array(n.get(k,default),dtype=float) for k,default in [('translation',[0,0,0]),('rotation',[0,0,0,1]),('scale',[1,1,1])]} for n in nodes]
  for channel in animation['channels']:
   sampler=animation['samplers'][channel['sampler']];times=accessor(sampler['input']).ravel();values=accessor(sampler['output'])
   end=int(np.searchsorted(times,time,side='right'));end=min(end,len(times)-1);start=max(0,end-1)
   alpha=0 if end==start else np.clip((time-times[start])/(times[end]-times[start]),0,1)
   target=channel['target'];key=target['path']
   if key not in trs[target['node']]:continue
   value=slerp(values[start],values[end],alpha) if key=='rotation' else values[start]*(1-alpha)+values[end]*alpha
   trs[target['node']][key]=value
  matrices={}
  def matrix(i):
   if i in matrices:return matrices[i]
   t=trs[i];m=np.eye(4);m[:3,:3]=quat_matrix(t['rotation'])@np.diag(t['scale']);m[:3,3]=t['translation']
   matrices[i]=matrix(parents[i])@m if i in parents else m
   return matrices[i]
  positions=[];normals=[]
  for p,n,j,w,joints,inverses,colors,indices in parts:
   bones=np.array([matrix(i) for i in joints])@inverses
   blended=(bones[j]*w[:,:,None,None]).sum(axis=1)
   positions.append(np.einsum('nij,nj->ni',blended[:,:3,:3],p)+blended[:,:3,3])
   normal=np.einsum('nij,nj->ni',blended[:,:3,:3],n)
   normals.append(normal/np.maximum(np.linalg.norm(normal,axis=1,keepdims=True),1e-9))
  return np.concatenate(positions),np.concatenate(normals)
 animations={a['name']:a for a in g['animations']}
 all_p=[];all_n=[];lengths=[]
 for clip in CLIPS:
  animation=animations[clip]
  length=max(float(accessor(s['input'])[-1,0]) for s in animation['samplers']);lengths.append(length)
  for frame in range(FRAMES):
   p,n=pose(animation,length*frame/FRAMES)
   # Author models face +Z. Convert to the game's -Z forward convention.
   p[:,[0,2]]*=-1;n[:,[0,2]]*=-1
   all_p.append(p);all_n.append(n)
 all_p=np.array(all_p);all_n=np.array(all_n)
 count=all_p.shape[1];rows=math.ceil(count/WIDTH);height=rows*FRAMES*len(CLIPS)
 lo=all_p.min(axis=(0,1));hi=all_p.max(axis=(0,1));extent=np.maximum(hi-lo,1e-5)
 output=ASSETS/'baked'/sex/path.stem;output.mkdir(parents=True,exist_ok=True)
 for name,values in [('positions',(all_p-lo)/extent),('normals',all_n*.5+.5)]:
  texture=np.zeros((len(all_p),rows*WIDTH,4),dtype='<f2')
  texture[:,:count,:3]=values;texture[:,:count,3]=1
  (output/(name+'.bin.gz')).write_bytes(gzip.compress(texture.tobytes(),compresslevel=6,mtime=0))
 mesh={'positions':all_p[FRAMES].tolist(),'normals':all_n[FRAMES].tolist(),
 'colors':np.concatenate([part[-2] for part in parts]).tolist(),
 'indices':np.concatenate([part[-1] for part in parts]).astype(int).tolist()}
 (output/'mesh.json').write_text(json.dumps(mesh,separators=(',',':')))
 return {'id':sex+'_'+path.stem,'gender':sex,'source':f'res://assets/characters/crowd/{sex}/{path.name}',
 'directory':'res://'+output.relative_to(ROOT).as_posix(),'width':WIDTH,'height':height,'rows':rows,
 'vertices':count,'frames':FRAMES,'clips':CLIPS,'lengths':lengths,'min':lo.tolist(),'extent':extent.tolist()}

if __name__=='__main__':
 manifest=[]
 for sex,models in MODELS.items():
  for name in models:
   item=bake(ASSETS/sex/(name+'.gltf'),sex);manifest.append(item)
   print(item['id'],item['vertices'],'vertices',flush=True)
 (ASSETS/'manifest.json').write_text(json.dumps(manifest,indent=2))
