extends Node3D
# The gun you see in first person. It is a child of the camera and copies the player's weapon
# state (slot, aiming, recoil, reload, sprint lowering) from the weapon system and avatar.
# Near walls it pulls back instead of poking through them.
const GunModels=preload("res://scripts/weapon_models.gd")
const VIEWMODEL_LAYER: int=1<<11
# Per slot: resting hip position and aimed-down-sights position, in camera space.
const HIP: Array[Vector3]=[Vector3(.19,-.2,-.45),Vector3(.17,-.2,-.5),Vector3(.17,-.19,-.52)]
# Sights sit just below eye level; the stock passes under the camera.
const ADS: Array[Vector3]=[Vector3(0,-.036,-.3),Vector3(0,-.079,-.24),Vector3(0,-.078,-.27)]
const WALL_PROBE: float=.85
var rig: Node3D
var models: Array[Node3D]=[]
var spill: OmniLight3D
var aim_blend: float=0
var sway:=Vector2.ZERO
var retract: float=0
var clock: float=0
func _ready() -> void:
    for slot in range(1,4):
        var weapon:=GunModels.build(slot);weapon.visible=false;add_child(weapon);models.append(weapon)
        # The wrappers carry a hand-fit offset for the third-person rig; here the bore runs straight down -Z.
        weapon.transform=Transform3D.IDENTITY
        for mesh: GeometryInstance3D in weapon.find_children("*","GeometryInstance3D",true,false):
            mesh.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF;mesh.layers=VIEWMODEL_LAYER
    # The flashlight skips the gun (it would be blown out at point-blank range); this soft
    # light stands in for the light spilling back onto it.
    spill=OmniLight3D.new();spill.name="FlashlightSpill"
    spill.light_cull_mask=VIEWMODEL_LAYER;spill.omni_range=1.4;spill.light_energy=0
    spill.light_color=Color(1.0,.87,.52);spill.position=Vector3(.22,-.05,.05)
    add_child(spill)
    visible=false
func player() -> CharacterBody3D:
    if rig==null or not rig.first_person or not rig.on_foot:return null
    return rig.target as CharacterBody3D
func muzzle_position() -> Vector3:
    var person:=player()
    if person==null:return global_position
    return models[person.weapons.selected_slot-1].get_node("Muzzle").global_position
func _process(delta: float) -> void:
    var person:=player()
    var weapons: Node3D=person.weapons if person else null
    var shown: bool=person!=null and person.active and weapons.enabled and not person.dead
    if shown and rig.sniper_scope and aim_blend>.8:shown=false
    visible=shown
    if person==null or not person.active:aim_blend=0;retract=0;return
    var slot: int=weapons.selected_slot
    for i in models.size():models[i].visible=i+1==slot
    var avatar: Node3D=person.avatar
    clock+=delta
    # Aiming, unless the gun is lowered for sprinting, switching or reloading.
    var lower: float=avatar.weapon_lower
    if person.roll_time>0:lower=1.0
    var aim_target: float=1.0 if weapons.aiming and lower<.5 else 0.0
    aim_blend=lerpf(aim_blend,aim_target,1-exp(-delta*15))
    var hip_weight: float=1.0-aim_blend*.85
    var offset: Vector3=HIP[slot-1].lerp(ADS[slot-1],aim_blend)
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
    # Sprint / weapon switch lowering and reload dip, from the avatar's own weapon handling.
    var reload_dip: float=sin(clampf(avatar.reload_progress,0,1)*PI)
    offset+=Vector3(-.04,-.11,.06)*lower+Vector3(0,-.07,.02)*reload_dip
    turn+=Vector3(-.75*lower-.3*reload_dip,.45*lower,.55*reload_dip)
    # Melee: the gun swings aside while you kick.
    if person.melee_time>0:
        var swing: float=sin((1.0-person.melee_time/float(person.settings.melee.duration))*PI)
        offset+=Vector3(-.06,-.08,.04)*swing;turn+=Vector3(-.25,.2,.7)*swing
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
