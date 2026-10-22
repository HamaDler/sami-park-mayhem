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
# The park itself (paths, lakes, courts, track) never changes, but drawing it took ~3.5 ms a
# frame: thousands of anti-aliased line segments re-sent every frame. It is rendered once into
# this offscreen texture, at the on-screen resolution, and only the markers are redrawn on top.
var static_view: SubViewport
var static_layer: Control
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
    _build_static_layer()
func _build_static_layer() -> void:
    static_view=SubViewport.new();static_view.name="StaticMap"
    static_view.transparent_bg=true;static_view.disable_3d=true
    static_view.render_target_update_mode=SubViewport.UPDATE_DISABLED
    static_layer=Control.new();static_layer.mouse_filter=Control.MOUSE_FILTER_IGNORE
    static_layer.draw.connect(_draw_static)
    static_view.add_child(static_layer);add_child(static_view)
    resized.connect(_refresh_static)
    get_viewport().size_changed.connect(_refresh_static)
    _refresh_static()
# Re-render the park layer when the minimap or window size changes.
func _refresh_static() -> void:
    if static_view==null or size.x<4 or size.y<4:return
    # Window stretch (canvas_items) times the HUD's own scale = pixels per minimap unit on screen.
    var screen_scale: float=clampf((get_viewport().get_final_transform()*get_global_transform_with_canvas()).get_scale().x,1.0,3.0)
    static_view.size=Vector2i(ceili(size.x*screen_scale),ceili(size.y*screen_scale))
    static_view.size_2d_override=Vector2i(ceili(size.x),ceili(size.y))
    static_view.size_2d_override_stretch=true
    static_layer.size=size;static_layer.queue_redraw()
    static_view.render_target_update_mode=SubViewport.UPDATE_ONCE
func _draw_static() -> void:
    if park==null:return
    static_layer.draw_colored_polygon(mapped(boundary),Color("334f42"))
    for line in path_lines:
        if line.size()>1:static_layer.draw_polyline(mapped(line),Color("9da998"),.9,true)
    static_layer.draw_polyline(mapped(park.running_track.centerline),Color("d47760"),1.4,true)
    for lake in lakes:static_layer.draw_colored_polygon(mapped(lake),Color("477f95"))
    for court in sports:static_layer.draw_colored_polygon(mapped(court),Color("9bb6c9"))
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
    if static_view:draw_texture_rect(static_view.get_texture(),Rect2(Vector2.ZERO,size),false)
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
