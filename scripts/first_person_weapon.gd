extends Node3D
# The gun and arms you see in first person. A child of the camera; it copies the player's weapon
# state (slot, aiming, recoil, reload, sprint lowering) from the weapon system and avatar, places
# the gun, then poses the hoodie arms onto it (scripts/first_person_arms.gd).
# Adds the hand-driven moments: magazine reloads, a left-hand shove for melee, the sniper bolt,
# weapons rising into view after a switch, and ejected shell casings. Pulls back near walls.
const GunModels=preload("res://scripts/weapon_models.gd")
const FirstPersonArms=preload("res://scripts/first_person_arms.gd")
const WeaponSystem=preload("res://scripts/weapon_system.gd")
const VIEWMODEL_LAYER: int=1<<11
# Per slot: resting hip position and aimed-down-sights position, in camera space.
const HIP: Array[Vector3]=[Vector3(.11,-.095,-.5),Vector3(.14,-.12,-.38),Vector3(.14,-.115,-.42)]
# Sights sit just below eye level; the stock passes under the camera.
const ADS: Array[Vector3]=[Vector3(0,-.034,-.42),Vector3(0,-.079,-.24),Vector3(0,-.078,-.27)]
# Shoulder midpoint per slot, in camera space (further forward for the long guns).
const SHOULDERS: Array[Vector3]=[Vector3(.02,-.42,-.06),Vector3(.06,-.37,-.12),Vector3(.06,-.37,-.14)]
# Hands, in each gun's own space: wrist-to-knuckle direction, thumb side, how closed the fist
# is (0 open .. 1 fist) and an offset from the gun's grip marker. The right palm faces left round
# the grip; the left hand cups the pistol from the left, or holds the handguard from below.
const RIGHT_HAND:={"fingers":Vector3(-.15,-.35,-.92),"thumb":Vector3(0,1,0),"curl":.9,"offset":Vector3(.02,0,0)}
const LEFT_HAND: Array[Dictionary]=[
    {"fingers":Vector3(.55,-.45,-.7),"thumb":Vector3(0,1,0),"curl":.8,"offset":Vector3(-.015,0,0)},
    {"fingers":Vector3(.5,.1,-.85),"thumb":Vector3(-1,.3,0),"curl":.75,"offset":Vector3(0,-.025,.07)},
    {"fingers":Vector3(.5,.1,-.85),"thumb":Vector3(-1,.3,0),"curl":.75,"offset":Vector3(0,-.025,.07)}]
# Reload and casing details per slot, in gun space.
const MAG_WELL: Array[Vector3]=[Vector3(0,-.15,.035),Vector3(0,-.19,-.09),Vector3(0,-.15,-.06)]
const MAG_SIZE: Array[Vector3]=[Vector3(.022,.075,.035),Vector3(.026,.13,.05),Vector3(.024,.075,.06)]
const EJECT_PORT: Array[Vector3]=[Vector3(.02,.02,-.06),Vector3(.03,.03,-.03),Vector3(.035,.03,.02)]
const CASING_SIZE: Array[Vector2]=[Vector2(.0045,.018),Vector2(.005,.03),Vector2(.006,.045)]
const BOLT_HANDLE:=Vector3(.045,-.012,.05)
const BOLT_START: float=.12
const BOLT_SECONDS: float=.75
const WALL_PROBE: float=.85
const CASING_LIFE: float=1.4
var rig: Node3D
var models: Array[Node3D]=[]
var arms: Node3D
var spill: OmniLight3D
var magazine: MeshInstance3D
var casings: Array[MeshInstance3D]=[]
var casing_state: Array[Dictionary]=[]
var casing_index: int=0
var connected_weapons: Node3D
var aim_blend: float=0
var sprint_lower: float=0
# Reload motion: the last reload stage and how much of it still shows (eases out when cancelled).
var reload_stage: float=0
var reload_weight: float=0
# Casings wait for this frame's gun placement, so they leave the gun where you see it.
var pending_ejects: Array[int]=[]
var sway:=Vector2.ZERO
var retract: float=0
var clock: float=0
var bolt_time: float=-1
var bolt_ejected: bool=true
# Working copies of the hand tables (captures and tuning can adjust them at runtime).
var right_hand: Dictionary=RIGHT_HAND.duplicate()
var left_hands: Array=LEFT_HAND.duplicate(true)
var hip_positions: Array[Vector3]=HIP.duplicate()
var shoulder_positions: Array[Vector3]=SHOULDERS.duplicate()
func _ready() -> void:
    for slot in range(1,4):
        var weapon:=GunModels.build(slot);weapon.visible=false;add_child(weapon);models.append(weapon)
        # The wrappers carry a hand-fit offset for the third-person rig; here the bore runs straight down -Z.
        weapon.transform=Transform3D.IDENTITY
        for mesh: GeometryInstance3D in weapon.find_children("*","GeometryInstance3D",true,false):
            mesh.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF;mesh.layers=VIEWMODEL_LAYER
    arms=FirstPersonArms.new();arms.name="Arms";add_child(arms)
    # The flashlight skips the gun and arms (they would be blown out at point-blank range); this
    # soft light stands in for the light spilling back onto them.
    spill=OmniLight3D.new();spill.name="FlashlightSpill"
    spill.light_cull_mask=VIEWMODEL_LAYER;spill.omni_range=1.4;spill.light_energy=0
    spill.light_color=Color(1.0,.87,.52);spill.position=Vector3(.22,-.05,.05)
    add_child(spill)
    magazine=MeshInstance3D.new();magazine.name="SpareMagazine";magazine.mesh=BoxMesh.new()
    magazine.material_override=ParkGeometry.material(Color("2b2c30"),.5)
    magazine.top_level=true;magazine.visible=false;magazine.layers=VIEWMODEL_LAYER
    magazine.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF;add_child(magazine)
    var brass:=ParkGeometry.material(Color("c99a3b"),.3);brass.metallic=.8
    for i in 20:
        var casing:=MeshInstance3D.new();var shell:=CylinderMesh.new();shell.radial_segments=6;shell.rings=1;casing.mesh=shell
        casing.material_override=brass;casing.top_level=true;casing.visible=false
        casing.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF;add_child(casing)
        casings.append(casing);casing_state.append({"life":0.0})
    visible=false
func player() -> CharacterBody3D:
    if rig==null or not rig.first_person or not rig.on_foot:return null
    return rig.target as CharacterBody3D
func muzzle_position() -> Vector3:
    var person:=player()
    if person==null:return global_position
    return models[person.weapons.selected_slot-1].get_node("Muzzle").global_position
func _on_fired(slot: int, _hit: Dictionary) -> void:
    if slot==3:bolt_time=0;bolt_ejected=false
    else:pending_ejects.append(slot)
func _process(delta: float) -> void:
    _update_casings(delta)
    var person:=player()
    var weapons: Node3D=person.weapons if person else null
    var shown: bool=person!=null and person.active and weapons.enabled and not person.dead
    if shown and rig.sniper_scope and aim_blend>.8:shown=false
    visible=shown
    if person==null or not person.active:aim_blend=0;retract=0;bolt_time=-1;reload_weight=0;pending_ejects.clear();return
    if connected_weapons!=weapons:
        connected_weapons=weapons
        if not weapons.fired.is_connected(_on_fired):weapons.fired.connect(_on_fired)
    var slot: int=weapons.selected_slot
    for i in models.size():models[i].visible=i+1==slot
    var gun: Node3D=models[slot-1]
    var avatar: Node3D=person.avatar
    clock+=delta
    # Lowered while sprinting or rolling (reloads and switches have their own motions below).
    sprint_lower=lerpf(sprint_lower,.85 if person.sprinting and not weapons.aiming else 0.0,1-exp(-delta*12))
    var lower: float=1.0 if person.roll_time>0 else sprint_lower
    # No aiming down the sights while sprinting, rolling, reloading or switching.
    var busy: bool=lower>.5 or weapons.reload_time>0 or weapons.raise_time>0
    var aim_target: float=1.0 if weapons.aiming and not busy else 0.0
    aim_blend=lerpf(aim_blend,aim_target,1-exp(-delta*15))
    var hip_weight: float=1.0-aim_blend*.85
    var offset: Vector3=hip_positions[slot-1].lerp(ADS[slot-1],aim_blend)
    var turn:=Vector3.ZERO
    # Sway: the gun lags behind mouse movement.
    var look_rate: Vector2=rig.frame_look/maxf(delta,.001)
    var sway_target:=Vector2(clampf(look_rate.x*.006,-.045,.045),clampf(look_rate.y*.006,-.035,.035))
    sway=sway.lerp(sway_target,1-exp(-delta*9))
    offset+=Vector3(sway.x,-sway.y,0)*hip_weight
    turn+=Vector3(-sway.y*1.4,sway.x*1.8,sway.x*.8)*hip_weight
    # Walking bob (shares the camera's stride) and idle breathing.
    var stride: float=rig.bob_time;var amount: float=rig.bob_amount*hip_weight
    offset+=Vector3(cos(stride)*.014,-absf(sin(stride))*.016,0)*amount
    turn.z+=cos(stride)*.02*amount
    offset.y+=sin(clock*1.7)*.0025*hip_weight
    offset+=Vector3(-.04,-.11,.06)*lower;turn+=Vector3(-.75*lower,.45*lower,0)
    # After a switch the new weapon rises from below the screen.
    var rising: float=weapons.raise_time/WeaponSystem.RAISE_SECONDS
    rising*=rising
    offset+=Vector3(.03,-.26,.06)*rising;turn+=Vector3(-.9*rising,.2*rising,0)
    # Reload: the gun tips towards you while the left hand swaps the magazine.
    if weapons.reload_time>0:reload_stage=avatar.reload_progress;reload_weight=1.0
    else:reload_weight=move_toward(reload_weight,0,delta*5)
    var reload: float=reload_stage if reload_weight>0 else 0.0
    var tip: float=smoothstep(0,.15,reload)*(1-smoothstep(.82,1,reload))*reload_weight
    var jolt: float=smoothstep(.62,.68,reload)*(1-smoothstep(.68,.78,reload))
    offset+=Vector3(-.06,.02+jolt*.012,.04)*tip;turn+=Vector3(.18*tip+jolt*.08,.22*tip,.5*tip)
    # Melee: the gun swings aside while the left hand shoves.
    var melee: float=0
    if person.melee_time>0:melee=1.0-person.melee_time/float(person.settings.melee.duration)
    var swing: float=sin(melee*PI) if melee>0 else 0.0
    offset+=Vector3(.05,-.07,.04)*swing;turn+=Vector3(-.2,-.25,-.5)*swing
    # Sniper bolt: the right hand works the bolt after each shot.
    var bolt: float=-1
    if bolt_time>=0:
        bolt_time+=delta
        bolt=(bolt_time-BOLT_START)/BOLT_SECONDS
        if bolt>=1:bolt_time=-1;bolt=-1
    if slot!=3:bolt_time=-1;bolt=-1
    if bolt>=0:
        var working: float=sin(bolt*PI)
        offset+=Vector3(-.03,-.045,-.03)*working;turn+=Vector3(-.08,.12,-.3)*working
    # Recoil kick from the weapon system.
    offset.z+=avatar.recoil*1.1+avatar.fire_push*.028
    turn.x+=avatar.recoil*2.2+avatar.fire_push*.05
    # Pull back near walls.
    var camera: Camera3D=get_parent() as Camera3D
    var wall_target: float=0
    if camera and camera.is_inside_tree():
        var from: Vector3=camera.global_position
        var query:=PhysicsRayQueryParameters3D.create(from,from-camera.global_basis.z*WALL_PROBE,3,[person.get_rid()])
        var hit:=get_world_3d().direct_space_state.intersect_ray(query)
        if not hit.is_empty():wall_target=clampf((WALL_PROBE-from.distance_to(hit.position))/.55,0,1)
    retract=lerpf(retract,wall_target,1-exp(-delta*14))
    offset+=Vector3(.02,-.06,.17)*retract;turn+=Vector3(-.65,.35,0)*retract
    position=offset;rotation=turn
    var flashlight: Node3D=rig.flashlight
    spill.light_energy=lerpf(spill.light_energy,.55 if flashlight and flashlight.is_lit() else 0.0,1-exp(-delta*20))
    if camera:_pose_hands(camera,gun,slot,reload,melee,bolt,delta)
    for pending in pending_ejects:_eject(pending)
    pending_ejects.clear()
func _pose_hands(camera: Camera3D, gun: Node3D, slot: int, reload: float, melee: float, bolt: float, delta: float) -> void:
    var gun_basis: Basis=gun.global_basis.orthonormalized()
    var right:={"palm":gun.get_node("GripRight").global_position+gun_basis*(right_hand.get("offset",Vector3.ZERO) as Vector3),"fingers":gun_basis*right_hand.fingers,"thumb":gun_basis*right_hand.thumb,"curl":right_hand.curl}
    var hand: Dictionary=left_hands[slot-1]
    var left:={"palm":gun.get_node("GripLeft").global_position+gun_basis*(hand.get("offset",Vector3.ZERO) as Vector3),"fingers":gun_basis*hand.fingers,"thumb":gun_basis*hand.thumb,"curl":hand.curl}
    magazine.visible=false
    if reload>0:
        var grip:=left.duplicate()
        _reload_hand(gun,slot,reload,left)
        if reload_weight<1:
            left.palm=(grip.palm as Vector3).lerp(left.palm,reload_weight)
            left.fingers=(grip.fingers as Vector3).lerp(left.fingers,reload_weight)
            left.curl=lerpf(float(grip.curl),float(left.curl),reload_weight)
            magazine.visible=false
    if melee>0:_shove_hand(camera,melee,left)
    if bolt>=0:_bolt_hand(gun,slot,bolt,right)
    var shoulders: Vector3=shoulder_positions[slot-1]+Vector3(-.03*aim_blend,0,0)
    arms.pose(camera,shoulders,right,left,delta)
# Left hand: grip -> magazine well -> down out of view -> back up with a fresh magazine -> grip.
func _reload_hand(gun: Node3D, slot: int, t: float, left: Dictionary) -> void:
    var grip: Vector3=gun.get_node("GripLeft").position
    var well: Vector3=MAG_WELL[slot-1]
    var below: Vector3=well+Vector3(0,-.05,0)
    var drop: Vector3=well+Vector3(-.07,-.12,.06)
    var palm: Vector3
    var holding: bool=false
    if t<.16:palm=grip.lerp(well,smoothstep(0,1,t/.16))
    elif t<.36:palm=well.lerp(drop,smoothstep(0,1,(t-.16)/.2))
    elif t<.6:palm=drop.lerp(below,smoothstep(0,1,(t-.36)/.24));holding=true
    elif t<.7:palm=below.lerp(well,smoothstep(0,1,(t-.6)/.1));holding=true
    else:palm=well.lerp(grip,smoothstep(0,1,(t-.7)/.3))
    var gun_basis: Basis=gun.global_basis.orthonormalized()
    left.palm=gun.to_global(palm)
    # Fingers point up to cup the magazine from below.
    var cup: float=1.0-smoothstep(.62,.8,t)
    left.fingers=(left.fingers as Vector3).lerp(gun_basis*Vector3(.2,.8,-.4),cup*smoothstep(0,.16,t))
    left.curl=lerpf(float(left.curl),.45,cup)
    if holding:
        var size: Vector3=MAG_SIZE[slot-1]
        (magazine.mesh as BoxMesh).size=size
        magazine.global_transform=Transform3D(gun_basis,gun.to_global(palm+Vector3(0,size.y*.45,0)))
        magazine.visible=true
# Left hand: quick wind-up, then an open-palm shove forward, then back to the grip.
func _shove_hand(camera: Camera3D, t: float, left: Dictionary) -> void:
    var wind: Vector3=camera.to_global(Vector3(-.15,-.2,-.32))
    var strike: Vector3=camera.to_global(Vector3(-.05,-.08,-.62))
    var palm: Vector3=left.palm
    var weight: float
    if t<.25:weight=smoothstep(0,1,t/.25);palm=(left.palm as Vector3).lerp(wind,weight)
    elif t<.42:weight=1;palm=wind.lerp(strike,smoothstep(0,1,(t-.25)/.17))
    elif t<.6:weight=1;palm=strike
    else:weight=1-smoothstep(0,1,(t-.6)/.4);palm=strike.lerp(left.palm,1-weight)
    left.palm=palm
    var up: Vector3=camera.global_basis.y;var forward: Vector3=-camera.global_basis.z
    left.fingers=(left.fingers as Vector3).lerp(up*.9+forward*.2,weight)
    left.thumb=(left.thumb as Vector3).lerp(camera.global_basis.x,weight)
    left.curl=lerpf(float(left.curl),.1,weight)
# Right hand: grip -> bolt handle, pull back (casing flies), push forward, back to the grip.
func _bolt_hand(gun: Node3D, slot: int, t: float, right: Dictionary) -> void:
    var grip: Vector3=gun.get_node("GripRight").position
    var handle: Vector3=BOLT_HANDLE
    var pulled: Vector3=handle+Vector3(.01,.01,.09)
    var palm: Vector3
    if t<.25:palm=grip.lerp(handle,smoothstep(0,1,t/.25))
    elif t<.45:palm=handle.lerp(pulled,smoothstep(0,1,(t-.25)/.2))
    elif t<.65:palm=pulled.lerp(handle,smoothstep(0,1,(t-.45)/.2))
    else:palm=handle.lerp(grip,smoothstep(0,1,(t-.65)/.35))
    if t>=.42 and not bolt_ejected:bolt_ejected=true;_eject(slot)
    var away: float=sin(clampf(t,0,1)*PI)
    var gun_basis: Basis=gun.global_basis.orthonormalized()
    right.palm=gun.to_global(palm)
    right.fingers=(right.fingers as Vector3).lerp(gun_basis*Vector3(-.5,-.55,-.6),away)
    right.curl=lerpf(float(right.curl),.75,away)
func _eject(slot: int) -> void:
    if not visible:return
    var gun: Node3D=models[slot-1]
    var casing: MeshInstance3D=casings[casing_index];var state: Dictionary=casing_state[casing_index]
    casing_index=(casing_index+1)%casings.size()
    var size: Vector2=CASING_SIZE[slot-1]
    var cylinder: CylinderMesh=casing.mesh;cylinder.top_radius=size.x;cylinder.bottom_radius=size.x;cylinder.height=size.y
    var basis: Basis=gun.global_basis.orthonormalized()
    casing.global_transform=Transform3D(basis*Basis(Vector3.FORWARD,PI*.5),gun.to_global(EJECT_PORT[slot-1]))
    var person:=player()
    var carry: Vector3=person.velocity if person else Vector3.ZERO
    state.velocity=basis.x*randf_range(1.3,1.9)+basis.y*randf_range(1.1,1.6)+basis.z*randf_range(.2,.5)+carry
    state.spin=Vector3(randf_range(-1,1),randf_range(-1,1),randf_range(-1,1)).normalized()
    state.spin_speed=randf_range(14,24);state.life=CASING_LIFE
    state.floor=(person.global_position.y if person else casing.global_position.y-1.5)+size.x
    casing.visible=true
func _update_casings(delta: float) -> void:
    for i in casings.size():
        var state: Dictionary=casing_state[i]
        if float(state.life)<=0:continue
        var casing: MeshInstance3D=casings[i]
        state.life=float(state.life)-delta
        if float(state.life)<=0:casing.visible=false;continue
        var velocity: Vector3=state.velocity
        velocity.y-=9.8*delta
        var spot: Vector3=casing.global_position+velocity*delta
        if spot.y<float(state.floor):
            spot.y=float(state.floor);velocity=Vector3(velocity.x*.55,-velocity.y*.3,velocity.z*.55)
            state.spin_speed=float(state.spin_speed)*.5
        state.velocity=velocity
        casing.global_transform=Transform3D(Basis(state.spin,float(state.spin_speed)*delta)*casing.global_basis.orthonormalized(),spot)
