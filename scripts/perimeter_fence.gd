extends Node3D
@export_file("*.json") var settings_file: String="res://data/perimeter_settings.json"
var settings: Dictionary
var outline:=PackedVector2Array()
var sections: Array[StaticBody3D]=[]
var length_m: float=0
var batches: Dictionary={}

func build(boundary: PackedVector2Array) -> void:
    settings=JSON.parse_string(FileAccess.get_file_as_string(settings_file))
    outline=boundary.duplicate()
    if outline.size()>2 and outline[0].is_equal_approx(outline[-1]):outline.remove_at(outline.size()-1)
    if outline.size()<3:return
    var height: float=settings.height
    for edge in outline.size():
        var a:=outline[edge]
        var b:=outline[(edge+1)%outline.size()]
        var distance:=a.distance_to(b)
        if distance<.001:continue
        length_m+=distance
        var direction: Vector2=(b-a)/distance
        var basis:=Basis(Vector3.UP,-atan2(direction.y,direction.x))
        # Short static boxes are also picked up by the survival navigation obstacle scan.
        # Overlapping ends seal every corner and avoid thin-wall tunnelling at 200 km/h.
        var count:=maxi(1,ceili(distance/float(settings.max_segment_length)))
        for i in count:
            var start:=a.lerp(b,float(i)/count)
            var end:=a.lerp(b,float(i+1)/count)
            var midpoint: Vector2=(start+end)*.5
            var span:=start.distance_to(end)
            var body:=StaticBody3D.new()
            body.name="Fence_%d_%d" % [edge,i]
            body.collision_layer=1
            body.collision_mask=0
            body.position=Vector3(midpoint.x,(height-.18)*.5,midpoint.y)
            body.basis=basis
            var collider:=CollisionShape3D.new()
            var shape:=BoxShape3D.new()
            shape.size=Vector3(span+float(settings.collision_thickness),height+.42,settings.collision_thickness)
            collider.shape=shape
            body.add_child(collider)
            add_child(body)
            sections.append(body)
            _piece(Vector3(midpoint.x,float(settings.base_height)*.5,midpoint.y),basis,Vector3(span+.06,settings.base_height,.54),"Base")
            for y in [.5,height*.52,height-.12]:
                _piece(Vector3(midpoint.x,y,midpoint.y),basis,Vector3(span+.06,.09,.10),"Metal")
        var posts:=maxi(1,ceili(distance/float(settings.post_spacing)))
        for i in posts:
            var point:=a.lerp(b,float(i)/posts)
            _piece(Vector3(point.x,height*.5,point.y),basis,Vector3(.16,height,.16),"Metal")
            _piece(Vector3(point.x,height+.04,point.y),basis,Vector3(.23,.16,.23),"Metal")
        var bars:=maxi(1,ceili(distance/float(settings.bar_spacing)))
        for i in bars:
            var point:=a.lerp(b,(float(i)+.5)/bars)
            _piece(Vector3(point.x,(height+float(settings.base_height))*.5,point.y),basis,Vector3(.045,height-float(settings.base_height),.045),"Metal")
    _finish_batches()

func _piece(point: Vector3, basis: Basis, size: Vector3, kind: String) -> void:
    var chunk:=Vector2i(floori(point.x/float(settings.chunk_size)),floori(point.z/float(settings.chunk_size)))
    var key:=kind+str(chunk)
    var origin:=Vector3(chunk.x*float(settings.chunk_size),0,chunk.y*float(settings.chunk_size))
    if not batches.has(key):batches[key]={"kind":kind,"origin":origin,"transforms":[]}
    batches[key].transforms.append(Transform3D(basis.scaled_local(size),point-origin))

func _finish_batches() -> void:
    var mesh:=BoxMesh.new()
    mesh.size=Vector3.ONE
    var materials: Dictionary={"Metal":ParkGeometry.material(Color(settings.metal_color),.65),"Base":ParkGeometry.material(Color(settings.base_color))}
    for key: String in batches:
        var batch: Dictionary=batches[key]
        var multi:=MultiMesh.new()
        multi.transform_format=MultiMesh.TRANSFORM_3D
        multi.mesh=mesh
        multi.instance_count=batch.transforms.size()
        for i in multi.instance_count:multi.set_instance_transform(i,batch.transforms[i])
        var instance:=MultiMeshInstance3D.new()
        instance.name=key
        instance.multimesh=multi
        instance.position=batch.origin
        instance.material_override=materials[batch.kind]
        instance.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
        add_child(instance)
    batches.clear()
