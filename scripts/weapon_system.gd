extends Node3D
signal fired(slot: int, hit: Dictionary)
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
var flash: MeshInstance3D
var flash_time: float=0
var survival_enabled: bool=false
var infinite_ammo: bool=false
var unlocked: Dictionary={1:true,2:true,3:true}
var tiers: Dictionary={1:0,2:0,3:0}
var reserve: Dictionary={1:96,2:180,3:30}
var survival_settings: Dictionary={}
func _ready() -> void:
    definitions=JSON.parse_string(FileAccess.get_file_as_string("res://data/weapon_settings.json")).weapons
    for definition: Dictionary in definitions:rounds[int(definition.slot)]=int(definition.magazine)
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
    enabled=value;aiming=false;reload_time=0;cooldown=.2;suppress_until_release=true
    if camera_rig:camera_rig.aiming=false;camera_rig.sniper_scope=false
    if player:player.avatar.set_weapon(selected_slot);player.avatar.set_first_person_view(false)
func select_weapon(slot: int) -> void:
    if not enabled or slot<1 or slot>3 or not unlocked[slot]:return
    if slot!=selected_slot:GameUI.play_ui("weapon_equip")
    selected_slot=slot;reload_time=0;cooldown=.2;suppress_until_release=true
    player.avatar.set_weapon(slot)
func reload() -> void:
    if infinite_ammo:return
    if survival_enabled and int(reserve[selected_slot])<=0:return
    if enabled and reload_time==0 and int(rounds[selected_slot])<int(current().magazine):
        reload_time=current().reload_seconds
        GameUI.play_ui(["reload_pistol","reload_rifle","reload_sniper"][selected_slot-1])
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
    cooldown=maxf(0,cooldown-delta)
    aiming=Input.is_action_pressed("aim")
    camera_rig.aiming=aiming;camera_rig.sniper_scope=aiming and selected_slot==3
    player.avatar.set_first_person_view(camera_rig.sniper_scope or camera_rig.arm.spring_length<1.1)
    if reload_time>0:
        reload_time=maxf(0,reload_time-delta)
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
    if (down if current().automatic else Input.is_action_just_pressed("fire")) and cooldown==0:
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
        if collider.has_method("receive_hit"):collider.call("receive_hit",float(definition.damage),target,hit.normal)
    if not infinite_ammo:rounds[selected_slot]=int(rounds[selected_slot])-1
    cooldown=definition.interval;shot_count+=1
    player.avatar.recoil=float(definition.recoil)
    _show_shot(muzzle,target,hit)
    fired.emit(selected_slot,hit)
    return hit
func _make_effects() -> void:
    var bright:=ParkGeometry.material(Color("ffd582"));bright.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED
    var dark:=ParkGeometry.material(Color("34322f"))
    for i in 24:
        var tracer:=MeshInstance3D.new();var beam:=BoxMesh.new();beam.size=Vector3(.009,.009,1)
        tracer.mesh=beam;tracer.material_override=bright;tracer.top_level=true;tracer.visible=false;tracer.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF;add_child(tracer);tracer_pool.append(tracer);tracers.append(0)
        var impact:=MeshInstance3D.new();var dot:=SphereMesh.new();dot.radius=.032;dot.height=.064;dot.radial_segments=8;dot.rings=4
        impact.mesh=dot;impact.material_override=dark;impact.top_level=true;impact.visible=false;impact.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF;add_child(impact);impact_pool.append(impact);impacts.append(0)
    flash=MeshInstance3D.new();var sphere:=SphereMesh.new();sphere.radius=.055;sphere.height=.11;sphere.radial_segments=6;sphere.rings=4
    flash.mesh=sphere;flash.material_override=bright;flash.top_level=true;flash.visible=false;flash.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF;add_child(flash)
func _show_shot(begin: Vector3, end: Vector3, hit: Dictionary) -> void:
    var i:=pool_index;pool_index=(pool_index+1)%tracer_pool.size()
    var tracer:=tracer_pool[i]
    var delta: Vector3=end-begin
    if delta.length()>.01:
        var z: Vector3=delta.normalized();var x:=Vector3.UP.cross(z).normalized()
        if x.length_squared()<.01:x=Vector3.RIGHT
        tracer.global_transform=Transform3D(Basis(x,z.cross(x).normalized(),z*delta.length()),(begin+end)*.5)
        tracer.visible=true;tracers[i]=.06
    if not hit.is_empty():impact_pool[i].global_position=end+hit.normal*.012;impact_pool[i].visible=true;impacts[i]=7
    flash.global_position=begin;flash.visible=true;flash_time=.045
    var audio: Node=GameUI.audio_manager()
    if audio:audio.play_weapon(selected_slot)
func _update_effects(delta: float) -> void:
    for i in tracers.size():
        tracers[i]=maxf(0,tracers[i]-delta);tracer_pool[i].visible=tracers[i]>0
        impacts[i]=maxf(0,impacts[i]-delta);impact_pool[i].visible=impacts[i]>0
    flash_time=maxf(0,flash_time-delta);flash.visible=flash_time>0
