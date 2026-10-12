extends Node3D
@export var settings: ChaseCameraSettings
var target: CharacterBody3D
var orbit_yaw: float = 0.0
var pitch: float = -0.24
var dragging: bool = false
var zoom_distance: float = 7.0
@onready var arm: SpringArm3D = $SpringArm3D
@onready var camera: Camera3D = $SpringArm3D/Camera3D
func initialize(cart: CharacterBody3D) -> void:
    target=cart
    zoom_distance=clampf(settings.default_distance,settings.min_distance,settings.max_distance)
    camera.fov=settings.field_of_view
    arm.spring_length=zoom_distance
    arm.add_excluded_object(cart.get_rid())
    target.get_global_transform_interpolated()
    snap()
func heading(pose: Transform3D) -> float:
    var forward: Vector3=-pose.basis.z
    return atan2(-forward.x,-forward.z) if Vector2(forward.x,forward.z).length_squared()>.01 else rotation.y
func snap() -> void:
    if target:
        global_position=target.global_position+Vector3(0,settings.follow_height,0)
        rotation.y=heading(target.global_transform)+orbit_yaw
        arm.spring_length=zoom_distance
        arm.rotation.x=pitch
func zoom_by(steps: float) -> void:
    zoom_distance=clampf(zoom_distance-steps*settings.scroll_step,settings.min_distance,settings.max_distance)
func _process(delta: float) -> void:
    if target==null:return
    var pose: Transform3D=target.get_global_transform_interpolated()
    global_position=global_position.lerp(pose.origin+Vector3(0,settings.follow_height,0),1.0-exp(-delta*9))
    camera.fov=settings.field_of_view
    arm.spring_length=lerpf(arm.spring_length,zoom_distance,1.0-exp(-delta*10))
    if not dragging:orbit_yaw=lerp_angle(orbit_yaw,0,1.0-exp(-delta*1.2))
    rotation.y=lerp_angle(rotation.y,heading(pose)+orbit_yaw,1.0-exp(-delta*7))
    arm.rotation.x=pitch
func _unhandled_input(event: InputEvent) -> void:
    if get_tree().paused:return
    if event is InputEventMouseButton:
        if event.pressed and event.button_index in [MOUSE_BUTTON_WHEEL_UP,MOUSE_BUTTON_WHEEL_DOWN]:
            zoom_by(1 if event.button_index==MOUSE_BUTTON_WHEEL_UP else -1)
            get_viewport().set_input_as_handled()
        elif event.button_index==MOUSE_BUTTON_RIGHT:
            dragging=event.pressed
            Input.mouse_mode=Input.MOUSE_MODE_CAPTURED if dragging else Input.MOUSE_MODE_VISIBLE
    elif event is InputEventMouseMotion and dragging:
        orbit_yaw-=event.relative.x*0.004
        pitch=clampf(pitch-event.relative.y*0.003,-0.7,-0.08)
