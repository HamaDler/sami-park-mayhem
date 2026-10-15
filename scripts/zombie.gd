extends CharacterBody3D
var manager: Node3D
var id: int=0
var health: float=0
var damage: float=25
var move_speed: float=1.8
var alive: bool=false
var alerted: bool=false
var think_time: float=0
var route_time: float=0
var attack_time: float=0
var attack_cooldown: float=0
var hit_time: float=0
var corpse_time: float=0
var wander_time: float=0
var route:=PackedVector2Array()
var route_index: int=0
var heading:=Vector2.ZERO
var last_position:=Vector2.ZERO
var stuck_time: float=0
var model: Node3D
var animator: AnimationPlayer
var clip: String=""
var animation_clock: float=0
var animation_accumulator: float=0
var head_box: Area3D
var body_box: Area3D
var skeleton: Skeleton3D
var head_attachment: BoneAttachment3D
var spawn_cooldown: float=0
var model_index: int=0
var archetype: String="walker"
var type_visual: Node3D
var scream_cooldown: float=0
var scream_time: float=0
var scream_ring: MeshInstance3D
var armor_helmet: MeshInstance3D
func build(owner_manager: Node3D, packed: PackedScene, _variant: int) -> void:
    manager=owner_manager
    model_index=_variant
    model=packed.instantiate();model.name="ImportedZombie";add_child(model)
    var meshes:=model.find_children("*","MeshInstance3D",true,false)
    var maximum: float=0
    for mesh: MeshInstance3D in meshes:maximum=maxf(maximum,mesh.get_aabb().end.y)
    var target_height: float=1.75
    model.scale=Vector3.ONE*target_height/maxf(maximum,.5)
    model.rotation.y=PI
    var animations:=model.find_children("*","AnimationPlayer",true,false)
    assert(not animations.is_empty(),"Zombie asset must include animations")
    animator=animations[0];animator.callback_mode_process=AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
    var skeletons:=model.find_children("*","Skeleton3D",true,false)
    if not skeletons.is_empty():skeleton=skeletons[0]
    body_box=_hitbox(false)
    body_box.position=Vector3(0,target_height*.42,0)
    var capsule:=CapsuleShape3D.new();capsule.radius=.30;capsule.height=target_height*.68
    body_box.get_child(0).shape=capsule
    add_child(body_box)
    head_box=_hitbox(true)
    var hitbox_data: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://assets/zombies/quaternius/head_hitboxes.json"))
    var head_data: Dictionary=hitbox_data.get(packed.resource_path.get_file(),{})
    var sphere:=SphereShape3D.new();sphere.radius=float(head_data.get("radius",.22/model.scale.x))
    head_box.get_child(0).shape=sphere
    if skeleton:
        var bone: int=-1
        for index in skeleton.get_bone_count():
            if skeleton.get_bone_name(index).to_lower().ends_with("head"):bone=index;break
        if bone>=0:
            head_attachment=BoneAttachment3D.new();head_attachment.bone_name=skeleton.get_bone_name(bone)
            skeleton.add_child(head_attachment);head_attachment.add_child(head_box)
            if head_data.has("center"):head_box.position=Vector3(head_data.center[0],head_data.center[1],head_data.center[2])
        else:add_child(head_box);head_box.position=Vector3(0,target_height*.9,0)
    else:add_child(head_box);head_box.position=Vector3(0,target_height*.9,0)
    for mesh: MeshInstance3D in meshes:mesh.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
    deactivate()
func _hitbox(head: bool) -> Area3D:
    var area:=Area3D.new();area.set_script(load("res://scripts/zombie_hitbox.gd"))
    area.zombie=self;area.headshot=head;area.collision_layer=0;area.collision_mask=0;area.monitoring=false;area.monitorable=false
    var shape:=CollisionShape3D.new();area.add_child(shape)
    return area
func activate(point: Vector2, identifier: int, stats: Dictionary) -> void:
    id=identifier;health=float(stats.health);damage=float(stats.damage);move_speed=float(stats.speed)
    _set_type(str(stats.get("kind","walker")))
    scream_cooldown=manager.random.randf_range(3,6);scream_time=0
    alive=true;alerted=false;corpse_time=0;hit_time=0;spawn_cooldown=1
    attack_time=0;attack_cooldown=0;think_time=manager.random.randf_range(0,.2);route_time=0;stuck_time=0
    heading=Vector2.ZERO;route.clear();route_index=0;wander_time=0;clip=""
    global_position=Vector3(point.x,.06,point.y);velocity=Vector3.ZERO;last_position=point
    collision_layer=8;body_box.collision_layer=16;head_box.collision_layer=32
    visible=true;set_physics_process(true);reset_physics_interpolation();_animate("Idle")
func deactivate() -> void:
    alive=false;visible=false;collision_layer=0
    if body_box:body_box.collision_layer=0
    if head_box:head_box.collision_layer=0
    set_physics_process(false)
func die() -> void:
    if not alive:return
    alive=false;collision_layer=0;body_box.collision_layer=0;head_box.collision_layer=0
    velocity=Vector3.ZERO;attack_time=0;corpse_time=float(manager.settings.corpse_seconds)
    scream_time=0
    if scream_ring:scream_ring.hide()
    _animate("Death",true)
func receive_hit(amount: float, point: Vector3, _normal: Vector3) -> void:
    manager.survival.damage_zombie(self,amount,false,"gun",point)
func _physics_process(delta: float) -> void:
    if not alive:
        corpse_time-=delta
        _advance_animation(delta,15)
        if corpse_time<=0:deactivate()
        return
    if manager.survival.over:return
    var actor: CharacterBody3D=manager.survival.game.get_active_actor()
    var point:=Vector2(global_position.x,global_position.z)
    var target:=Vector2(actor.global_position.x,actor.global_position.z)
    var distance:=point.distance_to(target)
    spawn_cooldown=maxf(0,spawn_cooldown-delta)
    scream_cooldown=maxf(0,scream_cooldown-delta)
    attack_cooldown=maxf(0,attack_cooldown-delta);hit_time=maxf(0,hit_time-delta)
    think_time-=delta;route_time-=delta
    if think_time<=0:
        think_time=float(manager.survival.config.navigation.think_interval)+manager.random.randf_range(0,.04)
        _think(point,target,distance,actor)
    if scream_time>0:
        scream_time=maxf(0,scream_time-delta)
        velocity.x=0;velocity.z=0
        if scream_ring:
            scream_ring.visible=true
            var radius:=1+(1-scream_time/float(manager.types.screamer.scream_windup))*7
            scream_ring.scale=Vector3(radius,.25,radius)
        if scream_time==0:
            if scream_ring:scream_ring.hide()
            if alerted and manager.line_of_sight(global_position+Vector3.UP,actor.global_position+Vector3.UP):manager.scream(self)
    elif attack_time>0:
        attack_time-=delta
        if attack_time<=0 and distance<_attack_range(actor)+.45 and manager.line_of_sight(global_position+Vector3.UP,actor.global_position+Vector3.UP):
            manager.survival.damage_target(damage)
        velocity.x=0;velocity.z=0
    elif hit_time>0:
        velocity.x=0;velocity.z=0;_animate("HitReact",true)
    else:
        var direction:=heading
        if route_index<route.size():
            if point.distance_to(route[route_index])<.9:route_index+=1
            if route_index<route.size():direction=(route[route_index]-point).normalized()
        direction+=manager.separation(self,point)*.65
        if direction.length_squared()>.01:direction=direction.normalized()
        var next:=point+direction*maxf(move_speed*delta,.6)
        if not manager.navigation.walkable(next) or manager.navigation.tree_blocked(next,.85):
            var avoid:=Vector2(-direction.y,direction.x)
            if not manager.navigation.walkable(point+avoid*1.5):avoid=-avoid
            direction=avoid if manager.navigation.walkable(point+avoid*1.5) else Vector2.ZERO
        var movement_speed:=move_speed if alerted else move_speed*.4
        velocity.x=direction.x*movement_speed;velocity.z=direction.y*movement_speed
        if direction.length_squared()>.01:rotation.y=lerp_angle(rotation.y,atan2(-direction.x,-direction.y),1-exp(-delta*8))
        _animate("Run" if alerted and move_speed>2.7 else ("Walk" if direction.length_squared()>.01 else "Idle"))
    velocity.y=-.5 if is_on_floor() else velocity.y-20*delta
    move_and_slide()
    if distance<55:_advance_animation(delta,30)
    elif distance<130:_advance_animation(delta,15)
    else:_advance_animation(delta,6)
    if point.distance_squared_to(last_position)<.015 and alerted and distance>3:stuck_time+=delta
    else:stuck_time=0;last_position=point
    if global_position.y< -3 or manager.survival.game.park.is_water(point):manager.relocate(self)
func _attack_range(actor: CharacterBody3D) -> float:
    return float(manager.settings.attack_distance)+(1.0 if not actor.is_in_group("walk_player") else 0.0)
func _think(point: Vector2, target: Vector2, distance: float, actor: CharacterBody3D) -> void:
    if scream_time>0:return
    if not alerted and distance<float(manager.settings.sight_distance):
        alerted=manager.line_of_sight(global_position+Vector3.UP,actor.global_position+Vector3.UP)
    if alerted:
        if archetype=="screamer" and scream_cooldown==0 and spawn_cooldown==0 and distance<float(manager.types.screamer.scream_range) and distance>_attack_range(actor)+1 and manager.line_of_sight(global_position+Vector3.UP,actor.global_position+Vector3.UP):
            scream_time=float(manager.types.screamer.scream_windup);scream_cooldown=float(manager.types.screamer.scream_cooldown)
            _animate("Jump",true);return
        if distance<_attack_range(actor) and attack_cooldown>0:
            heading=Vector2.ZERO;route.clear();route_index=0;return
        if distance<_attack_range(actor) and attack_cooldown==0 and spawn_cooldown==0 and manager.line_of_sight(global_position+Vector3.UP,actor.global_position+Vector3.UP):
            attack_time=float(manager.settings.attack_windup);attack_cooldown=float(manager.settings.attack_interval)
            _animate("Punch" if animator.has_animation("Punch") else "Jump",true)
            return
        heading=(target-point).normalized()
        if manager.navigation.segment_clear(point,target):route.clear();route_index=0
        elif route_time<=0 or stuck_time>2:
            var candidate: PackedVector2Array=manager.navigation.route(point,target)
            if not candidate.is_empty():route=candidate;route_index=mini(1,route.size()-1);stuck_time=0
            route_time=float(manager.survival.config.navigation.repath_interval)+manager.random.randf_range(0,.5)
    else:
        wander_time-=think_time
        if wander_time<=0:
            wander_time=manager.random.randf_range(2,5)
            heading=Vector2.from_angle(manager.random.randf()*TAU)
    if distance>float(manager.settings.relocate_distance) or stuck_time>12:manager.relocate(self)
func _animate(animation_name: String, one_shot: bool=false) -> void:
    if clip==animation_name:return
    if not animator.has_animation(animation_name):animation_name="Idle"
    clip=animation_name;animation_clock=0
    animator.play(animation_name,.12)
    if not one_shot:animator.get_animation(animation_name).loop_mode=Animation.LOOP_LINEAR
func _advance_animation(delta: float, fps: float) -> void:
    animation_accumulator+=delta
    if animation_accumulator<1.0/fps:return
    animator.advance(animation_accumulator);animation_accumulator=0
func _set_type(kind: String) -> void:
    archetype=kind
    if is_instance_valid(armor_helmet):head_box.remove_child(armor_helmet);armor_helmet.queue_free();armor_helmet=null
    if type_visual:remove_child(type_visual);type_visual.queue_free()
    type_visual=Node3D.new();type_visual.name="TypeDetails";add_child(type_visual);scream_ring=null
    if kind=="walker":return
    var color:=Color(manager.types[kind].color)
    var material:=ParkGeometry.material(color,.65)
    var label:=Label3D.new();label.text=manager.types[kind].name;label.modulate=color;label.font=GameUI.bold();label.font_size=32;label.pixel_size=.005
    label.position.y=2.05;label.billboard=BaseMaterial3D.BILLBOARD_ENABLED;label.visibility_range_end=45;type_visual.add_child(label)
    if kind=="armored":
        ParkGeometry.box(type_visual,Vector3(0,.9,0),Vector3(.68,.5,.45),material)
        # Use the imported head's local units so the helmet follows its animation and scale.
        var radius: float=head_box.get_child(0).shape.radius
        armor_helmet=ParkGeometry.box(head_box,Vector3(0,radius*.65,0),Vector3(radius*2.3,radius*.75,radius*2.2),material)
    elif kind=="runner":
        for x in [-.32,.32]:ParkGeometry.box(type_visual,Vector3(x,1.1,0),Vector3(.12,.14,.28),material)
    else:
        ParkGeometry.box(type_visual,Vector3(0,1.21,-.19),Vector3(.25,.28,.13),material)
        scream_ring=MeshInstance3D.new();var torus:=TorusMesh.new();torus.inner_radius=.65;torus.outer_radius=.75;torus.rings=24;torus.ring_segments=4
        scream_ring.mesh=torus;scream_ring.material_override=material;scream_ring.position.y=.16;scream_ring.scale.y=.25;type_visual.add_child(scream_ring);scream_ring.hide()
