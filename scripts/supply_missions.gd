extends Node3D
var survival: Node3D
var settings: Dictionary
var sites: Array[Dictionary]=[]
var cooldown: float=0
var active: bool=false
var remaining: float=0
var progress: float=0
var completed: int=0
var location_name: String=""
var site_index: int=-1
var position_2d:=Vector2.ZERO
var beacon: Node3D
var ring: MeshInstance3D
var status: String=""
var attract_time: float=0
var blocked_cells: Dictionary={}
func initialize(session: Node3D) -> void:
    survival=session;settings=JSON.parse_string(FileAccess.get_file_as_string("res://data/supply_missions.json"))
    cooldown=float(settings.initial_delay)
    for location: Dictionary in settings.locations:
        var anchor:=Vector2(location.anchor[0],location.anchor[1])
        var found:=_valid_site(anchor)
        if found!=Vector2.INF:sites.append({"name":str(location.name),"point":found})
func _valid_site(anchor: Vector2) -> Vector2:
    var nav: Node=survival.enemies.navigation
    var shape:=BoxShape3D.new();shape.size=Vector3(3.2,2.2,3.2)
    var query:=PhysicsShapeQueryParameters3D.new();query.shape=shape;query.collision_mask=3
    for radius in range(3,55,3):
        for angle in 16:
            var point:=anchor+Vector2.from_angle(angle*TAU/16)*radius
            if not nav.valid_spawn(point) or nav.tree_blocked(point,2.2) or survival.game.park.path_distance(point)>10:continue
            query.transform=Transform3D(Basis.IDENTITY,Vector3(point.x,1.2,point.y))
            if not get_world_3d().direct_space_state.intersect_shape(query,1).is_empty():continue
            return point
    return Vector2.INF
func start_mission(forced_index: int=-1) -> bool:
    if active or survival.over or sites.is_empty():return false
    var index:=forced_index
    if index<0:
        var actor: CharacterBody3D=survival.game.get_active_actor()
        var from:=Vector2(actor.global_position.x,actor.global_position.z)
        var candidates: Array[int]=[]
        for i in sites.size():
            var distance:=from.distance_to(sites[i].point)
            if i!=site_index and distance>=float(settings.minimum_distance) and distance<=float(settings.maximum_distance):candidates.append(i)
        if candidates.is_empty():cooldown=10;return false
        index=candidates[survival.enemies.random.randi_range(0,candidates.size()-1)]
        var route: PackedVector2Array=survival.enemies.navigation.route(from,sites[index].point)
        if route.is_empty() or route[-1].distance_to(sites[index].point)>8:cooldown=10;return false
    if index>=sites.size():return false
    site_index=index;location_name=sites[index].name;position_2d=sites[index].point
    active=true;remaining=float(settings.travel_seconds);progress=0;status="REACH THE SUPPLY CRATE";attract_time=0
    _build_beacon();survival.announce("SUPPLIES MARKED  /  "+location_name);GameUI.play_ui("wave_start")
    return true
func _build_beacon() -> void:
    beacon=Node3D.new();beacon.name="ActiveSupplyCrate";add_child(beacon);beacon.position=Vector3(position_2d.x,0,position_2d.y)
    var olive:=ParkGeometry.material(Color("3d5140"));var metal:=ParkGeometry.material(Color("c1d9dc"))
    ParkGeometry.box(beacon,Vector3(0,.47,0),Vector3(1.8,.94,1.2),olive,true)
    ParkGeometry.box(beacon,Vector3(0,.98,0),Vector3(1.88,.1,1.28),metal)
    for x in [-.6,.6]:ParkGeometry.box(beacon,Vector3(x,.5,-.61),Vector3(.12,.9,.04),metal)
    var light:=ParkGeometry.material(Color("64e2f0"));light.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED
    ring=MeshInstance3D.new();var torus:=TorusMesh.new();torus.inner_radius=float(settings.radius)-.12;torus.outer_radius=float(settings.radius)
    torus.rings=48;torus.ring_segments=4;ring.mesh=torus;ring.position.y=.13;ring.scale.y=.16;ring.material_override=light;beacon.add_child(ring)
    var pole:=ParkGeometry.box(beacon,Vector3(0,6,0),Vector3(.10,10,.1),light);pole.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
    var label:=Label3D.new();label.text="SUPPLY CACHE\nSECURE AREA ON FOOT";label.position.y=3;label.billboard=BaseMaterial3D.BILLBOARD_ENABLED;label.font=GameUI.bold();label.font_size=46;label.pixel_size=.012;beacon.add_child(label)
    # Preserve the previous grid state so removing a crate cannot clear a permanent obstacle.
    var nav: Node=survival.enemies.navigation
    var cell: Vector2i=nav.id(position_2d)
    for x in range(cell.x-1,cell.x+2):
        for z in range(cell.y-1,cell.y+2):
            var index:=Vector2i(x,z)
            if nav.grid.is_in_boundsv(index):blocked_cells[index]=nav.grid.is_point_solid(index)
    nav._static_obstacles(beacon)
func tick(delta: float) -> void:
    if survival.over or get_tree().paused:return
    if not active:
        cooldown=maxf(0,cooldown-delta)
        if cooldown==0:start_mission()
        return
    remaining=maxf(0,remaining-delta)
    if remaining==0:finish(false);return
    var actor: CharacterBody3D=survival.game.get_active_actor()
    var distance:=Vector2(actor.position.x,actor.position.z).distance_to(position_2d)
    var inside:=distance<=float(settings.radius)
    var contested:=false
    if inside:
        for zombie in survival.enemies.pool:
            if zombie.alive and Vector2(zombie.position.x,zombie.position.z).distance_to(position_2d)<float(settings.contest_radius):contested=true;break
    if not inside:status="REACH THE SUPPLY CRATE"
    elif survival.game.is_driving():status="EXIT VEHICLE TO SECURE"
    elif contested:status="CLEAR ZOMBIES FROM THE CRATE"
    else:status="SECURING SUPPLIES"
    if inside and not survival.game.is_driving() and not contested:
        progress+=delta
        if progress>=float(settings.hold_seconds):finish(true);return
    # Progress pauses while contested; leaving the area gradually loses progress.
    elif not inside:progress=maxf(0,progress-delta*2)
    attract_time-=delta
    if inside and attract_time<=0:attract_time=4;survival.enemies.hear_shot(beacon.global_position)
func finish(success: bool) -> void:
    if not active:return
    active=false;_clear_beacon();cooldown=float(settings.cooldown)
    if not success:survival.announce("SUPPLIES LOST  /  WATCH FOR THE NEXT CACHE");return
    completed+=1;survival.score+=int(settings.score)
    survival.dinars+=int(settings.dinars)*(2 if survival.rewards.double_dinars>0 else 1)
    var bonus: String=""
    if survival.enemies.random.randf()<float(settings.upgrade_chance):bonus=survival.upgrades.grant_random()
    if bonus.is_empty():survival.game.player.weapons.refill_all();bonus="MAX AMMO"
    survival.records.save_records(survival.score,survival.completed_wave)
    survival.announce("CACHE SECURED  /  +%d IQD  /  %s" % [int(settings.dinars)*(2 if survival.rewards.double_dinars>0 else 1),bonus]);GameUI.play_ui("pickup")
func _clear_beacon() -> void:
    if is_instance_valid(beacon):remove_child(beacon);beacon.queue_free()
    beacon=null;ring=null
    var nav: Node=survival.enemies.navigation
    for index: Vector2i in blocked_cells:nav.grid.set_point_solid(index,bool(blocked_cells[index]))
    blocked_cells.clear()
