extends SceneTree
var game: Node3D
var s: Node3D
var checks: int=0
var failures: Array[String]=[]
const OUTPUT="C:/Users/7amad/Documents/Codex/2026-10-11/c-users-7amad-desktop-godot-erbil/outputs/"
func _initialize() -> void:call_deferred("run")
func check(condition: bool, description: String) -> void:
    checks+=1
    if condition:print("PASS ",description)
    else:failures.append(description);push_error("FAIL "+description)
func frames(count: int) -> void:
    for i in count:await physics_frame
func enemy(kind: String, p: Vector2) -> CharacterBody3D:
    var zombie: CharacterBody3D=load("res://scenes/zombie.tscn").instantiate();s.enemies.add_child(zombie)
    var model: int=s.enemies.types[kind].model
    zombie.build(s.enemies,s.enemies.models[model],model);s.enemies.pool.append(zombie)
    zombie.activate(p,s.enemies.next_id,s.enemies.type_stats(1,kind));s.enemies.next_id+=1
    zombie.set_physics_process(false)
    return zombie
func screenshot(filename: String) -> void:
    if DisplayServer.get_name()=="headless":return
    await frames(4);await RenderingServer.frame_post_draw
    root.get_texture().get_image().save_png(OUTPUT+filename)
func run() -> void:
    game=load("res://scenes/main.tscn").instantiate();root.add_child(game);current_scene=game
    for connection in root.focus_exited.get_connections():root.focus_exited.disconnect(connection.callable)
    s=game.survival;s.set_physics_process(false);s.enemies.set_physics_process(false)
    var cart: CharacterBody3D=game.get_node("GolfCart")
    var player: CharacterBody3D=game.player
    var upgrades: Node=s.upgrades
    var missions: Node3D=s.missions
    var shop: Control=game.hud.survival_overlay.workshop
    await frames(4)
    check(missions.sites.size()==4,"All four landmark supply sites resolve to dry clear ground")
    check(s.enemies.types.size()==4,"Four readable enemy archetypes are available")
    var base: Dictionary=s.enemies.stats(1)
    var runner: Dictionary=s.enemies.type_stats(1,"runner")
    var armor: Dictionary=s.enemies.type_stats(1,"armored")
    check(runner.health<base.health and runner.speed>base.speed,"Sprinters are faster and more fragile")
    check(armor.health>base.health and armor.speed<base.speed,"Armored enemies are tougher and slower")
    check(s.enemies.type_stats(100,"runner").speed<=7.5 and s.enemies.type_stats(100,"armored").damage<=60,"Variant speed and damage remain capped")
    var rolled: Dictionary={};s.enemies.random.seed=67110
    for i in 1000:
        var kind: String=s.enemies.roll_type(1);rolled[kind]=int(rolled.get(kind,0))+1
    check(rolled.size()==4 and int(rolled.walker)>int(rolled.runner) and int(rolled.runner)>int(rolled.armored),"Weighted spawns include all variants while keeping special types uncommon")
    s.wave.begin_next()
    var armored:=enemy("armored",Vector2(-660,-40));s.wave.register_spawn()
    var hp: float=armored.health
    check(armored.armor_helmet.get_parent()==armored.head_box and armored.armor_helmet.global_position.distance_to(armored.head_box.global_position)<.3,"Armor helmet follows the animated head without floating or changing scale")
    s.damage_zombie(armored,20,false,"gun",armored.position)
    check(is_equal_approx(armored.health,hp-9),"Armor reduces body bullet damage")
    hp=armored.health;s.damage_zombie(armored,20,true,"gun",armored.position)
    check(is_equal_approx(armored.health,hp-40),"Headshots bypass armor and retain double damage")
    hp=armored.health;s.damage_zombie(armored,20,false,"ram",armored.position)
    check(is_equal_approx(armored.health,hp-14),"Armored enemies resist some vehicle impact damage")
    var money: int=s.dinars;var kills: int=s.kills
    s.damage_zombie(armored,10000,true,"gun",armored.position);s.damage_zombie(armored,10000,true,"gun",armored.position)
    check(s.kills==kills+1 and s.dinars==money+150,"Special enemy kills reward and count exactly once")
    var screamer:=enemy("screamer",Vector2(-660,-30))
    var listener:=enemy("walker",Vector2(-650,-30))
    var distant:=enemy("runner",Vector2(-400,-30))
    var spawned: int=s.wave.spawned
    s.enemies.scream(screamer)
    check(listener.alerted and not distant.alerted,"Scream alerts nearby living enemies within its radius")
    check(s.wave.spawned==spawned and s.kills==kills+1,"Scream does not create uncounted spawns or rewards")
    screamer.alerted=true;screamer.spawn_cooldown=0;screamer.scream_cooldown=0
    var target:=Vector2(-640,-30);player.teleport_to(target,0)
    var wall:=ParkGeometry.collider(game,Vector3(-650,1,-30),Vector3(.3,3,5));await frames(2)
    screamer._think(Vector2(-660,-30),target,20,player)
    check(screamer.scream_time==0,"Cover prevents a screamer from triggering through a wall")
    wall.queue_free();await frames(2)
    screamer._think(Vector2(-660,-30),target,20,player)
    check(screamer.scream_time>0 and screamer.scream_cooldown>0,"Screamer starts a telegraphed action with a cooldown")
    screamer.die()
    check(screamer.scream_time==0 and not screamer.scream_ring.visible,"Killing a screamer cancels its pending alert")
    for zombie in s.enemies.pool:zombie.deactivate()
    var station: Node3D=s.stations[0]
    var workshop_position: Vector3=station.to_global(Vector3(3.8,0,6.8))
    player.teleport_to(Vector2(workshop_position.x,workshop_position.z),0)
    var cart_position: Vector3=station.to_global(Vector3(8,0,0))
    cart.teleport_to(Vector2(cart_position.x,cart_position.z),0);await frames(20)
    check(s.nearest_action().get("kind","")=="upgrade","F selects the nearby workshop through shared interaction handling")
    s.dinars=0;var level: int=upgrades.levels.bumper
    check(not upgrades.purchase("bumper",station) and upgrades.levels.bumper==level,"Unaffordable upgrades never charge or change the cart")
    s.dinars=50000;cart.health=500
    var max_speed: float=cart.settings.max_speed;var drift_traction: float=cart.settings.drift_traction
    money=s.dinars
    check(upgrades.purchase("armor",station) and s.dinars==money-1500,"Armor purchase charges its exact next-level price")
    check(is_equal_approx(cart.max_health,1350) and is_equal_approx(cart.health/cart.max_health,.5),"Armor adds durability while preserving the existing damage percentage")
    hp=cart.health;cart.receive_damage(100)
    check(is_equal_approx(cart.health,hp-90),"Cart armor reduces actual incoming damage")
    check(upgrades.purchase("bumper",station) and upgrades.ram_damage>1 and upgrades.ram_wear<1,"Bumper upgrades increase roadkill damage and reduce wear")
    var grip: float=cart.settings.road_traction
    check(upgrades.purchase("handling",station) and cart.settings.road_traction>grip and cart.settings.rollover_lateral_acceleration>38,"Handling improves grip, brakes and rollover stability")
    check(cart.settings.max_speed==max_speed and cart.settings.drift_traction==drift_traction,"Upgrades retain 200 km/h maximum speed and handbrake drift")
    check(cart.visual.has_node("UpgradeParts") and cart.visual.get_node("UpgradeParts").get_child_count()>3,"Purchased upgrades appear on the imported cart")
    shop.open(s,station)
    check(shop.visible and player.movement_locked and not player.weapons.enabled and not paused,"Workshop prevents movement and firing while combat remains active")
    await screenshot("cart-workshop.png")
    check(shop.visible,"Workshop remains open after rendering while the cart is parked")
    money=s.dinars;shop.rows.armor.button.pressed.emit()
    check(upgrades.levels.armor==2 and s.dinars==money-2500 and upgrades.levels.handling==1,"Actual workshop button buys the selected category at its next-level price")
    s.damage_player(1)
    check(not shop.visible and not player.movement_locked and player.weapons.enabled,"Taking damage immediately closes shopping and restores controls")
    upgrades.grant("bumper");upgrades.grant("bumper");money=s.dinars
    check(not upgrades.purchase("bumper",station) and s.dinars==money and upgrades.levels.bumper==3,"Maxed upgrades cannot be purchased again")
    cart.health=0;hp=cart.health
    check(not upgrades.purchase("armor",station),"Destroyed carts must be repaired before buying upgrades")
    upgrades.grant("armor")
    check(cart.health==hp,"Free upgrade rewards do not resurrect a destroyed cart")
    cart.health=cart.max_health
    var wave_kills: int=s.wave.killed
    check(missions.start_mission(0),"A supply mission creates a marked world crate")
    var saved: Dictionary=missions.blocked_cells.duplicate()
    check(not saved.is_empty() and is_instance_valid(missions.beacon),"Active crates have collision and reserve nearby navigation cells")
    var mission_point: Vector2=missions.position_2d
    player.teleport_to(mission_point+Vector2(4,0),0)
    missions.tick(10)
    check(is_equal_approx(missions.progress,10),"Being inside the clear zone on foot accumulates hold time")
    var guard:=enemy("walker",mission_point+Vector2(2,0))
    missions.tick(2)
    check(is_equal_approx(missions.progress,10) and missions.status.begins_with("CLEAR"),"Zombies near the crate contest the mission without losing secured progress")
    guard.deactivate()
    player.teleport_to(mission_point+Vector2(30,0),0);missions.tick(3)
    check(is_equal_approx(missions.progress,4),"Leaving the objective gradually loses progress")
    cart.teleport_to(mission_point+Vector2(4,0),0);game.enter_vehicle(cart.get_node("VehicleAccess"),true)
    missions.tick(2)
    check(is_equal_approx(missions.progress,4) and missions.status.begins_with("EXIT"),"A vehicle cannot complete the on-foot supply hold")
    check(game.exit_vehicle(true),"Player can exit at an active supply cache")
    player.teleport_to(mission_point+Vector2(4,0),0)
    var timer: float=missions.remaining
    paused=true;missions.tick(10)
    check(missions.remaining==timer and missions.progress==4,"Pause freezes supply travel and capture timers")
    paused=false;missions.settings.upgrade_chance=0;s.rewards.double_dinars=20
    player.weapons.rounds[1]=0;player.weapons.reserve[1]=0
    money=s.dinars;var score: int=s.score
    missions.tick(26)
    check(not missions.active and missions.completed==1 and s.dinars==money+3000 and s.score==score+500,"Successful hold gives one reward and respects Double Dinars")
    check(player.weapons.rounds[1]==12 and player.weapons.reserve[1]==96,"Supply ammo rewards refill owned weapons")
    check(s.wave.killed==wave_kills,"Supply objectives do not alter wave kill accounting")
    var restored:=true
    for index: Vector2i in saved:restored=restored and s.enemies.navigation.grid.is_point_solid(index)==saved[index]
    check(restored and missions.beacon==null,"Mission cleanup removes collision and restores previous navigation state")
    money=s.dinars;missions.finish(true)
    check(s.dinars==money,"Completed supply missions cannot reward twice")
    check(missions.start_mission(1),"A later cache can use a different landmark")
    missions.remaining=.01;missions.tick(1)
    check(not missions.active and s.dinars==money and missions.cooldown>0,"Expired caches clean up without charging or granting rewards")
    missions.cooldown=.01;s.enemies.navigation.requests_this_frame=0;player.teleport_to(Vector2(-690,-35),0)
    missions.tick(.02)
    check(missions.active and player.position.distance_to(missions.beacon.position)>120,"Automatic objectives choose a reachable location away from the player")
    await screenshot("supply-mission-hud.png")
    player.teleport_to(missions.position_2d+Vector2(4,0),0);missions.progress=29;missions.settings.upgrade_chance=1
    var levels_before: int=int(upgrades.levels.bumper)+int(upgrades.levels.armor)+int(upgrades.levels.handling)
    missions.tick(1)
    check(not missions.active and int(upgrades.levels.bumper)+int(upgrades.levels.armor)+int(upgrades.levels.handling)==levels_before+1,"Supply bonus can grant one free upgrade to an available category")
    for kind: String in upgrades.levels:
        while int(upgrades.levels[kind])<3:upgrades.grant(kind)
    missions.start_mission(2);player.teleport_to(missions.position_2d+Vector2(4,0),0);missions.progress=29
    player.weapons.rounds[1]=0;missions.tick(1)
    check(not missions.active and player.weapons.rounds[1]==12 and upgrades.levels=={"bumper":3,"armor":3,"handling":3},"Fully upgraded carts receive ammunition instead of wasting a supply bonus")
    var music_id: int=GameUI.audio_manager().music.get_instance_id()
    shop.close();paused=false;reload_current_scene();await scene_changed;await frames(4);game=current_scene;s=game.survival
    check(s.upgrades.levels=={"bumper":0,"armor":0,"handling":0} and s.missions.completed==0 and not s.missions.active,"Restart clears all upgrades and unfinished mission state")
    check(GameUI.audio_manager().music.get_instance_id()==music_id,"Run restart preserves the continuous music player")
    GameUI.audio_manager().stop_all();game.queue_free();await frames(5)
    print("EXPANSION VALIDATION: ",checks," checks; ",failures.size()," failures")
    quit(0 if failures.is_empty() else 1)
