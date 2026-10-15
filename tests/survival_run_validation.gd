extends SceneTree
var game: Node3D
var checks: int=0
var failures: Array[String]=[]
func _initialize() -> void:call_deferred("run")
func check(value: bool, message: String) -> void:
    checks+=1
    if value:print("PASS ",message)
    else:failures.append(message);push_error("FAIL "+message)
func frames(count: int) -> void:
    for i in count:await physics_frame
func run() -> void:
    game=load("res://scenes/main.tscn").instantiate();root.add_child(game);current_scene=game
    for connection in root.focus_exited.get_connections():root.focus_exited.disconnect(connection.callable)
    await frames(5)
    var s: Node3D=game.survival;s.enemies.set_physics_process(false);s.wave.begin_next()
    s.config.powerups.drop_chance=0
    var starting_lifetime: int=s.records.lifetime_kills
    var peak_alive: int=0;var attempts: int=0;var saw_final_markers: bool=false
    while s.kills<100 and attempts<1400:
        attempts+=1
        var alive: Array[CharacterBody3D]=s.enemies.living()
        if s.wave.can_spawn(alive.size()):
            s.enemies.spawn_one();alive=s.enemies.living();peak_alive=maxi(peak_alive,alive.size())
        if (alive.size()>=40 or s.wave.spawned==s.wave.total) and not alive.is_empty():
            if s.wave.remaining()<=5:saw_final_markers=true
            var zombie: CharacterBody3D=alive[0]
            s.damage_zombie(zombie,100000,false,"gun",zombie.global_position);zombie.deactivate()
        await frames(1)
    check(s.kills==100 and s.wave.spawned==100,"An entire real 100-enemy wave spawns and clears")
    check(peak_alive==40,"Director holds first-wave simultaneous limit at 40")
    check(s.wave.killed==100 and not s.wave.running,"No stranded budget or phantom enemies at wave completion")
    check(s.score==10000 and s.dinars==10500,"Complete-wave score and currency accounting")
    check(s.records.lifetime_kills==starting_lifetime+100,"Every kill contributes once to lifetime records")
    check(saw_final_markers,"Final-five marker condition is reached during a real wave")
    check(s.enemies.spawn_one()==null,"Director refuses to spawn during preparation")
    # Exercise actual high-speed collision wear and ram damage on a clear path.
    var p:=Vector2(195.8739,-39.85362);var forward:=Vector2(.949736,.313053);var yaw:=atan2(-forward.x,-forward.y)
    var cart: CharacterBody3D=game.get_node("GolfCart")
    cart.teleport_to(p,yaw);game.enter_vehicle(cart.get_node("VehicleAccess"),true)
    await frames(5)
    var zombie: CharacterBody3D=s.enemies.pool[0]
    zombie.activate(p+forward*5,10001,{"health":100,"damage":25,"speed":1.8});zombie.set_physics_process(false)
    var wall:=ParkGeometry.collider(game,Vector3(p.x+forward.x*12,1.2,p.y+forward.y*12),Vector3(7,3,.3));wall.rotation.y=yaw
    await frames(3)
    var before: float=cart.health;var old_kills: int=s.kills
    s.previous_cart_position=cart.global_position;cart.speed=20
    await frames(55)
    check(not zombie.alive and s.kills==old_kills+1,"Driving over an actual enemy registers a roadkill")
    check(cart.health<before-float(s.config.cart.ram_wear),"Real wall impact and ramming both wear down the cart")
    wall.queue_free();await frames(2)
    # A disabled cart can still be repaired even when stranded far from stations.
    cart.receive_damage(100000)
    var station: Node3D=s.stations[0]
    game.player.teleport_to(Vector2(station.global_position.x,station.global_position.z+3),0)
    s.dinars=1000;s.begin_repair(station);s._timed_action(3.1)
    check(cart.health==cart.max_health and s.dinars==250,"Station can restore a stranded disabled cart without teleporting it")
    s.score=10000;s.completed_wave=1;s.damage_player(100000)
    var previous_game: int=game.get_instance_id()
    game.hud.survival_overlay.restart();await frames(8)
    game=current_scene
    check(game.get_instance_id()!=previous_game,"Restart replaces the entire previous run scene")
    check(game.survival.kills==0 and game.survival.score==0 and game.survival.dinars==500,"Restart clears run score, kills and currency")
    check(game.survival.wave.number==0 and game.survival.enemies.pool.is_empty(),"Restart clears waves and enemy pool")
    check(not game.player.weapons.unlocked[2] and not game.player.weapons.unlocked[3] and game.player.weapons.reserve[1]==96,"Restart restores pistol-only ammunition and loadout")
    check(game.survival.records.best_score>=10000 and game.survival.records.best_wave>=1,"Restart retains saved records")
    print("SURVIVAL FULL RUN: ",checks," checks; ",failures.size()," failures")
    paused=false;game.queue_free();await process_frame;await create_timer(.2).timeout
    quit(0 if failures.is_empty() else 1)
