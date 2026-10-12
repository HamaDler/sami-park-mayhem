extends CharacterBody3D
signal recovered(reason: String)
signal rollover_started
var control_enabled: bool=false
var rolling: bool = false
var rollover_risk: float = 0
var lateral_acceleration: float = 0
var rollover_body: RigidBody3D
var upright_time: float = 0
@onready var effects: Node3D = $TireEffects
@export var settings: DrivingSettings
var park: Node3D
var speed: float = 0.0
var steer: float = 0.0
var on_path: bool = true
var distance_m: float = 0.0
var safe_transform: Transform3D
var safe_timer: float = 0.0
var wheel_angle: float = 0.0
var front_pivots: Array[Node3D] = []
var wheels: Array[Node3D] = []
var steering_wheel: Node3D
var last_reason: String = ""
var last_recovery_position: Vector3 = Vector3.ZERO
var throttle_amount: float = 0.0
var travel_yaw: float = 0.0
var drift_blend: float = 0.0
var slip_angle: float = 0.0
var drifting: bool = false
var handbrake_down: bool = false
var drift_kick_timer: float = 0.0
@onready var visual: Node3D = $Visual

func _ready() -> void:
    _build_cart()
    effects.initialize(self)
    set_control_enabled(false)

func initialize(world: Node3D) -> void:
    park = world
    var spawn: Dictionary = park.layout.spawn
    position = Vector3(spawn.position[0],0.15,spawn.position[1])
    _stop_rollover()
    rotation=Vector3(0,spawn.yaw,0)
    speed=0
    velocity=Vector3.ZERO
    _reset_handling()
    safe_transform = global_transform
    reset_physics_interpolation()

func _physics_process(delta: float) -> void:
    if park == null:return
    if control_enabled and Input.is_action_just_pressed("recover"):recover("Back on the path")
    if rolling:
        _update_rollover(delta)
        return
    if not control_enabled:
        speed=0;velocity.x=0;velocity.z=0
        velocity.y=-.5 if is_on_floor() else velocity.y-20*delta
        move_and_slide();effects.update_effects(delta,false)
        return
    on_path = park.is_on_path(global_position)
    var throttle := Input.get_axis("reverse","accelerate")
    var steering_input := Input.get_axis("right","left")
    var handbrake := Input.is_action_pressed("brake")
    _drive(delta,throttle,steering_input,handbrake)
    _check_rollover(delta,handbrake)
    if rolling:return
    if not is_on_floor():velocity.y-=20.0*delta
    else:velocity.y=-0.5
    var before := global_position
    move_and_slide()
    distance_m+=Vector2(global_position.x-before.x,global_position.z-before.z).length()
    if is_on_wall():
        var planar := Vector3(velocity.x,0,velocity.z)
        speed = planar.length()*signf(speed)
        if planar.length()>0.1:
            var direction := planar*signf(speed)
            travel_yaw=atan2(-direction.x,-direction.z)
        else:
            speed=0
            drift_blend=0
            drifting=false
    wheel_angle+=speed*delta/0.246
    for wheel in wheels:wheel.rotation.x=wheel_angle
    for pivot in front_pivots:pivot.rotation.y=steer
    steering_wheel.rotation.z=-steer*1.8
    var lean := clampf(-steer*speed*0.008,-0.07,0.07)
    visual.rotation.z=lerpf(visual.rotation.z,lean,1.0-exp(-delta*5))
    effects.update_effects(delta,handbrake or (throttle<0 and speed>1))
    safe_timer+=delta
    var p := Vector2(global_position.x,global_position.z)
    if park.is_water(p):
        recover("Water ahead — returned to the path")
    elif global_position.y < -4 or not Geometry2D.is_point_in_polygon(p,park.boundary):
        recover("Returned inside the park")
    elif on_path and is_on_floor() and not is_on_wall() and safe_timer>2.0:
        safe_transform=global_transform
        safe_timer=0

func _reset_handling() -> void:
    rollover_risk=0
    lateral_acceleration=0
    if is_instance_valid(effects):effects.reset_contacts()
    throttle_amount=0
    travel_yaw=rotation.y
    drift_blend=0
    slip_angle=0
    drifting=false
    handbrake_down=false
    drift_kick_timer=0

func _drive(delta: float, throttle: float, steering_input: float, handbrake: bool) -> void:
    var surface_grip := 1.0 if on_path else 0.7
    throttle_amount=move_toward(throttle_amount,throttle,settings.throttle_response*delta)
    var speed_ratio := clampf(absf(speed)/settings.max_speed,0,1)
    var steering_ceiling := maxf(settings.max_speed,settings.steering_reduction_start+1.0)
    var high_speed := smoothstep(settings.steering_reduction_start,steering_ceiling,absf(speed))
    var steering_limit := settings.steering_angle*lerpf(1.0,settings.high_speed_steering_ratio,high_speed)
    steer=move_toward(steer,steering_input*steering_limit,delta*2.5*surface_grip)
    var drift_possible := speed>settings.drift_min_speed and absf(steering_input)>0.15 and is_on_floor()
    if handbrake and not handbrake_down and drift_possible:
        drift_kick_timer=settings.drift_kick_duration
        drift_blend=maxf(drift_blend,0.55)
    handbrake_down=handbrake
    drift_kick_timer=maxf(0,drift_kick_timer-delta)
    var break_traction := (handbrake or drift_kick_timer>0) and drift_possible
    drift_blend=move_toward(drift_blend,1.0 if break_traction else 0.0,delta*(settings.drift_engage_rate if break_traction else settings.drift_release_rate))
    if handbrake:
        var braking := lerpf(settings.brake_deceleration,settings.drift_brake_deceleration,drift_blend)
        speed=move_toward(speed,0,braking*delta)
    elif throttle!=0:
        var limit := settings.max_speed if throttle>0 else -settings.reverse_speed
        if not on_path:limit=clampf(limit,-settings.grass_speed,settings.grass_speed)
        # Strong launch torque eases towards top speed, rather than a fixed ramp.
        var engine_force := lerpf(settings.acceleration,settings.top_speed_acceleration,speed_ratio*speed_ratio)
        var force := settings.brake_deceleration if speed*throttle<0 else engine_force*absf(throttle_amount)*surface_grip
        speed=move_toward(speed,limit,force*delta)
    else:
        speed=move_toward(speed,0,(settings.coast_deceleration+settings.aerodynamic_drag*speed*speed)*delta)
    if not on_path:
        speed=move_toward(speed,clampf(speed,-settings.grass_speed,settings.grass_speed),settings.grass_deceleration*delta)
    speed=clampf(speed,-settings.reverse_speed,settings.max_speed)
    if absf(speed)>0.05:
        var yaw_rate := speed/settings.wheelbase*tan(steer)*(1.0+drift_blend*settings.drift_yaw_boost)
        var yaw_limit := lerpf(settings.max_yaw_rate,settings.drift_max_yaw_rate,drift_blend)
        var applied_yaw:=clampf(yaw_rate,-yaw_limit,yaw_limit)
        lateral_acceleration=absf(speed*applied_yaw)
        rotation.y+=applied_yaw*delta
        # Momentum follows heading slowly with the handbrake, creating real sideways travel.
        var traction := lerpf(settings.road_traction if on_path else settings.grass_traction,settings.drift_traction,drift_blend)
        travel_yaw=lerp_angle(travel_yaw,rotation.y,1.0-exp(-traction*delta))
        var slip := wrapf(rotation.y-travel_yaw,-PI,PI)
        travel_yaw=rotation.y-clampf(slip,-settings.max_drift_angle,settings.max_drift_angle)
    else:
        lateral_acceleration=0
        travel_yaw=rotation.y
        drift_blend=0
    slip_angle=wrapf(rotation.y-travel_yaw,-PI,PI)
    drifting=drift_blend>0.25 and absf(slip_angle)>0.12
    var direction := Vector3(-sin(travel_yaw),0,-cos(travel_yaw))
    velocity.x=direction.x*speed
    velocity.z=direction.z*speed

func recover(reason: String = "Back on the path") -> void:
    last_recovery_position=global_position
    _stop_rollover()
    global_transform = safe_transform
    global_position.y = 0.15
    velocity = Vector3.ZERO
    speed = 0
    steer = 0
    _reset_handling()
    safe_timer = 0
    visual.rotation.z=0
    reset_physics_interpolation()
    last_reason = reason
    recovered.emit(reason)

func teleport_to(point: Vector2, yaw: float) -> void:
    _stop_rollover()
    global_position=Vector3(point.x,0.15,point.y)
    rotation=Vector3(0,yaw,0)
    velocity=Vector3.ZERO
    speed=0
    steer=0
    safe_timer=0
    visual.rotation.z=0
    _reset_handling()
    safe_transform=global_transform
    on_path=park.is_on_path(global_position)
    reset_physics_interpolation()
    last_reason="Moved to your map destination"
    recovered.emit(last_reason)

func _build_cart() -> void:
    # Imported model is also instanced in the editable cart scene.
    var model: Node3D = $Visual/Club90
    for suffix in ["FL", "FR", "RL", "RR"]:
        var imported: Node3D = model.find_child("EVMCClub90_WheelStock_"+suffix,true,false)
        assert(imported != null, "Club90 wheel missing: "+suffix)
        # Identity pivots preserve the authored mirrored/scaled mesh transforms.
        var pivot := Node3D.new()
        pivot.name="Steer"+suffix
        pivot.position=visual.to_local(imported.global_position)
        visual.add_child(pivot)
        if suffix.begins_with("F"):front_pivots.append(pivot)
        var roll := Node3D.new()
        roll.name="Roll"+suffix
        pivot.add_child(roll)
        imported.reparent(roll,true)
        wheels.append(roll)
    var imported_steering: Node3D = model.find_child("EVMCClub90_Steering_Pivot",true,false)
    assert(imported_steering != null, "Club90 steering mesh missing")
    steering_wheel=Node3D.new()
    steering_wheel.name="SteeringAnimation"
    steering_wheel.position=visual.to_local(imported_steering.global_position)
    steering_wheel.rotation.x=-0.6
    visual.add_child(steering_wheel)
    imported_steering.reparent(steering_wheel,true)
    _build_driver()

func _build_driver() -> void:
    var driver: Node3D=load("res://scenes/character_avatar.tscn").instantiate()
    driver.name="SeatedDriver"
    visual.add_child(driver)
    driver.set_seated(self)

func _check_rollover(delta: float, handbrake: bool) -> void:
    var minimum:=settings.rollover_brake_min_speed if handbrake else settings.rollover_min_speed
    var load_value:=lateral_acceleration*(settings.rollover_brake_multiplier if handbrake else 1.0)
    var excess:=load_value/settings.rollover_lateral_acceleration-1.0
    if is_on_floor() and speed>minimum and excess>0:
        rollover_risk+=excess*settings.rollover_risk_gain*delta
    else:rollover_risk=move_toward(rollover_risk,0,settings.rollover_risk_release*delta)
    if rollover_risk>=1:_start_rollover()
func _start_rollover() -> void:
    if rolling:return
    rolling=true
    upright_time=0
    visual.rotation.z=0
    rollover_body=load("res://scenes/rollover_body.tscn").instantiate()
    get_parent().add_child(rollover_body)
    rollover_body.global_transform=global_transform
    var side:=signf(steer)
    if side==0:side=1
    rollover_body.linear_velocity=velocity+Vector3.UP*settings.rollover_launch_speed+global_basis.x*side*1.5
    rollover_body.angular_velocity=-global_basis.z*side*settings.rollover_spin_speed+Vector3.UP*side*.5
    collision_layer=0
    collision_mask=0
    effects.reset_contacts()
    rollover_body.reset_physics_interpolation()
    rollover_started.emit()
func _update_rollover(delta: float) -> void:
    if not is_instance_valid(rollover_body):recover();return
    global_transform=rollover_body.global_transform
    velocity=rollover_body.linear_velocity
    speed=Vector2(velocity.x,velocity.z).length()
    drifting=false
    effects.update_effects(delta,false)
    var point:=Vector2(global_position.x,global_position.z)
    if park.is_water(point):recover("Water ahead - returned to the path");return
    if global_position.y< -4 or not Geometry2D.is_point_in_polygon(point,park.boundary):recover("Returned inside the park");return
    if global_basis.y.dot(Vector3.UP)>.9 and rollover_body.angular_velocity.length()<.4 and speed<1 and global_position.y<.5:
        upright_time+=delta
        if upright_time>1:
            var forward: Vector3=-global_basis.z
            var yaw:=atan2(-forward.x,-forward.z)
            _stop_rollover()
            rotation=Vector3(0,yaw,0)
            _reset_handling()
            reset_physics_interpolation()
            last_reason="Back on your wheels"
            recovered.emit(last_reason)
    else:upright_time=0
func _stop_rollover() -> void:
    if is_instance_valid(rollover_body):
        rollover_body.collision_layer=0
        rollover_body.collision_mask=0
        rollover_body.queue_free()
    rollover_body=null
    rolling=false
    collision_layer=2
    collision_mask=5
    upright_time=0

func set_control_enabled(value: bool) -> void:
    control_enabled=value
    if not value:
        speed=0;velocity=Vector3.ZERO;steer=0;visual.rotation.z=0;_reset_handling()
    var driver: Node3D=visual.get_node("SeatedDriver")
    driver.visible=value;driver.set_process(value)
