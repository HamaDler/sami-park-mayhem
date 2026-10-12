from pathlib import Path
import json,random,math,collections
root=Path(__file__).resolve().parents[1]
l=json.loads((root/'data/park_layout.json').read_text())
spec=json.loads((root/'assets/nature/bake_models.json').read_text())
seed=int(json.loads((root/"data/nature_settings.json").read_text()).get("seed",20261011));rng=random.Random(seed)
def solve(a,b):
 a=[list(row)+[v] for row,v in zip(a,b)]
 for i in range(3):
  p=max(range(i,3),key=lambda k:abs(a[k][i]));a[i],a[p]=a[p],a[i]
  d=a[i][i];a[i]=[x/d for x in a[i]]
  for k in range(3):
   if k!=i:
    d=a[k][i];a[k]=[x-d*y for x,y in zip(a[k],a[i])]
 return [row[3] for row in a]
a=[[151,383,1],[255,124,1],[544,386,1]]
ax=solve(a,[-701.007,-491.754,117.027]);az=solve(a,[-36.875,-605.95,-63.5085])
def mapped(p):return [round(ax[0]*p[0]+ax[1]*p[1]+ax[2],3),round(az[0]*p[0]+az[1]*p[1]+az[2],3)]
raw=[
 ('Northwestern rows',.90,True,['NormalTree','PineTree'],[(272,91),(470,72),(433,316),(233,309)]),
 ('Northern groves',.91,False,['NormalTree','MapleTree'],[(479,73),(632,149),(640,279),(462,313)]),
 ('Northeastern dense belt',.98,True,['NormalTree','BirchTree'],[(638,150),(846,202),(809,331),(737,357),(668,273)]),
 ('Western perimeter',.94,True,['NormalTree','PineTree'],[(169,275),(237,318),(221,483),(183,721),(142,763),(118,675)]),
 ('Eastern gardens',.74,True,['NormalTree','MapleTree'],[(636,402),(797,354),(785,519),(601,630),(500,606)]),
 ('Lake groves',.92,False,['NormalTree','MapleTree'],[(617,253),(753,266),(786,399),(622,460),(575,398)]),
 ('Southern garden rows',.75,True,['NormalTree','MapleTree'],[(204,551),(466,578),(400,693),(150,756)]),
 ('Western loop mixed groves',.71,False,['NormalTree','MapleTree'],[(236,352),(440,352),(467,512),(414,576),(281,565),(219,461)]),
 ('Western loop open interior',.17,False,['NormalTree'],[(283,387),(373,374),(408,452),(390,516),(324,523),(270,462)]),
 ('Fairgrounds open lawns',.13,False,['NormalTree'],[(448,553),(616,580),(625,690),(397,748)]),
 ('Central circle lawn',.20,False,['NormalTree'],[(527,360),(568,356),(591,389),(574,414),(536,416),(515,389)]),
]
zones=[dict(name=n,density=d,rows=rows,families=f,polygon=[mapped(p) for p in ps],reference_pixels=ps) for n,d,rows,f,ps in raw]
zone_file=root/'data/planting_zones.json'
if zone_file.exists():zones=json.loads(zone_file.read_text())['zones']
else:zone_file.write_text(json.dumps({'seed':seed,'zones':zones},indent=2))
def bbox(poly):return min(p[0] for p in poly),min(p[1] for p in poly),max(p[0] for p in poly),max(p[1] for p in poly)
def inside(p,poly):
 x,z=p;v=False;a=poly[-1]
 for b in poly:
  if (a[1]>z)!=(b[1]>z) and x<(b[0]-a[0])*(z-a[1])/(b[1]-a[1])+a[0]:v=not v
  a=b
 return v
def shape(poly):return(poly,bbox(poly))
def contains(p,s):
 b=s[1];return b[0]<=p[0]<=b[2] and b[1]<=p[1]<=b[3] and inside(p,s[0])
sports=[shape(c['polygon']) for c in json.loads((root/'data/sports_layout.json').read_text())['courts']]
bound=shape(l['boundary']);buildings=[shape(x['points']) for x in l['buildings']];waters=[shape(x['points']) for x in l['waters']]
building_hash=collections.defaultdict(list);water_hash=collections.defaultdict(list);paths=collections.defaultdict(list)
def index_shape(s,h):
 b=s[1]
 for x in range(math.floor(b[0]/32),math.floor(b[2]/32)+1):
  for z in range(math.floor(b[1]/32),math.floor(b[3]/32)+1):h[x,z].append(s)
for s in buildings:index_shape(s,building_hash)
for s in waters:index_shape(s,water_hash)
for road in l['paths']:
 ps=road['points'];width=road['width']/2
 for a,b in zip(ps,ps[1:]):
  if a==b:continue
  pad=width+12
  for x in range(math.floor((min(a[0],b[0])-pad)/32),math.floor((max(a[0],b[0])+pad)/32)+1):
   for z in range(math.floor((min(a[1],b[1])-pad)/32),math.floor((max(a[1],b[1])+pad)/32)+1):paths[x,z].append((a,b,width))
def dist_segment(p,a,b):
 dx=b[0]-a[0];dz=b[1]-a[1];t=max(0,min(1,((p[0]-a[0])*dx+(p[1]-a[1])*dz)/(dx*dx+dz*dz)))
 return math.hypot(p[0]-a[0]-t*dx,p[1]-a[1]-t*dz)
def path_distance(p):return min((dist_segment(p,a,b)-w for a,b,w in paths[int(p[0]//32),int(p[1]//32)]),default=1000)
def valid(p,clear):
 k=(int(p[0]//32),int(p[1]//32))
 return contains(p,bound) and path_distance(p)>=clear and not any(contains(p,s) for s in building_hash[k]) and not any(contains(p,s) for s in water_hash[k])
zone_shapes=[shape(z['polygon']) for z in zones]
def profile(p):
 data={'density':.64,'rows':False,'families':['NormalTree','MapleTree']}
 for zone,s in zip(zones,zone_shapes):
  if contains(p,s):data=zone
 return data
models=spec['trees'];names={name:i for i,name in enumerate(models)}
trees=[];family_count=collections.Counter()
for gx in range(-1120,1120,9):
 for gz in range(-1120,1120,9):
  # Rotation gives the planting rows a consistent direction within each section.
  x=gx*math.cos(.24)-gz*math.sin(.24);z=gx*math.sin(.24)+gz*math.cos(.24)
  data=profile((x,z));jitter=1.0 if data['rows'] else 3.5
  p=(x+rng.uniform(-jitter,jitter),z+rng.uniform(-jitter,jitter))
  noise=.82+.18*math.sin(x*.013+math.sin(z*.009))
  if rng.random()>data['density']*noise or not valid(p,3.8):continue
  cell=(math.floor(x/95),math.floor(z/95));pr=random.Random((cell[0]*73856093)^(cell[1]*19349663)^seed)
  family=pr.choices(data['families'],weights=[.78]+[.22]*(len(data['families'])-1))[0]
  variants={'NormalTree':[1,2,3,4,5],'MapleTree':[1,2,4],'BirchTree':[1,4],'PineTree':[1,2,5]}[family]
  variant=rng.choice(variants);name=family+'_'+str(variant)
  scale=rng.uniform(.95,1.40) if family=='NormalTree' else rng.uniform(1.0,1.45)
  trees.append([names[name],round(p[0],3),round(p[1],3),round(scale,3),round(rng.random()*math.tau,3)])
  family_count[family]+=1
# Small grouped palms on the western approach and near the plaza, rather than blanket palms.
for center in [(-650,-35),(117,-64)]:
 for i in range(16):
  angle=i*math.tau/16
  radius=36 if center[0]<0 else 95
  p=(center[0]+math.cos(angle)*radius,center[1]+math.sin(angle)*radius)
  if valid(p,5):
   name='PalmTree_'+str(rng.choice([1,3,5]));trees.append([names[name],round(p[0],3),round(p[1],3),round(rng.uniform(1.2,1.65),3),round(rng.random()*math.tau,3)]);family_count['PalmTree']+=1
rng.shuffle(trees)
details=collections.defaultdict(list)
def detail(name,p,scale=1):details[name].append([round(p[0],3),round(p[1],3),round(scale,3),round(rng.random()*math.tau,3)])
for x in range(-870,870,5):
 for z in range(-930,930,5):
  p=(x+rng.uniform(-2,2),z+rng.uniform(-2,2))
  data=profile(p)
  if rng.random()>.62 or not valid(p,1.0):continue
  for j in range(rng.randint(2,4)):
   q=(p[0]+rng.uniform(-1.25,1.25),p[1]+rng.uniform(-1.25,1.25))
   if not valid(q,.8):continue
   name=rng.choices(['Grass_Small','Grass_Large','Grass_Large_Extruded'],weights=[.52,.40,.08])[0]
   detail(name,q,rng.uniform(.8,1.6))
  if rng.random()<.025 and data['density']>.7:detail(rng.choice(['Bush','Bush_Small','Bush_Large','Plant_1','Plant_2']),p,rng.uniform(.75,1.4))
# Intermittent borders following actual mapped garden polygons.
flower_sections=0
for i,garden in enumerate(l['gardens']):
 if i%4==3:continue
 poly=garden['points'];center=(sum(p[0] for p in poly)/len(poly),sum(p[1] for p in poly)/len(poly));flower_sections+=1
 for a,b in zip(poly,poly[1:]+poly[:1]):
  length=math.dist(a,b)
  for j in range(int(length/3.0)):
   t=(j+.5)*3.0/length;p=(a[0]+(b[0]-a[0])*t,a[1]+(b[1]-a[1])*t)
   d=math.dist(p,center)
   if d<1:continue
   p=(p[0]+(center[0]-p[0])/d*4.5,p[1]+(center[1]-p[1])/d*4.5)
   if math.sin(j*.45+i*1.8)<-.25 or not valid(p,1.0):continue
   for k in range(3):
    q=(p[0]+rng.uniform(-.6,.6),p[1]+rng.uniform(-.6,.6))
    if valid(q,.8):detail('Flower_'+str(rng.randint(1,5))+'_Clump',q,rng.uniform(.7,1.1))
   if j%4==0:detail(rng.choice(['Bush_Small_Flowers','Bush_Flowers','Plant_Flowers']),p,rng.uniform(.7,1.1))
# Varied stone groups along dry lake shores; sparse extra stones in gardens.
for lake in l['waters']:
 poly=lake['points'];center=(sum(p[0] for p in poly)/len(poly),sum(p[1] for p in poly)/len(poly))
 for a,b in zip(poly,poly[1:]+poly[:1]):
  length=math.dist(a,b)
  for j in range(int(length/12)):
   t=(j+.5)*12/length;p=(a[0]+(b[0]-a[0])*t,a[1]+(b[1]-a[1])*t);d=math.dist(p,center)
   if d<1:continue
   p=(p[0]+(p[0]-center[0])/d*3.5,p[1]+(p[1]-center[1])/d*3.5)
   if not valid(p,2.5):continue
   for k in range(rng.randint(1,3)):
    q=(p[0]+rng.uniform(-1.4,1.4),p[1]+rng.uniform(-1.4,1.4))
    if valid(q,2):detail('Rock_'+str(rng.choice([1,2,3,4,5])),q,rng.uniform(.45,1.35))
for zone in zones:
 poly=zone['polygon'];b=bbox(poly)
 for i in range(16):
  p=(rng.uniform(b[0],b[2]),rng.uniform(b[1],b[3]))
  if inside(p,poly) and valid(p,7):
   for j in range(3):
    q=(p[0]+rng.uniform(-2,2),p[1]+rng.uniform(-2,2))
    if valid(q,4):detail('Rock_'+str(rng.randint(1,5)),q,rng.uniform(.4,.85))
# Filter the reserved court parcels last, preserving seeded placement order elsewhere.
trees=[row for row in trees if not any(contains((row[1],row[2]),sport) for sport in sports)]
for name in details:details[name]=[row for row in details[name] if not any(contains((row[0],row[1]),sport) for sport in sports)]
family_count=collections.Counter(models[int(row[0])].split('_')[0] for row in trees)
out={'seed':seed,'tree_models':models,'trees':trees,'details':details,'metadata':{'tree_counts':dict(family_count),'flower_sections':flower_sections,'source':'User satellite screenshot + local OSM geometry; approximate ecological zones and artistic species placements.'}}
(root/'data/vegetation_layout.json').write_text(json.dumps(out,separators=(',',':')))
print('Trees',len(trees),dict(family_count));print('Details',sum(map(len,details.values())),{k:len(v) for k,v in details.items()});print('Flower sections',flower_sections)
