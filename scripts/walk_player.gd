extends CharacterBody3D
signal recovered(reason: String)
signal melee_landed(count: int)
var active: bool=false
var movement_locked: bool=false
var park: Node3D
var camera_rig: Node3D
var settings: Dictionary
var safe_transform: Transform3D
var safe_time: float=0
var distance_m: float=0
# Stamina is shared by sprinting and rolling. Exhaustion locks sprint until it recovers to sprint_unlock.
var stamina: float=100
var stamina_delay: float=0
var exhausted: bool=false
var sprinting: bool=false
var sprint_block: float=0
var roll_time: float=0
var roll_cooldown: float=0
var roll_direction:=Vector3.ZERO
var melee_time: float=0
var melee_cooldown: float=0
var melee_struck: bool=false
var dead: bool=false
@onready var avatar: Node3D=$Avatar
@onready var weapons: Node3D=$WeaponSystem
func _ready() -> void:
    add_to_group("walk_player")
    settings=JSON.parse_string(FileAccess.get_file_as_string("res://data/player_settings.json"))
    stamina=float(settings.stamina.max)
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
    sprinting=false;roll_time=0;melee_time=0
    if is_instance_valid(avatar):avatar.sprinting=false;avatar.cancel_action()
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
func is_busy() -> bool:return roll_time>0 or melee_time>0 or dead
func is_invulnerable() -> bool:
    return roll_time>0 and float(settings.roll.duration)-roll_time<float(settings.roll.invulnerable)
func break_sprint() -> void:sprinting=false;sprint_block=.35
func _unhandled_input(event: InputEvent) -> void:
    if not active or movement_locked or dead or get_tree().paused or (event is InputEventKey and event.echo):return
    if event.is_action_pressed("roll"):start_roll();get_viewport().set_input_as_handled()
    elif event.is_action_pressed("melee"):start_melee();get_viewport().set_input_as_handled()
func _move_direction(input: Vector2) -> Vector3:
    var direction: Vector3=camera_rig.global_basis.x*input.x+camera_rig.global_basis.z*input.y
    direction.y=0;return direction.normalized()
func start_roll() -> bool:
    if is_busy() or roll_cooldown>0 or not is_on_floor() or stamina<float(settings.roll.get("min_stamina",10)):return false
    var direction:=_move_direction(Input.get_vector("left","right","accelerate","reverse"))
    if direction.length_squared()<.01:direction=global_basis.z;direction.y=0;direction=direction.normalized()
    roll_direction=direction;roll_time=float(settings.roll.duration)
    _spend_stamina(float(settings.stamina.roll_cost))
    sprinting=false;avatar.play_action("Roll",roll_time,false)
    rotation.y=atan2(-direction.x,-direction.z)
    GameUI.play_ui("roll")
    return true
func start_melee() -> bool:
    if is_busy() or melee_cooldown>0:return false
    melee_time=float(settings.melee.duration);melee_cooldown=float(settings.melee.cooldown);melee_struck=false
    sprinting=false;avatar.play_action("Kick_Right",melee_time,true)
    rotation.y=camera_rig.foot_yaw
    GameUI.play_ui("melee_swing_%d" % randi_range(0,1))
    return true
func _strike() -> void:
    melee_struck=true
    var game: Node=get_parent()
    if not game.get("survival"):return
    var forward: Vector3=-global_basis.z;forward.y=0
    var count: int=game.survival.enemies.apply_melee(global_position,forward.normalized(),float(settings.melee.range),float(settings.melee.angle_degrees),float(settings.melee.damage),float(settings.melee.knockback),float(settings.melee.stagger))
    if count>0:
        GameUI.play_ui("melee_hit");camera_rig.add_trauma(.22)
        melee_landed.emit(count)
func _spend_stamina(amount: float) -> void:
    stamina=maxf(0,stamina-amount);stamina_delay=float(settings.stamina.regen_delay)
    if stamina<=0:exhausted=true
func on_damaged(amount: float) -> void:
    if camera_rig:camera_rig.add_trauma(clampf(amount/40.0,.2,.6))
    if not is_busy():avatar.play_action("HitRecieve",.32,true)
func play_death() -> void:
    dead=true;sprinting=false;roll_time=0;melee_time=0;velocity=Vector3.ZERO
    avatar.sprinting=false;avatar.play_action("Death",1.1,false)
func _physics_process(delta: float) -> void:
    if not active or park==null:return
    var input:=Input.get_vector("left","right","accelerate","reverse")
    if movement_locked or dead:input=Vector2.ZERO
    var direction:=_move_direction(input)
    roll_cooldown=maxf(0,roll_cooldown-delta);melee_cooldown=maxf(0,melee_cooldown-delta);sprint_block=maxf(0,sprint_block-delta)
    # Sprint: forward or sideways only, never while aiming, reloading is allowed.
    var stamina_settings: Dictionary=settings.stamina
    if exhausted and stamina>=float(stamina_settings.sprint_unlock):exhausted=false
    sprinting=Input.is_action_pressed("sprint") and not movement_locked and not dead and not weapons.aiming and not is_busy() and not exhausted and sprint_block==0 and input.length()>.2 and input.y<.35
    if sprinting:_spend_stamina(float(stamina_settings.sprint_drain)*delta)
    else:
        stamina_delay=maxf(0,stamina_delay-delta)
        if stamina_delay==0:stamina=minf(float(stamina_settings.max),stamina+float(stamina_settings.regen)*delta)
    avatar.sprinting=sprinting
    var horizontal:=Vector2(velocity.x,velocity.z)
    if roll_time>0:
        roll_time=maxf(0,roll_time-delta)
        # Fast start, eased finish so the roll lands into normal movement.
        var t: float=1-roll_time/float(settings.roll.duration)
        horizontal=Vector2(roll_direction.x,roll_direction.z)*float(settings.roll.speed)*lerpf(1.0,.45,t*t)
        if roll_time==0:roll_cooldown=float(settings.roll.cooldown)
    else:
        var speed: float=settings.run_speed if sprinting else settings.walk_speed
        if melee_time>0:speed*=.35
        var target:=Vector2(direction.x,direction.z)*speed
        var rate: float=float(settings.acceleration) if target.length_squared()>.01 else float(settings.get("deceleration",settings.acceleration))
        horizontal=horizontal.move_toward(target,rate*delta)
    velocity.x=horizontal.x;velocity.z=horizontal.y
    if melee_time>0:
        melee_time=maxf(0,melee_time-delta)
        if not melee_struck and float(settings.melee.duration)-melee_time>=float(settings.melee.hit_time):_strike()
    if is_on_floor():
        velocity.y=-.5
        if not movement_locked and not dead and not is_busy() and Input.is_action_just_pressed("jump"):velocity.y=settings.jump_velocity
    else:velocity.y-=float(settings.gravity)*delta
    if roll_time>0:rotation.y=lerp_angle(rotation.y,atan2(-roll_direction.x,-roll_direction.z),1-exp(-delta*20))
    elif dead:pass
    elif weapons.selected_slot>0:rotation.y=lerp_angle(rotation.y,camera_rig.foot_yaw,1-exp(-delta*18))
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
