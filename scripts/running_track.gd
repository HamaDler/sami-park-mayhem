extends Node3D
@export var layout_file: String="res://data/running_track.json"
var layout: Dictionary
var centerline: PackedVector2Array
var points: PackedVector2Array
var miters: PackedVector2Array
var lane_dividers: Array[PackedVector2Array]=[]
func _ready() -> void:
    layout=JSON.parse_string(FileAccess.get_file_as_string(layout_file))
    centerline=ParkGeometry.points(layout.points,true)
    points=ParkGeometry.points(layout.points)
    _build_miters()
    var half: float=float(layout.width)*.5
    var height: float=float(layout.surface_height)
    _strip(-half-.18,half+.18,height-.014,layout.border_color,"TrackBorder")
    for lane in int(layout.lanes):
        var left: float=-half+lane*float(layout.width)/int(layout.lanes)
        var right: float=left+float(layout.width)/int(layout.lanes)
        _strip(left,right,height,layout.lane_colors[lane%layout.lane_colors.size()],"Lane"+str(lane+1))
    var paint:=PackedVector3Array()
    for divider in range(1,int(layout.lanes)):
        var offset: float=-half+divider*float(layout.width)/int(layout.lanes)
        lane_dividers.append(offset_points(offset))
        paint.append_array(ribbon_vertices(offset-float(layout.line_width)*.5,offset+float(layout.line_width)*.5,height+.003))
    for offset in [-half+.09,half-.09]:
        paint.append_array(ribbon_vertices(offset-float(layout.edge_line_width)*.5,offset+float(layout.edge_line_width)*.5,height+.003))
    var white:=ParkGeometry.material(Color("f4f1e8"))
    white.cull_mode=BaseMaterial3D.CULL_DISABLED
    var line_mesh:=ParkGeometry.mesh_from_vertices(self,paint,white,"LaneMarkings")
    line_mesh.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
    # The park's continuous ground supports this flush surface. Paint and borders
    # are visual only so all shared walking-path junctions remain drivable.
    print("TRACK: two red lanes; closed ",layout.length_m," m northwestern loop")
func _build_miters() -> void:
    for i in points.size():
        var before: Vector2=(points[i]-points[(i-1+points.size())%points.size()]).normalized()
        var after: Vector2=(points[(i+1)%points.size()]-points[i]).normalized()
        var first:=Vector2(-before.y,before.x)
        var second:=Vector2(-after.y,after.x)
        var normal: Vector2=(first+second).normalized()
        var divisor:=normal.dot(second)
        miters.append(normal*minf(2.5,1.0/maxf(.4,divisor)))
func offset_points(distance: float) -> PackedVector2Array:
    var result:=PackedVector2Array()
    for i in points.size():result.append(points[i]+miters[i]*distance)
    result.append(result[0])
    return result
func ribbon_vertices(left: float, right: float, height: float) -> PackedVector3Array:
    var vertices:=PackedVector3Array()
    for i in points.size():
        var next: int=(i+1)%points.size()
        var corners: Array[Vector2]=[points[i]+miters[i]*left,points[i]+miters[i]*right,points[next]+miters[next]*right,points[next]+miters[next]*left]
        for index in [0,1,2,0,2,3]:
            var p: Vector2=corners[index]
            vertices.append(Vector3(p.x,height,p.y))
    return vertices
func _strip(left: float, right: float, height: float, color: String, label: String) -> void:
    var material:=ParkGeometry.material(Color(color))
    material.cull_mode=BaseMaterial3D.CULL_DISABLED
    var item:=ParkGeometry.mesh_from_vertices(self,ribbon_vertices(left,right,height),material,label)
    item.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
func contains(point: Vector2) -> bool:
    for i in range(centerline.size()-1):
        if point.distance_to(Geometry2D.get_closest_point_to_segment(point,centerline[i],centerline[i+1]))<=float(layout.width)*.5:return true
    return false
