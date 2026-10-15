extends SceneTree
var game: Node3D
var survival: Node3D
var checks: int=0
var failures: Array[String]=[]
func _initialize() -> void:call_deferred("run")
func check(condition: bool, description: String) -> void:
    checks+=1
    if condition:print("PASS ",description)
    else:failures.append(description);push_error("FAIL "+description)
func frames(count: int) -> void:
    for i in count:await physics_frame
func run() -> void:
    game=load("res://scenes/main.tscn").instantiate();root.add_child(game);current_scene=game
    for connection in root.focus_exited.get_connections():root.focus_exited.disconnect(connection.callable)
    await frames(5)
    survival=game.survival
    var enemies: Node3D=survival.enemies
    var player: CharacterBody3D=game.player
    var cart: CharacterBody3D=game.get_node("GolfCart")
    var guns: Node3D=player.weapons
    enemies.set_physics_process(false)
    check(player.active and not game.is_driving(),"Run begins on foot at English Door")
    check(player.global_position.distance_to(cart.global_position)<5,"Cart is parked beside the starting player")
    check(survival.health==100 and survival.dinars==500,"Initial health and dinars")
    check(guns.selected_slot==1 and guns.unlocked[1] and not guns.unlocked[2] and not guns.unlocked[3],"Only pistol is initially unlocked")
    check(int(guns.rounds[1])==12 and int(guns.reserve[1])==96,"Initial pistol magazine and finite reserve")
    check(game.get_node("Crowd").process_mode==Node.PROCESS_MODE_DISABLED,"Ambient population disabled")
    check(survival.stations.size()==4,"Four mystery-box stations")
    for station: Node3D in survival.stations:
        var dry: bool=true
        for action: Dictionary in station.actions:
            var world_point: Vector3=station.to_global(action.position)
            if not game.park._map_land_rejection(Vector2(world_point.x,world_point.z)).is_empty():dry=false
        check(dry,"Every purchase pedestal is on dry land at "+station.display_name)
    check(game.hud.full_map.navigation_only and not game.hud.full_map.spawn_button.visible,"Survival map disables teleport UI")
    var previous:=player.global_position;game.teleport_active(Vector2.ZERO,0)
    check(player.global_position==previous,"Direct map teleport blocked")
    survival.wave.begin_next()
    check(survival.wave.total==100 and survival.wave.active_limit==40,"First wave budget and active cap")
    check(survival.wave.can_spawn(39) and not survival.wave.can_spawn(40),"Active enemy cap enforced")
    check(enemies.stats(1).health==100 and enemies.stats(2).health>100,"Health increases with wave")
    check(enemies.stats(100).speed==5.5 and enemies.stats(100).damage==60,"Movement and damage caps")
    var zombie: CharacterBody3D
    for attempt in 20:
        zombie=enemies.spawn_one()
        if zombie:break
        await frames(1)
    check(zombie!=null,"Director finds an unseen connected spawn near English Door")
    if not zombie:finish();return
    check(not enemies.seen(zombie.global_position+Vector3.UP),"New enemy is outside view or behind cover")
    check(zombie.global_position.distance_to(player.global_position)>=31,"New enemy respects minimum distance")
    check(enemies.navigation.valid_spawn(Vector2(zombie.global_position.x,zombie.global_position.z)),"Spawn is dry navigable ground")
    check(zombie.animator.has_animation("Death") and zombie.animator.has_animation("HitReact") and zombie.animator.has_animation("Run"),"Imported zombie has required animation clips")
    await frames(3)
    check(zombie.head_box.collision_layer==32 and zombie.body_box.collision_layer==16,"Separate head and body damage layers")
    var before_money: int=survival.dinars;var before_score: int=survival.score
    survival.damage_zombie(zombie,50,true,"gun",zombie.global_position)
    check(not zombie.alive and survival.kills==1,"Double headshot damage kills a 100-health zombie")
    check(survival.dinars==before_money+150 and survival.score==before_score+150,"Headshot rewards")
    survival.damage_zombie(zombie,1000,false,"gun",zombie.global_position)
    check(survival.kills==1 and survival.dinars==before_money+150,"Dead enemies cannot reward twice")
    zombie.deactivate();await frames(1)
    zombie=enemies.spawn_one()
    check(zombie!=null,"Enemy pool reuses a retired model")
    if zombie:
        var hp: float=zombie.health;var spawned: int=survival.wave.spawned
        zombie.health=27;enemies.relocate(zombie)
        check(zombie.health==27 and survival.wave.spawned==spawned,"Relocation preserves health and spawn budget")
        zombie.health=hp;zombie.alerted=false;enemies.hear_shot(zombie.global_position)
        check(zombie.alerted,"Gunshot hearing alerts nearby zombies")
        survival.rewards.double_dinars=30
        before_money=survival.dinars;survival.damage_zombie(zombie,999,false,"ram",zombie.global_position)
        check(survival.dinars==before_money+100,"Roadkill rewards participate in Double Dinars")
        check(survival.kills==2,"Roadkills count as kills")
    survival.rewards.double_dinars=0
    guns.rounds[1]=2;guns.reserve[1]=3;guns.cooldown=0;guns.reload();guns.reload_time=.001
    await frames(2)
    check(guns.rounds[1]==5 and guns.reserve[1]==0,"Reload transfers only available reserve ammunition")
    guns.reload()
    check(guns.reload_time==0,"No reload from an empty reserve")
    guns.rounds[1]=0;guns.cooldown=0;survival.rewards.collect(0)
    var shot_count: int=guns.shot_count;guns.shoot()
    check(guns.shot_count==shot_count+1 and guns.rounds[1]==0,"Infinite Ammo fires from empty magazine without consuming ammo")
    check(guns.reload_time==0,"Infinite Ammo skips reloads")
    survival.rewards._physics_process(21)
    check(not guns.infinite_ammo,"Infinite Ammo expires")
    survival.rewards.collect(2)
    check(guns.rounds[1]==12 and guns.reserve[1]==96 and not guns.unlocked[2],"Max Ammo refills owned weapons without unlocking guns")
    guns.grant_weapon(2,2);guns.grant_weapon(2,0)
    check(guns.unlocked[2] and guns.tiers[2]==2,"Box rewards unlock weapon slots and never downgrade")
    check(is_equal_approx(float(guns.current().damage),36.0),"Damage tier applies to hitscan weapon")
    var station: Node3D=survival.stations[0]
    survival.dinars=500;station.use("box")
    check(not station.rolling and survival.dinars==500,"Unaffordable box does not charge or roll")
    survival.dinars=1000;station.use("box")
    check(station.rolling and survival.dinars==50,"Box charges exactly once when rolling")
    station.use("box")
    check(survival.dinars==50,"Busy mystery box does not charge again")
    station._physics_process(3.1)
    check(not station.rolling and not station.reward.is_empty(),"Box reveals a weapon after three seconds")
    station.use("box")
    check(station.reward.is_empty(),"F claims the revealed reward")
    guns.rounds[guns.selected_slot]=0;guns.reserve[guns.selected_slot]=0;survival.dinars=1000
    station.use("ammo")
    check(survival.dinars==750 and guns.ammo_full(),"Ammo station charges and refills selected weapon")
    station.use("ammo")
    check(survival.dinars==750,"Full ammo does not charge")
    player.teleport_to(Vector2(station.global_position.x+3,station.global_position.z),0)
    cart.teleport_to(Vector2(station.global_position.x+7,station.global_position.z),0)
    cart.health=300;survival.dinars=2000
    survival.begin_repair(station);survival._timed_action(1)
    check(cart.health==300 and survival.dinars==2000,"Repair waits without charging")
    player.global_position.x+=.6;survival._timed_action(.1)
    check(survival.action.is_empty() and survival.dinars==2000,"Moving cancels repair without charge")
    survival.begin_repair(station);survival.damage_player(1)
    check(survival.action.is_empty(),"Taking damage cancels repair")
    survival.begin_repair(station);survival._timed_action(3.1)
    check(cart.health==cart.max_health and survival.dinars==1250,"Three-second repair restores cart and charges once")
    survival.damage_player(40);var injured: float=survival.health
    survival.since_damage=4;survival._physics_process(.1)
    check(survival.health==injured,"Health regeneration waits five seconds")
    survival.since_damage=5;survival._physics_process(1)
    check(survival.health>injured,"Health regenerates after delay")
    cart._start_rollover();cart.rollover_body.freeze=true;cart.speed=0;cart.rollover_body.linear_velocity=Vector3.ZERO;cart.rollover_body.angular_velocity=Vector3.ZERO
    player.global_position=cart.global_position+Vector3(3.2,0,0);player.velocity=Vector3.ZERO
    var recovery_position:=cart.global_position;var recovery_health: float=cart.health
    Input.action_press("recover");survival._recovery(3.1);Input.action_release("recover")
    check(not cart.rolling and cart.global_position.distance_to(recovery_position)<.5,"Timed rollover recovery rights cart in place")
    check(cart.health==recovery_health,"Recovery does not heal the cart")
    survival.wave.spawned=100;survival.wave.killed=99;survival.wave.register_kill()
    check(not survival.wave.running and survival.completed_wave==1 and survival.wave.preparation==15,"Wave completes only at full budget and starts preparation")
    survival.wave.tick(14)
    check(survival.wave.number==1,"Preparation does not start wave early")
    survival.wave.tick(1)
    check(survival.wave.number==2 and survival.wave.total==125 and survival.wave.active_limit==44,"Next wave increases budget and simultaneous count")
    var lake: Vector2=Vector2(game.park.layout.waters[0].points[0][0],game.park.layout.waters[0].points[0][1])
    check(not enemies.navigation.valid_spawn(lake),"Lake edge is excluded from navigation spawns")
    await frames(1)
    enemies.navigation.requests_this_frame=0
    var lakeside: Vector2=Vector2(survival.stations[2].global_position.x,survival.stations[2].global_position.z)
    var destination: Vector2=enemies.navigation.point(enemies.navigation.nearest(lakeside,25))
    var route: PackedVector2Array=enemies.navigation.route(Vector2(-660,-30),destination)
    check(not route.is_empty() and route[-1].distance_to(destination)<4,"Navigation connects west entrance to lake district")
    survival.rewards.infinite_ammo=10;var hp: float=survival.health
    paused=true;await frames(4)
    check(survival.rewards.infinite_ammo==10 and survival.health==hp,"Pause freezes buffs and combat")
    paused=false
    player.global_position=cart.global_position+Vector3(2.8,0,0)
    check(game.enter_vehicle(cart.get_node("VehicleAccess")),"Survival still supports entering the cart")
    cart.receive_damage(99999)
    check(not game.is_driving() and player.active and cart.health==0,"Cart destruction safely ejects the player")
    check(not cart.get_node("VehicleAccess").available(),"Destroyed cart cannot be entered")
    survival.damage_player(99999)
    check(survival.over and paused and game.hud.survival_overlay.ending.visible,"Death ends the run and shows restart screen")
    check(survival.records.best_score>=survival.score and survival.records.best_wave>=1,"Run records save")
    finish()
func finish() -> void:
    paused=false
    print("SURVIVAL VALIDATION: ",checks," checks; ",failures.size()," failures")
    game.queue_free();await process_frame;await create_timer(.2).timeout
    quit(0 if failures.is_empty() else 1)
