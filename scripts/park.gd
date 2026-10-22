extends Node3D
@export_range(0.2,1.0,0.1) var vegetation_density: float = 1.0
@export var layout_file: String = "res://data/park_layout.json"
var layout: Dictionary
var boundary: PackedVector2Array
var path_segments: Array = []
var water_polygons: Array[PackedVector2Array] = []
var water_bounds: Array[Rect2] = []
var building_polygons: Array[PackedVector2Array] = []
var spatial_paths: Dictionary = {}
var tree_count: int = 0
var tree_positions := PackedVector2Array()
var nature: Node3D
var sports: Node3D
var running_track: Node3D
var perimeter_fence: Node3D
var tree_colliders: Array[StaticBody3D] = []
var rng := RandomNumberGenerator.new()
var grass := ParkGeometry.material(Color("719954"))
var path_mat := ParkGeometry.material(Color("b8b49d"))
var edge_mat := ParkGeometry.material(Color("a0987e"))
var wood := ParkGeometry.material(Color("806144"))
var metal := ParkGeometry.material(Color("35433e"))

func _ready() -> void:
    rng.seed = 20261011
    layout = JSON.parse_string(FileAccess.get_file_as_string(layout_file))
    boundary = ParkGeometry.points(layout.boundary)
    running_track=load("res://scenes/running_track.tscn").instantiate()
    add_child(running_track)
    _ground_and_paths()
    _water_and_buildings()
    perimeter_fence=load("res://scenes/perimeter_fence.tscn").instantiate()
    add_child(perimeter_fence)
    perimeter_fence.build(boundary)
    sports=load("res://scenes/sports_area.tscn").instantiate()
    add_child(sports)
    _vegetation()
    _furniture()
    _entrance()

func _ground_and_paths() -> void:
    ParkGeometry.box(self,Vector3(0,-0.7,0),Vector3(3200,0.9,3200),ParkGeometry.material(Color("b5aa8d")))
    ParkGeometry.collider(self,Vector3(0,-0.45,0),Vector3(3200,0.9,3200))
    var mat := ShaderMaterial.new()
    mat.shader=load("res://assets/grass.gdshader")
    ParkGeometry.mesh_from_vertices(self,ParkGeometry.polygon_vertices(boundary,0.012),mat,"ParkBoundary")
    var street_vertices := PackedVector3Array()
    for road in layout.streets:
        street_vertices.append_array(ParkGeometry.road_vertices(ParkGeometry.points(road.points,true),road.width,0.025))
    var asphalt := ParkGeometry.material(Color("747b78"))
    asphalt.cull_mode = BaseMaterial3D.CULL_DISABLED
    ParkGeometry.mesh_from_vertices(self,street_vertices,asphalt,"SurroundingStreets")
    var paths := PackedVector3Array()
    var edges := PackedVector3Array()
    for road in layout.paths:
        var pts := ParkGeometry.points(road.points,true)
        if road.id not in running_track.layout.path_ids:
            paths.append_array(ParkGeometry.road_vertices(pts,road.width,0.055))
            edges.append_array(ParkGeometry.road_vertices(pts,road.width+0.45,0.04))
        for i in range(pts.size()-1):
            var a := pts[i]
            var b := pts[i+1]
            var entry := [a,b,float(road.width)*0.5]
            path_segments.append(entry)
            var pad: float = float(road.width)*0.5+8.0
            for x in range(int(floor((minf(a.x,b.x)-pad)/32.0)),int(floor((maxf(a.x,b.x)+pad)/32.0))+1):
                for z in range(int(floor((minf(a.y,b.y)-pad)/32.0)),int(floor((maxf(a.y,b.y)+pad)/32.0))+1):
                    var key := Vector2i(x,z)
                    if not spatial_paths.has(key): spatial_paths[key] = []
                    spatial_paths[key].append(entry)
    path_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
    edge_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
    ParkGeometry.mesh_from_vertices(self,edges,edge_mat,"PathBorders")
    ParkGeometry.mesh_from_vertices(self,paths,path_mat,"MappedPaths")

func path_distance(p: Vector2) -> float:
    var best := 1000.0
    var key := Vector2i(int(floor(p.x/32.0)),int(floor(p.y/32.0)))
    for entry in spatial_paths.get(key,[]):
        var nearest := Geometry2D.get_closest_point_to_segment(p,entry[0],entry[1])
        best = minf(best,p.distance_to(nearest)-entry[2])
    return best

func is_on_path(p: Vector3) -> bool:
    if is_instance_valid(sports) and sports.is_inside(Vector2(p.x,p.z)):return true
    return path_distance(Vector2(p.x,p.z)) < 0.5

func is_water(p: Vector2) -> bool:
    for i in water_polygons.size():
        # Reject outside the lake rectangle before the polygon ray test.
        # This avoids numerical false positives along distant edge extensions.
        if water_bounds[i].has_point(p) and _inside_water_polygon(p,water_polygons[i]):return true
    return false

func _inside_water_polygon(p: Vector2, poly: PackedVector2Array) -> bool:
    # A horizontal, half-open ray avoids counting the same polygon vertex twice.
    # Keep the intersection arithmetic in GDScript's double-precision floats.
    var inside := false
    var previous := poly.size()-1
    for current in poly.size():
        var a := poly[current]
        var b := poly[previous]
        if (a.y>p.y)!=(b.y>p.y):
            var intersection_x: float = float(a.x)+(float(p.y)-float(a.y))*(float(b.x)-float(a.x))/(float(b.y)-float(a.y))
            if float(p.x)<intersection_x:inside=not inside
        previous=current
    return inside

func safe_ground(p: Vector2, clearance: float = 2.5) -> bool:
    if is_instance_valid(sports) and sports.is_inside(p):return false
    if not Geometry2D.is_point_in_polygon(p,boundary) or path_distance(p)<clearance or is_water(p):return false
    for poly in building_polygons:
        if Geometry2D.is_point_in_polygon(p,poly):return false
    return true

func _water_and_buildings() -> void:
    var water := ShaderMaterial.new()
    water.shader = load("res://assets/water.gdshader")
    var shore := ParkGeometry.material(Color("c6bd9d"))
    shore.cull_mode = BaseMaterial3D.CULL_DISABLED
    for lake in layout.waters:
        var p := ParkGeometry.points(lake.points)
        water_polygons.append(p)
        var bounds := Rect2(p[0],Vector2.ZERO)
        for vertex in p:bounds=bounds.expand(vertex)
        water_bounds.append(bounds)
        var border := p.duplicate()
        border.append(p[0])
        ParkGeometry.mesh_from_vertices(self,ParkGeometry.road_vertices(border,2.2,0.028),shore,"LakeShore")
        ParkGeometry.mesh_from_vertices(self,ParkGeometry.polygon_vertices(p,0.04),water,"Water")
    var walls := PackedVector3Array()
    var roofs := PackedVector3Array()
    for building in layout.buildings:
        var poly := ParkGeometry.points(building.points)
        var height: float = float(building.height)
        building_polygons.append(poly)
        roofs.append_array(ParkGeometry.polygon_vertices(poly,height))
        for i in range(poly.size()):
            var a := poly[i]
            var b := poly[(i+1)%poly.size()]
            var v := [Vector3(a.x,0,a.y),Vector3(a.x,height,a.y),Vector3(b.x,height,b.y),Vector3(b.x,0,b.y)]
            for j in [0,1,2,0,2,3]:walls.append(v[j])
        if building.internal:
            var vertices := ParkGeometry.polygon_vertices(poly,height)
            for i in range(poly.size()):
                var a := poly[i]
                var b := poly[(i+1)%poly.size()]
                vertices.append_array(PackedVector3Array([Vector3(a.x,0,a.y),Vector3(a.x,height,a.y),Vector3(b.x,height,b.y),Vector3(a.x,0,a.y),Vector3(b.x,height,b.y),Vector3(b.x,0,b.y)]))
            var form := ConcavePolygonShape3D.new()
            form.backface_collision = true
            form.set_faces(vertices)
            var body := StaticBody3D.new()
            var collision := CollisionShape3D.new()
            collision.shape = form
            body.add_child(collision)
            add_child(body)
    var wall_mat := ParkGeometry.material(Color("bba98a"))
    wall_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
    var roof_mat := ParkGeometry.material(Color("ddd0ae"))
    roof_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
    ParkGeometry.mesh_from_vertices(self,walls,wall_mat,"MappedBuildings")
    ParkGeometry.mesh_from_vertices(self,roofs,roof_mat,"BuildingRoofs")
    for feature in layout.landmarks:
        var p := ParkGeometry.points(feature.points)
        var c := Vector2.ZERO
        for v in p:c+=v
        c/=p.size()
        var pale := ParkGeometry.material(Color("dfd6bd"))
        ParkGeometry.box(self,Vector3(c.x,0.35,c.y),Vector3(14,0.7,14),pale,true)
        ParkGeometry.box(self,Vector3(c.x,5.0,c.y),Vector3(2.8,9,2.8),pale,true)

func _instance_batch(mesh: Mesh, mat: Material, transforms: Array[Transform3D], label: String) -> void:
    if transforms.is_empty():return
    var multi := MultiMesh.new()
    multi.transform_format = MultiMesh.TRANSFORM_3D
    multi.mesh = mesh
    multi.instance_count = transforms.size()
    for i in transforms.size():multi.set_instance_transform(i,transforms[i])
    var instance := MultiMeshInstance3D.new()
    instance.name = label
    instance.multimesh = multi
    instance.material_override = mat
    add_child(instance)

func _vegetation() -> void:
    nature=Node3D.new()
    nature.name="NatureScenery"
    nature.set_script(load("res://scripts/nature.gd"))
    add_child(nature)
    nature.build(self)
    if vegetation_density<1.0:nature.set_fraction(vegetation_density)

func set_visible_tree_fraction(fraction: float) -> void:
    nature.set_fraction(fraction)

func _furniture() -> void:
    var last_positions: Array[Vector2] = []
    var index := 0
    for entry in path_segments:
        var a: Vector2 = entry[0]
        var b: Vector2 = entry[1]
        if a.distance_to(b)<15:continue
        var p := (a+b)*0.5
        var d := (b-a).normalized()
        var n := Vector2(-d.y,d.x)
        p+=n*(float(entry[2])+3.3)
        if not safe_ground(p,2.3):continue
        var skip := false
        for old in last_positions:
            if old.distance_to(p)<42:skip=true;break
        if skip:continue
        last_positions.append(p)
        var prop := Node3D.new()
        prop.position = Vector3(p.x,0,p.y)
        prop.rotation.y = -atan2(d.y,d.x)
        add_child(prop)
        if index%3==0:
            ParkGeometry.box(prop,Vector3(0,0.6,0),Vector3(2.1,0.13,0.55),wood)
            ParkGeometry.box(prop,Vector3(0,1.0,0.25),Vector3(2.1,0.55,0.12),wood)
            for x in [-0.8,0.8]:ParkGeometry.box(prop,Vector3(x,0.28,0),Vector3(0.09,0.55,0.45),metal)
            ParkGeometry.collider(prop,Vector3(0,0.6,0),Vector3(2.1,1.2,0.7))
        else:
            ParkGeometry.cylinder(prop,Vector3(0,2.0,0),0.055,4.0,metal)
            ParkGeometry.box(prop,Vector3(0,4.1,0),Vector3(0.45,0.12,0.45),metal)
            var bulb := ParkGeometry.material(Color("efe3ba"))
            bulb.emission_enabled = true
            bulb.emission = Color("ecce7f")
            bulb.emission_energy_multiplier = 4.0
            ParkGeometry.box(prop,Vector3(0,3.95,0),Vector3(0.27,0.2,0.27),bulb)
            ParkGeometry.collider(prop,Vector3(0,1.0,0),Vector3(0.17,2,0.17))
            # Night lighting: no shadows, and distant lamps fade out to stay inside the light limit.
            var lamp := OmniLight3D.new()
            lamp.position = Vector3(0,3.7,0)
            lamp.light_color = Color(1.0,0.78,0.48)
            lamp.light_energy = 1.6
            lamp.omni_range = 15.0
            lamp.omni_attenuation = 1.3
            lamp.distance_fade_enabled = true
            lamp.distance_fade_begin = 60.0
            lamp.distance_fade_length = 20.0
            prop.add_child(lamp)
        index+=1

func _entrance() -> void:
    var s: Array = layout.spawn.gate_position
    var gate := Node3D.new()
    gate.rotation.y = layout.spawn.gate_yaw
    gate.position = Vector3(s[0],0,s[1])-gate.basis.z*5.0
    add_child(gate)
    var pale := ParkGeometry.material(Color("d6ceb3"))
    for x in [-5.5,5.5]:
        ParkGeometry.box(gate,Vector3(x,2.0,5),Vector3(0.65,4,0.65),pale,true)
    ParkGeometry.box(gate,Vector3(0,4.2,5),Vector3(11.7,0.8,0.6),wood)
    var label := Label3D.new()
    label.text = "ENGLISH DOOR • SAMI PARK"
    label.font_size = 64
    label.pixel_size = 0.004
    label.position = Vector3(0,4.2,4.68)
    label.modulate = Color("fff2cf")
    label.outline_size = 0
    gate.add_child(label)
    var board := Node3D.new()
    board.position = Vector3(7,0,-1)
    gate.add_child(board)
    ParkGeometry.box(board,Vector3(0,1.3,0),Vector3(1.8,1.2,0.16),metal,true)
    for x in [-0.65,0.65]:ParkGeometry.box(board,Vector3(x,0.65,0),Vector3(0.08,1.3,0.08),wood)
    var welcome := Label3D.new()
    welcome.text = "ENGLISH DOOR\nWELCOME TO SAMI PARK"
    welcome.font_size = 32
    welcome.pixel_size = 0.002
    welcome.position = Vector3(0,1.3,-0.1)
    welcome.outline_size = 0
    welcome.rotation.y = PI
    board.add_child(welcome)

func resolve_map_spawn(point: Vector2, current_yaw: float, excluded_body: RID, walking: bool=false) -> Dictionary:
    var rejection := _map_land_rejection(point)
    if not rejection.is_empty():return {"valid":false,"reason":rejection,"position":point}
    var yaw := current_yaw
    var best_distance := 20.0
    for segment in path_segments:
        var nearest := Geometry2D.get_closest_point_to_segment(point,segment[0],segment[1])
        var distance := point.distance_to(nearest)
        if distance<best_distance and segment[0].distance_to(segment[1])>0.1:
            best_distance=distance
            var direction: Vector2=(segment[1]-segment[0]).normalized()
            yaw=atan2(-direction.x,-direction.y)
    if cos(yaw-current_yaw)<0:yaw+=PI
    var box:=BoxShape3D.new()
    box.size=Vector3(1.7,1.9,3.0)
    var query:=PhysicsShapeQueryParameters3D.new()
    query.shape=box
    if walking:
        var capsule:=CapsuleShape3D.new();capsule.radius=.30;capsule.height=1.72
        query.shape=capsule
    query.collision_mask=3 if walking else 1
    query.exclude=[excluded_body]
    var candidates: Array[Vector2]=[point]
    for radius in [2.0,4.0,6.0,8.0]:
        for index in 12:
            candidates.append(point+Vector2(cos(index*TAU/12),sin(index*TAU/12))*radius)
    for candidate in candidates:
        if not _map_land_rejection(candidate).is_empty():continue
        query.transform=Transform3D(Basis(Vector3.UP,yaw),Vector3(candidate.x,1.05 if walking else 1.1,candidate.y))
        if not get_world_3d().direct_space_state.intersect_shape(query,1).is_empty():continue
        if _map_tree_blocked(candidate):continue
        return {"valid":true,"position":candidate,"yaw":yaw,"reason":""}
    return {"valid":false,"reason":"This place is blocked by scenery. Choose a nearby clear spot.","position":point}

func _map_land_rejection(point: Vector2) -> String:
    if not _inside_water_polygon(point,boundary):return "Choose a place inside the park."
    if is_water(point):return "That point is in water. Choose a path or open grass."
    for polygon in building_polygons:
        if _inside_water_polygon(point,polygon):return "That point is inside a building. Choose a clear spot."
    return ""

func _map_tree_blocked(point: Vector2) -> bool:
    return nature.tree_blocked(point)
