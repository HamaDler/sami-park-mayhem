extends SceneTree
var failures: Array[String] = []
var checks: int = 0
var game: Node3D
var cart: CharacterBody3D
var park: Node3D
func _initialize() -> void:
    call_deferred("run")
func check(condition: bool, message: String) -> void:
    checks+=1
    if not condition:
        failures.append(message)
        push_error("FAIL: "+message)
    else: print("PASS: ",message)
func frames(count: int) -> void:
    for i in count:await physics_frame
func reset() -> void:
    for action in ["accelerate","reverse","left","right","brake"]:Input.action_release(action)
    cart.initialize(park)
    cart.velocity=Vector3.ZERO
    cart.speed=0
    cart.steer=0
    await frames(5)
func run() -> void:
    game=load("res://scenes/main.tscn").instantiate()
    root.add_child(game)
    current_scene=game
    for connection in root.focus_exited.get_connections():root.focus_exited.disconnect(connection.callable)
    cart=game.get_node("GolfCart")
    park=game.get_node("SamiPark")
    await frames(10)
    var imported: Node3D = cart.get_node("Visual/Club90")
    check(imported.scene_file_path.ends_with("assets/vehicles/club90/scene.gltf"),"Playable cart instances the supplied Club90 glTF")
    check(cart.wheels.size()==4 and cart.front_pivots.size()==2,"Four original wheels are bound to rolling and front steering pivots")
    var authored_wheels:=true
    for wheel in cart.wheels:
        authored_wheels=authored_wheels and wheel.get_child_count()==1 and str(wheel.get_child(0).name).begins_with("EVMCClub90_WheelStock_")
    check(authored_wheels,"Animated pivots contain the imported vehicle wheels")
    check(cart.steering_wheel.get_child(0).name=="EVMCClub90_Steering_Pivot","Steering animation uses the imported steering assembly")
    check(cart.is_on_floor(),"Cart rests on ground with wheels above floor")
    check(cart.position.y>=-0.01,"Collision shape rests at cart ground origin")
    check(park.is_on_path(cart.position),"Spawn is on a mapped western path")
    var start:=cart.position
    Input.action_press("accelerate")
    await frames(180)
    check(cart.speed>5.0,"Accelerates while following the spawn path")
    check(cart.position.distance_to(start)>7.0,"Forward input moves the cart")
    check(cart.speed<=cart.settings.max_speed+0.01,"Speed remains at or below 200 km/h")
    Input.action_release("accelerate")
    Input.action_press("brake")
    await frames(80)
    check(absf(cart.speed)<0.01,"Space brake brings cart to rest")
    Input.action_release("brake")
    Input.action_press("reverse")
    await frames(75)
    check(cart.speed < -1.5,"S engages reverse after braking")
    await reset()
    var yaw:=cart.rotation.y
    Input.action_press("accelerate")
    Input.action_press("left")
    await frames(45)
    check(cart.rotation.y>yaw+0.1,"Left steering changes heading left")
    check(absf(cart.front_pivots[0].rotation.y)>0.1,"Front wheels animate steering")
    check(absf(cart.wheels[0].rotation.x)>0.1,"Wheels animate rolling")
    await reset()
    # A known empty grass sample is selected from the actual map.
    var grass_found:=false
    for x in range(-500,600,15):
        for z in range(-600,600,15):
            if park.safe_ground(Vector2(x,z),10):
                cart.position=Vector3(x,0.1,z)
                grass_found=true
                break
        if grass_found:break
    await frames(5)
    check(grass_found and not cart.on_path,"Grass is detected off the path")
    cart.speed=cart.settings.max_speed
    await frames(120)
    check(absf(cart.speed)<=cart.settings.grass_speed+0.1,"Grass slows the cart")
    await reset()
    # A temporary wall validates the real controller's collision response.
    var obstacle:=ParkGeometry.collider(game,cart.position-cart.basis.z*5+Vector3(0,1,0),Vector3(5,2,1))
    var obstacle_pos:=obstacle.position
    Input.action_press("accelerate")
    await frames(160)
    check(cart.is_on_wall(),"Cart detects and stops at an obstacle")
    check(cart.speed<0.3,"Collision prevents continuing through the obstacle")
    check(cart.position.distance_to(obstacle_pos)>1.0,"Cart stays outside obstacle")
    obstacle.queue_free()
    await reset()
    var safe: Vector3 = cart.safe_transform.origin
    cart.position=Vector3(1400,0,1400)
    await frames(3)
    check(cart.position.distance_to(safe)<0.4 and cart.last_reason=="Returned inside the park","Boundary exit recovers to safe path")
    await reset()
    var lake: PackedVector2Array = park.water_polygons[0]
    var lake_point:=Vector2.ZERO
    for p in lake:lake_point+=p
    lake_point/=lake.size()
    check(not park.is_water(Vector2(35.88363,-143.0265)),"Dry central loop is not classified as water along a distant polygon edge")
    check(not park.is_water(Vector2(307,-191)),"Dry lake route stays outside water even within the lake bounds")
    check(park.is_water(lake_point),"Lake interior is identified")
    cart.position=Vector3(lake_point.x,0,lake_point.y)
    await frames(3)
    check(cart.position.distance_to(cart.safe_transform.origin)<0.4 and cart.last_reason.begins_with("Water"),"Entering lake recovers cart")
    await reset()
    cart.position.y=-5
    await frames(3)
    check(cart.position.distance_to(cart.safe_transform.origin)<0.4,"Falling beneath world recovers cart")
    await reset()
    cart.position-=cart.basis.z*10
    var event:=InputEventKey.new()
    event.physical_keycode=KEY_R
    event.pressed=true
    Input.parse_input_event(event)
    await frames(3)
    event.pressed=false
    Input.parse_input_event(event)
    check(cart.position.distance_to(cart.safe_transform.origin)<0.4,"R key recovers cart")
    var hud=game.get_node("HUD")
    hud.set_paused(true)
    var paused_pos:=cart.position
    Input.action_press("accelerate")
    await create_timer(0.08,true).timeout
    check(paused and cart.position.is_equal_approx(paused_pos) and hud.pause_overlay.visible,"Pause freezes driving and displays menu")
    hud.set_paused(false)
    Input.action_release("accelerate")
    check(not paused and not hud.pause_overlay.visible,"Resume restores gameplay")
    var camera_rig=game.get_node("ChaseCamera")
    var mouse:=InputEventMouseButton.new()
    mouse.button_index=MOUSE_BUTTON_RIGHT
    mouse.pressed=true
    camera_rig._unhandled_input(mouse)
    var motion:=InputEventMouseMotion.new()
    motion.relative=Vector2(100,30)
    camera_rig._unhandled_input(motion)
    check(camera_rig.dragging and absf(camera_rig.orbit_yaw)>0.1,"Right mouse orbits the camera")
    mouse.pressed=false
    camera_rig._unhandled_input(mouse)
    check(Input.mouse_mode==Input.MOUSE_MODE_VISIBLE,"Releasing mouse restores pointer")
    var probe:SpringArm3D=camera_rig.arm
    camera_rig.orbit_yaw=0
    camera_rig.snap()
    var camera_obstacle:=ParkGeometry.collider(game,camera_rig.position+camera_rig.basis.z*3,Vector3(8,5,1))
    camera_obstacle.rotation.y=camera_rig.rotation.y
    await frames(5)
    check(probe.get_hit_length()<probe.spring_length-1,"Spring arm shortens before camera obstacles")
    camera_obstacle.queue_free()
    var path_ok:=true
    var sample_count:=0
    var query:=PhysicsRayQueryParameters3D.new()
    query.collision_mask=1
    for entry in park.path_segments:
        var midpoint:Vector2=(entry[0]+entry[1])*0.5
        var point:=Vector3(midpoint.x,0.1,midpoint.y)
        if not park.is_on_path(point):path_ok=false
        query.from=point+Vector3(0,3,0)
        query.to=point-Vector3(0,4,0)
        if game.get_world_3d().direct_space_state.intersect_ray(query).is_empty():path_ok=false
        sample_count+=1
    check(path_ok,"All "+str(sample_count)+" path segments have connected classification and solid ground")
    var before_count:int=park.nature.visible_tree_count
    hud._toggle_density()
    check(park.nature.visible_tree_count<before_count,"Low vegetation option reduces rendered tree count")
    await frames(3)
    var invisible_collision:=false
    var shown:int=park.nature.visible_tree_count
    for i in range(shown,park.tree_colliders.size()):
        if park.tree_colliders[i] and park.tree_colliders[i].collision_layer!=0:invisible_collision=true
    check(not invisible_collision,"Hidden trees do not leave invisible collision obstacles")
    check(hud.map.position.x>0 and hud.speed_label.is_visible_in_tree(),"Minimap and speed HUD are positioned onscreen")
    print("RESULT: ",checks," checks, ",failures.size()," failures")
    quit(0 if failures.is_empty() else 1)
