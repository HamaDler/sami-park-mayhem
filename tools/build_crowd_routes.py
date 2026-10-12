"""Build a civilian walking graph from the park's mapped path centerlines."""
import json,math
from collections import defaultdict
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1]
def inside(p,poly):
 result=False
 for a,b in zip(poly,poly[1:]+poly[:1]):
  if (a[1]>p[1])!=(b[1]>p[1]) and p[0]<(b[0]-a[0])*(p[1]-a[1])/(b[1]-a[1])+a[0]:result=not result
 return result
def build(layout):
 polygons=[x['points'] for x in layout['waters']+layout['buildings']]
 rectangles=[(min(p[0] for p in poly),min(p[1] for p in poly),max(p[0] for p in poly),max(p[1] for p in poly)) for poly in polygons]
 def safe(p):
  if not inside(p,layout['boundary']):return False
  for poly,(x,y,r,b) in zip(polygons,rectangles):
   if x<=p[0]<=r and y<=p[1]<=b and inside(p,poly):return False
  return True
 segments=[];cells=defaultdict(list)
 for path in layout['paths']:
  for a,b in zip(path['points'],path['points'][1:]):
   length=math.dist(a,b)
   if length<.05:continue
   index=len(segments);segments.append((a,b,float(path['width']),length))
   for x in range(math.floor(min(a[0],b[0])/32),math.floor(max(a[0],b[0])/32)+1):
    for y in range(math.floor(min(a[1],b[1])/32),math.floor(max(a[1],b[1])/32)+1):cells[x,y].append(index)
 cuts=[{0.0,1.0} for _ in segments];checked=set()
 def cross(a,b):return a[0]*b[1]-a[1]*b[0]
 for entries in cells.values():
  for i in entries:
   for j in entries:
    if j<=i or (i,j) in checked:continue
    checked.add((i,j));a,b,_,length=segments[i];c,d,_,other_length=segments[j]
    ab=(b[0]-a[0],b[1]-a[1]);cd=(d[0]-c[0],d[1]-c[1]);ac=(c[0]-a[0],c[1]-a[1]);den=cross(ab,cd)
    if abs(den)>1e-8:
     t=cross(ac,cd)/den;u=cross(ac,ab)/den
     if -.001<=t<=1.001 and -.001<=u<=1.001:
      cuts[i].add(max(0,min(1,t)));cuts[j].add(max(0,min(1,u)))
    # Join path endpoints that touch the interior of another centerline.
    for p in [c,d]:
     t=((p[0]-a[0])*ab[0]+(p[1]-a[1])*ab[1])/(length*length)
     if 0<t<1 and math.dist(p,(a[0]+ab[0]*t,a[1]+ab[1]*t))<.08:cuts[i].add(t)
 nodes=[];lookup={};edges=[];seen=set()
 def node(p):
  key=(round(p[0]*10),round(p[1]*10))
  if key not in lookup:lookup[key]=len(nodes);nodes.append([round(p[0],4),round(p[1],4)])
  return lookup[key]
 for (a,b,width,length),split in zip(segments,cuts):
  split=sorted(split)
  for start,end in zip(split,split[1:]):
   dist=(end-start)*length
   if dist<.12:continue
   samples=max(1,math.ceil(dist/2))
   pts=[(a[0]+(b[0]-a[0])*(start+(end-start)*k/samples),a[1]+(b[1]-a[1])*(start+(end-start)*k/samples)) for k in range(samples+1)]
   # Discard unsafe spans rather than cutting across water/buildings.
   if not all(safe(p) for p in pts):continue
   first=node(pts[0]);last=node(pts[-1]);key=tuple(sorted([first,last]))
   if first==last or key in seen:continue
   seen.add(key);edges.append([first,last,round(width,3),round(dist,4)])
 return {'nodes':nodes,'edges':edges,'source':'data/park_layout.json','version':1}
if __name__=='__main__':
 graph=build(json.loads((ROOT/'data/park_layout.json').read_text()))
 (ROOT/'data/crowd_routes.json').write_text(json.dumps(graph,separators=(',',':')))
 print('Crowd routes:',len(graph['nodes']),'junctions,',len(graph['edges']),'safe path spans')
