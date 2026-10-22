extends Node
# Comic / graphic-novel art direction.
# - Swaps every lit StandardMaterial3D in the scene (imported models, generated park geometry,
#   streamed trees, zombies spawned later) for a toon material with the same colour and texture.
#   Custom shaders get the same toon lighting through assets/shaders/comic_light.gdshaderinc.
# - Attaches the full-screen ink pass (assets/shaders/comic_post.gdshader) to the camera.
# Materials that glow (emission), blend (transparency) or are unshaded keep their original look,
# except the pre-lit distant tree billboards, which are relit so they match the trees up close.
@export var enabled: bool=true
@export var outline_width: float=1.4
@export_range(0.0,1.0) var hatch_strength: float=0.55
const TOON_BODY:="res://assets/shaders/comic_toon.gdshaderinc"
const POST_SHADER:=preload("res://assets/shaders/comic_post.gdshader")
const IMPOSTOR_FOLDER:="/impostors/"
var shaders: Dictionary={}
var converted: Dictionary={}
var pending: Array[Node]=[]
var post: MeshInstance3D
func _ready() -> void:
    RenderingServer.global_shader_parameter_set("comic_amount",1.0 if enabled else 0.0)
    if not enabled:return
    get_tree().node_added.connect(_on_node_added)
    convert_tree(get_parent())
    var rig: Node=get_parent().get_node_or_null("ChaseCamera")
    if rig and rig.get("camera"):attach_post(rig.camera)
func _exit_tree() -> void:
    if get_tree().node_added.is_connected(_on_node_added):get_tree().node_added.disconnect(_on_node_added)
func attach_post(camera: Camera3D) -> void:
    post=MeshInstance3D.new();post.name="ComicInkPass"
    var quad:=QuadMesh.new();quad.size=Vector2.ONE;post.mesh=quad
    var material:=ShaderMaterial.new();material.shader=POST_SHADER
    # Lowest priority: drawn first among transparent objects, so labels and particles stay on top.
    material.render_priority=Material.RENDER_PRIORITY_MIN
    material.set_shader_parameter("line_width",outline_width)
    material.set_shader_parameter("hatch_strength",hatch_strength)
    post.material_override=material
    post.extra_cull_margin=16384;post.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
    post.set_meta("comic",true)
    camera.add_child(post);post.position=Vector3(0,0,-.5)
func convert_tree(root: Node) -> void:
    process_node(root)
    for child in root.find_children("*","GeometryInstance3D",true,false):process_node(child)
func _on_node_added(node: Node) -> void:
    # Many nodes get their mesh/material right after add_child, so convert at the end of the frame.
    if node is GeometryInstance3D:
        if pending.is_empty():_flush.call_deferred()
        pending.append(node)
func _flush() -> void:
    var batch:=pending;pending=[]
    for node in batch:
        if is_instance_valid(node):process_node(node)
func process_node(node: Node) -> void:
    if not node is GeometryInstance3D or node.has_meta("comic"):return
    var item: GeometryInstance3D=node
    if item.material_override:item.material_override=toon(item.material_override)
    var mesh: Mesh=null
    if item is MeshInstance3D:
        mesh=item.mesh
        if mesh:
            for surface in mesh.get_surface_count():
                var override: Material=item.get_surface_override_material(surface)
                if override:item.set_surface_override_material(surface,toon(override))
    elif item is MultiMeshInstance3D and item.multimesh:mesh=item.multimesh.mesh
    elif item is CPUParticles3D:mesh=item.mesh
    if mesh:_convert_mesh(mesh)
func _convert_mesh(mesh: Mesh) -> void:
    if mesh.has_meta("comic"):return
    mesh.set_meta("comic",true)
    if mesh is PrimitiveMesh:
        if mesh.material:mesh.material=toon(mesh.material)
    elif mesh is ArrayMesh:
        for surface in mesh.get_surface_count():
            var material: Material=mesh.surface_get_material(surface)
            if material:mesh.surface_set_material(surface,toon(material))
func toon(source: Material) -> Material:
    if source==null or source.has_meta("comic"):return source
    if converted.has(source):return converted[source]
    var result: Material=source
    if source is BaseMaterial3D and _convertible(source):result=_make_toon(source)
    converted[source]=result
    return result
func _convertible(material: BaseMaterial3D) -> bool:
    if material.transparency not in [BaseMaterial3D.TRANSPARENCY_DISABLED,BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR,BaseMaterial3D.TRANSPARENCY_ALPHA_HASH]:return false
    if material.emission_enabled or material.no_depth_test or material.uv1_triplanar:return false
    if material.billboard_mode!=BaseMaterial3D.BILLBOARD_DISABLED:return false
    if material.shading_mode==BaseMaterial3D.SHADING_MODE_UNSHADED:return _is_impostor(material)
    return true
func _is_impostor(material: BaseMaterial3D) -> bool:
    return material.albedo_texture!=null and material.albedo_texture.resource_path.contains(IMPOSTOR_FOLDER)
func _shader(cull: int, cutout: bool) -> Shader:
    var key:=str(cull)+(":cutout" if cutout else "")
    if not shaders.has(key):
        var mode: String=["cull_back","cull_front","cull_disabled"][cull]
        var shader:=Shader.new()
        shader.code="shader_type spatial;\nrender_mode %s;\n%s#include \"%s\"\n" % [mode,"#define COMIC_CUTOUT\n" if cutout else "",TOON_BODY]
        shaders[key]=shader
    return shaders[key]
func _make_toon(source: BaseMaterial3D) -> ShaderMaterial:
    var cutout: bool=source.transparency!=BaseMaterial3D.TRANSPARENCY_DISABLED
    var material:=ShaderMaterial.new()
    material.shader=_shader(source.cull_mode,cutout)
    material.render_priority=source.render_priority
    material.next_pass=source.next_pass
    material.set_meta("comic",true)
    var impostor: bool=_is_impostor(source)
    # Billboards were baked under daylight; darken them a little so they sit with the relit trees.
    material.set_shader_parameter("albedo",source.albedo_color*(Color(.82,.82,.82,1) if impostor else Color.WHITE))
    material.set_shader_parameter("use_texture",source.albedo_texture!=null)
    if source.albedo_texture:material.set_shader_parameter("albedo_texture",source.albedo_texture)
    material.set_shader_parameter("use_vertex_color",source.vertex_color_use_as_albedo)
    material.set_shader_parameter("vertex_color_srgb",source.vertex_color_is_srgb)
    material.set_shader_parameter("uv1_scale",source.uv1_scale)
    material.set_shader_parameter("uv1_offset",source.uv1_offset)
    material.set_shader_parameter("alpha_scissor",source.alpha_scissor_threshold)
    material.set_shader_parameter("flat_up_normal",impostor)
    # Shiny and metal parts (gun, cart trim) keep a hard comic highlight.
    var gloss: float=maxf(clampf((.6-source.roughness)/.6,0,1),source.metallic*.7)
    material.set_shader_parameter("comic_gloss",gloss)
    return material
