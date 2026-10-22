extends Node3D
const Flashlight=preload("res://scripts/flashlight.gd")
const FirstPersonWeapon=preload("res://scripts/first_person_weapon.gd")
@export var settings: ChaseCameraSettings
var target: CharacterBody3D
var orbit_yaw: float=0
var pitch: float=-.24
var dragging: bool=false
var zoom_distance: float=7
var car_zoom: float=7
var foot_zoom: float=4.5
var foot_yaw: float=0
var foot_settings: Dictionary
var on_foot: bool=false
var aiming: bool=false
var sniper_scope: bool=false
var snap_through_physics_frame: int=-1
# Feel: trauma-based shake (strength = trauma²) plus a spring-damped recoil kick.
var trauma: float=0
var shake_time: float=0
var kick_offset:=Vector2.ZERO
var kick_velocity:=Vector2.ZERO
var fov_punch: float=0
var base_fov: float=70
var noise:=FastNoiseLite.new()
# First person. The rig sits at the eyes; the spring arm stays at zero length and its local
# position carries head bob and road rumble.
var first_person: bool=true
var eye_height: float=1.6
var look_yaw: float=0
var look_idle: float=0
var look_delta:=Vector2.ZERO
var frame_look:=Vector2.ZERO
var bob_time: float=0
var bob_amount: float=0
var land_dip: float=0
var land_velocity: float=0
var fall_speed: float=0
var death_blend: float=0
var rumble_time: float=0
var last_impact_frame: int=-1
var driver_eye:=Vector3(-.26,1.58,.11)
var flashlight: Node3D
var viewmodel: Node3D
@onready var arm: SpringArm3D=$SpringArm3D
@onready var camera: Camera3D=$SpringArm3D/Camera3D
func _ready() -> void:
    foot_settings=JSON.parse_string(FileAccess.get_file_as_string("res://data/player_settings.json"))
    foot_zoom=float(foot_settings.camera_default_distance)
    noise.seed=7;noise.frequency=.9
    base_fov=camera.fov
    first_person=settings.first_person
    eye_height=settings.eye_height
    flashlight=Flashlight.new();flashlight.name="Flashlight";add_child(flashlight);flashlight.initialize(camera)
    viewmodel=FirstPersonWeapon.new();viewmodel.name="FirstPersonWeapon";viewmodel.rig=self;camera.add_child(viewmodel)
    if not first_person:flashlight.set_stowed(true)
func add_trauma(amount: float) -> void:
    trauma=clampf(trauma+amount,0,1)
func kick(pitch_amount: float, yaw_amount: float=0) -> void:
    kick_velocity+=Vector2(pitch_amount,yaw_amount)*28
    fov_punch=minf(fov_punch+pitch_amount*40,4)
func initialize(cart: CharacterBody3D) -> void:
    car_zoom=clampf(settings.default_distance,settings.min_distance,settings.max_distance)
    follow_actor(cart,false)
func follow_actor(actor: CharacterBody3D, walking: bool) -> void:
    if target:arm.remove_excluded_object(target.get_rid())
    if on_foot:foot_zoom=zoom_distance
    else:car_zoom=zoom_distance if target else settings.default_distance
    if first_person and target and target!=actor:_set_driver_view(target,false)
    target=actor;on_foot=walking;dragging=false;aiming=false;sniper_scope=false;orbit_yaw=0
    zoom_distance=foot_zoom if walking else car_zoom
    foot_yaw=actor.rotation.y
    arm.collision_mask=3;arm.add_excluded_object(actor.get_rid())
    pitch=-.18 if walking else -.24
    if first_person:
        pitch=0.0 if walking else -.08
        look_yaw=0;look_idle=0;bob_amount=0;land_dip=0;land_velocity=0;fall_speed=0;death_blend=0
        arm.collision_mask=0;arm.spring_length=0;arm.position=Vector3.ZERO
        _set_driver_view(actor,not walking)
        flashlight.set_stowed(not walking)
    target.get_global_transform_interpolated();snap()
    Input.mouse_mode=Input.MOUSE_MODE_CAPTURED if walking or first_person else Input.MOUSE_MODE_VISIBLE
# In the driver's seat the camera replaces the seated character's head, so you see your own
# arms on the wheel. The head mesh stays as a shadow only.
func _set_driver_view(vehicle: CharacterBody3D, seated: bool) -> void:
    var driver: Node3D=vehicle.get_node_or_null("Visual/SeatedDriver")
    var visual: Node3D=vehicle.get_node_or_null("Visual")
    if driver==null or visual==null:return
    if driver.has_method("set_head_hidden"):driver.set_head_hidden(seated)
    if seated and driver.has_method("bone_world"):
        driver_eye=visual.to_local(driver.bone_world("Head").origin)+Vector3(0,.17,-.07)
func heading(pose: Transform3D) -> float:
    var forward: Vector3=-pose.basis.z
    return atan2(-forward.x,-forward.z) if Vector2(forward.x,forward.z).length_squared()>.01 else rotation.y
func snap() -> void:
    if target:
        # A teleport can occur between ticks while interpolation still holds the old pose.
        snap_through_physics_frame=Engine.get_physics_frames()+1
        if first_person:
            _place_first_person(target.global_transform)
            flashlight.snap()
            return
        global_position=target.global_position+Vector3(0,1.4 if on_foot else settings.follow_height,0)
        rotation.y=foot_yaw if on_foot else heading(target.global_transform)+orbit_yaw
        arm.spring_length=zoom_distance;arm.rotation.x=pitch;arm.position.x=.38 if on_foot else 0.0
func zoom_by(steps: float) -> void:
    if first_person:return
    zoom_distance=clampf(zoom_distance-steps*settings.scroll_step,float(foot_settings.camera_min_distance) if on_foot else settings.min_distance,float(foot_settings.camera_max_distance) if on_foot else settings.max_distance)
func wants_mouse_captured() -> bool:
    return first_person or on_foot
func _desired_fov() -> float:
    var desired: float=22.0 if sniper_scope else (48.0 if on_foot and aiming else settings.field_of_view)
    if on_foot and not aiming and target.get("sprinting"):desired+=float(foot_settings.get("sprint_fov_bonus",0))
    return desired
func _process(delta: float) -> void:
    if target==null:return
    var pose: Transform3D=target.get_global_transform_interpolated()
    if Engine.get_physics_frames()<=snap_through_physics_frame:pose=target.global_transform
    base_fov=lerpf(base_fov,_desired_fov(),1-exp(-delta*(14 if aiming else 7)))
    camera.fov=base_fov+fov_punch
    _update_feel(delta)
    if first_person:
        frame_look=look_delta;look_delta=Vector2.ZERO
        if on_foot:_update_head_motion(delta)
        else:_update_driver_look(delta)
        _place_first_person(pose)
        return
    global_position=global_position.lerp(pose.origin+Vector3(0,(1.55 if sniper_scope else 1.4) if on_foot else settings.follow_height,0),1-exp(-delta*9))
    arm.spring_length=lerpf(arm.spring_length,.12 if sniper_scope else zoom_distance,1-exp(-delta*18 if sniper_scope else -delta*10))
    camera.near=.08 if sniper_scope else .35
    arm.position.x=lerpf(arm.position.x,.38 if on_foot and not sniper_scope else 0.0,1-exp(-delta*12))
    if on_foot:rotation.y=foot_yaw
    else:
        if not dragging:orbit_yaw=lerp_angle(orbit_yaw,0,1-exp(-delta*1.2))
        rotation.y=lerp_angle(rotation.y,heading(pose)+orbit_yaw,1-exp(-delta*7))
    arm.rotation.x=pitch
func _place_first_person(pose: Transform3D) -> void:
    camera.near=.05
    arm.spring_length=0
    if on_foot:
        global_transform=Transform3D(Basis(Vector3.UP,foot_yaw),pose.origin+Vector3.UP*_eye_height_now())
        var stride: float=bob_amount*(.25 if aiming else 1.0)
        arm.position=Vector3(cos(bob_time)*.022*stride,sin(bob_time*2)*.03*stride,0)
        arm.rotation=Vector3(pitch-_roll_curve()*.3,0,death_blend*1.15)
    else:
        var visual: Node3D=target.get_node_or_null("Visual")
        var seat: Transform3D=pose*(visual.transform if visual else Transform3D.IDENTITY)
        var view_basis: Basis=seat.basis.orthonormalized()*Basis(Vector3.UP,look_yaw)
        global_transform=Transform3D(view_basis,seat*driver_eye)
        arm.rotation=Vector3(pitch,0,0)
# 0 -> 1 -> 0 over a dodge roll.
func _roll_curve() -> float:
    var remaining=target.get("roll_time") if target else null
    if remaining==null or float(remaining)<=0:return 0.0
    return sin((1.0-float(remaining)/float(target.settings.roll.duration))*PI)
func _eye_height_now() -> float:
    var height: float=eye_height+land_dip-_roll_curve()*.75
    return lerpf(height,.35,death_blend)
func _update_head_motion(delta: float) -> void:
    var person: CharacterBody3D=target
    var speed: float=Vector2(person.velocity.x,person.velocity.z).length()
    var grounded: bool=person.is_on_floor()
    var walking: bool=grounded and speed>.6 and not person.is_busy()
    bob_amount=lerpf(bob_amount,clampf(speed/4.5,0,1.7) if walking else 0.0,1-exp(-delta*8))
    if walking:bob_time+=delta*(5.2+speed*.85)
    # Landing: dip the view in proportion to fall speed, then spring back.
    if not grounded:fall_speed=maxf(fall_speed,-person.velocity.y)
    elif fall_speed>0:
        if fall_speed>3:land_velocity-=clampf(fall_speed*.25,0,2.5)
        fall_speed=0
    land_velocity+=(-land_dip*120-land_velocity*14)*delta
    land_dip+=land_velocity*delta
    death_blend=move_toward(death_blend,1.0 if person.get("dead") else 0.0,delta/1.1)
func _update_driver_look(delta: float) -> void:
    var speed: float=absf(float(target.get("speed")))
    look_idle+=delta
    # Free look snaps back to the road once you stop moving the mouse while driving.
    if look_idle>.8 and speed>2:
        var rate: float=1-exp(-delta*2.5)
        look_yaw=lerp_angle(look_yaw,0,rate);pitch=lerpf(pitch,-.08,rate)
    # Road rumble, stronger on grass, and a jolt on hard impacts.
    var rough: float=.0022 if target.get("on_path") else .008
    var amount: float=clampf(speed/25.0,0,1)*rough
    rumble_time+=delta*(18+speed*1.5)
    arm.position=Vector3(noise.get_noise_2d(rumble_time,40)*amount,noise.get_noise_2d(40,rumble_time)*amount*1.6,0)
    var impact: float=float(target.get("impact_speed"))
    if impact>3 and Engine.get_physics_frames()!=last_impact_frame:
        last_impact_frame=Engine.get_physics_frames();add_trauma(clampf(impact/14.0,.15,.7))
func _update_feel(delta: float) -> void:
    # Spring back to zero: stiff enough to recover between pistol shots, damped to avoid wobble.
    kick_velocity+=(-kick_offset*260-kick_velocity*26)*delta
    kick_offset+=kick_velocity*delta
    fov_punch=move_toward(fov_punch,0,delta*30)
    trauma=maxf(0,trauma-delta*1.6);shake_time+=delta*60
    var shake: float=trauma*trauma*(.35 if sniper_scope else 1.0)
    camera.rotation=Vector3(kick_offset.x+noise.get_noise_2d(shake_time,0)*.05*shake,kick_offset.y+noise.get_noise_2d(0,shake_time)*.05*shake,noise.get_noise_2d(shake_time,shake_time)*.04*shake)
func mouse_look_sensitivity() -> float:
    var base: float=foot_settings.get("mouse_sensitivity",.0035)
    if on_foot and is_instance_valid(target) and Input.is_action_pressed("aim"):
        var weapons: Node3D=target.get_node_or_null("WeaponSystem")
        if weapons!=null and weapons.enabled:
            return base*clampf(float(weapons.current().get("aim_sensitivity_multiplier",1.0)),.01,1.0)
    return base
func _unhandled_input(event: InputEvent) -> void:
    if get_tree().paused:return
    if first_person:
        if event is InputEventMouseMotion and Input.mouse_mode==Input.MOUSE_MODE_CAPTURED:
            var sensitivity:=mouse_look_sensitivity()
            look_delta+=event.relative*sensitivity
            if on_foot:
                foot_yaw-=event.relative.x*sensitivity;pitch=clampf(pitch-event.relative.y*sensitivity,-1.45,1.45)
            else:
                var limit: float=settings.driver_look_yaw_limit
                look_yaw=clampf(look_yaw-event.relative.x*sensitivity,-limit,limit)
                pitch=clampf(pitch-event.relative.y*sensitivity,-1.0,.75);look_idle=0
        return
    if event is InputEventMouseButton:
        if event.pressed and event.button_index in [MOUSE_BUTTON_WHEEL_UP,MOUSE_BUTTON_WHEEL_DOWN]:
            zoom_by(1 if event.button_index==MOUSE_BUTTON_WHEEL_UP else -1);get_viewport().set_input_as_handled()
        elif not on_foot and event.button_index==MOUSE_BUTTON_RIGHT:
            dragging=event.pressed;Input.mouse_mode=Input.MOUSE_MODE_CAPTURED if dragging else Input.MOUSE_MODE_VISIBLE
    elif event is InputEventMouseMotion:
        if on_foot and Input.mouse_mode==Input.MOUSE_MODE_CAPTURED:
            var sensitivity:=mouse_look_sensitivity()
            foot_yaw-=event.relative.x*sensitivity;pitch=clampf(pitch-event.relative.y*sensitivity,-.8,.65)
        elif dragging:
            orbit_yaw-=event.relative.x*.004;pitch=clampf(pitch-event.relative.y*.003,-.7,-.08)
