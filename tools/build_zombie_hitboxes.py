"""Derive head hitboxes from head-weighted vertices in the source skins."""
from pathlib import Path
import json, base64
import numpy as np
ROOT=Path(__file__).resolve().parents[1]
result={}
for path in sorted((ROOT/'assets/zombies/quaternius').glob('*.gltf')):
    g=json.loads(path.read_text(encoding='utf8'));buffers=[base64.b64decode(b['uri'].split(',',1)[1]) for b in g['buffers']]
    def accessor(index):
        a=g['accessors'][index];view=g['bufferViews'][a['bufferView']]
        dtype=np.dtype({5126:'<f4',5123:'<u2',5121:'u1',5125:'<u4'}[a['componentType']]);size={'VEC3':3,'VEC4':4,'MAT4':16,'SCALAR':1}[a['type']]
        return np.ndarray((a['count'],size),dtype=dtype,buffer=buffers[view['buffer']],offset=view.get('byteOffset',0)+a.get('byteOffset',0),strides=(view.get('byteStride',size*dtype.itemsize),dtype.itemsize)).copy()
    vertices=[];bone_name=''
    for node in g['nodes']:
        if 'mesh' not in node or 'skin' not in node:continue
        skin=g['skins'][node['skin']];head=next((i for i,n in enumerate(skin['joints']) if g['nodes'][n].get('name','').lower().endswith('head')),None)
        if head is None:continue
        bone_name=g['nodes'][skin['joints'][head]]['name']
        inverse=accessor(skin['inverseBindMatrices'])[head].reshape(4,4).T
        for primitive in g['meshes'][node['mesh']]['primitives']:
            a=primitive['attributes'];p=accessor(a['POSITION']);j=accessor(a['JOINTS_0']);w=accessor(a['WEIGHTS_0'])
            selected=p[((j==head)*w).sum(axis=1)>.5]
            if len(selected):vertices.append((inverse@np.column_stack([selected,np.ones(len(selected))]).T).T[:,:3])
    if not vertices:
        print(path.name,'has no head; excluded from humanoid enemy roster');continue
    points=np.concatenate(vertices);lo=points.min(axis=0);hi=points.max(axis=0)
    entry={'bone':bone_name,'center':((lo+hi)/2).tolist(),'radius':float(max(hi-lo)*.48)}
    result[path.name]=entry;print(path.name,entry)
(ROOT/'assets/zombies/quaternius/head_hitboxes.json').write_text(json.dumps(result,indent=2),encoding='utf8')
