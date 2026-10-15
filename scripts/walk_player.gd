extends CharacterBody3D
signal recovered(reason: String)
var active: bool=false
var park: Node3D
var camera_rig: Node3D
var settings: Dictionary
var safe_transform: Transform3D
var safe_time: float=0
var distance_m: float=0
@onready var avatar: Node3D=$Avatar
@onready var weapons: Node3D=$WeaponSystem
func _ready() -> void:
    add_to_group("walk_player")
    settings=JSON.parse_string(FileAccess.get_file_as_string("res://data/player_settings.json"))
    set_active(false)
func initialize(world: Node3D, camera: Node3D) -> void:
    park=world;camera_rig=camera
    weapons.initialize(self,camera)
func set_active(value: bool) -> void:
    active=value
    visible=value
    collision_layer=4 if value else 0
    collision_mask=11 if value else 0
    velocity=Vector3.ZERO
    if is_instance_valid(weapons):weapons.set_enabled(value)
func teleport_to(point: Vector2, yaw: float) -> void:
    global_position=Vector3(point.x,.15,point.y)
    rotation=Vector3(0,yaw,0);velocity=Vector3.ZERO
    safe_transform=global_transform;safe_time=0;reset_physics_interpolation()
    if park:park.nature.refresh()
func recover(reason: String="Returned to safe ground") -> void:
    var game: Node=get_parent()
    if game.get("survival"):
        var point: Vector2=game.survival.safe_point(Vector2(global_position.x,global_position.z),self)
        global_position=Vector3(point.x,.15,point.y)
    else:global_transform=safe_transform
    global_position.y=.15;velocity=Vector3.ZERO
    reset_physics_interpolation();recovered.emit(reason)
    if camera_rig:camera_rig.foot_yaw=rotation.y;camera_rig.snap()
func _physics_process(delta: float) -> void:
    if not active or park==null:return
    var input:=Input.get_vector("left","right","accelerate","reverse")
    var direction: Vector3=camera_rig.global_basis.x*input.x+camera_rig.global_basis.z*input.y
    direction.y=0;direction=direction.normalized()
    var speed: float=settings.run_speed if Input.is_action_pressed("sprint") and not weapons.aiming else settings.walk_speed
    velocity.x=move_toward(velocity.x,direction.x*speed,float(settings.acceleration)*delta)
    velocity.z=move_toward(velocity.z,direction.z*speed,float(settings.acceleration)*delta)
    if is_on_floor():
        velocity.y=-.5
        if Input.is_action_just_pressed("jump"):velocity.y=settings.jump_velocity
    else:velocity.y-=float(settings.gravity)*delta
    if weapons.selected_slot>0:rotation.y=lerp_angle(rotation.y,camera_rig.foot_yaw,1-exp(-delta*18))
    elif direction.length_squared()>.01:rotation.y=lerp_angle(rotation.y,atan2(-direction.x,-direction.z),1-exp(-delta*14))
    var before:=global_position
    move_and_slide()
    distance_m+=Vector2(global_position.x-before.x,global_position.z-before.z).length()
    avatar.set_motion(Vector2(velocity.x,velocity.z).length(),is_on_floor(),weapons.aiming,camera_rig.pitch)
    avatar.move_input=input
    var point:=Vector2(global_position.x,global_position.z)
    if global_position.y< -4 or not park._inside_water_polygon(point,park.boundary):recover("Returned inside the park")
    elif park.is_water(point):recover("Water ahead - returned to safe ground")
    elif is_on_floor():
        safe_time+=delta
        if safe_time>1:safe_transform=global_transform;safe_time=0
func receive_hit(amount: float, _point: Vector3, _normal: Vector3) -> void:
    var game: Node=get_parent()
    if game.get("survival"):game.survival.damage_player(amount)
