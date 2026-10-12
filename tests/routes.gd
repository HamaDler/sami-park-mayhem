extends SceneTree
var failures:int=0
func _initialize() -> void:call_deferred("run")
func run() -> void:
    Engine.time_scale=12.0
    Engine.physics_ticks_per_second=720
    var game=load("res://scenes/main.tscn").instantiate()
    root.add_child(game)
    current_scene=game
    for connection in root.focus_exited.get_connections():root.focus_exited.disconnect(connection.callable)
    var park=game.get_node("SamiPark")
    var cart=game.get_node("GolfCart")
    var recoveries:Array[String]=[]
    cart.recovered.connect(func(reason):recoveries.append(reason))
    cart.settings.max_speed=4.0
    for route_id in ["195485176","195248928","195248936"]:
        var route:Dictionary={}
        for road in park.layout.paths:
            if road.id==route_id:route=road;break
        var points:PackedVector2Array=ParkGeometry.points(route.points,true)
        cart.position=Vector3(points[0].x,0.15,points[0].y)
        var dir:Vector2=(points[1]-points[0]).normalized()
        cart.rotation.y=atan2(-dir.x,-dir.y)
        cart.speed=0
        cart.steer=0
        cart.velocity=Vector3.ZERO
        cart.safe_transform=cart.global_transform
        cart.safe_timer=0
        cart.reset_physics_interpolation()
        # Let the physics server synchronize the test-only teleport before driving.
        for settle_frame in 3:await physics_frame
        recoveries.clear()
        var index:int=1
        var wall_frames:int=0
        var max_off_path:float=0
        var start_trip:float=cart.distance_m
        for tick in 30000:
            if index>=points.size():break
            var pos:=Vector2(cart.position.x,cart.position.z)
            var toward:Vector2=points[index]-pos
            if toward.length()<2.0:
                index+=1
                if index>=points.size():break
                toward=points[index]-pos
            var yaw:float=atan2(-toward.x,-toward.y)
            var error:float=wrapf(yaw-cart.rotation.y,-PI,PI)
            var angle:float=atan2(2*cart.settings.wheelbase*sin(error),maxf(toward.length(),2.0))
            var strength:float=clampf(angle/cart.settings.steering_angle,-1,1)
            Input.action_release("left")
            Input.action_release("right")
            Input.action_press("left" if strength>0 else "right",absf(strength))
            Input.action_press("accelerate")
            await physics_frame
            if cart.is_on_wall():wall_frames+=1
            max_off_path=maxf(max_off_path,park.path_distance(Vector2(cart.position.x,cart.position.z)))
            if not recoveries.is_empty() or wall_frames>60:break
        var success:bool=index>=points.size() and recoveries.is_empty() and wall_frames<60
        print("ROUTE ",route_id," ","PASS" if success else "FAIL"," waypoints=",index,"/",points.size()," distance=",snappedf(cart.distance_m-start_trip,0.1),"m walls=",wall_frames," off_path=",snappedf(max_off_path,0.1)," recoveries=",recoveries)
        if not success:failures+=1
        Input.action_release("accelerate")
        Input.action_release("left")
        Input.action_release("right")
    print("ROUTE RESULT: 3 drives, ",failures," failures")
    quit(failures)
