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
func initialize(session: Node) -> void:
    survival=session;settings=survival.config.zombies;random.randomize()
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
    while corpses.size()>int(settings.max_corpses):corpses.pop_front().deactivate()
func spawn_one() -> CharacterBody3D:
    if not survival.wave.can_spawn(living().size()):return null
    var candidate:=spawn_position()
    if candidate==Vector2.INF:return null
    var zombie: CharacterBody3D=null
    for item in pool:
        if not item.alive and not item.visible:zombie=item;break
    if zombie==null:
        zombie=load("res://scenes/zombie.tscn").instantiate();add_child(zombie)
        var variant: int=pool.size()%models.size();zombie.build(self,models[variant],variant);pool.append(zombie)
    zombie.activate(candidate,next_id,stats(maxi(1,survival.wave.number)))
    next_id+=1;survival.wave.register_spawn()
    return zombie
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
