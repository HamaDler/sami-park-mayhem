extends SceneTree
var game: Node3D
var checks: int=0
var failures: Array[String]=[]
func _initialize() -> void:call_deferred("run")
func check(condition: bool, message: String) -> void:
    checks+=1
    if condition:print("PASS: ",message)
    else:failures.append(message);push_error("FAIL: "+message)
func frames(count: int) -> void:
    for i in count:await physics_frame
func block(point: Vector3, dimensions: Vector3) -> StaticBody3D:
    return ParkGeometry.collider(game,point,dimensions)
func run() -> void:
    game=load("res://scenes/main.tscn").instantiate();root.add_child(game);current_scene=game
    for connection in root.focus_exited.get_connections():root.focus_exited.disconnect(connection.callable)
    var cart: CharacterBody3D=game.get_node("GolfCart")
    var player: CharacterBody3D=game.player
    var camera: Node3D=game.camera_rig
    var access: Node3D=cart.get_node("VehicleAccess")
    game.survival.process_mode=Node.PROCESS_MODE_DISABLED
    player.weapons.grant_weapon(3,0)
    cart.teleport_to(Vector2(445,-76.47),0)
    game.enter_vehicle(access,true)
    await frames(8)
    camera.zoom_by(1000)
    check(is_equal_approx(camera.zoom_distance,2.8),"Driving camera still clamps to 2.8 metres")
    camera.zoom_by(-1000)
    check(is_equal_approx(camera.zoom_distance,18),"Driving camera still clamps to 18 metres")
    camera.zoom_distance=9.4;camera.snap()
    var markers: Array[Vector3]=access.exit_candidates()
    var left:=block(markers[0]+Vector3.UP,Vector3(.9,2.4,.9))
    await frames(4)
    var exit: Dictionary=game._exit_position(access)
    check(not exit.is_empty() and exit.position.distance_to(Vector2(markers[1].x,markers[1].z))<.1,"A blocked left exit chooses the clear right side")
    var right:=block(markers[1]+Vector3.UP,Vector3(.9,2.4,.9))
    var rear:=block(markers[2]+Vector3.UP,Vector3(.9,2.4,.9))
    await frames(4)
    check(not game.exit_vehicle() and game.is_driving() and cart.control_enabled and not player.active,"Blocking every exit keeps the player safely inside the vehicle")
    left.queue_free();right.queue_free();rear.queue_free();await frames(4)
    check(game.exit_vehicle(),"The vehicle can be exited once its exits are clear")
    await frames(6)
    camera.zoom_by(1000)
    check(is_equal_approx(camera.zoom_distance,float(player.settings.camera_min_distance)),"On-foot zoom clamps to its configured minimum")
    camera.zoom_by(-1000)
    check(is_equal_approx(camera.zoom_distance,float(player.settings.camera_max_distance)),"On-foot zoom clamps to its configured maximum")
    camera.zoom_distance=5.2;camera.snap()
    player.teleport_to(Vector2(447.3,-76.47),0);camera.snap();await frames(6)
    check(game.nearest_vehicle()==access,"An unobstructed nearby parked vehicle can be entered")
    var wall:=block(cart.global_position+Vector3(1.35,1,0),Vector3(.2,2.4,3))
    await frames(4)
    check(game.nearest_vehicle()==null,"A wall blocks the vehicle interaction ray")
    var begin:=player.global_position
    for i in 50:
        player.velocity=Vector3(-4,0,0);player.move_and_slide();await physics_frame
    check(player.global_position.x>cart.global_position.x+1.7 and player.global_position.distance_to(begin)<.8,"The walking capsule cannot pass through a solid wall")
    wall.queue_free();await frames(4)
    begin=player.global_position
    for i in 50:
        player.velocity=Vector3(-4,0,0);player.move_and_slide();await physics_frame
    check(player.global_position.x>cart.global_position.x+.55 and player.global_position.x<begin.x-.1,"The walking capsule collides with the parked cart")
    player.teleport_to(Vector2(447.3,-76.47),0);await frames(4)
    check(game.enter_vehicle(access) and is_equal_approx(camera.zoom_distance,9.4),"Entering restores the selected driving zoom")
    check(game.exit_vehicle() and is_equal_approx(camera.zoom_distance,5.2),"Exiting restores the selected walking zoom")
    player.weapons.select_weapon(3);Input.action_press("aim");await frames(40)
    check(camera.sniper_scope and camera.arm.spring_length<.3 and not player.avatar.model.visible,"The sniper scope has an unobstructed eye-height view")
    check(is_equal_approx(camera.zoom_distance,5.2),"Scoped aiming preserves the selected walking zoom")
    Input.action_release("aim");await frames(50)
    check(player.avatar.model.visible and player.avatar.weapon_mount.visible and camera.arm.spring_length>5,"Leaving scope restores the character, weapon and chase distance")
    var second: CharacterBody3D=load("res://scenes/cart.tscn").instantiate();second.name="AnotherVehicle";game.add_child(second);second.initialize(game.park)
    second.teleport_to(Vector2(445,-66),0);player.teleport_to(Vector2(447,-66),0);await frames(6)
    check(game.enter_vehicle(second.get_node("VehicleAccess")),"The same interaction component supports a second vehicle")
    second.global_position+=Vector3(7,0,0);second.recover();await frames(1)
    check(second.global_position.distance_to(Vector3(445,.05,-66))<.3 and camera.global_position.distance_to(second.global_position+Vector3.UP*camera.settings.follow_height)<.1,"Recovering a second vehicle snaps the active camera to it")
    print("PLAYER_SAFETY_RESULT: ",checks," checks, ",failures.size()," failures")
    quit(0 if failures.is_empty() else 1)
