"""Bake a compact grass-and-path navigation grid. Requires NumPy only at build time."""
from pathlib import Path
import json, gzip, math
import numpy as np
ROOT=Path(__file__).resolve().parents[1]
layout=json.loads((ROOT/'data/park_layout.json').read_text(encoding='utf8'))
config=json.loads((ROOT/'data/survival_settings.json').read_text(encoding='utf8'))
cell=config['navigation']['cell_size']
boundary=np.array(layout['boundary'])
origin=np.floor(boundary.min(axis=0)/cell)*cell-cell
shape=np.ceil((boundary.max(axis=0)-origin)/cell).astype(int)+2
xx,zz=np.meshgrid(origin[0]+np.arange(shape[0])*cell,origin[1]+np.arange(shape[1])*cell)
def inside(poly):
    poly=np.array(poly); out=np.zeros(xx.shape,dtype=bool)
    lo=poly.min(axis=0)-1;hi=poly.max(axis=0)+1
    crop=(xx>=lo[0])&(xx<=hi[0])&(zz>=lo[1])&(zz<=hi[1])
    xs=xx[crop];zs=zz[crop];result=np.zeros(xs.shape,dtype=bool)
    for a,b in zip(poly,np.roll(poly,1,axis=0)):
        if a[1]==b[1]:continue
        result^=((a[1]>zs)!=(b[1]>zs))&(xs<(b[0]-a[0])*(zs-a[1])/(b[1]-a[1])+a[0])
    out[crop]=result;return out
solid=~inside(layout['boundary'])
for feature in layout['waters']+layout['buildings']:
    solid|=inside(feature['points'])
# A half-metre actor needs clearance along lake shores and building corners.
original=solid.copy()
for dz,dx in ((0,1),(0,-1),(1,0),(-1,0)):
    solid|=np.roll(original,(dz,dx),axis=(0,1))
trees=json.loads((ROOT/'data/vegetation_layout.json').read_text(encoding='utf8'))['trees']
for tree in trees:
    px,pz=tree[1:3];ix=round((px-origin[0])/cell);iz=round((pz-origin[1])/cell)
    if 0<=ix<shape[0] and 0<=iz<shape[1] and (xx[iz,ix]-px)**2+(zz[iz,ix]-pz)**2<1.1**2:
        solid[iz,ix]=True
# Enclosed padel parcels and nets are obstacles, rather than spawn locations.
sports=json.loads((ROOT/'data/sports_layout.json').read_text(encoding='utf8'))
for court in sports['courts']:
    if court['kind']=='padel':solid|=inside(court['polygon'])
solid[[0,-1],:]=True;solid[:,[0,-1]]=True
raw=solid.astype('uint8').tobytes()
(ROOT/'data/survival_navigation.bin.gz').write_bytes(gzip.compress(raw,mtime=0))
metadata={'origin':origin.tolist(),'size':shape.tolist(),'cell_size':cell,'bytes':len(raw),'blocked':int(solid.sum()),'source':'park_layout.json + vegetation_layout.json + sports_layout.json; static furniture added at runtime'}
(ROOT/'data/survival_navigation.json').write_text(json.dumps(metadata,indent=2),encoding='utf8')
print(metadata)
