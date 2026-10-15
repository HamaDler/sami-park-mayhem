extends SceneTree
var game: Node3D
var survival: Node3D
var checks: int=0
var failures: Array[String]=[]
func _initialize() -> void:call_deferred("run")
func check(value: bool, text: String) -> void:
    checks+=1
    if value:print("PASS ",text)
    else:failures.append(text);push_error("FAIL "+text)
func frames(count: int) -> void:
    for i in count:await physics_frame
func run() -> void:
    game=load("res://scenes/main.tscn").instantiate();root.add_child(game);current_scene=game
    for connection in root.focus_exited.get_connections():root.focus_exited.disconnect(connection.callable)
    await frames(5)
    survival=game.survival;survival.enemies.set_physics_process(false);survival.wave.begin_next()
    var fixture: Dictionary=find_corridor()
    check(not fixture.is_empty(),"Find a clear combat corridor on mapped paths")
    if fixture.is_empty():finish();return
    var p: Vector2=fixture.position;var forward: Vector2=fixture.forward
    var yaw:=atan2(-forward.x,-forward.y)
    game.player.teleport_to(p,yaw);game.camera_rig.foot_yaw=yaw;game.camera_rig.snap()
    game.camera_rig.set_process(false)
    var zombie: CharacterBody3D=load("res://scenes/zombie.tscn").instantiate();survival.enemies.add_child(zombie)
    zombie.build(survival.enemies,survival.enemies.models[0],0);survival.enemies.pool.append(zombie)
    zombie.activate(p+forward*8,900,{"health":1000,"damage":25,"speed":1.8});survival.wave.register_spawn();zombie.set_physics_process(false)
    zombie.animator.advance(.2)
    await frames(5)
    var camera: Camera3D=game.camera_rig.camera
    camera.global_position=game.player.global_position+Vector3(0,1.5,0)
    var target: Vector3=zombie.body_box.global_position
    camera.look_at(target,Vector3.UP)
    var guns: Node3D=game.player.weapons;guns.cooldown=0;guns.reload_time=0;guns.rounds[1]=12
    var result: Dictionary=guns.shoot()
    check(not result.is_empty() and result.collider==zombie.body_box,"Actual muzzle hitscan reaches zombie body")
    check(zombie.health==976,"Body hit applies exactly one pistol damage event")
    target=zombie.head_box.global_position;camera.look_at(target,Vector3.UP);guns.cooldown=0
    result=guns.shoot()
    check(not result.is_empty() and result.collider==zombie.head_box,"Actual aiming ray reaches the animated head hitbox")
    check(zombie.health==928,"Actual head hit doubles pistol damage")
    var wall:=ParkGeometry.collider(game,game.player.global_position+Vector3(forward.x*4,1,forward.y*4),Vector3(4,3,.3))
    wall.rotation.y=yaw
    await frames(3)
    guns.cooldown=0;camera.look_at(zombie.head_box.global_position,Vector3.UP);result=guns.shoot()
    check(not result.is_empty() and result.collider==wall and zombie.health==928,"Cover blocks bullets before the zombie")
    wall.queue_free();await frames(3)
    zombie.global_position=game.player.global_position+Vector3(forward.x*1.4,0,forward.y*1.4)
    zombie.alerted=true;zombie.spawn_cooldown=0;zombie.hit_time=0;zombie.attack_time=0;zombie.attack_cooldown=0;zombie.think_time=0
    zombie.set_physics_process(true);survival.health=100;survival.since_damage=0
    await frames(42)
    check(survival.health==75,"Zombie melee applies damage after its animation windup")
    check(zombie.global_position.distance_to(game.player.global_position)>.65,"Attacking zombie stops instead of walking through player")
    zombie.set_physics_process(false);zombie.global_position=game.player.global_position+Vector3(forward.x*1.5,0,forward.y*1.5)
    wall=ParkGeometry.collider(game,game.player.global_position+Vector3(forward.x*.75,1,forward.y*.75),Vector3(4,3,.25));wall.rotation.y=yaw
    zombie.attack_cooldown=0;zombie.attack_time=0;zombie.think_time=0;zombie.set_physics_process(true)
    var before: float=survival.health;await frames(90)
    check(survival.health==before,"Zombies cannot melee through a wall")
    wall.queue_free();await frames(3)
    var start:=p+forward*20;zombie.global_position=Vector3(start.x,.06,start.y);zombie.alerted=true;zombie.think_time=0;zombie.attack_time=0;zombie.attack_cooldown=0
    var old_distance: float=zombie.global_position.distance_to(game.player.global_position)
    await frames(120)
    check(zombie.global_position.distance_to(game.player.global_position)<old_distance-1.0,"Alerted zombie moves toward player on real park ground")
    check(not game.park.is_water(Vector2(zombie.global_position.x,zombie.global_position.z)),"Pursuit stays out of water")
    zombie.set_physics_process(false)
    var old_id: int=zombie.id;var old_hp: float=zombie.health;var budget: int=survival.wave.spawned
    game.player.teleport_to(Vector2(117,-63),0);game.camera_rig.follow_actor(game.player,true);game.camera_rig.snap()
    survival.enemies.navigation.requests_this_frame=0;survival.enemies.relocate(zombie)
    check(zombie.id==old_id and zombie.health==old_hp and survival.wave.spawned==budget,"Long-distance relocation retains enemy identity and budget")
    for index in survival.enemies.models.size():
        var item: CharacterBody3D=load("res://scenes/zombie.tscn").instantiate();survival.enemies.add_child(item);item.build(survival.enemies,survival.enemies.models[index],index)
        check(item.animator.has_animation("Walk") and item.animator.has_animation("Death") and item.animator.has_animation("HitReact"),"Zombie variant %d imports its required animations" % index)
        item.queue_free()
    finish()
func find_corridor() -> Dictionary:
    for entry: Array in game.park.path_segments:
        var a: Vector2=entry[0];var b: Vector2=entry[1]
        if a.distance_to(b)<35 or float(entry[2])<2:continue
        var p:=a.lerp(b,.4);var forward: Vector2=(b-a).normalized()
        if p.distance_to(Vector2(117,-63))>250:continue
        if not survival.enemies.navigation.segment_clear(p,p+forward*25):continue
        var query:=PhysicsRayQueryParameters3D.create(Vector3(p.x,1,p.y),Vector3(p.x+forward.x*25,1,p.y+forward.y*25),1)
        if not game.get_world_3d().direct_space_state.intersect_ray(query).is_empty():continue
        return {"position":p,"forward":forward}
    return {}
func finish() -> void:
    print("SURVIVAL COMBAT: ",checks," checks; ",failures.size()," failures")
    game.queue_free();await process_frame;await process_frame
    quit(0 if failures.is_empty() else 1)
