extends Node3D
var survival: Node
var settings: Dictionary
var navigation: Node
var random:=RandomNumberGenerator.new()
var pool: Array[CharacterBody3D]=[]
var models: Array[PackedScene]=[]
var next_id: int=1
var spawn_clock: float=0
var positions: Dictionary={}
var refresh_clock: float=0
var types: Dictionary
var scream_notice: float=0
var groan_clock: float=1.5
var sound_times: Dictionary={}
func initialize(session: Node) -> void:
    survival=session;settings=survival.config.zombies;random.randomize()
    types=JSON.parse_string(FileAccess.get_file_as_string("res://data/zombie_types.json"))
    navigation=Node.new();navigation.set_script(load("res://scripts/zombie_navigation.gd"));navigation.name="ParkNavigation";add_child(navigation)
    navigation.initialize(survival.game.park)
    for path: String in survival.config.models:models.append(load(path))
func stats(wave: int) -> Dictionary:
    return {"health":float(settings.health)*pow(float(settings.health_growth),wave-1),"damage":minf(float(settings.damage_cap),float(settings.damage)+(wave-1)*float(settings.damage_increment)),"speed":minf(float(settings.speed_cap),float(settings.speed)+(wave-1)*float(settings.speed_increment))}
func living() -> Array[CharacterBody3D]:
    var result: Array[CharacterBody3D]=[]
    for zombie in pool:
        if zombie.alive:result.append(zombie)
    return result
func _physics_process(delta: float) -> void:
    if not survival or survival.over:return
    scream_notice=maxf(0,scream_notice-delta)
    _ambient_groans(delta)
    refresh_clock-=delta
    if refresh_clock<=0:
        refresh_clock=.15;positions.clear()
        for zombie in pool:
            if not zombie.alive:continue
            var p:=Vector2(zombie.global_position.x,zombie.global_position.z)
            var key:=Vector2i(floori(p.x/4),floori(p.y/4))
            if not positions.has(key):positions[key]=[]
            positions[key].append(zombie)
    spawn_clock-=delta
    if spawn_clock>0:return
    spawn_clock=float(survival.config.waves.spawn_interval)
    var alive:=living()
    if survival.wave.can_spawn(alive.size()):spawn_one()
    var corpses: Array=[]
    for zombie in pool:
        if not zombie.alive and zombie.visible:corpses.append(zombie)
    while corpses.size()>int(settings.max_corpses):corpses.pop_front().start_sink()
func spawn_one() -> CharacterBody3D:
    if not survival.wave.can_spawn(living().size()):return null
    var candidate:=spawn_position()
    if candidate==Vector2.INF:return null
    var kind:=roll_type(maxi(1,survival.wave.number))
    var model_index: int=types[kind].model
    var zombie: CharacterBody3D=null
    for item in pool:
        if not item.alive and not item.visible and item.model_index==model_index:zombie=item;break
    if zombie==null:
        zombie=load("res://scenes/zombie.tscn").instantiate();add_child(zombie)
        zombie.build(self,models[model_index],model_index);pool.append(zombie)
    zombie.activate(candidate,next_id,type_stats(maxi(1,survival.wave.number),kind))
    # Fast pacing: early waves come straight at the player; later waves mix in wanderers.
    var waves: Dictionary=survival.config.waves
    if survival.wave.number<=int(waves.get("always_alerted_waves",0)) or random.randf()<float(waves.get("late_alerted_chance",0)):zombie.alerted=true
    next_id+=1;survival.wave.register_spawn()
    return zombie
func roll_type(number: int) -> String:
    var weights: Dictionary={};var total: float=0
    for kind: String in types:
        var weight:=maxf(8 if kind=="walker" else 1,float(types[kind].weight)+mini(number-1,25)*float(types[kind].wave_weight))
        weights[kind]=weight;total+=weight
    var roll:=random.randf()*total
    for kind: String in weights:
        roll-=float(weights[kind])
        if roll<=0:return kind
    return "walker"
func type_stats(number: int, kind: String) -> Dictionary:
    var result:=stats(number);var definition: Dictionary=types[kind]
    result.health*=float(definition.health)
    result.damage=minf(60,float(result.damage)*float(definition.damage))
    result.speed=minf(7.5,float(result.speed)*float(definition.speed))
    result.kind=kind
    return result
func scream(source: CharacterBody3D) -> void:
    if survival.over or not source.alive or source.archetype!="screamer":return
    var radius: float=types.screamer.scream_radius
    for zombie in pool:
        if zombie.alive and zombie.global_position.distance_to(source.global_position)<radius:zombie.alerted=true
    if scream_notice<=0:
        scream_notice=3
        survival.announce("SCREAMER ALERTED THE HORDE")
        GameUI.play_ui("wave_start")
func spawn_position() -> Vector2:
    var actor: CharacterBody3D=survival.game.get_active_actor()
    var center:=Vector2(actor.global_position.x,actor.global_position.z)
    var driving: bool=survival.game.is_driving()
    var minimum: float=settings.spawn_min_cart if driving else settings.spawn_min_foot
    var maximum: float=settings.spawn_max_cart if driving else settings.spawn_max_foot
    for attempt in 36:
        var p:=center+Vector2.from_angle(random.randf()*TAU)*random.randf_range(minimum,maximum)
        if not navigation.valid_spawn(p):continue
        if seen(Vector3(p.x,1.0,p.y)):continue
        var crowded:=false
        for zombie in pool:
            if zombie.alive and Vector2(zombie.global_position.x,zombie.global_position.z).distance_squared_to(p)<9: crowded=true;break
        if crowded:continue
        var shape:=SphereShape3D.new();shape.radius=.55
        var query:=PhysicsShapeQueryParameters3D.new();query.shape=shape;query.collision_mask=1;query.transform=Transform3D(Basis.IDENTITY,Vector3(p.x,.85,p.y))
        if not get_world_3d().direct_space_state.intersect_shape(query,1).is_empty():continue
        # Check connectivity to the actor rather than marooning enemies behind a lake/fence.
        var path: PackedVector2Array=navigation.route(p,center)
        if path.is_empty() or path[-1].distance_to(center)>18:continue
        return p
    return Vector2.INF
func seen(point: Vector3) -> bool:
    var camera: Camera3D=survival.game.camera_rig.camera
    if camera.is_position_behind(point):return false
    var screen:=camera.unproject_position(point)
    if not get_viewport().get_visible_rect().grow(70).has_point(screen):return false
    return line_of_sight(camera.global_position,point)
func line_of_sight(from: Vector3, to: Vector3) -> bool:
    var query:=PhysicsRayQueryParameters3D.create(from,to,1)
    return get_world_3d().direct_space_state.intersect_ray(query).is_empty()
func relocate(zombie: CharacterBody3D) -> void:
    if not zombie.alive or seen(zombie.global_position+Vector3.UP):return
    var p:=spawn_position()
    if p==Vector2.INF:return
    zombie.global_position=Vector3(p.x,.06,p.y);zombie.velocity=Vector3.ZERO
    zombie.route.clear();zombie.route_index=0;zombie.stuck_time=0;zombie.last_position=p;zombie.route_time=0
    zombie.reset_physics_interpolation()
func hear_shot(origin: Vector3) -> void:
    for zombie in pool:
        if zombie.alive and zombie.global_position.distance_to(origin)<float(settings.hearing_distance):zombie.alerted=true
func separation(zombie: CharacterBody3D, point: Vector2) -> Vector2:
    var cell:=Vector2i(floori(point.x/4),floori(point.y/4));var result:=Vector2.ZERO
    for x in range(cell.x-1,cell.x+2):
        for z in range(cell.y-1,cell.y+2):
            for other: CharacterBody3D in positions.get(Vector2i(x,z),[]):
                if other==zombie or not other.alive:continue
                var difference:=point-Vector2(other.global_position.x,other.global_position.z)
                var d:=difference.length()
                if d>0.01 and d<1.1:result+=difference/d*(1.1-d)
    return result.limit_length(1.0)
func play_sound(zombie: CharacterBody3D, event: String, extra_db: float=0, throttle: float=0) -> void:
    if throttle>0:
        var now: float=Time.get_ticks_msec()/1000.0
        if now-float(sound_times.get(event,-10.0))<throttle:return
        sound_times[event]=now
    var audio: Node=GameUI.audio_manager()
    if audio and audio.has_method("play_at"):audio.play_at(event,zombie.global_position+Vector3.UP*1.5,extra_db)
# Every 1.5–3 s one of the closest living zombies groans, so the horde is audible before it is visible.
func _ambient_groans(delta: float) -> void:
    groan_clock-=delta
    if groan_clock>0:return
    groan_clock=random.randf_range(1.5,3.0)
    var listener: Vector3=survival.game.get_active_actor().global_position
    var candidates: Array[CharacterBody3D]=[]
    for zombie in pool:
        if zombie.alive and zombie.global_position.distance_to(listener)<45:candidates.append(zombie)
    if candidates.is_empty():return
    candidates.sort_custom(func(a: CharacterBody3D,b: CharacterBody3D):return a.global_position.distance_squared_to(listener)<b.global_position.distance_squared_to(listener))
    var pick: CharacterBody3D=candidates[random.randi_range(0,mini(3,candidates.size()-1))]
    play_sound(pick,"zombie_groan_%d" % random.randi_range(0,4),0.0 if pick.alerted else -5.0)
# Cone check in front of the player; returns the number of zombies struck.
func apply_melee(origin: Vector3, forward: Vector3, reach: float, angle_degrees: float, amount: float, force: float, stagger: float) -> int:
    var count: int=0
    var cos_limit: float=cos(deg_to_rad(angle_degrees*.5))
    for zombie in pool:
        if not zombie.alive:continue
        var offset: Vector3=zombie.global_position-origin;offset.y=0
        var distance: float=offset.length()
        if distance>reach+.35:continue
        if distance>.3 and offset.normalized().dot(forward)<cos_limit:continue
        if not line_of_sight(origin+Vector3.UP,zombie.global_position+Vector3.UP):continue
        survival.damage_zombie(zombie,amount,false,"melee",zombie.global_position+Vector3.UP*1.1,forward,force,stagger)
        count+=1
    return count
