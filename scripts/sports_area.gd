extends Node3D
@export var layout_file: String = "res://data/sports_layout.json"
var layout: Dictionary
var polygons: Array[PackedVector2Array] = []
var white := ParkGeometry.material(Color("f2eee1"))
var metal := ParkGeometry.material(Color("344944"))
var glass: StandardMaterial3D
var net_material: ShaderMaterial
func _ready() -> void:
    layout=JSON.parse_string(FileAccess.get_file_as_string(layout_file))
    glass=ParkGeometry.material(Color(.68,.83,.84,.19))
    glass.transparency=BaseMaterial3D.TRANSPARENCY_ALPHA
    glass.cull_mode=BaseMaterial3D.CULL_DISABLED
    glass.roughness=.15
    net_material=ShaderMaterial.new()
    net_material.shader=load("res://assets/sports_net.gdshader")
    for field: Dictionary in layout.courts:
        polygons.append(ParkGeometry.points(field.polygon))
        var parcel:=Node3D.new()
        parcel.name=field.label.replace(" ","")
        parcel.position=Vector3(field.center[0],0,field.center[1])
        parcel.rotation.y=field.yaw
        add_child(parcel)
        var base_mat:=ParkGeometry.material(Color("bba783") if field.kind=="basketball" else Color("aa765e"))
        ParkGeometry.box(parcel,Vector3(0,.045,0),Vector3(field.size[0]-1,.09,field.size[1]-1),base_mat,true)
        if field.kind=="basketball":_basketball(parcel)
        elif field.kind=="volleyball":_volleyball(parcel)
        else:
            for index in 3:
                var court:=Node3D.new()
                court.name="PadelCourt"+str(index+1)
                court.position=Vector3(0,0,(index-1)*13.0)
                parcel.add_child(court)
                _padel(court)
        var court_sign:=Label3D.new()
        court_sign.text=field.label.to_upper()
        court_sign.position=Vector3(0,2.6,-float(field.size[1])*.5+1)
        court_sign.font_size=40
        court_sign.pixel_size=.016
        court_sign.billboard=BaseMaterial3D.BILLBOARD_ENABLED
        court_sign.modulate=Color("fff3cb")
        parcel.add_child(court_sign)
    print("SPORTS: basketball, volleyball, three padel courts at mapped southwest footprints")
func is_inside(point: Vector2) -> bool:
    for polygon in polygons:
        if Geometry2D.is_point_in_polygon(point,polygon):return true
    return false
func _paint(parent: Node3D, points: PackedVector2Array, width: float=.075) -> void:
    ParkGeometry.mesh_from_vertices(parent,ParkGeometry.road_vertices(points,width,.105),white,"CourtLine")
func _rectangle(parent: Node3D, width: float, length: float, center: Vector2=Vector2.ZERO) -> void:
    _paint(parent,PackedVector2Array([center+Vector2(-width/2,-length/2),center+Vector2(width/2,-length/2),center+Vector2(width/2,length/2),center+Vector2(-width/2,length/2),center+Vector2(-width/2,-length/2)]))
func _arc(parent: Node3D, center: Vector2, radius: float, begin: float=0, end: float=TAU) -> void:
    var points:=PackedVector2Array()
    for index in 49:
        var angle:=lerpf(begin,end,index/48.0)
        points.append(center+Vector2(cos(angle),sin(angle))*radius)
    _paint(parent,points)
func _net(parent: Node3D, width: float, height: float, base: float, yaw: float=0) -> void:
    var plane:=MeshInstance3D.new()
    var mesh:=QuadMesh.new()
    mesh.size=Vector2(width,height)
    plane.mesh=mesh
    plane.material_override=net_material
    plane.position=Vector3(0,base+height/2,0)
    plane.rotation.y=yaw
    parent.add_child(plane)
    var size:=Vector3(width,.07,.09) if yaw==0 else Vector3(.09,.07,width)
    ParkGeometry.box(parent,Vector3(0,base+height-.035,0),size,white)
    ParkGeometry.collider(parent,Vector3(0,base+height/2,0),Vector3(width,height,.09) if yaw==0 else Vector3(.09,height,width))
func _basketball(parent: Node3D) -> void:
    ParkGeometry.box(parent,Vector3(0,.096,0),Vector3(15,.008,28),ParkGeometry.material(Color("537b86")))
    _rectangle(parent,15,28)
    _paint(parent,PackedVector2Array([Vector2(-7.5,0),Vector2(7.5,0)]))
    _arc(parent,Vector2.ZERO,1.8)
    for side in [-1.0,1.0]:
        _rectangle(parent,4.9,5.8,Vector2(0,side*11.1))
        _arc(parent,Vector2(0,side*8.2),1.8)
        var points:=PackedVector2Array()
        for i in 41:
            var angle:=i*PI/40
            points.append(Vector2(cos(angle)*6.75,side*(12.4-sin(angle)*6.75)))
        _paint(parent,points)
        for x in [-6.75,6.75]:_paint(parent,PackedVector2Array([Vector2(x,side*12.4),Vector2(x,side*14)]))
        ParkGeometry.cylinder(parent,Vector3(0,1.8,side*15.6),.13,3.6,metal)
        ParkGeometry.collider(parent,Vector3(0,1.5,side*15.6),Vector3(.35,3,.35))
        ParkGeometry.box(parent,Vector3(0,3.12,side*14.55),Vector3(1.8,1.05,.09),white)
        ParkGeometry.box(parent,Vector3(0,2.8,side*15.0),Vector3(.13,.13,1.2),metal)
        var rim:=MeshInstance3D.new()
        var ring:=TorusMesh.new()
        ring.inner_radius=.195;ring.outer_radius=.225;ring.rings=16;ring.ring_segments=8
        rim.mesh=ring
        rim.material_override=ParkGeometry.material(Color("d7753f"))
        rim.position=Vector3(0,3.05,side*14.05)
        parent.add_child(rim)
        for i in 8:
            var angle:=i*TAU/8
            ParkGeometry.line(parent,Vector3(cos(angle)*.20,3.05,side*14.05+sin(angle)*.20),Vector3(cos(angle)*.13,2.65,side*14.05+sin(angle)*.13),.008,white)
func _volleyball(parent: Node3D) -> void:
    ParkGeometry.box(parent,Vector3(0,.096,0),Vector3(9,.008,18),ParkGeometry.material(Color("cfac7c")))
    _rectangle(parent,9,18)
    for z in [-3.0,0.0,3.0]:_paint(parent,PackedVector2Array([Vector2(-4.5,z),Vector2(4.5,z)]))
    _net(parent,10.8,1.0,1.43)
    for x in [-5.4,5.4]:
        ParkGeometry.cylinder(parent,Vector3(x,1.4,0),.09,2.8,metal)
        ParkGeometry.collider(parent,Vector3(x,1.4,0),Vector3(.22,2.8,.22))
func _padel(parent: Node3D) -> void:
    ParkGeometry.box(parent,Vector3(0,.096,0),Vector3(20,.008,10),ParkGeometry.material(Color("64868a")))
    _rectangle(parent,20,10)
    for x in [-6.95,6.95]:_paint(parent,PackedVector2Array([Vector2(x,-5),Vector2(x,5)]))
    for side in [-1.0,1.0]:_paint(parent,PackedVector2Array([Vector2(side*.1,0),Vector2(side*6.95,0)]))
    _net(parent,10,.92,.09,PI/2)
    for z in [-5.05,5.05]:ParkGeometry.cylinder(parent,Vector3(0,.65,z),.055,1.3,metal)
    for x in [-10.0,10.0]:
        ParkGeometry.box(parent,Vector3(x,1.6,0),Vector3(.07,3,10),glass,true)
        for z in [-5.0,-2.5,0.0,2.5,5.0]:ParkGeometry.cylinder(parent,Vector3(x,2.05,z),.045,4.0,metal)
        var upper:=Node3D.new();upper.position=Vector3(x,0,0);upper.rotation.y=PI/2;parent.add_child(upper)
        _net(upper,10,1,3.1)
    for z in [-5.0,5.0]:
        for x in [-8.0,8.0]:ParkGeometry.box(parent,Vector3(x,1.6,z),Vector3(4,3,.07),glass,true)
        for x in [-3.45,3.45]:
            var fence:=Node3D.new();fence.position=Vector3(x,0,z);parent.add_child(fence)
            _net(fence,5.1,3,.1)
        for x in [-10.0,-6.0,-.9,.9,6.0,10.0]:ParkGeometry.cylinder(parent,Vector3(x,1.6,z),.045,3.0,metal)
