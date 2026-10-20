extends SceneTree
# Checks the combat-feel mechanics: pacing, stamina/sprint, dodge-roll i-frames, melee cone,
# aim spread, hit feedback and sinking corpses.
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
    check(survival.wave.total==24 and survival.wave.active_limit==12,"Wave 1 starts small: 24 zombies, 12 at once")
    var player: CharacterBody3D=game.player
    var fixture: Dictionary=find_corridor()
    check(not fixture.is_empty(),"Find a clear corridor on mapped paths")
    if fixture.is_empty():finish();return
    var p: Vector2=fixture.position;var forward: Vector2=fixture.forward
    var yaw:=atan2(-forward.x,-forward.y)
    player.teleport_to(p,yaw);game.camera_rig.foot_yaw=yaw;game.camera_rig.snap()
    await frames(5)
    # Every locomotion state keeps one looping clip playing (regression: alternating clips froze the pose).
    var avatar: Node3D=player.avatar
    avatar.set_process(false)
    var cases: Array=[["walk forward",Vector2(0,-1),4.5,false],["sprint",Vector2(0,-1),8.0,true],["walk left",Vector2(-1,0),4.5,false],["sprint right",Vector2(1,0),8.0,true],["walk back",Vector2(0,1),4.5,false]]
    for entry: Array in cases:
        avatar.move_input=entry[1];avatar.sprinting=entry[3];avatar.set_motion(entry[2],true,false,0)
        avatar._process(1.0/60)
        var clip: String=avatar.current_animation;var start: float=avatar.animations.current_animation_position
        for i in 20:avatar._process(1.0/60)
        check(avatar.current_animation==clip and avatar.animations.current_animation_position!=start,"%s animates (%s)" % [entry[0],clip.get_slice("|",1)])
    avatar.sprinting=false;avatar.move_input=Vector2.ZERO;avatar.set_process(true)
    # Sprint drains stamina and moves faster than walking, then regenerates after a delay.
    var full: float=float(player.settings.stamina.max)
    Input.action_press("sprint");Input.action_press("accelerate")
    await frames(70)
    var sprint_speed: float=Vector2(player.velocity.x,player.velocity.z).length()
    check(player.sprinting and player.stamina<full-10,"Sprinting drains stamina")
    check(sprint_speed>float(player.settings.walk_speed)+2,"Sprint is clearly faster than walking (%.1f m/s)" % sprint_speed)
    check(sprint_speed<=float(player.settings.run_speed)+.05,"Sprint stays within its configured speed")
    Input.action_release("sprint");Input.action_release("accelerate")
    var drained: float=player.stamina
    await frames(110)
    check(player.stamina>drained+10,"Stamina regenerates after the delay")
    player.stamina=0;player.exhausted=true
    Input.action_press("sprint");Input.action_press("accelerate");await frames(5)
    check(not player.sprinting,"Exhaustion locks sprint until stamina recovers")
    Input.action_release("sprint");Input.action_release("accelerate")
    player.stamina=full;player.exhausted=false
    player.teleport_to(p,yaw);await frames(10)
    # Dodge roll: invulnerable early, vulnerable after.
    survival.health=100
    check(player.start_roll(),"Roll starts from standing")
    check(player.stamina<full,"Roll costs stamina")
    survival.damage_player(20)
    check(survival.health==100,"Damage is ignored during roll i-frames")
    await frames(45)
    survival.damage_player(20)
    check(survival.health==80,"Damage applies again after the roll")
    survival.health=100
    player.teleport_to(p,yaw);game.camera_rig.foot_yaw=yaw;await frames(10)
    # Melee hits the zombie in front and misses the one behind.
    var front: CharacterBody3D=_zombie(p+forward*1.5,1)
    var behind: CharacterBody3D=_zombie(p-forward*1.6,2)
    await frames(3)
    player.rotation.y=yaw
    check(player.start_melee(),"Melee starts")
    await frames(20)
    check(front.health<1000,"Melee damages the zombie in front")
    check(behind.health==1000,"Melee misses the zombie behind the player")
    var away: Vector3=front.global_position-player.global_position
    await frames(6)
    check(front.global_position.distance_to(player.global_position)>away.length(),"Melee knocks the zombie back")
    # Aim spread is tighter than hip fire.
    var guns: Node3D=player.weapons;guns.set_physics_process(false)
    guns.bloom=0;guns.aiming=false;var hip: float=guns.spread_degrees()
    guns.aiming=true;var aim: float=guns.spread_degrees()
    check(aim<hip*.5,"Aiming tightens spread (hip %.2f / aim %.2f deg)" % [hip,aim])
    guns.aiming=false;guns.set_physics_process(true)
    # Hit feedback and blood on a kill; the corpse sinks and is recycled.
    var kinds: Array[String]=[]
    survival.hit_feedback.connect(func(kind: String,_points: int,_label: String):kinds.append(kind))
    survival.damage_zombie(front,10,false,"gun",front.global_position+Vector3.UP)
    survival.damage_zombie(front,100000,true,"gun",front.global_position+Vector3.UP*1.6)
    check(kinds==["body","headkill"],"Survival reports body hits and headshot kills to the HUD")
    check(not front.alive and front.visible,"Killed zombie leaves a corpse")
    front.corpse_time=.05;var base_y: float=front.model.position.y
    await frames(30)
    check(front.model.position.y<base_y-.05,"Corpse sinks into the ground")
    await frames(90)
    check(not front.visible,"Sunk corpse is recycled")
    behind.deactivate()
    finish()
func _zombie(point: Vector2, identifier: int) -> CharacterBody3D:
    var zombie: CharacterBody3D=load("res://scenes/zombie.tscn").instantiate();survival.enemies.add_child(zombie)
    zombie.build(survival.enemies,survival.enemies.models[0],0);survival.enemies.pool.append(zombie)
    zombie.activate(point,identifier,{"health":1000,"damage":25,"speed":1.8});survival.wave.register_spawn()
    zombie.spawn_cooldown=99;zombie.attack_cooldown=99
    return zombie
func find_corridor() -> Dictionary:
    for entry: Array in game.park.path_segments:
        var a: Vector2=entry[0];var b: Vector2=entry[1]
        if a.distance_to(b)<35 or float(entry[2])<2:continue
        var p:=a.lerp(b,.4);var forward: Vector2=(b-a).normalized()
        if p.distance_to(Vector2(117,-63))>250:continue
        if not survival.enemies.navigation.segment_clear(p-forward*10,p+forward*25):continue
        var query:=PhysicsRayQueryParameters3D.create(Vector3(p.x-forward.x*10,1,p.y-forward.y*10),Vector3(p.x+forward.x*25,1,p.y+forward.y*25),1)
        if not game.get_world_3d().direct_space_state.intersect_ray(query).is_empty():continue
        return {"position":p,"forward":forward}
    return {}
func finish() -> void:
    print("COMBAT FEEL: ",checks," checks; ",failures.size()," failures")
    game.queue_free();await process_frame;await process_frame
    quit(0 if failures.is_empty() else 1)
