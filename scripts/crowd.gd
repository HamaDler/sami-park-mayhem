extends Node3D
# Population records live independently from rendering. Missions can retain an ID
# even when that person is beyond the visible distance or changes rendering tiles.
signal person_arrived(person_id: int, junction: int)
signal person_state_changed(person_id: int, state: String)

class Person:
    var id: int
    var model: int
    var from_node: int
    var to_node: int
    var previous_node: int
    var progress: float
    var edge_length: float
    var lane: float
    var speed: float
    var height_scale: float
    var tint: float
    var animation_offset: float
    var clip: int = 0
    var wait: float = 0
    var mission_paused: bool = false
    var position := Vector2.ZERO
    var previous_position := Vector2.ZERO
    var direction := Vector2.UP
    var mission_data: Dictionary = {}

var park: Node3D
var settings: Dictionary
var people: Array[Person] = []
var nodes: PackedVector2Array
var edges: Array = []
var neighbors: Array = []
var variants: Array = []
var batches: Dictionary = {}
var visible_people: Array[Person] = []
var rng := RandomNumberGenerator.new()
var animation_clock: float = 0
var simulation_elapsed: float = 0
var visibility_elapsed: float = 0
var obstacle_cursor: int = 0
var initialized: bool = false
var visible_count: int = 0
var last_actor_position := Vector2(INF, INF)

func _ready() -> void:
    set_process(false)

func initialize(world: Node3D) -> void:
    if initialized:return
    park=world
    settings=JSON.parse_string(FileAccess.get_file_as_string("res://data/crowd_settings.json"))
    if int(settings.seed)==0:rng.randomize()
    else:rng.seed=int(settings.seed)
    var routes: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://data/crowd_routes.json"))
    nodes=ParkGeometry.points(routes.nodes,true)
    neighbors.resize(nodes.size())
    for i in nodes.size():neighbors[i]=[]
    edges=routes.edges
    for edge: Array in edges:
        neighbors[int(edge[0])].append([int(edge[1]),float(edge[2]),float(edge[3])])
        neighbors[int(edge[1])].append([int(edge[0]),float(edge[2]),float(edge[3])])
    _load_models()
    _populate()
    initialized=true
    refresh()
    set_process(true)
    print("CROWD: ",people.size()," civilian visitors, ",variants.size()," outfits; shared animated meshes")

func _load_models() -> void:
    var manifest: Array=JSON.parse_string(FileAccess.get_file_as_string("res://assets/characters/crowd/manifest.json"))
    var shader:=load("res://assets/characters/crowd/crowd.gdshader") as Shader
    for entry: Dictionary in manifest:
        var raw: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(entry.directory+"/mesh.json"))
        var vertices:=PackedVector3Array()
        var normals:=PackedVector3Array()
        var colors:=PackedColorArray()
        var uv2:=PackedVector2Array()
        for i in raw.positions.size():
            var p: Array=raw.positions[i]
            var n: Array=raw.normals[i]
            var c: Array=raw.colors[i]
            vertices.append(Vector3(p[0],p[1],p[2]))
            normals.append(Vector3(n[0],n[1],n[2]))
            colors.append(Color(c[0],c[1],c[2],c[3]))
            uv2.append(Vector2((i%int(entry.width)+.5)/float(entry.width),(floori(float(i)/float(entry.width))+.5)/float(entry.height)))
        var arrays:=[]
        arrays.resize(Mesh.ARRAY_MAX)
        arrays[Mesh.ARRAY_VERTEX]=vertices
        arrays[Mesh.ARRAY_NORMAL]=normals
        arrays[Mesh.ARRAY_COLOR]=colors
        arrays[Mesh.ARRAY_TEX_UV2]=uv2
        arrays[Mesh.ARRAY_INDEX]=PackedInt32Array(raw.indices)
        var mesh:=ArrayMesh.new()
        mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)
        var material:=ShaderMaterial.new()
        material.shader=shader
        for texture_name in ["positions","normals"]:
            var packed:=FileAccess.get_file_as_bytes(entry.directory+"/"+texture_name+".bin.gz")
            var data:=packed.decompress(int(entry.width)*int(entry.height)*8,FileAccess.COMPRESSION_GZIP)
            var image:=Image.create_from_data(int(entry.width),int(entry.height),false,Image.FORMAT_RGBAH,data)
            material.set_shader_parameter("pose_"+texture_name,ImageTexture.create_from_image(image))
        material.set_shader_parameter("pose_min",Vector3(entry.min[0],entry.min[1],entry.min[2]))
        material.set_shader_parameter("pose_extent",Vector3(entry.extent[0],entry.extent[1],entry.extent[2]))
        material.set_shader_parameter("row_stride",float(entry.rows)/float(entry.height))
        material.set_shader_parameter("frames_per_clip",float(entry.frames))
        material.set_shader_parameter("clip_lengths",PackedFloat32Array(entry.lengths))
        mesh.surface_set_material(0,material)
        # Animated bounds differ from the neutral vertices; include every baked pose.
        mesh.custom_aabb=AABB(Vector3(entry.min[0],entry.min[1],entry.min[2]),Vector3(entry.extent[0],entry.extent[1],entry.extent[2]))
        entry.mesh=mesh
        entry.material=material
        variants.append(entry)

func _populate() -> void:
    var weights:=PackedFloat64Array()
    var total:=0.0
    var entrance_edges: Array=[]
    var spawn:=Vector2(park.layout.spawn.position[0],park.layout.spawn.position[1])
    for i in edges.size():
        total+=float(edges[i][3]);weights.append(total)
        var midpoint: Vector2=(nodes[int(edges[i][0])]+nodes[int(edges[i][1])])*.5
        if midpoint.distance_to(spawn)<float(settings.entrance_radius):entrance_edges.append(i)
    var genders: Array=[[],[]]
    for i in variants.size():genders[0 if variants[i].gender=="men" else 1].append(i)
    for i in int(settings.population):
        var choice:=weights.bsearch(rng.randf()*total)
        if i<int(settings.population*settings.entrance_population_fraction) and not entrance_edges.is_empty():choice=entrance_edges[rng.randi_range(0,entrance_edges.size()-1)]
        var edge: Array=edges[mini(choice,edges.size()-1)]
        var p:=Person.new()
        p.id=i
        var models: Array=genders[i%2]
        p.model=models[rng.randi_range(0,models.size()-1)]
        p.from_node=int(edge[0]);p.to_node=int(edge[1]);p.previous_node=p.from_node
        if rng.randf()<.5:
            var swap:=p.from_node;p.from_node=p.to_node;p.to_node=swap
        p.edge_length=float(edge[3]);p.progress=rng.randf()
        p.lane=rng.randf_range(-minf(.7,float(edge[2])*.22),minf(.7,float(edge[2])*.22))
        p.speed=rng.randf_range(float(settings.walk_speed_min),float(settings.walk_speed_max))
        p.height_scale=rng.randf_range(.92,1.06);p.tint=rng.randf()
        p.animation_offset=rng.randf_range(0,20)
        _update_position(p)
        # Reject blocked initial placements without asking physics to spawn 1000 bodies.
        if park._map_tree_blocked(p.position):p.lane=0;_update_position(p)
        p.previous_position=p.position
        if rng.randf()<.12:_pause_person(p)
        people.append(p)

func _update_position(p: Person) -> void:
    p.direction=(nodes[p.to_node]-nodes[p.from_node]).normalized()
    var lateral:=Vector2(-p.direction.y,p.direction.x)*p.lane
    # Fade lane offsets at junctions so turns do not cut across lawns or snap sideways.
    var junction_blend:=minf(1,minf(p.progress,1-p.progress)*p.edge_length/1.5)
    p.position=nodes[p.from_node].lerp(nodes[p.to_node],p.progress)+lateral*junction_blend

func _set_clip(p: Person, clip: int) -> void:
    if p.clip==clip:return
    p.clip=clip
    p.animation_offset=-animation_clock+rng.randf_range(0,.2)
    person_state_changed.emit(p.id,"walking" if clip==0 else "idle")

func _pause_person(p: Person) -> void:
    var roll:=rng.randf()
    var clip:=3 if roll<.12 else (4 if roll<.18 else (1 if roll<.6 else 2))
    _set_clip(p,clip)
    p.wait=float(variants[p.model].lengths[clip]) if clip>=3 else rng.randf_range(float(settings.idle_seconds_min),float(settings.idle_seconds_max))

func _next_edge(p: Person) -> void:
    var arrived:=p.to_node
    var options: Array=neighbors[arrived]
    var choices: Array=[]
    for entry: Array in options:
        if int(entry[0])!=p.from_node:choices.append(entry)
    if choices.is_empty():choices=options
    var edge: Array=choices[rng.randi_range(0,choices.size()-1)]
    p.previous_node=p.from_node;p.from_node=arrived;p.to_node=int(edge[0])
    p.edge_length=float(edge[2]);p.progress=0
    p.lane=clampf(p.lane,-minf(.7,float(edge[1])*.22),minf(.7,float(edge[1])*.22))
    person_arrived.emit(p.id,arrived)
    if rng.randf()<float(settings.pause_chance_at_junction):_pause_person(p)

func _simulate(delta: float, actor: Vector2) -> void:
    for p: Person in people:
        p.previous_position=p.position
        if p.mission_paused:continue
        if p.wait>0:
            p.wait=maxf(0,p.wait-delta)
            if p.wait==0:_set_clip(p,0)
            continue
        if p.position.distance_squared_to(actor)<pow(float(settings.actor_clearance),2):
            _set_clip(p,1);continue
        _set_clip(p,0)
        var remaining:=p.speed*delta
        while remaining>0:
            var available: float=(1-p.progress)*p.edge_length
            if remaining<available:p.progress+=remaining/p.edge_length;remaining=0
            else:
                remaining-=available
                _next_edge(p)
                if p.wait>0:remaining=0
        _update_position(p)
    _check_obstacles(actor)

func _check_obstacles(actor: Vector2) -> void:
    var checked:=0
    var inspected:=0
    while inspected<people.size() and checked<int(settings.max_obstacle_queries_per_tick):
        var p:=people[obstacle_cursor]
        obstacle_cursor=(obstacle_cursor+1)%people.size();inspected+=1
        if p.clip!=0 or p.mission_paused or p.position.distance_squared_to(actor)>pow(float(settings.obstacle_check_distance),2):continue
        checked+=1
        var a:=Vector3(p.position.x,.85,p.position.y)
        var b:=a+Vector3(p.direction.x,0,p.direction.y)*1.1
        var query:=PhysicsRayQueryParameters3D.create(a,b,1)
        if park.get_world_3d().direct_space_state.intersect_ray(query).is_empty():continue
        # Turn back on the same safe route when a bench, trunk or other scenery blocks it.
        var swap:=p.from_node;p.from_node=p.to_node;p.to_node=swap
        p.progress=1-p.progress;p.lane=-p.lane
        _update_position(p);p.previous_position=p.position
        _pause_person(p)

func _actor_position() -> Vector2:
    var actor: Node3D=get_parent().get_active_actor()
    return Vector2(actor.global_position.x,actor.global_position.z)

func _process(delta: float) -> void:
    if not initialized:return
    animation_clock+=delta
    simulation_elapsed+=delta
    var actor:=_actor_position()
    var interval: float=settings.simulation_interval
    var ticks:=0
    while simulation_elapsed>=interval and ticks<4:
        simulation_elapsed-=interval;_simulate(interval,actor);ticks+=1
    simulation_elapsed=minf(simulation_elapsed,interval)
    visibility_elapsed+=delta
    if visibility_elapsed>=float(settings.visibility_interval) or actor.distance_to(last_actor_position)>25:
        refresh();visibility_elapsed=0
    for variant: Dictionary in variants:variant.material.set_shader_parameter("animation_clock",animation_clock)
    var alpha:=clampf(simulation_elapsed/interval,0,1)
    for batch: Dictionary in batches.values():
        if not batch.node.visible:continue
        var multi: MultiMesh=batch.node.multimesh
        for i in batch.people.size():
            var p: Person=batch.people[i]
            var point:=p.previous_position.lerp(p.position,alpha)
            var yaw:=atan2(-p.direction.x,-p.direction.y)
            var transform:=Transform3D(Basis(Vector3.UP,yaw).scaled(Vector3.ONE*p.height_scale),Vector3(point.x,.06,point.y)-batch.node.position)
            multi.set_instance_transform(i,transform)
            multi.set_instance_color(i,Color.WHITE)
            multi.set_instance_custom_data(i,Color(p.animation_offset,p.speed/1.4 if p.clip==0 else 1,p.clip,p.tint))

func refresh() -> void:
    if not initialized:return
    var actor:=_actor_position()
    last_actor_position=actor
    visible_people.clear()
    for batch: Dictionary in batches.values():batch.people.clear();batch.node.hide()
    var width: float=settings.batch_cell_size
    for p: Person in people:
        if p.position.distance_squared_to(actor)>pow(float(settings.visible_distance),2):continue
        visible_people.append(p)
        var cell:=Vector2i(floori(p.position.x/width),floori(p.position.y/width))
        var key:=str(p.model)+":"+str(cell)
        if not batches.has(key):
            var multi:=MultiMesh.new()
            multi.transform_format=MultiMesh.TRANSFORM_3D
            multi.use_colors=true
            multi.use_custom_data=true
            multi.mesh=variants[p.model].mesh
            # The tile and animated height bound all instances, including movement
            # between visibility refreshes. Avoid recalculating bounds every frame.
            multi.custom_aabb=AABB(Vector3(-4,-2,-4),Vector3(width+8,6,width+8))
            var node:=MultiMeshInstance3D.new()
            node.name="Visitors_"+variants[p.model].id
            node.position=Vector3(cell.x*width,0,cell.y*width)
            node.multimesh=multi
            node.physics_interpolation_mode=Node.PHYSICS_INTERPOLATION_MODE_OFF
            add_child(node)
            batches[key]={"node":node,"people":[]}
        batches[key].people.append(p)
    # Drop empty tiles instead of accumulating render objects as visitors wander.
    for key: String in batches.keys():
        var batch: Dictionary=batches[key]
        if batch.people.is_empty():batch.node.queue_free();batches.erase(key);continue
        var multi: MultiMesh=batch.node.multimesh
        var capacity:=ceili(batch.people.size()/8.0)*8
        if multi.instance_count!=capacity:multi.instance_count=capacity
        multi.visible_instance_count=batch.people.size()
        var center:=Vector2(batch.node.position.x+width*.5,batch.node.position.z+width*.5)
        batch.node.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_ON if center.distance_to(actor)<float(settings.shadow_distance)+width*.5 else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
        batch.node.show()
    visible_count=visible_people.size()

func get_person_state(person_id: int) -> Dictionary:
    if person_id<0 or person_id>=people.size():return {}
    var p:=people[person_id]
    return {"id":p.id,"position":p.position,"gender":variants[p.model].gender,"outfit":variants[p.model].id,"state":"walking" if p.clip==0 else "idle","animation":variants[p.model].clips[p.clip],"mission_data":p.mission_data}

func set_person_paused(person_id: int, value: bool) -> void:
    if person_id<0 or person_id>=people.size():return
    var p:=people[person_id]
    p.mission_paused=value
    _set_clip(p,1 if value else 0)

func nearest_person(point: Vector2, radius: float = 4) -> int:
    var best: float=radius*radius
    var result: int=-1
    for p: Person in people:
        var distance:=p.position.distance_squared_to(point)
        if distance<best:best=distance;result=p.id
    return result
