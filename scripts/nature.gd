extends Node3D
# Shared imported meshes are batched into spatial tiles. Distant trees use rendered
# impostors of the same models; only nearby trunks participate in physics.
var park: Node3D
var settings: Dictionary
var manifest: Dictionary
var tree_records: Array = []
var near_batches: Array = []
var far_batches: Array = []
var detail_batches: Array = []
var tree_grid: Dictionary = {}
var active_bodies: Dictionary = {}
var body_pool: Array[StaticBody3D] = []
var visible_tree_count: int = 0
var fraction: float = 1.0
var grass_count: int = 0
var flower_count: int = 0
var rock_count: int = 0
var lod_time: float = 0
var collider_time: float = 0
var forced_detail: bool = false
var last_collision_position := Vector2(INF,INF)
var grass_tiles: Dictionary = {}
var grass_queue: Array[Vector2i] = []
var ground_buildings: Dictionary = {}
var close_grass_meshes: Array[Mesh] = []
var grass_tile_center := Vector2i(99999,99999)
func build(world: Node3D) -> void:
    park=world
    settings=JSON.parse_string(FileAccess.get_file_as_string("res://data/nature_settings.json"))
    manifest=JSON.parse_string(FileAccess.get_file_as_string("res://assets/nature/manifest.json"))
    var planting: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://data/vegetation_layout.json"))
    tree_records=planting.trees
    visible_tree_count=tree_records.size()
    park.tree_count=tree_records.size()
    park.tree_colliders.resize(park.tree_count)
    var near_groups: Dictionary={}
    var far_groups: Dictionary={}
    for i in tree_records.size():
        var row: Array=tree_records[i]
        var model_name: String=planting.tree_models[int(row[0])]
        var p:=Vector2(row[1],row[2])
        park.tree_positions.append(p)
        var cell:=_cell(p)
        if not tree_grid.has(cell):tree_grid[cell]=[]
        tree_grid[cell].append(i)
        var placement:=_transform(row.slice(1))
        if not model_name.begins_with("Palm") and not model_name.begins_with("Pine"):
            placement.basis=placement.basis.scaled(Vector3(1.25,1,1.25))
        _group(near_groups,model_name,cell,placement,i)
        # Share a representative model per species for distant batches.
        var family:=model_name.get_slice("_",0)
        var representative:=family+"_1"
        var original_height: float=manifest[model_name].size[1]
        var representative_height: float=manifest[representative].size[1]
        var far_transform:=placement
        far_transform.basis=far_transform.basis.scaled(Vector3.ONE*original_height/representative_height)
        _group(far_groups,representative,cell,far_transform,i)
    for group: Dictionary in near_groups.values():near_batches.append(_batch(group,false,true))
    for group: Dictionary in far_groups.values():far_batches.append(_batch(group,true,true))
    var detail_groups: Dictionary={}
    for model_name: String in planting.details:
        var rows: Array=planting.details[model_name]
        if model_name.begins_with("Grass"):grass_count+=rows.size()
        if model_name.begins_with("Flower") or model_name.contains("Flowers"):flower_count+=rows.size()
        if model_name.begins_with("Rock"):rock_count+=rows.size()
        for row: Array in rows:
            var p:=Vector2(row[0],row[1])
            var placement:=_transform(row)
            if model_name.begins_with("Rock"):
                placement.origin.y=-.16*float(row[2])
                placement.basis=placement.basis*Basis(Vector3.RIGHT,sin(p.x*1.31)*.15)
                _rock_collision(model_name,placement,float(row[2]))
            _group(detail_groups,model_name,_cell(p),placement,-1)
    for group: Dictionary in detail_groups.values():detail_batches.append(_batch(group,false,false))
    for i in int(settings.max_active_tree_colliders):
        var body:=StaticBody3D.new()
        body.name="NearbyTrunk"+str(i)
        body.collision_layer=0
        body.collision_mask=0
        var shape:=CollisionShape3D.new()
        var cylinder:=CylinderShape3D.new()
        cylinder.radius=.42
        cylinder.height=3.0
        shape.shape=cylinder
        body.add_child(shape)
        add_child(body)
        body_pool.append(body)
    _prepare_close_grass()
    set_physics_process(true)
    call_deferred("refresh")
    print("NATURE: ",park.tree_count," trees, ",grass_count," grass tufts, ",flower_count," flowers, ",rock_count," stones; batched distance detail")
func _cell(point: Vector2) -> Vector2i:
    return Vector2i(floori(point.x/float(settings.chunk_size)),floori(point.y/float(settings.chunk_size)))
func _transform(row: Array) -> Transform3D:
    var instance_scale: float=row[2]
    return Transform3D(Basis(Vector3.UP,float(row[3])).scaled(Vector3.ONE*instance_scale),Vector3(row[0],.018,row[1]))
func _group(groups: Dictionary, model_name: String, cell: Vector2i, placement: Transform3D, index: int) -> void:
    var key:=model_name+":"+str(cell)
    if not groups.has(key):groups[key]={"name":model_name,"cell":cell,"transforms":[],"indices":[]}
    groups[key].transforms.append(placement)
    groups[key].indices.append(index)
func _batch(group: Dictionary, distant: bool, is_tree: bool) -> Dictionary:
    var node:=MultiMeshInstance3D.new()
    node.name=group.name+("_Distant" if distant else "_Detailed")
    var multi:=MultiMesh.new()
    multi.transform_format=MultiMesh.TRANSFORM_3D
    multi.use_colors=true
    multi.mesh=load(manifest[group.name].impostor if distant else manifest[group.name].mesh)
    multi.instance_count=group.transforms.size()
    var center: Vector2=(Vector2(group.cell)+Vector2(.5,.5))*float(settings.chunk_size)
    node.position=Vector3(center.x,0,center.y)
    for i in group.transforms.size():
        var placement: Transform3D=group.transforms[i]
        placement.origin-=node.position
        multi.set_instance_transform(i,placement)
        multi.set_instance_color(i,Color.WHITE)
    node.multimesh=multi
    node.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF if distant or group.name.begins_with("Grass") or group.name.begins_with("Flower") else GeometryInstance3D.SHADOW_CASTING_SETTING_ON
    add_child(node)
    node.visible=false
    group.node=node
    group.center=center
    group.tree=is_tree
    return group
func _rock_collision(model_name: String, placement: Transform3D, instance_scale: float) -> void:
    # Static stones use shared box shapes, slightly inset from the visible mesh.
    var size: Array=manifest[model_name].size
    var center: Array=manifest[model_name].center
    var shape:=BoxShape3D.new()
    shape.size=Vector3(size[0],size[1],size[2])*instance_scale*.83
    var body:=StaticBody3D.new()
    body.collision_mask=0
    body.transform=Transform3D(placement.basis.orthonormalized(),placement*Vector3(center[0],center[1],center[2]))
    var collision:=CollisionShape3D.new()
    collision.shape=shape
    body.add_child(collision)
    add_child(body)
func _physics_process(delta: float) -> void:
    _stream_close_grass()
    lod_time+=delta
    collider_time+=delta
    if lod_time>=.3:
        lod_time=0
        _update_lod()
    var cart: Node3D=park.get_parent().get_active_actor() if park.get_parent().has_method("get_active_actor") else park.get_parent().get_node_or_null("GolfCart")
    if cart and (collider_time>=.2 or Vector2(cart.position.x,cart.position.z).distance_to(last_collision_position)>10):
        collider_time=0
        _update_colliders(Vector2(cart.position.x,cart.position.z))
func refresh() -> void:
    _update_lod()
    var cart: Node3D=park.get_parent().get_active_actor() if park.get_parent().has_method("get_active_actor") else park.get_parent().get_node_or_null("GolfCart")
    if cart:_update_colliders(Vector2(cart.position.x,cart.position.z))
func _update_lod() -> void:
    var camera:=get_viewport().get_camera_3d()
    var point:=Vector2.ZERO
    if camera:point=Vector2(camera.global_position.x,camera.global_position.z)
    var detail_range: float=settings.tree_detail_distance*(.75 if fraction<.6 else 1.0)
    for batch: Dictionary in near_batches:
        batch.node.visible=forced_detail or batch.center.distance_squared_to(point)<detail_range*detail_range
    for batch: Dictionary in far_batches:
        var distance: float=batch.center.distance_squared_to(point)
        batch.node.visible=not forced_detail and distance>=detail_range*detail_range and distance<float(settings.tree_draw_distance)*float(settings.tree_draw_distance)
    for batch: Dictionary in detail_batches:
        var distance: float=settings.garden_draw_distance
        if batch.name.begins_with("Grass"):distance=settings.grass_draw_distance*(.75 if fraction<.6 else 1.0)
        elif batch.name.begins_with("Rock"):distance=settings.stone_draw_distance
        batch.node.visible=forced_detail or batch.center.distance_squared_to(point)<distance*distance
func set_fraction(value: float) -> void:
    fraction=clampf(value,0,1)
    visible_tree_count=int(park.tree_count*fraction)
    # Global randomized ordering means low density thins every grove evenly.
    for batches: Array in [near_batches,far_batches]:
        for batch: Dictionary in batches:
            var count:=0
            for index: int in batch.indices:
                if index<visible_tree_count:count+=1
            var multi: MultiMesh=batch.node.multimesh
            var cursor:=0
            for i in batch.indices.size():
                if int(batch.indices[i])>=visible_tree_count:continue
                var placement: Transform3D=batch.transforms[i]
                placement.origin-=batch.node.position
                multi.set_instance_transform(cursor,placement)
                cursor+=1
            multi.visible_instance_count=count
    for batch: Dictionary in detail_batches:
        if not batch.name.begins_with("Rock"):batch.node.multimesh.visible_instance_count=int(batch.transforms.size()*fraction)
    for tile: Array in grass_tiles.values():
        for node: MultiMeshInstance3D in tile:node.multimesh.visible_instance_count=int(node.multimesh.instance_count*fraction)
    refresh()
func tree_blocked(point: Vector2, clearance: float = 2.1) -> bool:
    var cell:=_cell(point)
    for x in range(cell.x-1,cell.x+2):
        for z in range(cell.y-1,cell.y+2):
            for i: int in tree_grid.get(Vector2i(x,z),[]):
                if i<visible_tree_count and point.distance_squared_to(park.tree_positions[i])<clearance*clearance:return true
    return false
func _update_colliders(point: Vector2) -> void:
    last_collision_position=point
    var required: Dictionary={}
    var cell:=_cell(point)
    var radius: float=settings.collision_radius
    for x in range(cell.x-1,cell.x+2):
        for z in range(cell.y-1,cell.y+2):
            for i: int in tree_grid.get(Vector2i(x,z),[]):
                if i<visible_tree_count and point.distance_squared_to(park.tree_positions[i])<radius*radius:required[i]=true
    for i: int in active_bodies.keys():
        if required.has(i):continue
        var body: StaticBody3D=active_bodies[i]
        body.collision_layer=0
        park.tree_colliders[i]=null
        body_pool.append(body)
        active_bodies.erase(i)
    for i: int in required:
        if active_bodies.has(i):continue
        if body_pool.is_empty():break
        var body: StaticBody3D=body_pool.pop_back()
        var tree_point: Vector2=park.tree_positions[i]
        body.position=Vector3(tree_point.x,1.5,tree_point.y)
        body.reset_physics_interpolation()
        body.collision_layer=1
        active_bodies[i]=body
        park.tree_colliders[i]=body

func _prepare_close_grass() -> void:
    var occupied: Array=park.building_polygons.duplicate()
    occupied.append_array(park.sports.polygons)
    for polygon: PackedVector2Array in occupied:
        var bounds:=Rect2(polygon[0],Vector2.ZERO)
        for point in polygon:bounds=bounds.expand(point)
        for x in range(floori(bounds.position.x/32),floori(bounds.end.x/32)+1):
            for z in range(floori(bounds.position.y/32),floori(bounds.end.y/32)+1):
                var key:=Vector2i(x,z)
                if not ground_buildings.has(key):ground_buildings[key]=[]
                ground_buildings[key].append([bounds,polygon])
    for model_name in ["Grass_Small","Grass_Large"]:
        var mesh:=load(manifest[model_name].mesh).duplicate() as ArrayMesh
        var material:=mesh.surface_get_material(0).duplicate() as ShaderMaterial
        material.set_shader_parameter("near_grass",true)
        mesh.surface_set_material(0,material)
        close_grass_meshes.append(mesh)
func _close_grass_ground(point: Vector2) -> bool:
    if park.path_distance(point)<.7 or park.is_water(point):return false
    if not park._inside_water_polygon(point,park.boundary):return false
    var cell:=Vector2i(floori(point.x/32),floori(point.y/32))
    for item: Array in ground_buildings.get(cell,[]):
        if item[0].has_point(point) and park._inside_water_polygon(point,item[1]):return false
    return true
func _stream_close_grass() -> void:
    var camera:=get_viewport().get_camera_3d()
    if not camera:return
    if camera.projection==Camera3D.PROJECTION_ORTHOGONAL:return
    var point:=Vector2(camera.global_position.x,camera.global_position.z)
    var width: float=settings.grass_tile_size
    var cell:=Vector2i(floori(point.x/width),floori(point.y/width))
    if cell!=grass_tile_center:
        grass_tile_center=cell
        grass_queue.clear()
        var keep: Dictionary={}
        var radius: float=settings.grass_close_distance+width*.7
        for x in range(cell.x-3,cell.x+4):
            for z in range(cell.y-3,cell.y+4):
                var key:=Vector2i(x,z)
                var center: Vector2=(Vector2(key)+Vector2(.5,.5))*width
                if center.distance_to(point)>radius:continue
                keep[key]=true
                if not grass_tiles.has(key):grass_queue.append(key)
        grass_queue.sort_custom(func(a: Vector2i,b: Vector2i):return a.distance_squared_to(cell)<b.distance_squared_to(cell))
        for key: Vector2i in grass_tiles.keys():
            if keep.has(key):continue
            for node: MultiMeshInstance3D in grass_tiles[key]:node.queue_free()
            grass_tiles.erase(key)
    # Limit generation per physics tick so fast travel never builds an entire ring at once.
    for i in 2:
        if grass_queue.is_empty():break
        _make_grass_tile(grass_queue.pop_front())
func _make_grass_tile(cell: Vector2i) -> void:
    var width: float=settings.grass_tile_size
    var random:=RandomNumberGenerator.new()
    random.seed=abs(cell.x*73856093 ^ cell.y*19349663 ^ int(settings.seed))
    var groups: Array=[[],[]]
    var spacing: float=settings.grass_close_spacing
    var count:=ceili(width/spacing)
    for x in count:
        for z in count:
            var point: Vector2=Vector2(cell)*width+Vector2((x+.25+random.randf()*.5)*spacing,(z+.25+random.randf()*.5)*spacing)
            if not _close_grass_ground(point):continue
            var instance_scale:=random.randf_range(.65,1.12)
            var placement:=Transform3D(Basis(Vector3.UP,random.randf()*TAU).scaled(Vector3.ONE*instance_scale),Vector3(point.x,.018,point.y))
            groups[0 if random.randf()<.8 else 1].append(placement)
    var nodes: Array=[]
    for variant in 2:
        var transforms: Array=groups[variant]
        if transforms.is_empty():continue
        var multi:=MultiMesh.new()
        multi.transform_format=MultiMesh.TRANSFORM_3D
        multi.mesh=close_grass_meshes[variant]
        multi.instance_count=transforms.size()
        var node:=MultiMeshInstance3D.new()
        node.name="CloseGrass"
        node.position=Vector3(cell.x*width,0,cell.y*width)
        for i in transforms.size():
            var placement: Transform3D=transforms[i]
            placement.origin-=node.position
            multi.set_instance_transform(i,placement)
        multi.visible_instance_count=int(multi.instance_count*fraction)
        node.multimesh=multi
        node.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
        add_child(node)
        nodes.append(node)
    grass_tiles[cell]=nodes
