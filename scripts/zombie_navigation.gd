extends Node
var grid:=AStarGrid2D.new()
var park: Node3D
var origin:=Vector2.ZERO
var cell_size: float=3
var width: int
var height: int
var solid:=PackedByteArray()
var requests_this_frame: int=0
var tree_cells: Dictionary={}
func initialize(world: Node3D) -> void:
    park=world
    var metadata: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://data/survival_navigation.json"))
    origin=Vector2(metadata.origin[0],metadata.origin[1]);cell_size=float(metadata.cell_size)
    width=int(metadata.size[0]);height=int(metadata.size[1])
    solid=FileAccess.get_file_as_bytes("res://data/survival_navigation.bin.gz").decompress_dynamic(int(metadata.bytes),FileAccess.COMPRESSION_GZIP)
    assert(solid.size()==width*height,"Survival navigation bake missing or corrupt")
    grid.region=Rect2i(0,0,width,height);grid.cell_size=Vector2.ONE*cell_size;grid.offset=origin
    grid.diagonal_mode=AStarGrid2D.DIAGONAL_MODE_ONLY_IF_NO_OBSTACLES
    grid.default_compute_heuristic=AStarGrid2D.HEURISTIC_OCTILE;grid.default_estimate_heuristic=AStarGrid2D.HEURISTIC_OCTILE
    grid.update()
    for z in height:
        for x in width:
            if solid[z*width+x]!=0:grid.set_point_solid(Vector2i(x,z))
    _static_obstacles(park)
    for p: Vector2 in park.tree_positions:
        var cell:=Vector2i(floori(p.x/4),floori(p.y/4))
        if not tree_cells.has(cell):tree_cells[cell]=[]
        tree_cells[cell].append(p)
func _physics_process(_delta: float) -> void:requests_this_frame=0
func id(world_point: Vector2) -> Vector2i:return Vector2i(roundi((world_point.x-origin.x)/cell_size),roundi((world_point.y-origin.y)/cell_size))
func point(index: Vector2i) -> Vector2:return origin+Vector2(index)*cell_size
func open_id(index: Vector2i) -> bool:return grid.is_in_boundsv(index) and not grid.is_point_solid(index)
func walkable(position: Vector2) -> bool:return open_id(id(position))
func nearest(position: Vector2, radius: int=8) -> Vector2i:
    var center:=id(position)
    if open_id(center):return center
    for ring in range(1,radius+1):
        for dx in range(-ring,ring+1):
            for dz in [-ring,ring]:
                var candidate:=center+Vector2i(dx,dz)
                if open_id(candidate):return candidate
        for dz in range(-ring+1,ring):
            for dx in [-ring,ring]:
                var candidate:=center+Vector2i(dx,dz)
                if open_id(candidate):return candidate
    return Vector2i(-1,-1)
func route(from: Vector2, to: Vector2) -> PackedVector2Array:
    if requests_this_frame>=3:return PackedVector2Array()
    requests_this_frame+=1
    var a:=nearest(from);var b:=nearest(to)
    if a.x<0 or b.x<0:return PackedVector2Array()
    # Partial routes still let a zombie approach a temporarily blocked target.
    return grid.get_point_path(a,b,true)
func segment_clear(from: Vector2, to: Vector2) -> bool:
    var steps:=maxi(1,ceili(from.distance_to(to)/(cell_size*.45)))
    for i in range(1,steps+1):
        if not walkable(from.lerp(to,float(i)/steps)):return false
    return true
func valid_spawn(position: Vector2) -> bool:
    return walkable(position) and park._map_land_rejection(position).is_empty() and not tree_blocked(position,1.0)
func tree_blocked(position: Vector2, clearance: float=.85) -> bool:
    var cell:=Vector2i(floori(position.x/4),floori(position.y/4))
    for x in range(cell.x-1,cell.x+2):
        for z in range(cell.y-1,cell.y+2):
            for tree: Vector2 in tree_cells.get(Vector2i(x,z),[]):
                if tree.distance_squared_to(position)<clearance*clearance:return true
    return false
func _static_obstacles(root: Node) -> void:
    for child in root.get_children():
        if child is StaticBody3D and child.collision_layer!=0:
            for shape_node in child.get_children():
                if not shape_node is CollisionShape3D or not shape_node.shape is BoxShape3D:continue
                var dimensions: Vector3=shape_node.shape.size
                if dimensions.x>200 or dimensions.z>200 or dimensions.y<.25:continue
                var center: Vector3=shape_node.global_position
                if center.y+dimensions.y*.5<.3:continue
                var radius:=Vector2(dimensions.x,dimensions.z).length()*.5+cell_size
                var lower:=id(Vector2(center.x-radius,center.z-radius));var upper:=id(Vector2(center.x+radius,center.z+radius))
                for x in range(lower.x,upper.x+1):
                    for z in range(lower.y,upper.y+1):
                        var index:=Vector2i(x,z)
                        if not grid.is_in_boundsv(index):continue
                        var p:=point(index)
                        var local: Vector3=shape_node.to_local(Vector3(p.x,center.y,p.y))
                        if absf(local.x)<dimensions.x*.5+cell_size*.55 and absf(local.z)<dimensions.z*.5+cell_size*.55:grid.set_point_solid(index)
        _static_obstacles(child)
