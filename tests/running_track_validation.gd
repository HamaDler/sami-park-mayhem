extends SceneTree
var game: Node3D
var cart: CharacterBody3D
var park: Node3D
var checks: int=0
var failures: Array[String]=[]
func _initialize() -> void:call_deferred("run")
func check(condition: bool, message: String) -> void:
    checks+=1
    if condition:print("PASS: ",message)
    else:failures.append(message);push_error("FAIL: "+message)
func frames(count: int) -> void:
    for i in count:await physics_frame
func run() -> void:
    Engine.time_scale=12;Engine.physics_ticks_per_second=720
    game=load("res://scenes/main.tscn").instantiate();root.add_child(game);current_scene=game
    for connection in root.focus_exited.get_connections():root.focus_exited.disconnect(connection.callable)
    cart=game.get_node("GolfCart");park=game.get_node("SamiPark")
    var track: Node3D=park.running_track
    await frames(5)
    check(track.centerline[0].is_equal_approx(track.centerline[-1]) and track.layout.lanes==2,"Running loop is closed with exactly two lanes")
    check(track.layout.path_ids==["1392513106","1392513107"],"Running loop follows the current mapped northwestern route")
    var support:=true
    var grip:=true
    var clear:=true
    var grass_excluded:=true
    var query:=PhysicsRayQueryParameters3D.new();query.collision_mask=1
    var samples: int=0
    for i in track.centerline.size()-1:
        var a: Vector2=track.centerline[i];var b: Vector2=track.centerline[i+1]
        var direction: Vector2=(b-a).normalized();var side:=Vector2(-direction.y,direction.x)
        for offset in [-1.0,0.0,1.0]:
            var point: Vector2=(a+b)*.5+side*offset
            grip=grip and park.is_on_path(Vector3(point.x,0,point.y))
            clear=clear and not park.is_water(point) and not park._map_tree_blocked(point)
            grass_excluded=grass_excluded and not park.nature._close_grass_ground(point)
            query.from=Vector3(point.x,2,point.y);query.to=Vector3(point.x,-1,point.y)
            support=support and not game.get_world_3d().direct_space_state.intersect_ray(query).is_empty()
            samples+=1
    check(support,"All "+str(samples)+" lane/center samples have solid ground")
    check(grip,"Both lanes retain path traction around the full loop")
    check(clear,"Loop lanes stay clear of water and blocking tree trunks")
    check(grass_excluded,"Streamed grass stays off both red lanes")
    var shared:=0
    for road: Dictionary in park.layout.paths:
        if road.id in track.layout.path_ids:continue
        for p: Vector2 in ParkGeometry.points(road.points,true):
            if track.centerline.has(p):shared+=1
    check(shared>=3,"Track retains existing path junctions ("+str(shared)+" shared points)")
    var hud: Node=game.get_node("HUD")
    hud.open_map()
    var sample: Vector2=(track.centerline[8]+track.centerline[9])*.5
    hud.full_map.select_point(sample)
    check(hud.full_map.selection.valid and hud.full_map.selection.position.distance_to(sample)<.01,"Map waypoint can select the running track without clearance shifts")
    hud.full_map.spawn_selected()
    await frames(5)
    check(not paused and cart.on_path and Vector2(cart.position.x,cart.position.z).distance_to(sample)<.1,"Map spawning places a drivable cart on the track")
    var start: Vector2=track.centerline[0].lerp(track.centerline[1],.2)
    var direction: Vector2=(track.centerline[1]-track.centerline[0]).normalized()
    cart.teleport_to(start,atan2(-direction.x,-direction.y));await frames(3)
    cart.speed=15;cart.travel_yaw=cart.rotation.y
    Input.action_press("accelerate");await frames(60);Input.action_release("accelerate")
    check(cart.on_path and cart.speed>cart.settings.grass_speed+1,"Track driving can exceed the grass speed limit")
    check(cart.effects.written>0,"Tire trails remain active on the running surface")
    cart.settings=cart.settings.duplicate();cart.settings.max_speed=4
    cart.teleport_to(track.centerline[0],atan2(-(track.centerline[1]-track.centerline[0]).x,-(track.centerline[1]-track.centerline[0]).y))
    await frames(3)
    var recoveries: Array[String]=[]
    cart.recovered.connect(func(reason: String):recoveries.append(reason))
    # Dense targets prevent the test driver from swinging wide when it advances
    # from a bend vertex to a distant original OSM vertex.
    var drive_points:=PackedVector2Array()
    for i in track.centerline.size()-1:
        var a: Vector2=track.centerline[i];var b: Vector2=track.centerline[i+1]
        var steps: int=maxi(1,ceili(a.distance_to(b)/2.0))
        for j in steps:drive_points.append(a.lerp(b,float(j)/steps))
    drive_points.append(drive_points[0])
    var index:=1
    var walls:=0
    var off_path_frames:=0
    var start_trip: float=cart.distance_m
    for tick in 30000:
        if index>=drive_points.size():break
        var pos:=Vector2(cart.position.x,cart.position.z)
        var toward: Vector2=drive_points[index]-pos
        if toward.length()<1.2:
            index+=1
            if index>=drive_points.size():break
            toward=drive_points[index]-pos
        var yaw: float=atan2(-toward.x,-toward.y)
        var error: float=wrapf(yaw-cart.rotation.y,-PI,PI)
        var angle: float=atan2(2*cart.settings.wheelbase*sin(error),maxf(toward.length(),3.0))
        var strength: float=clampf(angle/cart.settings.steering_angle,-1,1)
        Input.action_release("left");Input.action_release("right")
        Input.action_press("left" if strength>0 else "right",absf(strength));Input.action_press("accelerate")
        await physics_frame
        if cart.is_on_wall():walls+=1
        if not cart.on_path:off_path_frames+=1
        if not recoveries.is_empty() or walls>10:break
    for action in ["accelerate","left","right"]:Input.action_release(action)
    print("TRACK_DRIVE: waypoints=",index,"/",drive_points.size()," distance=",snappedf(cart.distance_m-start_trip,.1),"m walls=",walls," off_path_frames=",off_path_frames," recoveries=",recoveries)
    check(index>=drive_points.size() and walls==0 and recoveries.is_empty(),"Cart completes the entire running loop without walls or recovery")
    check(off_path_frames==0,"Loop follower remains on the drivable running surface")
    print("TRACK_RESULT: ",checks," checks, ",failures.size()," failures")
    quit(0 if failures.is_empty() else 1)
