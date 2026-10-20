extends Node3D
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
@onready var arm: SpringArm3D=$SpringArm3D
@onready var camera: Camera3D=$SpringArm3D/Camera3D
func _ready() -> void:
    foot_settings=JSON.parse_string(FileAccess.get_file_as_string("res://data/player_settings.json"))
    foot_zoom=float(foot_settings.camera_default_distance)
    noise.seed=7;noise.frequency=.9
    base_fov=camera.fov
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
    target=actor;on_foot=walking;dragging=false;aiming=false;sniper_scope=false;orbit_yaw=0
    zoom_distance=foot_zoom if walking else car_zoom
    foot_yaw=actor.rotation.y
    arm.collision_mask=3;arm.add_excluded_object(actor.get_rid())
    pitch=-.18 if walking else -.24
    target.get_global_transform_interpolated();snap()
    Input.mouse_mode=Input.MOUSE_MODE_CAPTURED if walking else Input.MOUSE_MODE_VISIBLE
func heading(pose: Transform3D) -> float:
    var forward: Vector3=-pose.basis.z
    return atan2(-forward.x,-forward.z) if Vector2(forward.x,forward.z).length_squared()>.01 else rotation.y
func snap() -> void:
    if target:
        # A teleport can occur between ticks while interpolation still holds the old pose.
        snap_through_physics_frame=Engine.get_physics_frames()+1
        global_position=target.global_position+Vector3(0,1.4 if on_foot else settings.follow_height,0)
        rotation.y=foot_yaw if on_foot else heading(target.global_transform)+orbit_yaw
        arm.spring_length=zoom_distance;arm.rotation.x=pitch;arm.position.x=.38 if on_foot else 0.0
func zoom_by(steps: float) -> void:
    zoom_distance=clampf(zoom_distance-steps*settings.scroll_step,float(foot_settings.camera_min_distance) if on_foot else settings.min_distance,float(foot_settings.camera_max_distance) if on_foot else settings.max_distance)
func _process(delta: float) -> void:
    if target==null:return
    var pose: Transform3D=target.get_global_transform_interpolated()
    if Engine.get_physics_frames()<=snap_through_physics_frame:pose=target.global_transform
    global_position=global_position.lerp(pose.origin+Vector3(0,(1.55 if sniper_scope else 1.4) if on_foot else settings.follow_height,0),1-exp(-delta*9))
    var desired_fov: float=22.0 if sniper_scope else (48.0 if on_foot and aiming else settings.field_of_view)
    if on_foot and not aiming and target.get("sprinting"):desired_fov+=float(foot_settings.get("sprint_fov_bonus",0))
    base_fov=lerpf(base_fov,desired_fov,1-exp(-delta*(14 if aiming else 7)))
    camera.fov=base_fov+fov_punch
    _update_feel(delta)
    arm.spring_length=lerpf(arm.spring_length,.12 if sniper_scope else zoom_distance,1-exp(-delta*18 if sniper_scope else -delta*10))
    camera.near=.08 if sniper_scope else .35
    arm.position.x=lerpf(arm.position.x,.38 if on_foot and not sniper_scope else 0.0,1-exp(-delta*12))
    if on_foot:rotation.y=foot_yaw
    else:
        if not dragging:orbit_yaw=lerp_angle(orbit_yaw,0,1-exp(-delta*1.2))
        rotation.y=lerp_angle(rotation.y,heading(pose)+orbit_yaw,1-exp(-delta*7))
    arm.rotation.x=pitch
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
