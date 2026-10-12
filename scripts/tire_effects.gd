extends Node3D
@export var capacity: int = 3000
@export var lifetime: float = 65.0
var vehicle: CharacterBody3D
var marks: MultiMeshInstance3D
var trail_material: ShaderMaterial
var emitters: Array[CPUParticles3D] = []
var particle_materials: Array[StandardMaterial3D] = []
var last_contacts: Array[Vector3] = []
var has_contact: Array[bool] = []
var clock: float = 0
var written: int = 0
var smoke_active: bool = false
func initialize(cart: CharacterBody3D) -> void:
    vehicle=cart
    top_level=true
    global_transform=Transform3D.IDENTITY
    var mesh:=PlaneMesh.new()
    mesh.size=Vector2(.19,1)
    trail_material=ShaderMaterial.new()
    trail_material.shader=load("res://assets/tire_trail.gdshader")
    trail_material.set_shader_parameter("lifetime",lifetime)
    mesh.material=trail_material
    var multi:=MultiMesh.new()
    multi.transform_format=MultiMesh.TRANSFORM_3D
    multi.use_custom_data=true
    multi.mesh=mesh
    multi.instance_count=capacity
    multi.visible_instance_count=0
    marks=MultiMeshInstance3D.new()
    marks.name="TireTrails"
    marks.multimesh=multi
    marks.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
    add_child(marks)
    for i in 4:last_contacts.append(Vector3.ZERO);has_contact.append(false)
    for i in 2:
        var particles:=CPUParticles3D.new()
        particles.name="RearTireSmoke"+str(i)
        particles.emitting=false
        particles.amount=60
        particles.lifetime=.9
        particles.local_coords=false
        particles.direction=Vector3.UP
        particles.spread=65
        particles.initial_velocity_min=.5
        particles.initial_velocity_max=1.5
        particles.gravity=Vector3(0,.2,0)
        particles.scale_amount_min=.22
        particles.scale_amount_max=.58
        particles.damping_min=.7
        particles.damping_max=1.6
        particles.fixed_fps=30
        var gradient:=Gradient.new()
        gradient.offsets=PackedFloat32Array([0,.25,1])
        gradient.colors=PackedColorArray([Color(.8,.79,.73,.08),Color(.8,.79,.73,.35),Color(.8,.79,.73,0)])
        particles.color_ramp=gradient
        var grow:=Curve.new()
        grow.add_point(Vector2(0,.35));grow.add_point(Vector2(.7,1));grow.add_point(Vector2(1,0))
        particles.scale_amount_curve=grow
        var quad:=QuadMesh.new()
        quad.size=Vector2.ONE
        var material:=StandardMaterial3D.new()
        material.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED
        material.transparency=BaseMaterial3D.TRANSPARENCY_ALPHA
        material.billboard_mode=BaseMaterial3D.BILLBOARD_PARTICLES
        material.vertex_color_use_as_albedo=false
        material.albedo_color=Color(.82,.80,.73,.28)
        material.albedo_texture=load("res://assets/dust_puff.svg")
        quad.material=material
        particle_materials.append(material)
        particles.mesh=quad
        particles.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
        add_child(particles)
        emitters.append(particles)
func reset_contacts() -> void:
    for i in has_contact.size():has_contact[i]=false
    smoke_active=false
    for particles in emitters:particles.emitting=false
func update_effects(delta: float, braking: bool) -> void:
    clock+=delta
    trail_material.set_shader_parameter("clock",clock)
    if vehicle.rolling or not vehicle.is_on_floor():reset_contacts();return
    var speed_value:=absf(vehicle.speed)
    smoke_active=speed_value>4 and (braking or vehicle.drifting or (not vehicle.on_path and speed_value>7))
    for i in emitters.size():
        var wheel: Node3D=vehicle.wheels[i+2]
        emitters[i].global_position=wheel.global_position+Vector3(0,-.15,0)
        particle_materials[i].albedo_color=Color(.82,.80,.73,.28) if vehicle.on_path else Color(.65,.55,.39,.28)
        emitters[i].emitting=smoke_active
    var strength:=.24 if vehicle.on_path else .42
    if braking or vehicle.drifting:strength=.94
    for i in vehicle.wheels.size():
        var contact: Vector3=vehicle.wheels[i].global_position
        var query:=PhysicsRayQueryParameters3D.create(contact+Vector3(0,.2,0),contact-Vector3(0,.8,0),1)
        var hit:=get_world_3d().direct_space_state.intersect_ray(query)
        if hit.is_empty() or speed_value<.7:has_contact[i]=false;continue
        contact=hit.position+Vector3.UP*(.067 if vehicle.on_path and float(hit.position.y)<.05 else (.023 if float(hit.position.y)>.05 else .009))
        if has_contact[i]:
            var length:=last_contacts[i].distance_to(contact)
            if length>=.3 and length<3.0:
                add_mark(last_contacts[i],contact,strength,not vehicle.on_path)
                last_contacts[i]=contact
            elif length>=3.0:has_contact[i]=false
        if not has_contact[i]:last_contacts[i]=contact;has_contact[i]=true
func add_mark(begin: Vector3, end: Vector3, strength: float, dirt: bool) -> void:
    var direction:=end-begin
    var length:=direction.length()
    if length<.01:return
    var yaw:=atan2(direction.x,direction.z)
    var placement:=Transform3D(Basis(Vector3.UP,yaw).scaled(Vector3(1,1,length+.03)),(begin+end)*.5)
    var slot:=written%capacity
    marks.multimesh.set_instance_transform(slot,placement)
    marks.multimesh.set_instance_custom_data(slot,Color(clock,strength,1 if dirt else 0,0))
    written+=1
    marks.multimesh.visible_instance_count=mini(written,capacity)
