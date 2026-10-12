class_name ParkGeometry
extends RefCounted

static func material(color: Color, roughness: float = 0.85) -> StandardMaterial3D:
    var m := StandardMaterial3D.new()
    m.albedo_color = color.srgb_to_linear()
    m.roughness = roughness
    return m

static func box(parent: Node3D, pos: Vector3, size: Vector3, mat: Material, solid: bool = false) -> MeshInstance3D:
    var mesh := BoxMesh.new()
    mesh.size = size
    var item := MeshInstance3D.new()
    item.mesh = mesh
    item.material_override = mat
    item.position = pos
    parent.add_child(item)
    if solid:
        collider(parent, pos, size)
    return item

static func collider(parent: Node3D, pos: Vector3, size: Vector3) -> StaticBody3D:
    var body := StaticBody3D.new()
    body.position = pos
    var shape := CollisionShape3D.new()
    var form := BoxShape3D.new()
    form.size = size
    shape.shape = form
    body.add_child(shape)
    parent.add_child(body)
    return body

static func cylinder(parent: Node3D, pos: Vector3, radius: float, height: float, mat: Material, top_radius: float = -1.0) -> MeshInstance3D:
    var form := CylinderMesh.new()
    form.bottom_radius = radius
    form.top_radius = radius if top_radius < 0.0 else top_radius
    form.height = height
    form.radial_segments = 12
    var item := MeshInstance3D.new()
    item.mesh = form
    item.position = pos
    item.material_override = mat
    parent.add_child(item)
    return item

static func sphere(parent: Node3D, pos: Vector3, size: Vector3, mat: Material) -> MeshInstance3D:
    var form := SphereMesh.new()
    form.radius = 1.0
    form.height = 2.0
    form.radial_segments = 16
    form.rings = 8
    var item := MeshInstance3D.new()
    item.mesh = form
    item.position = pos
    item.scale = size
    item.material_override = mat
    parent.add_child(item)
    return item

static func line(parent: Node3D, a: Vector3, b: Vector3, radius: float, mat: Material) -> MeshInstance3D:
    var item := cylinder(parent, (a+b)*0.5, radius, a.distance_to(b), mat)
    var up := (b-a).normalized()
    var right := up.cross(Vector3.FORWARD).normalized()
    if right.length_squared() < 0.01:
        right = up.cross(Vector3.RIGHT).normalized()
    item.basis = Basis(right,up,right.cross(up).normalized())
    return item

static func polygon_vertices(polygon_points: PackedVector2Array, y: float) -> PackedVector3Array:
    var vertices := PackedVector3Array()
    var triangles := Geometry2D.triangulate_polygon(polygon_points)
    for i in range(0, triangles.size(), 3):
        for j in [0,2,1]:
            var p := polygon_points[triangles[i+j]]
            vertices.append(Vector3(p.x,y,p.y))
    return vertices

static func mesh_from_vertices(parent: Node3D, vertices: PackedVector3Array, mat: Material, label: String) -> MeshInstance3D:
    if vertices.is_empty():
        return null
    var st := SurfaceTool.new()
    st.begin(Mesh.PRIMITIVE_TRIANGLES)
    for i in range(0,vertices.size(),3):
        for j in [0,2,1]:st.add_vertex(vertices[i+j])
    st.generate_normals()
    var item := MeshInstance3D.new()
    item.name = label
    item.mesh = st.commit()
    item.material_override = mat
    if label in ["ParkBoundary","GardenBeds","MappedPaths","PathBorders","SurroundingStreets","LakeShore","Water"]:
        item.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
    parent.add_child(item)
    return item

static func points(raw: Array, keep_closed: bool = false) -> PackedVector2Array:
    var result := PackedVector2Array()
    for p in raw:
        result.append(Vector2(float(p[0]),float(p[1])))
    if not keep_closed and result.size()>2 and result[0].is_equal_approx(result[-1]):
        result.remove_at(result.size()-1)
    return result

static func road_vertices(points_list: PackedVector2Array, width: float, y: float) -> PackedVector3Array:
    var vertices := PackedVector3Array()
    for i in range(points_list.size()-1):
        var a := points_list[i]
        var b := points_list[i+1]
        var d := (b-a).normalized()
        var n := Vector2(-d.y,d.x)*width*0.5
        var corners := [a-n,a+n,b+n,b-n]
        for j in [0,1,2,0,2,3]:
            var p: Vector2 = corners[j]
            vertices.append(Vector3(p.x,y,p.y))
    # Rounded caps cover joints and crossings without disconnected collision surfaces.
    for p in points_list:
        for j in range(10):
            var a := p+Vector2.from_angle(j*TAU/10.0)*width*0.5
            var b := p+Vector2.from_angle((j+1)*TAU/10.0)*width*0.5
            vertices.append_array(PackedVector3Array([Vector3(p.x,y,p.y),Vector3(a.x,y,a.y),Vector3(b.x,y,b.y)]))
    return vertices
