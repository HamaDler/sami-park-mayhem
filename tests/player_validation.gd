extends SceneTree
var game: Node3D
var cart: CharacterBody3D
var player: CharacterBody3D
var checks: int=0
var failures: Array[String]=[]
func _initialize() -> void:call_deferred("run")
func check(condition: bool, message: String) -> void:
    checks+=1
    if condition:print("PASS: ",message)
    else:failures.append(message);push_error("FAIL: "+message)
func frames(count: int) -> void:
    for i in count:await physics_frame
func key(code: Key) -> void:
    var event:=InputEventKey.new();event.physical_keycode=code;event.pressed=true;Input.parse_input_event(event)
    await frames(2)
    var released:=event.duplicate() as InputEventKey
    released.pressed=false;Input.parse_input_event(released);await frames(2)
func run() -> void:
    game=load("res://scenes/main.tscn").instantiate();root.add_child(game);current_scene=game
    for connection in root.focus_exited.get_connections():root.focus_exited.disconnect(connection.callable)
    cart=game.get_node("GolfCart");player=game.player
    var hud: Node=game.hud
    await frames(6)
    check(game.is_driving() and cart.control_enabled and not player.active,"Game starts in the cart with walking controls disabled")
    var driver: Node3D=cart.get_node("Visual/SeatedDriver")
    check(driver.get_node("Model").scene_file_path.ends_with("hoodie.glb") and driver.skeleton.get_bone_count()>50,"Seated driver uses the supplied rigged Hoodie GLB")
    check(driver.bone_world("Wrist.L").origin.distance_to(cart.steering_wheel.global_position-cart.visual.global_basis.x*.13)<.04 and driver.bone_world("Wrist.R").origin.distance_to(cart.steering_wheel.global_position+cart.visual.global_basis.x*.13)<.04,"Both driver hands reach the actual steering wheel")
    check(absf(cart.to_local(driver.bone_world("Body").origin).y-.78)<.01 and cart.to_local(driver.bone_world("Foot.L").origin).y>.30,"Driver hips sit on the seat and feet stay above the cart floor")
    await key(KEY_3)
    check(player.weapons.selected_slot==1,"Weapon keys are ignored inside a vehicle")
    await key(KEY_F)
    await frames(6)
    check(not game.is_driving() and player.active and not cart.control_enabled and not driver.visible,"F exits the cart, hides its occupant and parks it")
    check(player.is_on_floor() and player.global_position.distance_to(cart.global_position)>1.2,"Character exits at a clear grounded position")
    check(game.camera_rig.target==player and game.camera_rig.on_foot and Input.mouse_mode==Input.MOUSE_MODE_CAPTURED,"On-foot camera follows the character and captures mouse look")
    check(not hud.gauge.visible and hud.combat_hud.visible and hud.map.cart==player,"HUD and minimap switch to the walking character")
    var parked:=cart.global_position
    var start:=player.global_position
    Input.action_press("accelerate");await frames(70);Input.action_release("accelerate");await frames(10)
    check(player.global_position.distance_to(start)>3,"WASD moves the character on foot")
    check(cart.global_position.distance_to(parked)<.01,"Walking inputs do not move the parked vehicle")
    await key(KEY_F)
    check(not game.is_driving(),"F cannot enter a vehicle from beyond its interaction range")
    var before_jump:=player.global_position.y
    Input.action_press("jump");await frames(12);Input.action_release("jump")
    check(player.global_position.y>before_jump+.5,"Space launches the character into a real jump")
    await frames(75)
    check(player.is_on_floor() and absf(player.global_position.y-before_jump)<.1,"Jump lands back on solid ground")
    var wall_pos: Vector3=player.global_position-game.camera_rig.global_basis.z*5+Vector3.UP*1.4
    var wall: StaticBody3D=ParkGeometry.collider(game,wall_pos,Vector3(8,3,.5));wall.rotation.y=player.rotation.y
    wall.set_script(load("res://tests/damage_receiver.gd"))
    await frames(5)
    await key(KEY_1);await frames(18)
    var initial_rounds: int=player.weapons.rounds[1]
    Input.action_press("fire");await frames(35);Input.action_release("fire");await frames(2)
    check(player.weapons.rounds[1]==initial_rounds-1,"Holding fire with the pistol produces one shot")
    check(wall.damage_received>0,"Aiming ray and muzzle ray hit colliding targets and call the damage receiver")
    await key(KEY_2);await frames(18)
    initial_rounds=player.weapons.rounds[2]
    Input.action_press("fire");await frames(38);Input.action_release("fire");await frames(2)
    check(player.weapons.selected_slot==2 and player.weapons.rounds[2]<=initial_rounds-4,"Slot 2 equips an automatic rifle and fires repeatedly while held")
    await key(KEY_R)
    check(player.weapons.reload_time>0,"R starts reloading on foot")
    var shots: int=player.weapons.shot_count
    player.weapons.shoot()
    check(player.weapons.shot_count==shots,"Firing is blocked during a reload")
    await frames(115)
    check(player.weapons.rounds[2]==30 and player.weapons.reload_time==0,"Rifle reload refills its magazine")
    await key(KEY_3);await frames(18)
    Input.action_press("aim");await frames(25)
    check(player.weapons.selected_slot==3 and game.camera_rig.sniper_scope and game.camera_rig.camera.fov<25,"Slot 3 equips the sniper and right mouse engages scoped zoom")
    initial_rounds=player.weapons.rounds[3]
    Input.action_press("fire");await frames(35);Input.action_release("fire");Input.action_release("aim");await frames(2)
    check(player.weapons.rounds[3]==initial_rounds-1,"Sniper fires a single shot with its slower cooldown")
    check(player.avatar.get_weapon().name=="Sniper","Equipped weapon is visible on the character")
    hud.set_paused(true)
    var paused_position:=player.global_position
    var ammo: int=player.weapons.rounds[3]
    Input.action_press("accelerate");Input.action_press("fire")
    await create_timer(.1,true).timeout
    check(player.global_position.is_equal_approx(paused_position) and player.weapons.rounds[3]==ammo,"Pause freezes walking and weapon firing")
    Input.action_release("accelerate");Input.action_release("fire");hud.set_paused(false)
    check(Input.mouse_mode==Input.MOUSE_MODE_CAPTURED,"Resuming on foot restores mouse capture")
    var car_before:=cart.global_position
    hud.open_map();hud.full_map.select_point(Vector2(445,-76.47));hud.full_map.spawn_selected();await frames(6)
    check(player.global_position.distance_to(Vector3(445,0,-76.47))<.3 and cart.global_position.is_equal_approx(car_before),"Map travel on foot moves the player and leaves the parked car behind")
    check(game.park.nature.last_collision_position.distance_to(Vector2(player.position.x,player.position.z))<.5,"Nearby tree collisions follow the walking player after map travel")
    player.global_position=Vector3(1500,0,1500);await frames(3)
    check(player.global_position.distance_to(player.safe_transform.origin)<.3,"Leaving the world recovers the walking character")
    var lake: PackedVector2Array=game.park.water_polygons[0]
    var lake_point:=Vector2.ZERO
    for point in lake:lake_point+=point
    lake_point/=lake.size();player.global_position=Vector3(lake_point.x,0,lake_point.y);await frames(3)
    check(player.global_position.distance_to(player.safe_transform.origin)<.3,"Entering water recovers the walking character")
    wall.queue_free()
    var near: Dictionary=game._exit_position(cart.get_node("VehicleAccess"))
    player.teleport_to(near.position,cart.rotation.y);game.camera_rig.snap();await frames(4)
    await key(KEY_F)
    check(game.is_driving() and game.camera_rig.target==cart and not player.active and driver.visible,"F near the cart re-enters and restores the driver and chase camera")
    shots=player.weapons.shot_count
    Input.action_press("fire");await frames(20);Input.action_release("fire")
    check(player.weapons.shot_count==shots,"Weapons cannot fire from inside the vehicle")
    await key(KEY_F)
    check(player.weapons.selected_slot==3,"Weapon selection persists across entering and exiting")
    # A second instance proves interaction discovers vehicles rather than a fixed node.
    var second: CharacterBody3D=load("res://scenes/cart.tscn").instantiate();second.name="SecondCart";game.add_child(second);second.initialize(game.park)
    second.teleport_to(Vector2(445,-76.47),0)
    check(not second.control_enabled and not second.get_node("Visual/SeatedDriver").visible,"New vehicles start parked and empty until entered")
    player.teleport_to(Vector2(447,-76.47),0);game.camera_rig.snap();await frames(6)
    await key(KEY_F)
    check(game.is_driving() and game.get_active_actor()==second,"F can enter a newly added vehicle through the shared interaction component")
    print("PLAYER_RESULT: ",checks," checks, ",failures.size()," failures")
    quit(0 if failures.is_empty() else 1)
