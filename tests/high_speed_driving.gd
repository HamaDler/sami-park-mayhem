extends SceneTree
class Arena:
    extends Node3D
    var grass: bool = false
    var boundary := PackedVector2Array([Vector2(-800,-800),Vector2(800,-800),Vector2(800,800),Vector2(-800,800)])
    var layout: Dictionary = {"spawn":{"position":[0,0],"yaw":0}}
    func is_on_path(_position: Vector3) -> bool:return not grass
    func is_water(_point: Vector2) -> bool:return false

var world: Node3D
var arena: Arena
var cart: CharacterBody3D
var failures: int = 0
var checks: int = 0
func _initialize() -> void:call_deferred("run")
func frames(count: int) -> void:
    for i in count:await physics_frame
func check(condition: bool, message: String) -> void:
    checks+=1
    if not condition:failures+=1;push_error("FAIL: "+message)
    else:print("PASS: ",message)
func reset() -> void:
    for action in ["accelerate","reverse","left","right","brake"]:Input.action_release(action)
    arena.grass=false
    cart.recover()
    cart.initialize(arena)
    await frames(5)
func run() -> void:
    for action in ["accelerate","reverse","left","right","brake","recover"]:
        if not InputMap.has_action(action):InputMap.add_action(action)
    world=Node3D.new()
    root.add_child(world)
    current_scene=world
    # Test controller handling on a clear road, isolated from the park's trees and water.
    ParkGeometry.collider(world,Vector3(0,-0.45,0),Vector3(1800,0.9,1800))
    arena=Arena.new()
    world.add_child(arena)
    cart=load("res://scenes/cart.tscn").instantiate()
    world.add_child(cart)
    cart.initialize(arena)
    await frames(8)
    Input.action_press("accelerate")
    await frames(60)
    var first_second: float = cart.speed
    check(first_second>5.5,"Launch acceleration reaches over 20 km/h in one second")
    await frames(120)
    var third_second: float = cart.speed
    await frames(60)
    check(cart.speed-third_second<first_second,"Engine acceleration eases as speed increases")
    await frames(360)
    print("TOP_SPEED ",cart.speed*3.6," km/h")
    check(absf(cart.speed*3.6-200.0)<0.05,"Sustained throttle reaches exactly 200 km/h on road")
    check(cart.velocity.length()<cart.settings.max_speed+0.05,"Physical velocity obeys the 200 km/h cap")
    cart.speed=100.0/3.6
    Input.action_press("left")
    await frames(20)
    check(not cart.drifting and absf(cart.slip_angle)<0.15,"Normal high-speed steering retains grip")
    check(absf(cart.visual.rotation.z)<=0.071,"Body lean remains bounded at high speed")
    Input.action_press("brake")
    await frames(30)
    var heading := -cart.global_basis.z
    var actual := Vector3(cart.velocity.x,0,cart.velocity.z).normalized()
    print("DRIFT speed=",cart.speed*3.6," slip_degrees=",rad_to_deg(cart.slip_angle)," velocity_angle=",rad_to_deg(heading.angle_to(actual)))
    check(cart.drifting and absf(cart.slip_angle)>0.25,"Fast turn plus Space engages a sideways drift")
    check(heading.angle_to(actual)>0.25,"Actual travel direction differs from body heading during drift")
    check(cart.speed*3.6>60,"Handbrake drift preserves forward momentum")
    Input.action_release("brake")
    Input.action_release("left")
    await frames(90)
    check(not cart.drifting and absf(cart.slip_angle)<0.08,"Releasing handbrake restores traction and straight travel")
    cart.speed=100.0/3.6
    Input.action_press("left")
    await frames(10)
    Input.action_press("brake")
    await frames(1)
    Input.action_release("brake")
    await frames(20)
    check(cart.drifting and absf(cart.slip_angle)>0.2,"A quick Space tap initiates a drift while turning fast")
    Input.action_release("left")
    await frames(90)
    Input.action_press("brake")
    await frames(190)
    check(absf(cart.speed)<0.01,"Space without steering brakes to a complete stop")
    Input.action_release("brake")
    Input.action_release("accelerate")
    Input.action_press("reverse")
    await frames(90)
    check(cart.speed< -3 and cart.speed>=-cart.settings.reverse_speed-0.01,"Reverse remains controllable and capped")
    await reset()
    cart.speed=5
    Input.action_press("brake")
    Input.action_press("left")
    await frames(30)
    check(not cart.drifting and cart.speed<0.01,"Slow turn plus Space brakes without triggering drift")
    await reset()
    arena.grass=true
    cart.speed=cart.settings.max_speed
    Input.action_press("accelerate")
    await frames(120)
    check(cart.speed<=cart.settings.grass_speed+0.01,"Grass limits high-speed driving to 40 km/h")
    await reset()
    var wall := ParkGeometry.collider(world,Vector3(0,1,-12),Vector3(20,2,0.4))
    cart.speed=cart.settings.max_speed
    Input.action_press("accelerate")
    await frames(60)
    check(cart.is_on_wall() and cart.position.z> -11.1,"200 km/h collision stops before a thin wall without tunnelling")
    check(absf(cart.speed)<0.1,"High-speed impact cancels forward motion")
    wall.queue_free()
    cart.recover()
    check(not cart.drifting and cart.slip_angle==0 and cart.speed==0,"Recovery clears drift momentum")
    print("HIGH_SPEED_RESULT: ",checks," checks, ",failures," failures")
    quit(failures)
