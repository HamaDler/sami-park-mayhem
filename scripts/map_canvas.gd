extends Control
signal point_selected(world_point: Vector2, quick_spawn: bool)
var cart: CharacterBody3D
var park: Node3D
var center_world := Vector2.ZERO
var zoom: float = 1.0
var fit_scale: float = 0.3
var bounds: Rect2
var park_polygon: PackedVector2Array
var roads: Array = []
var paths: Array = []
var gardens: Array[PackedVector2Array] = []
var buildings: Array[PackedVector2Array] = []
var lakes: Array[PackedVector2Array] = []
var sports_polygons: Array[PackedVector2Array] = []
var trees: PackedVector2Array
var labels: Array = []
var selected: Dictionary = {}
var requested_point: Vector2
var panning: bool = false
var label_rects: Array[Rect2] = []
var terrain: Node2D
var overlay: Node2D
var terrain_scale: float = -1.0
var tree_mesh: ArrayMesh
var label_font: Font
var compass_font: Font
var label_style: StyleBoxFlat
var survival: Node3D
const TREE_SEGMENTS: int = 12

func _ready() -> void:
    clip_contents=true
    mouse_filter=Control.MOUSE_FILTER_STOP
    mouse_default_cursor_shape=Control.CURSOR_POINTING_HAND
    # Retain world-space scenery commands; panning only changes its transform.
    terrain=Node2D.new();terrain.name="Terrain";add_child(terrain)
    terrain.draw.connect(_draw_terrain)
    overlay=Node2D.new();overlay.name="Overlay";add_child(overlay)
    overlay.draw.connect(_draw_overlay)
    label_font=GameUI.body_bold();compass_font=GameUI.display()
    label_style=StyleBoxFlat.new()
    label_style.bg_color=Color(.045,.065,.10,.94)
    resized.connect(_resize_map)

func initialize(vehicle: CharacterBody3D, world: Node3D) -> void:
    cart=vehicle
    park=world
    park_polygon=park.boundary
    bounds=Rect2(park_polygon[0],Vector2.ZERO)
    for p in park_polygon:bounds=bounds.expand(p)
    for road in park.layout.streets:roads.append({"points":ParkGeometry.points(road.points,true),"width":float(road.width)})
    for path in park.layout.paths:paths.append({"points":ParkGeometry.points(path.points,true),"width":float(path.width)})
    for garden in park.layout.gardens:
        var poly:=ParkGeometry.points(garden.points)
        if not Geometry2D.triangulate_polygon(poly).is_empty():gardens.append(poly)
    for building in park.layout.buildings:
        var poly:=ParkGeometry.points(building.points)
        if not Geometry2D.triangulate_polygon(poly).is_empty():buildings.append(poly)
    lakes.assign(park.water_polygons)
    sports_polygons.assign(park.sports.polygons)
    trees=park.tree_positions.duplicate()
    _build_tree_mesh()
    terrain_scale=-1.0
    labels=JSON.parse_string(FileAccess.get_file_as_string("res://data/map_labels.json"))
    fit_park()

func _resize_map() -> void:
    if park:
        fit_scale=maxf(0.01,minf((size.x-100)/bounds.size.x,(size.y-80)/bounds.size.y))
    queue_redraw()

func fit_park() -> void:
    zoom=1
    center_world=bounds.get_center()
    _resize_map()

func find_cart() -> void:
    center_world=Vector2(cart.global_position.x,cart.global_position.z)
    zoom=maxf(zoom,2.5)
    queue_redraw()

func world_to_map(point: Vector2) -> Vector2:
    return size*0.5+(point-center_world)*fit_scale*zoom

func map_to_world(point: Vector2) -> Vector2:
    return center_world+(point-size*0.5)/(fit_scale*zoom)

func zoom_at(multiplier: float, anchor: Vector2) -> void:
    var before:=map_to_world(anchor)
    zoom=clampf(zoom*multiplier,0.8,10.0)
    center_world+=before-map_to_world(anchor)
    queue_redraw()

func _gui_input(event: InputEvent) -> void:
    if event is InputEventMouseButton:
        if event.pressed and event.button_index in [MOUSE_BUTTON_WHEEL_UP,MOUSE_BUTTON_WHEEL_DOWN]:
            zoom_at(1.2 if event.button_index==MOUSE_BUTTON_WHEEL_UP else 1.0/1.2,event.position)
            accept_event()
        elif event.button_index in [MOUSE_BUTTON_RIGHT,MOUSE_BUTTON_MIDDLE]:
            panning=event.pressed
            mouse_default_cursor_shape=Control.CURSOR_DRAG if panning else Control.CURSOR_POINTING_HAND
            accept_event()
        elif event.pressed and event.button_index==MOUSE_BUTTON_LEFT:
            point_selected.emit(map_to_world(event.position),event.double_click)
            accept_event()
    elif event is InputEventMouseMotion and panning:
        center_world-=event.relative/(fit_scale*zoom)
        queue_redraw()
        accept_event()

func _build_tree_mesh() -> void:
    tree_mesh=null
    if trees.is_empty():return
    # One indexed mesh replaces more than ten thousand individual circle commands.
    var vertices:=PackedVector2Array()
    var indices:=PackedInt32Array()
    vertices.resize(trees.size()*(TREE_SEGMENTS+1))
    indices.resize(trees.size()*TREE_SEGMENTS*3)
    for i in trees.size():
        var first:=i*(TREE_SEGMENTS+1)
        vertices[first]=trees[i]
        for segment in TREE_SEGMENTS:
            var angle:=TAU*segment/TREE_SEGMENTS
            vertices[first+1+segment]=trees[i]+Vector2(cos(angle),sin(angle))*4.5
            var triangle: int=(i*TREE_SEGMENTS+segment)*3
            indices[triangle]=first
            indices[triangle+1]=first+1+segment
            indices[triangle+2]=first+1+(segment+1)%TREE_SEGMENTS
    var arrays:=[]
    arrays.resize(Mesh.ARRAY_MAX)
    arrays[Mesh.ARRAY_VERTEX]=vertices
    arrays[Mesh.ARRAY_INDEX]=indices
    tree_mesh=ArrayMesh.new()
    tree_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays,[],{},Mesh.ARRAY_FLAG_USE_2D_VERTICES)

func _draw() -> void:
    draw_rect(Rect2(Vector2.ZERO,size),Color("dadccd"))
    if park==null:return
    var scale_factor:=fit_scale*zoom
    terrain.position=size*0.5-center_world*scale_factor
    terrain.scale=Vector2.ONE*scale_factor
    if not is_equal_approx(terrain_scale,scale_factor):
        terrain_scale=scale_factor
        terrain.queue_redraw()
    overlay.queue_redraw()

func _draw_terrain() -> void:
    if park==null:return
    var scale_factor:=fit_scale*zoom
    for road in roads:
        terrain.draw_polyline(road.points,Color("b3b6a6"),maxf(road.width+7,5/scale_factor),true)
        terrain.draw_polyline(road.points,Color("f3eed9"),maxf(road.width,2.5/scale_factor),true)
    for building in buildings:terrain.draw_colored_polygon(building,Color("c4c2af"))
    terrain.draw_colored_polygon(park_polygon,Color("8ea97b"))
    var border:=park_polygon.duplicate()
    border.append(border[0])
    terrain.draw_polyline(border,Color("536c50"),2.0/scale_factor,true)
    for i in gardens.size():terrain.draw_colored_polygon(gardens[i],Color("a0b48a") if i%2==0 else Color("83a474"))
    if tree_mesh:terrain.draw_mesh(tree_mesh,null,Transform2D.IDENTITY,Color("79966a"))
    for poly in lakes:
        var shore:=poly.duplicate()
        shore.append(shore[0])
        terrain.draw_polyline(shore,Color("b9c5a0"),5,true)
        terrain.draw_colored_polygon(poly,Color("65a7af"))
        terrain.draw_polyline(shore,Color("498791"),1.0/scale_factor,true)
    for path in paths:
        terrain.draw_polyline(path.points,Color("7c8767"),maxf(path.width+2,2.5/scale_factor),true)
        terrain.draw_polyline(path.points,Color("e9ddba"),maxf(path.width,1.2/scale_factor),true)
    terrain.draw_polyline(park.running_track.centerline,Color("b75346"),maxf(float(park.running_track.layout.width),2.8/scale_factor),true)
    for divider in park.running_track.lane_dividers:terrain.draw_polyline(divider,Color("f4f1e8"),maxf(float(park.running_track.layout.line_width),.55/scale_factor),true)
    for court in sports_polygons:terrain.draw_colored_polygon(court,Color("698d92"))
    for building in buildings:
        if bounds.has_point(building[0]):terrain.draw_colored_polygon(building,Color("b9b597"))

func _draw_overlay() -> void:
    if park==null:return
    var scale_factor:=fit_scale*zoom
    label_rects.clear()
    for entry in labels:
        var point:=world_to_map(Vector2(entry.position[0],entry.position[1]))
        if Rect2(Vector2(8,8),size-Vector2(16,16)).has_point(point):
            _place_label(point,entry.name,entry.get("kind","place"))
    if not selected.is_empty():
        var point: Vector2 = selected.get("position",requested_point)
        var marker:=world_to_map(point)
        var color:=GameUI.LIME if selected.valid else Color("be5645")
        overlay.draw_circle(marker,12,Color(0.1,0.2,0.14,0.25))
        overlay.draw_arc(marker,9,0,TAU,32,color,2.5,true)
        overlay.draw_line(marker-Vector2(15,0),marker+Vector2(15,0),color,1.5,true)
        overlay.draw_line(marker-Vector2(0,15),marker+Vector2(0,15),color,1.5,true)
        if selected.valid:
            var heading:=Vector2(-sin(selected.yaw),-cos(selected.yaw))
            overlay.draw_line(marker,marker+heading*25,color,3,true)
    if cart.is_in_group("walk_player"):
        for access: Node3D in get_tree().get_nodes_in_group("vehicles"):
            var vehicle_point:=world_to_map(Vector2(access.vehicle.global_position.x,access.vehicle.global_position.z))
            overlay.draw_rect(Rect2(vehicle_point-Vector2(6,4),Vector2(12,8)),GameUI.INK)
            overlay.draw_rect(Rect2(vehicle_point-Vector2(4,2),Vector2(8,4)),Color("8bcbd4"))
            if zoom>2 and Rect2(Vector2(8,8),size-Vector2(16,16)).has_point(vehicle_point):_place_label(vehicle_point,access.display_name,"vehicle")
    if survival:
        if survival.missions.active:
            var mission_point:=world_to_map(survival.missions.position_2d)
            overlay.draw_arc(mission_point,10,0,TAU,4,Color("64e2f0"),3,true)
            if Rect2(Vector2(10,10),size-Vector2(20,20)).has_point(mission_point):_place_label(mission_point,"SUPPLIES / "+survival.missions.location_name,"mission")
        for station in survival.stations:
            var marker:=world_to_map(Vector2(station.global_position.x,station.global_position.z))
            overlay.draw_rect(Rect2(marker-Vector2(6,5),Vector2(12,10)),Color("ffd268"))
            if Rect2(Vector2(10,10),size-Vector2(20,20)).has_point(marker):_place_label(marker,"BOX + WORKSHOP / "+station.display_name,"box")
        if survival.wave.running and survival.wave.spawned>=survival.wave.total and survival.wave.remaining()<=5:
            for zombie in survival.enemies.living():overlay.draw_circle(world_to_map(Vector2(zombie.global_position.x,zombie.global_position.z)),5,GameUI.RED)
    var player:=world_to_map(Vector2(cart.global_position.x,cart.global_position.z))
    var direction:=Vector2(-sin(cart.rotation.y),-cos(cart.rotation.y))
    var sideways:=Vector2(-direction.y,direction.x)
    overlay.draw_circle(player,12,Color("1f4138"))
    overlay.draw_colored_polygon(PackedVector2Array([player+direction*12,player-direction*7+sideways*6,player-direction*7-sideways*6]),GameUI.LIME)
    _draw_compass()
    _draw_scale(scale_factor)

func _place_label(point: Vector2, text: String, kind: String) -> void:
    var font:=label_font
    var font_size:=13 if kind=="place" else 12
    var text_size:=font.get_string_size(text,HORIZONTAL_ALIGNMENT_LEFT,-1,font_size)
    var rect:=Rect2(point+Vector2(9,-13),text_size+Vector2(14,10))
    var offsets: Array[Vector2]=[Vector2(9,-13),Vector2(9,24),Vector2(9,-52),Vector2(-text_size.x-23,-13),Vector2(-text_size.x-23,24),Vector2(9,58),Vector2(9,-86)]
    for offset in offsets:
        var candidate:=Rect2(point+offset,text_size+Vector2(14,10))
        var clear:=Rect2(Vector2(6,6),size-Vector2(12,12)).encloses(candidate)
        for previous in label_rects:
            if previous.grow(3).intersects(candidate):clear=false
        if clear:
            rect=candidate
            break
    label_rects.append(rect)
    if rect.position.distance_to(point+Vector2(9,-13))>10:
        overlay.draw_line(point,rect.position+Vector2(0,rect.size.y*0.5),Color("536c50"),1,true)
    overlay.draw_style_box(label_style,rect)
    overlay.draw_circle(point,4,GameUI.LIME if kind=="gate" else Color("e5ebd2"))
    overlay.draw_string(font,rect.position+Vector2(7,17),text,HORIZONTAL_ALIGNMENT_LEFT,-1,font_size,Color("f4efd9"))

func _draw_compass() -> void:
    var origin:=Vector2(size.x-42,44)
    overlay.draw_colored_polygon(PackedVector2Array([origin+Vector2(-24,-24),origin+Vector2(15,-24),origin+Vector2(24,-15),origin+Vector2(24,24),origin+Vector2(-24,24)]),Color(.045,.065,.10,.94))
    overlay.draw_line(origin+Vector2(0,11),origin+Vector2(0,-8),GameUI.LIME,2,true)
    overlay.draw_colored_polygon(PackedVector2Array([origin+Vector2(0,-13),origin+Vector2(-5,-4),origin+Vector2(5,-4)]),GameUI.LIME)
    overlay.draw_string(compass_font,origin+Vector2(-5,-27),"N",HORIZONTAL_ALIGNMENT_LEFT,-1,14,GameUI.INK)

func _draw_scale(scale_factor: float) -> void:
    var metres:=200.0
    while metres*scale_factor>160:metres*=0.5
    while metres*scale_factor<50:metres*=2
    var length:=metres*scale_factor
    var point:=Vector2(24,size.y-28)
    overlay.draw_rect(Rect2(point-Vector2(12,29),Vector2(length+24,47)),Color(.045,.065,.10,.94))
    overlay.draw_line(point,point+Vector2(length,0),GameUI.WHITE,2,true)
    for end in [point,point+Vector2(length,0)]:overlay.draw_line(end-Vector2(0,4),end+Vector2(0,4),GameUI.WHITE,2,true)
    overlay.draw_string(label_font,point-Vector2(0,11),"%.0f m" % metres,HORIZONTAL_ALIGNMENT_LEFT,-1,12,GameUI.WHITE)
