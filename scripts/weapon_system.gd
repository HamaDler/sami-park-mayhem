extends Node3D
signal fired(slot: int, hit: Dictionary)
const CombatEffects=preload("res://scripts/combat_effects.gd")
const RAISE_SECONDS: float=.25
const BLOOM_RECOVERY: float=7.0
var player: CharacterBody3D
var camera_rig: Node3D
var definitions: Array
var selected_slot: int=1
var rounds: Dictionary={}
var enabled: bool=false
var aiming: bool=false
var cooldown: float=0
var reload_time: float=0
var suppress_until_release: bool=true
var shot_count: int=0
var tracer_pool: Array[MeshInstance3D]=[]
var impact_pool: Array[MeshInstance3D]=[]
var tracers: Array[float]=[]
var impacts: Array[float]=[]
var pool_index: int=0
var survival_enabled: bool=false
var infinite_ammo: bool=false
var unlocked: Dictionary={1:true,2:true,3:true}
var tiers: Dictionary={1:0,2:0,3:0}
var reserve: Dictionary={1:96,2:180,3:30}
var survival_settings: Dictionary={}
# Feel state: degrees of extra spread from sustained fire, weapon raise after switching,
# and the short sprint-to-fire delay.
var bloom: float=0
var raise_time: float=0
var ready_delay: float=0
var effects: Node3D
# Tests that measure exact hitbox placement disable the random cone.
var spread_enabled: bool=true
var random:=RandomNumberGenerator.new()
func _ready() -> void:
    definitions=JSON.parse_string(FileAccess.get_file_as_string("res://data/weapon_settings.json")).weapons
    for definition: Dictionary in definitions:rounds[int(definition.slot)]=int(definition.magazine)
    random.randomize()
    effects=CombatEffects.new();effects.name="CombatEffects";add_child(effects)
    _make_effects()
func initialize(person: CharacterBody3D, camera: Node3D) -> void:
    player=person;camera_rig=camera;player.avatar.set_weapon(selected_slot)
func current() -> Dictionary:
    var result: Dictionary=definitions[selected_slot-1].duplicate()
    if survival_enabled:result.damage=float(result.damage)*float(survival_settings.damage_tiers[int(tiers[selected_slot])])
    return result
func start_survival(config: Dictionary) -> void:
    survival_enabled=true;survival_settings=config;unlocked={1:true,2:false,3:false};tiers={1:0,2:0,3:0}
    rounds={1:int(definitions[0].magazine),2:0,3:0};reserve={1:int(config.reserve_ammo[0]),2:0,3:0};selected_slot=1
    player.avatar.set_weapon(1)
func grant_weapon(slot: int, tier: int) -> void:
    var new_weapon: bool=not unlocked[slot]
    unlocked[slot]=true;tiers[slot]=maxi(int(tiers[slot]),tier)
    rounds[slot]=int(definitions[slot-1].magazine);reserve[slot]=int(survival_settings.reserve_ammo[slot-1])
    if new_weapon:select_weapon(slot)
func refill_selected() -> void:
    rounds[selected_slot]=int(current().magazine);reserve[selected_slot]=int(survival_settings.reserve_ammo[selected_slot-1]);reload_time=0
func refill_all() -> void:
    for slot in range(1,4):
        if not unlocked[slot]:continue
        rounds[slot]=int(definitions[slot-1].magazine);reserve[slot]=int(survival_settings.reserve_ammo[slot-1])
    reload_time=0
func ammo_full() -> bool:
    return int(rounds[selected_slot])>=int(current().magazine) and int(reserve[selected_slot])>=int(survival_settings.reserve_ammo[selected_slot-1])
func set_enabled(value: bool) -> void:
    enabled=value;aiming=false;reload_time=0;cooldown=.2;suppress_until_release=true;bloom=0
    if camera_rig:camera_rig.aiming=false;camera_rig.sniper_scope=false
    if player:player.avatar.set_weapon(selected_slot);player.avatar.set_first_person_view(false)
func select_weapon(slot: int) -> void:
    if not enabled or slot<1 or slot>3 or not unlocked[slot]:return
    if slot!=selected_slot:GameUI.play_ui("weapon_equip");raise_time=RAISE_SECONDS
    selected_slot=slot;reload_time=0;cooldown=.2;suppress_until_release=true;bloom=0
    player.avatar.set_weapon(slot)
func reload() -> void:
    if infinite_ammo:return
    if survival_enabled and int(reserve[selected_slot])<=0:return
    if enabled and reload_time==0 and int(rounds[selected_slot])<int(current().magazine):
        reload_time=current().reload_seconds
        GameUI.play_ui(["reload_pistol","reload_rifle","reload_sniper"][selected_slot-1])
func reload_ratio() -> float:
    return 0.0 if reload_time<=0 else 1-reload_time/float(current().reload_seconds)
# Current cone half-angle in degrees: hip/aim base + movement + air + bloom.
func spread_degrees() -> float:
    var definition: Dictionary=definitions[selected_slot-1]
    var base: float=float(definition.get("aim_spread",0)) if aiming else float(definition.get("hip_spread",0))
    if player==null:return base+bloom
    var moving: float=clampf(Vector2(player.velocity.x,player.velocity.z).length()/maxf(float(player.settings.walk_speed),.1),0,1.5)
    var air: float=0.0 if player.is_on_floor() else 2.5
    return base+moving*(.35 if aiming else 1.1)+air+bloom*(.5 if aiming else 1.0)
func _unhandled_input(event: InputEvent) -> void:
    if not enabled or get_tree().paused or (event is InputEventKey and event.echo):return
    for slot in range(1,4):
        if event.is_action_pressed("weapon_"+str(slot)):select_weapon(slot);get_viewport().set_input_as_handled();return
    if event.is_action_pressed("recover"):
        var game: Node=player.get_parent()
        if game.get("survival") and game.survival.can_recover():return
        reload();get_viewport().set_input_as_handled()
func _physics_process(delta: float) -> void:
    _update_effects(delta)
    if not enabled or player==null:return
    var busy: bool=player.has_method("is_busy") and player.is_busy()
    cooldown=maxf(0,cooldown-delta);raise_time=maxf(0,raise_time-delta);ready_delay=maxf(0,ready_delay-delta)
    bloom=move_toward(bloom,0,BLOOM_RECOVERY*delta)
    aiming=Input.is_action_pressed("aim") and not busy
    camera_rig.aiming=aiming;camera_rig.sniper_scope=aiming and selected_slot==3
    player.avatar.set_first_person_view(camera_rig.sniper_scope or camera_rig.arm.spring_length<1.1)
    player.avatar.weapon_raise=raise_time/RAISE_SECONDS
    player.avatar.reload_progress=reload_ratio()
    if reload_time>0:
        # Rolling and melee pause the reload instead of cancelling it.
        if not busy:reload_time=maxf(0,reload_time-delta)
        if reload_time==0:
            var needed:=int(current().magazine)-int(rounds[selected_slot])
            var amount:=mini(needed,int(reserve[selected_slot])) if survival_enabled else needed
            rounds[selected_slot]=int(rounds[selected_slot])+amount
            if survival_enabled:reserve[selected_slot]=int(reserve[selected_slot])-amount
        return
    var down:=Input.is_action_pressed("fire")
    if suppress_until_release:
        if not down:suppress_until_release=false
        return
    if busy:return
    var wants_fire: bool=down if current().automatic else Input.is_action_just_pressed("fire")
    if wants_fire and player.get("sprinting"):
        # Firing breaks a sprint; the gun comes up after a short delay.
        player.break_sprint();ready_delay=maxf(ready_delay,float(player.settings.get("sprint_to_fire",.12)))
        return
    if ready_delay>0 or raise_time>0:return
    if wants_fire and cooldown==0:
        if int(rounds[selected_slot])>0 or infinite_ammo:shoot()
        else:
            reload()
            if reload_time==0:GameUI.play_ui("dry_fire");cooldown=.3
func shoot() -> Dictionary:
    if not enabled or get_tree().paused or cooldown>0 or reload_time>0 or (int(rounds[selected_slot])<=0 and not infinite_ammo):return {}
    var definition: Dictionary=current()
    var camera: Camera3D=camera_rig.camera
    var middle: Vector2=get_viewport().get_visible_rect().size*.5
    var origin: Vector3=camera.project_ray_origin(middle)
    var direction: Vector3=camera.project_ray_normal(middle)
    if spread_enabled:direction=_spread_direction(direction,spread_degrees())
    var target: Vector3=origin+direction*float(definition.range)
    var query:=PhysicsRayQueryParameters3D.create(origin,target,51,[player.get_rid()])
    query.collide_with_areas=true
    var aim_hit:=get_world_3d().direct_space_state.intersect_ray(query)
    if not aim_hit.is_empty():target=aim_hit.position
    var muzzle: Vector3=player.avatar.get_weapon().get_node("Muzzle").global_position
    query.from=muzzle;query.to=target+(target-muzzle).normalized()*.04
    var hit:=get_world_3d().direct_space_state.intersect_ray(query)
    if not hit.is_empty():
        target=hit.position
        var collider: Object=hit.collider
        hit.direction=(target-muzzle).normalized()
        if collider.has_method("receive_hit"):collider.call("receive_hit",float(definition.damage),target,hit.normal)
    if not infinite_ammo:rounds[selected_slot]=int(rounds[selected_slot])-1
    cooldown=definition.interval;shot_count+=1
    bloom=minf(float(definition.get("bloom_max",3.0)),bloom+float(definition.get("bloom_per_shot",0)))
    player.avatar.recoil=float(definition.recoil)
    player.avatar.on_fire()
    var steady: float=.55 if aiming else 1.0
    var kick: float=float(definition.get("kick",0))
    if camera_rig.has_method("kick"):
        camera_rig.kick(kick*steady,random.randf_range(-kick,kick)*.35*steady)
        camera_rig.add_trauma(float(definition.get("shake",0))*steady)
    _show_shot(muzzle,target,hit)
    fired.emit(selected_slot,hit)
    return hit
func _spread_direction(direction: Vector3, degrees: float) -> Vector3:
    if degrees<=.001:return direction
    # Uniform within the cone's disc; sqrt keeps it from clustering in the centre.
    var radius: float=tan(deg_to_rad(degrees))*sqrt(random.randf())
    var angle: float=random.randf()*TAU
    var side:=direction.cross(Vector3.UP).normalized()
    if side.length_squared()<.01:side=Vector3.RIGHT
    var up:=side.cross(direction).normalized()
    return (direction+side*cos(angle)*radius+up*sin(angle)*radius).normalized()
func _make_effects() -> void:
    var bright:=ParkGeometry.material(Color("ffd582"));bright.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED
    var dark:=ParkGeometry.material(Color("34322f"))
    for i in 24:
        var tracer:=MeshInstance3D.new();var beam:=BoxMesh.new();beam.size=Vector3(.016,.016,1)
        tracer.mesh=beam;tracer.material_override=bright;tracer.top_level=true;tracer.visible=false;tracer.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF;add_child(tracer);tracer_pool.append(tracer);tracers.append(0)
        var impact:=MeshInstance3D.new();var dot:=SphereMesh.new();dot.radius=.032;dot.height=.064;dot.radial_segments=8;dot.rings=4
        impact.mesh=dot;impact.material_override=dark;impact.top_level=true;impact.visible=false;impact.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF;add_child(impact);impact_pool.append(impact);impacts.append(0)
const TRACER_SECONDS: float=.07
func _show_shot(begin: Vector3, end: Vector3, hit: Dictionary) -> void:
    var i:=pool_index;pool_index=(pool_index+1)%tracer_pool.size()
    var tracer:=tracer_pool[i]
    var delta: Vector3=end-begin
    if delta.length()>.01:
        var z: Vector3=delta.normalized();var x:=Vector3.UP.cross(z).normalized()
        if x.length_squared()<.01:x=Vector3.RIGHT
        tracer.global_transform=Transform3D(Basis(x,z.cross(x).normalized(),z),(begin+end)*.5)
        tracer.scale=Vector3(1,1,delta.length())
        tracer.visible=true;tracers[i]=TRACER_SECONDS
    var hit_zombie: bool=not hit.is_empty() and hit.collider is Area3D and hit.collider.get("zombie")!=null
    if not hit.is_empty() and not hit_zombie:
        impact_pool[i].global_position=end+hit.normal*.012;impact_pool[i].visible=true;impacts[i]=7
        effects.dust_puff(end+hit.normal*.03,hit.normal)
    effects.muzzle_flash(begin,1.4 if selected_slot==3 else 1.0)
    var audio: Node=GameUI.audio_manager()
    if audio:audio.play_weapon(selected_slot)
func _update_effects(delta: float) -> void:
    for i in tracers.size():
        if tracers[i]>0:
            tracers[i]=maxf(0,tracers[i]-delta)
            var width: float=tracers[i]/TRACER_SECONDS
            tracer_pool[i].scale=Vector3(width,width,tracer_pool[i].scale.z)
        tracer_pool[i].visible=tracers[i]>0
        impacts[i]=maxf(0,impacts[i]-delta);impact_pool[i].visible=impacts[i]>0
