extends Control
var cart: CharacterBody3D
var park: Node3D
var path_lines: Array[PackedVector2Array] = []
var boundary: PackedVector2Array
var lakes: Array[PackedVector2Array] = []
var sports: Array[PackedVector2Array] = []
var bounds: Rect2
var elapsed: float = 0
var survival: Node3D
func project(point: Vector2) -> Vector2:
    var scale_factor:=minf((size.x-28)/bounds.size.x,(size.y-64)/bounds.size.y)
    return Vector2(size.x*.5,(size.y+24)*.5)+(point-bounds.get_center())*scale_factor
func initialize(vehicle: CharacterBody3D, world: Node3D) -> void:
    mouse_filter=Control.MOUSE_FILTER_IGNORE
    cart=vehicle;park=world
    boundary=park.boundary
    bounds=Rect2(boundary[0],Vector2.ZERO)
    for point in boundary:bounds=bounds.expand(point)
    for path in park.layout.paths:path_lines.append(ParkGeometry.points(path.points,true))
    lakes.assign(park.water_polygons)
    sports.assign(park.sports.polygons)
func _process(delta: float) -> void:
    elapsed+=delta
    if elapsed>.06:elapsed=0;queue_redraw()
func mapped(points: PackedVector2Array) -> PackedVector2Array:
    var output:=PackedVector2Array()
    for point in points:output.append(project(point))
    return output
func _draw() -> void:
    GameUI.draw_plate(self,Rect2(Vector2.ZERO,size),Color(.04,.05,.08,.92),12,false)
    draw_rect(Rect2(Vector2(3,3),Vector2(size.x-18,4)),GameUI.LIME)
    draw_string(GameUI.display(),Vector2(14,25),"SAMI PARK",HORIZONTAL_ALIGNMENT_LEFT,-1,GameUI.SIZE_LABEL,GameUI.WHITE)
    draw_string(GameUI.display(),Vector2(size.x-41,25),"M",HORIZONTAL_ALIGNMENT_LEFT,-1,GameUI.SIZE_LABEL,GameUI.LIME)
    if park==null:return
    draw_colored_polygon(mapped(boundary),Color("334f42"))
    for line in path_lines:
        if line.size()>1:draw_polyline(mapped(line),Color("9da998"),.9,true)
    draw_polyline(mapped(park.running_track.centerline),Color("d47760"),1.4,true)
    for lake in lakes:draw_colored_polygon(mapped(lake),Color("477f95"))
    for court in sports:draw_colored_polygon(mapped(court),Color("9bb6c9"))
    if survival:
        for station in survival.stations:
            var marker:=project(Vector2(station.global_position.x,station.global_position.z))
            draw_rect(Rect2(marker-Vector2(3,3),Vector2(6,6)),Color("ffd268"))
        if survival.wave.running and survival.wave.spawned>=survival.wave.total and survival.wave.remaining()<=5:
            for zombie in survival.enemies.living():draw_circle(project(Vector2(zombie.global_position.x,zombie.global_position.z)),3,GameUI.RED)
    if cart.is_in_group("walk_player"):
        for access: Node3D in get_tree().get_nodes_in_group("vehicles"):
            var vehicle_point:=project(Vector2(access.vehicle.global_position.x,access.vehicle.global_position.z))
            draw_rect(Rect2(vehicle_point-Vector2(3,2),Vector2(6,4)),Color("8bcbd4"))
    var point:=project(Vector2(cart.global_position.x,cart.global_position.z))
    var forward: Vector2=Vector2(-cart.global_basis.z.x,-cart.global_basis.z.z).normalized()
    var side:=Vector2(-forward.y,forward.x)
    draw_circle(point,9,Color(0,0,0,.7))
    draw_colored_polygon(PackedVector2Array([point+forward*8,point-forward*5+side*5,point-forward*5-side*5]),GameUI.LIME)
    draw_string(GameUI.display(),Vector2(size.x-27,48),"N",HORIZONTAL_ALIGNMENT_LEFT,-1,GameUI.SIZE_SMALL,GameUI.WHITE)
    draw_line(Vector2(14,size.y-17),Vector2(34,size.y-17),GameUI.MUTED,2)
    draw_string(GameUI.body_bold(),Vector2(42,size.y-12),"200 m",HORIZONTAL_ALIGNMENT_LEFT,-1,GameUI.SIZE_MICRO+1,GameUI.MUTED)
