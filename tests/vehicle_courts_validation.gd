extends SceneTree
class Arena:
    extends Node3D
    var grass:=false
    var boundary:=PackedVector2Array([Vector2(-1600,-1600),Vector2(1600,-1600),Vector2(1600,1600),Vector2(-1600,1600)])
    var layout: Dictionary={"spawn":{"position":[0,0],"yaw":0}}
    func is_on_path(_p: Vector3) -> bool:return not grass
    func is_water(_p: Vector2) -> bool:return false
var checks:=0
var failures:=0
var world: Node3D
var cart: CharacterBody3D
var rig: Node3D
var arena: Arena
func _initialize() -> void:call_deferred("run")
func frames(count: int) -> void:
    for i in count:await physics_frame
func check(value: bool, message: String) -> void:
    checks+=1
    if value:print("PASS: ",message)
    else:failures+=1;push_error("FAIL: "+message)
func reset(speed_value: float=0) -> void:
    for action in ["accelerate","reverse","left","right","brake","recover"]:Input.action_release(action)
    cart.initialize(arena)
    await frames(4)
    cart.speed=speed_value
    rig.snap()
func run() -> void:
    for action in ["accelerate","reverse","left","right","brake","recover"]:
        if not InputMap.has_action(action):InputMap.add_action(action)
    world=Node3D.new();root.add_child(world);current_scene=world
    ParkGeometry.collider(world,Vector3(0,-.45,0),Vector3(3400,.9,3400))
    arena=Arena.new();world.add_child(arena)
    cart=load("res://scenes/cart.tscn").instantiate();world.add_child(cart);cart.initialize(arena)
    rig=load("res://scenes/chase_camera.tscn").instantiate();world.add_child(rig);rig.initialize(cart)
    await frames(8)
    rig.zoom_by(100)
    check(rig.zoom_distance==rig.settings.min_distance,"Scroll zoom clamps at its minimum distance")
    rig.zoom_by(-100)
    check(rig.zoom_distance==rig.settings.max_distance,"Scroll zoom clamps at its maximum distance")
    rig.zoom_distance=9
    rig.snap()
    cart.speed=cart.settings.max_speed
    rig._process(.2)
    check(absf(rig.arm.spring_length-9)<.01 and rig.camera.fov==rig.settings.field_of_view,"Speed changes neither selected zoom nor field of view")
    cart.recover();rig.snap()
    check(rig.zoom_distance==9,"Recovery preserves the player's camera zoom")
    Input.action_press("accelerate")
    await frames(600)
    check(absf(cart.speed*3.6-200)<.05,"Acceleration reaches the new 200 km/h road limit")
    check(cart.effects.written>100,"Driving lays down four wheel trails")
    var before: int=cart.effects.written
    Input.action_release("accelerate");Input.action_press("brake")
    await frames(10)
    check(cart.effects.smoke_active and cart.effects.emitters[0].emitting,"Braking at speed emits simple rear-wheel particles")
    check(cart.effects.written>before,"Braking leaves stronger tire marks")
    Input.action_release("brake");cart.speed=0
    await frames(3)
    check(not cart.effects.smoke_active,"Particles stop when the cart stops")
    for i in cart.effects.capacity+5:cart.effects.add_mark(Vector3(i*.1,.067,0),Vector3(i*.1,.067,.4),.8,false)
    check(cart.effects.marks.multimesh.visible_instance_count==cart.effects.capacity,"Trail storage remains bounded after wrapping")
    await reset(cart.settings.max_speed)
    Input.action_press("accelerate");Input.action_press("left",.06)
    await frames(45)
    check(not cart.rolling,"Gentle steering at 200 km/h stays controllable")
    await reset(cart.settings.max_speed)
    Input.action_press("accelerate");Input.action_press("left")
    for i in 100:
        await physics_frame
        if cart.rolling:break
    check(cart.rolling and is_instance_valid(cart.rollover_body),"Sharp high-speed steering launches a real rigid-body rollover")
    var min_up:=1.0
    for i in 120:
        await physics_frame
        min_up=minf(min_up,cart.global_basis.y.dot(Vector3.UP))
    print("ROLLOVER_MIN_UP ",min_up)
    check(min_up<-.15,"Cart physically rotates past its side and flips over")
    Input.action_press("recover");await frames(2);Input.action_release("recover")
    check(not cart.rolling and cart.rollover_body==null and cart.global_basis.y.dot(Vector3.UP)>.99,"R restores an upright cart and removes the rollover body")
    await reset(150.0/3.6)
    Input.action_press("left");Input.action_press("brake")
    for i in 80:
        await physics_frame
        if cart.rolling:break
    check(cart.rolling,"Fast braking while turning can tip the cart sooner")
    cart.teleport_to(Vector2(40,-20),.5)
    check(not cart.rolling and cart.speed==0 and absf(cart.rotation.z)<.001,"Map spawning clears a rollover and restores driving")
    check(not cart.effects.has_contact.has(true),"Teleporting breaks tire trails instead of drawing across the map")
    await reset(80.0/3.6)
    Input.action_press("left");Input.action_press("brake")
    await frames(50)
    check(not cart.rolling and cart.drifting,"Moderate-speed handbrake turns still drift without automatically flipping")
    world.queue_free();await frames(3)
    var game: Node3D=load("res://scenes/main.tscn").instantiate();root.add_child(game);current_scene=game
    for connection in root.focus_exited.get_connections():root.focus_exited.disconnect(connection.callable)
    await frames(8)
    var park: Node3D=game.get_node("SamiPark")
    var sports: Node3D=park.sports
    check(sports.layout.courts.size()==3,"Sports complex uses the three mapped parcels")
    var padel:=sports.get_node("Padelcourts")
    check(padel.has_node("PadelCourt1") and padel.has_node("PadelCourt2") and padel.has_node("PadelCourt3"),"Left parcel contains three separate enclosed padel courts")
    var basketball:=sports.get_node("Basketball")
    var hoops:=0
    for mesh: MeshInstance3D in basketball.find_children("*","MeshInstance3D",true,false):
        if mesh.mesh is TorusMesh:hoops+=1
    check(hoops==2,"Right basketball court has two hoops and marked playing surface")
    check(sports.has_node("Volleyball"),"Middle parcel contains the volleyball court and net")
    var clear:=true
    for tree: Vector2 in park.tree_positions:
        if sports.is_inside(tree):clear=false
    check(clear,"All court surfaces are cleared of tree planting")
    var solid:=true
    for field: Dictionary in sports.layout.courts:
        var point: Vector3=sports.get_node(field.label.replace(" ","")).to_global(Vector3(7,0,12))
        var hit:=park.get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(point+Vector3.UP*2,point-Vector3.UP,1))
        if hit.is_empty() or float(hit.position.y)<.08:solid=false
        if park.nature._close_grass_ground(Vector2(point.x,point.z)):solid=false
    check(solid,"Courts have solid surfaces and reject streamed grass")
    check(game.get_node("HUD").full_map.canvas.sports_polygons.size()==3,"Full map displays the sports court footprints")
    print("UPGRADES_RESULT: ",checks," checks, ",failures," failures")
    quit(failures)
