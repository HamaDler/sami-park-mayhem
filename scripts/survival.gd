extends Node3D
signal zombie_killed(id: int, cause: String, headshot: bool)
signal player_damaged(amount: float)
signal run_ended
# kind: "body", "head", "kill", "headkill"; points/label feed the floating score popups.
signal hit_feedback(kind: String, points: int, label: String)
# World position the last hit came from; the HUD draws a directional indicator toward it.
signal player_hit_from(source: Vector3)
var game: Node3D
var config: Dictionary
var health: float=100
var score: int=0
var kills: int=0
var dinars: int=500
var completed_wave: int=0
var over: bool=false
var since_damage: float=100
var damage_flash: float=0
var hit_flash: float=0
var last_hit_headshot: bool=false
var records: RefCounted
var stations: Array[Node3D]=[]
var action: Dictionary={}
var action_progress: float=0
var recovery_time: float=0
var cart_damage_time: float=0
var previous_cart_position:=Vector3.ZERO
var ram_hits: Dictionary={}
@onready var wave: Node=$Waves
@onready var enemies: Node3D=$Enemies
@onready var rewards: Node3D=$Rewards
@onready var upgrades: Node=$Upgrades
@onready var missions: Node3D=$Missions
func initialize(parent_game: Node3D) -> void:
    game=parent_game
    config=JSON.parse_string(FileAccess.get_file_as_string("res://data/survival_settings.json"))
    health=float(config.player.max_health);dinars=int(config.economy.starting_dinars)
    records=load("res://scripts/survival_records.gd").new();records.load_records()
    wave.initialize(config.waves);wave.started.connect(_wave_started);wave.completed.connect(_wave_completed)
    enemies.initialize(self);rewards.initialize(self)
    game.player.weapons.start_survival(config.weapons)
    game.player.weapons.fired.connect(func(_slot: int,_hit: Dictionary):enemies.hear_shot(game.player.global_position))
    var cart: CharacterBody3D=game.get_node("GolfCart")
    cart.max_health=float(config.cart.max_health);cart.health=cart.max_health;cart.survival=self
    cart.destroyed.connect(_cart_destroyed)
    cart.rollover_started.connect(func():cart.receive_damage(80))
    previous_cart_position=cart.global_position
    upgrades.initialize(self)
    _build_stations()
    enemies.navigation._static_obstacles($Stations)
    missions.initialize(self)
    announce("SURVIVE SAMI PARK  /  WAVE 1 IN %ds" % ceili(wave.preparation))
func _build_stations() -> void:
    var locations: Array=JSON.parse_string(FileAccess.get_file_as_string("res://data/survival_locations.json"))
    for entry: Dictionary in locations:
        var anchor:=Vector2(entry.anchor[0],entry.anchor[1])
        var placement:=_station_placement(anchor)
        if placement.is_empty():push_error("No safe station location: "+entry.name);continue
        var p: Vector2=placement.position
        var station: Node3D=load("res://scenes/mystery_station.tscn").instantiate();$Stations.add_child(station)
        station.global_position=Vector3(p.x,.1,p.y);station.rotation.y=float(placement.yaw);station.initialize(self,str(entry.name));stations.append(station)
func _station_placement(anchor: Vector2) -> Dictionary:
    var shape:=SphereShape3D.new();shape.radius=.8
    var query:=PhysicsShapeQueryParameters3D.new();query.shape=shape;query.collision_mask=3
    for radius in range(0,64,3):
        for angle in (1 if radius==0 else 16):
            var center:=anchor+Vector2.from_angle(angle*TAU/16)*radius
            if not enemies.navigation.valid_spawn(center) or game.park.path_distance(center)>14:continue
            for quarter in 4:
                var yaw: float=quarter*PI*.5;var basis:=Basis(Vector3.UP,yaw);var clear:=true
                for local: Vector3 in [Vector3.ZERO,Vector3(3.8,0,0),Vector3(0,0,4.8),Vector3(3.8,0,4.8)]:
                    var offset: Vector3=basis*local;var site:=center+Vector2(offset.x,offset.z)
                    var approach_offset: Vector3=basis*Vector3(0,0,-2)
                    var approach:=site+Vector2(approach_offset.x,approach_offset.z)
                    if not enemies.navigation.valid_spawn(site) or enemies.navigation.tree_blocked(site,1.8) or not enemies.navigation.valid_spawn(approach):clear=false;break
                    query.transform=Transform3D(Basis.IDENTITY,Vector3(site.x,.95,site.y))
                    if not get_world_3d().direct_space_state.intersect_shape(query,1).is_empty():clear=false;break
                if clear:return {"position":center,"yaw":yaw}
    return {}
func _physics_process(delta: float) -> void:
    if not game or over:return
    wave.tick(delta)
    missions.tick(delta)
    since_damage+=delta;damage_flash=maxf(0,damage_flash-delta);hit_flash=maxf(0,hit_flash-delta)
    if since_damage>=float(config.player.regeneration_delay):health=minf(float(config.player.max_health),health+float(config.player.regeneration_per_second)*delta)
    cart_damage_time=maxf(0,cart_damage_time-delta)
    _cart_impacts(delta);_timed_action(delta);_recovery(delta)
func _wave_started(number: int) -> void:_banner("WAVE %d" % number,"%d ZOMBIES INCOMING" % wave.total,GameUI.RED)
func _wave_completed(number: int) -> void:
    completed_wave=number;records.save_records(score,completed_wave)
    _banner("WAVE %d CLEARED" % number,"%dS TO PREPARE" % ceili(wave.preparation),GameUI.LIME)
func _banner(title: String, subtitle: String, color: Color) -> void:
    if game.hud.survival_overlay and game.hud.survival_overlay.has_method("show_banner"):game.hud.survival_overlay.show_banner(title,subtitle,color)
    else:announce(title+"  /  "+subtitle)
func effects() -> Node3D:return game.player.weapons.effects
# direction: travel direction of the hit (bullet, kick or cart). force: knockback in m/s.
func damage_zombie(zombie: CharacterBody3D, amount: float, headshot: bool, cause: String, point: Vector3, direction:=Vector3.ZERO, force: float=-1, stagger: float=0) -> void:
    if over or not zombie.alive or amount<=0:return
    if direction.length_squared()<.0001:
        var source: Vector3=game.get_active_actor().global_position
        direction=(zombie.global_position-source);direction.y=0
        if direction.length_squared()<.0001:direction=Vector3.FORWARD
    direction=direction.normalized()
    var applied:=amount*(float(config.weapons.headshot_multiplier) if headshot else 1.0)
    var type: Dictionary=enemies.types.get(zombie.archetype,{})
    if cause=="gun" and not headshot:applied*=float(type.get("body_multiplier",1.0))
    elif cause=="ram":applied*=float(type.get("ram_multiplier",1.0))
    zombie.health-=applied;zombie.alerted=true
    if cause=="gun":hit_flash=.16;last_hit_headshot=headshot
    var killed: bool=zombie.health<=0
    if is_instance_valid(effects()) and cause!="ram":effects().blood_burst(point,direction,headshot or killed)
    if force<0:force={"gun":2.2 if applied<60 else 4.5,"melee":5.0,"ram":9.0}.get(cause,2.0)
    if not killed:
        zombie.apply_hit(direction,force,headshot or applied>=60 or cause=="melee",stagger)
        if cause!="ram":hit_feedback.emit("head" if headshot else "body",0,"")
        return
    # This is the only death/reward path. die() clears alive before any signals.
    zombie.die();zombie.apply_hit(direction,force*1.4,true);kills+=1;wave.register_kill();records.lifetime_kills+=1
    if is_instance_valid(effects()):effects().blood_splat(zombie.global_position,1.4 if headshot else 1.0)
    var economy: Dictionary=config.economy
    var key: String="roadkill" if cause=="ram" else ("headshot" if headshot else "kill")
    var multiplier: int=2 if rewards.double_dinars>0 else 1
    score+=int(economy[key+"_score"])
    dinars+=int(economy[key+"_dinars"])*multiplier
    hit_feedback.emit("headkill" if headshot else "kill",int(economy[key+"_score"]),{"roadkill":"ROADKILL","headshot":"HEADSHOT"}.get(key,"MELEE" if cause=="melee" else ""))
    rewards.maybe_drop(point);zombie_killed.emit(zombie.id,cause,headshot)
    if kills%10==0:records.save_records(score,completed_wave)
func damage_target(amount: float, source:=Vector3.INF) -> void:
    if game.is_driving():game.active_vehicle.vehicle.receive_damage(amount)
    else:damage_player(amount,source)
func damage_player(amount: float, source:=Vector3.INF) -> void:
    if over or amount<=0:return
    # A well-timed dodge roll avoids the strike entirely.
    if not game.is_driving() and game.player.has_method("is_invulnerable") and game.player.is_invulnerable():return
    health=maxf(0,health-amount);since_damage=0;damage_flash=.35
    if source!=Vector3.INF:player_hit_from.emit(source)
    if health>0 and game.player.has_method("on_damaged"):game.player.on_damaged(amount)
    if game.hud.survival_overlay:game.hud.survival_overlay.workshop.close()
    action.clear();action_progress=0;recovery_time=0;player_damaged.emit(amount)
    if health<=0:end_run()
func end_run() -> void:
    if over:return
    over=true;action.clear();records.save_records(score,completed_wave)
    game.player.weapons.set_enabled(false);game.player.velocity=Vector3.ZERO
    run_ended.emit()
    # Death beat: the character falls in slow motion before the summary appears.
    var slowmo: float=float(config.player.get("death_slowmo_seconds",0))
    if slowmo>0 and not game.is_driving():
        if game.player.has_method("play_death"):game.player.play_death()
        game.camera_rig.add_trauma(.5)
        Engine.time_scale=float(config.player.get("death_time_scale",.3))
        await get_tree().create_timer(slowmo,true,false,true).timeout
        Engine.time_scale=1.0
        if not is_inside_tree():return
    game.hud.show_game_over();get_tree().paused=true;Input.mouse_mode=Input.MOUSE_MODE_VISIBLE
func spend(amount: int) -> bool:
    if dinars<amount:GameUI.play_ui("ui_error");announce("NOT ENOUGH DINARS");return false
    dinars-=amount;GameUI.play_ui("purchase");return true
func weapon_title(slot: int, tier: int) -> String:
    return ["PISTOL","RIFLE","SNIPER"][slot-1]+" / "+["STANDARD","IMPROVED","RARE","LEGENDARY"][tier]
func roll_weapon() -> Dictionary:
    var weights: Array=config.weapons.base_tier_weights.duplicate()
    var advancement:=minf(35,(maxi(1,wave.number)-1)*2)
    weights[0]=maxf(10,float(weights[0])-advancement)
    weights[2]=float(weights[2])+advancement*.65;weights[3]=float(weights[3])+advancement*.35
    var total: float=0
    for value in weights:total+=float(value)
    var roll: float=enemies.random.randf()*total;var tier: int=0
    for i in weights.size():
        roll-=float(weights[i])
        if roll<=0:tier=i;break
    return {"slot":enemies.random.randi_range(1,3),"tier":tier}
func nearest_action() -> Dictionary:
    if over or game.is_driving():return {}
    var point: Vector3=game.player.global_position;var nearest: float=3.0;var result: Dictionary={}
    for station in stations:
        for candidate: Dictionary in station.actions:
            var interaction_point: Vector3=station.to_global(candidate.position)
            var distance:=point.distance_to(interaction_point)
            if distance<nearest and enemies.line_of_sight(point+Vector3.UP,interaction_point+Vector3.UP*1.6):
                nearest=distance;result=candidate
    return result
func use_action(candidate: Dictionary) -> void:
    if not candidate.is_empty():candidate.station.use(str(candidate.kind))
func begin_repair(station: Node3D) -> void:
    var cart: CharacterBody3D=game.get_node("GolfCart")
    if cart.health>=cart.max_health:announce("CART ALREADY REPAIRED");return
    if cart.health>0 and cart.global_position.distance_to(station.global_position)>12:announce("BRING THE CART WITHIN 12 METRES");return
    if dinars<int(config.economy.repair_price):announce("NOT ENOUGH DINARS");return
    action={"kind":"repair","station":station,"start":game.player.global_position};action_progress=0
    announce("REPAIRING — STAY STILL FOR %ds" % ceili(config.economy.repair_seconds))
func _timed_action(delta: float) -> void:
    if action.is_empty():return
    var cart: CharacterBody3D=game.get_node("GolfCart")
    if game.is_driving() or game.player.global_position.distance_to(action.start)>.4 or (cart.health>0 and cart.global_position.distance_to(action.station.global_position)>12):
        action.clear();action_progress=0;announce("REPAIR CANCELLED");return
    action_progress+=delta
    if action_progress>=float(config.economy.repair_seconds):
        if spend(int(config.economy.repair_price)):cart.health=cart.max_health;announce("CART REPAIRED")
        action.clear();action_progress=0
func can_recover() -> bool:
    var cart: CharacterBody3D=game.get_node("GolfCart")
    return not game.is_driving() and cart.rolling and game.player.global_position.distance_to(cart.global_position)<5
func _recovery(delta: float) -> void:
    if not can_recover() or not Input.is_action_pressed("recover") or game.player.velocity.length()>.5:recovery_time=0;return
    var cart: CharacterBody3D=game.get_node("GolfCart")
    if cart.velocity.length()>.8:recovery_time=0;return
    if is_instance_valid(cart.rollover_body) and (cart.rollover_body.linear_velocity.length()>.8 or cart.rollover_body.angular_velocity.length()>.8):recovery_time=0;return
    recovery_time+=delta
    if recovery_time>=float(config.economy.recovery_seconds):
        game.get_node("GolfCart").right_in_place();recovery_time=0;announce("CART UPRIGHT")
func _cart_impacts(delta: float) -> void:
    var cart: CharacterBody3D=game.get_node("GolfCart")
    var before:=previous_cart_position;previous_cart_position=cart.global_position
    if not game.is_driving() or cart.health<=0:return
    var travelled:=cart.global_position.distance_to(before)
    var speed:=maxf(absf(cart.speed),travelled/maxf(delta,.001))
    # Ignore teleports/environmental recovery; sweep fast travel to avoid tunnelling past enemies.
    if travelled>12:return
    if cart.impact_speed>4 and cart_damage_time==0:
        cart.receive_damage(cart.impact_speed*float(config.cart.crash_damage_per_metre_second));cart_damage_time=.8
    if speed<float(config.cart.ram_min_speed):return
    for zombie in enemies.pool:
        if cart.health<=0:break
        if not zombie.alive:continue
        var closest:=Geometry3D.get_closest_point_to_segment(zombie.global_position+Vector3.UP*.7,before+Vector3.UP*.7,cart.global_position+Vector3.UP*.7)
        if closest.distance_to(zombie.global_position+Vector3.UP*.7)>1.25:continue
        var now:=Time.get_ticks_msec()
        if now-int(ram_hits.get(zombie.id,-2000))<1000:continue
        ram_hits[zombie.id]=now
        damage_zombie(zombie,speed*float(config.cart.ram_damage_per_metre_second)*upgrades.ram_damage,false,"ram",zombie.global_position,cart.global_position-before,minf(speed*.6,12))
        cart.receive_damage(float(config.cart.ram_wear)*upgrades.ram_wear)
func _cart_destroyed() -> void:
    announce("CART DISABLED — FIND A REPAIR STATION")
    if game.is_driving():game.exit_vehicle(true)
func safe_point(point: Vector2, actor: CharacterBody3D) -> Vector2:
    var index: Vector2i=enemies.navigation.nearest(point,35)
    if index.x<0:return Vector2(actor.safe_transform.origin.x,actor.safe_transform.origin.z)
    var p: Vector2=enemies.navigation.point(index)
    var result: Dictionary=game.park.resolve_map_spawn(p,actor.rotation.y,actor.get_rid(),actor.is_in_group("walk_player"))
    return result.position if result.valid else p
func announce(text: String) -> void:game.hud.show_toast(text)
func _exit_tree() -> void:
    Engine.time_scale=1.0
    if is_instance_valid(records):records.save_records(score,completed_wave)
