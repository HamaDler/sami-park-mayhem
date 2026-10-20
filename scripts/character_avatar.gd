extends Node3D
const GunModels=preload("res://scripts/weapon_models.gd")
var model: Node3D
var skeleton: Skeleton3D
var animations: AnimationPlayer
var settings: Dictionary
var seated: bool=false
var first_person_view: bool=false
var vehicle: CharacterBody3D
var speed: float=0
var grounded: bool=true
var aiming: bool=false
var aim_pitch: float=0
var equipped_slot: int=0
var weapon_mount: Node3D
var weapon_models: Array[Node3D]=[]
var current_animation: String=""
var recoil: float=0
var move_input:=Vector2.ZERO
# Procedural weapon handling (0..1): raise after switching, reload progress, sprint lowering.
var weapon_raise: float=0
var reload_progress: float=0
var sprinting: bool=false
var weapon_lower: float=0
var fire_push: float=0
# One-shot action clip layered over locomotion (roll, kick, hit, death).
var action_time: float=0
var action_ik: bool=true
const MOUNT_BASE:=Vector3(.17,1.22,-.23)
func _ready() -> void:
    settings=JSON.parse_string(FileAccess.get_file_as_string("res://data/player_settings.json"))
    model=$Model
    skeleton=model.find_children("*","Skeleton3D",true,false)[0] as Skeleton3D
    animations=model.find_children("*","AnimationPlayer",true,false)[0] as AnimationPlayer
    animations.callback_mode_process=AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
    var library:=AnimationLibrary.new()
    for clip_name in animations.get_animation_list():
        var clip:=animations.get_animation(clip_name).duplicate() as Animation
        if str(clip_name).contains("Idle") or str(clip_name).contains("Walk") or str(clip_name).contains("Run"):clip.loop_mode=Animation.LOOP_LINEAR
        library.add_animation(clip_name,clip)
    animations.remove_animation_library("");animations.add_animation_library("",library)
    model.scale=Vector3.ONE*float(settings.standing_scale)
    weapon_mount=Node3D.new();weapon_mount.name="WeaponMount";weapon_mount.position=MOUNT_BASE;add_child(weapon_mount)
    for slot in range(1,4):
        var weapon:=GunModels.build(slot);weapon_mount.add_child(weapon);weapon.visible=false;weapon_models.append(weapon)
    _play("Idle_Neutral");animations.advance(0)
func _play(clip_name: String) -> void:
    var full: String="CharacterArmature|"+clip_name
    if current_animation==full:return
    current_animation=full
    animations.play(full,.16)
func set_seated(cart: CharacterBody3D) -> void:
    vehicle=cart;seated=true;equipped_slot=0;weapon_mount.hide()
    model.scale=Vector3.ONE*float(settings.seated_scale)
    _pose_driver()
func set_weapon(slot: int) -> void:
    if slot!=equipped_slot and slot>0 and not seated:weapon_lower=1
    equipped_slot=slot;weapon_mount.visible=slot>0 and not seated and not first_person_view
    for i in weapon_models.size():weapon_models[i].visible=i+1==slot
func set_first_person_view(value: bool) -> void:
    first_person_view=value
    model.visible=not value
    weapon_mount.visible=equipped_slot>0 and not seated and not value
func set_motion(value: float, on_ground: bool, aim: bool, pitch: float) -> void:
    speed=value;grounded=on_ground;aiming=aim;aim_pitch=pitch
func play_action(clip_name: String, duration: float, keep_ik: bool=false) -> void:
    var full: String="CharacterArmature|"+clip_name
    if not animations.has_animation(full):return
    current_animation=full;action_time=duration;action_ik=keep_ik
    animations.play(full,.08);animations.seek(0,false)
    animations.speed_scale=animations.get_animation(full).length/maxf(duration,.05)
func cancel_action() -> void:action_time=0
# Exactly one clip per frame: calling _play twice with different clips restarts the
# animation every frame and freezes the pose.
func _locomotion_clip() -> String:
    if not grounded:return "Idle_Neutral"
    if speed<=.2:return "Idle_Gun" if equipped_slot>0 else "Idle_Neutral"
    var sideways: bool=absf(move_input.x)>absf(move_input.y)
    if sprinting and not aiming and not sideways:return "Run"
    if equipped_slot==0:
        if sideways:return "Run_Left" if move_input.x<0 else "Run_Right"
        return "Run_Back" if move_input.y>.2 else "Walk"
    if move_input.y>.2 and not sideways:return "Run_Back"
    if sideways:return "Run_Left" if move_input.x<0 else "Run_Right"
    return "Run_Shoot"
func on_fire() -> void:fire_push=1
func get_weapon() -> Node3D:return weapon_models[equipped_slot-1] if equipped_slot>0 else null
func _process(delta: float) -> void:
    if not is_visible_in_tree():return
    if seated:_pose_driver();return
    if action_time>0:
        action_time=maxf(0,action_time-delta)
        animations.advance(delta)
        weapon_mount.visible=equipped_slot>0 and action_ik and not first_person_view
        if not action_ik:return
    else:
        weapon_mount.visible=equipped_slot>0 and not first_person_view
        _play(_locomotion_clip())
        animations.speed_scale=clampf(speed/5.5,.55,1.35) if speed>.2 else 1.0
        animations.advance(delta)
    recoil=move_toward(recoil,0,delta*5)
    fire_push=move_toward(fire_push,0,delta*14)
    # Lower the gun while sprinting or just after switching; dip and roll it during reloads.
    var reload_dip: float=sin(clampf(reload_progress,0,1)*PI)
    var lower_target: float=maxf(weapon_raise,.85 if sprinting and not aiming else 0.0)
    weapon_lower=lerpf(weapon_lower,maxf(lower_target,reload_dip*.55),1-exp(-delta*14))
    weapon_mount.position=MOUNT_BASE+Vector3(-.04*weapon_lower,-.22*weapon_lower,.10*weapon_lower+recoil*1.6+fire_push*.025)
    weapon_mount.rotation=Vector3(aim_pitch*.75*(1-weapon_lower)-recoil-weapon_lower*.85,weapon_lower*.35,reload_dip*.7)
    if equipped_slot>0:
        var weapon:=get_weapon()
        _solve_arm("R",weapon.get_node("GripRight").global_position,to_global(Vector3(.36,1.08,.02)))
        _solve_arm("L",weapon.get_node("GripLeft").global_position,to_global(Vector3(-.30,1.1,-.02)))
func _sample_neutral() -> void:
    current_animation="CharacterArmature|Idle_Neutral"
    animations.play(current_animation,0);animations.seek(0,true);animations.advance(0)
func _pose_driver() -> void:
    if vehicle==null:return
    position=Vector3.ZERO
    _sample_neutral()
    var anchor: Array=settings.driver_body_anchor
    position=Vector3(anchor[0],anchor[1],anchor[2])-to_local(bone_world("Body").origin)
    var torso:=bone_world("Torso").origin
    _orient("Torso",bone_world("Chest").origin-torso,vehicle.visual.global_basis*Vector3(0,1,-.12))
    for side in ["L","R"]:
        var ankle: Array=settings.driver_ankles[0 if side=="L" else 1]
        var target: Vector3=vehicle.visual.to_global(Vector3(ankle[0],ankle[1],ankle[2]))
        _solve_leg(side,target,vehicle.visual.to_global(Vector3(ankle[0],.85,-.50)))
    var wheel: Vector3=vehicle.steering_wheel.global_position
    var right: Vector3=vehicle.visual.global_basis.x.normalized()
    _solve_arm("L",wheel-right*.13,vehicle.visual.to_global(Vector3(-.50,1.11,.09)))
    _solve_arm("R",wheel+right*.13,vehicle.visual.to_global(Vector3(.03,1.11,.09)))
func bone_world(bone_name: String) -> Transform3D:
    return skeleton.global_transform*skeleton.get_bone_global_pose(skeleton.find_bone(bone_name))
func _orient(bone_name: String, old_direction: Vector3, new_direction: Vector3) -> void:
    if old_direction.length_squared()<.0000001 or new_direction.length_squared()<.0000001:return
    var index:=skeleton.find_bone(bone_name)
    # Updating an entire global pose decomposes shear back into local scale.
    # Repeating that through the arm chain inflates the skin over time.
    # Grip IK changes only a normalized local rotation, preserving bone lengths.
    var rotation_delta:=Basis(Quaternion(old_direction.normalized(),new_direction.normalized()).normalized())
    var desired_world: Basis=rotation_delta*bone_world(bone_name).basis.orthonormalized()
    var parent_index:=skeleton.get_bone_parent(index)
    var parent_world: Basis=skeleton.global_basis.orthonormalized()
    if parent_index>=0:
        parent_world=(skeleton.global_basis*skeleton.get_bone_global_pose(parent_index).basis).orthonormalized()
    var local_rotation: Quaternion=(parent_world.inverse()*desired_world).get_rotation_quaternion().normalized()
    skeleton.set_bone_pose_rotation(index,local_rotation)
func _hinge(start: Vector3, target: Vector3, pole: Vector3, first_length: float, second_length: float) -> Vector3:
    var direction: Vector3=(target-start).normalized()
    var distance:=clampf(start.distance_to(target),absf(first_length-second_length)+.001,first_length+second_length-.001)
    var along: float=(first_length*first_length-second_length*second_length+distance*distance)/(2*distance)
    var across:=sqrt(maxf(0,first_length*first_length-along*along))
    var bend: Vector3=(pole-start)-direction*(pole-start).dot(direction)
    if bend.length_squared()<.000001:bend=Vector3.UP.cross(direction)
    return start+direction*along+bend.normalized()*across
func _solve_arm(side: String, target: Vector3, pole: Vector3) -> void:
    var upper: String="UpperArm."+side;var lower: String="LowerArm."+side;var wrist: String="Wrist."+side
    var a:=bone_world(upper).origin;var b:=bone_world(lower).origin;var c:=bone_world(wrist).origin
    var elbow:=_hinge(a,target,pole,a.distance_to(b),b.distance_to(c))
    _orient(upper,b-a,elbow-a)
    b=bone_world(lower).origin;c=bone_world(wrist).origin
    _orient(lower,c-b,target-b)
func _solve_leg(side: String, target: Vector3, pole: Vector3) -> void:
    var upper: String="UpperLeg."+side;var lower: String="LowerLeg."+side;var foot: String="Foot."+side
    var a:=bone_world(upper).origin;var b:=bone_world(lower).origin
    var lower_pose:=bone_world(lower)
    var length: float=lower_pose.basis.y.length()*.0051112
    var knee:=_hinge(a,target,pole,a.distance_to(b),length)
    _orient(upper,b-a,knee-a)
    b=bone_world(lower).origin;lower_pose=bone_world(lower)
    _orient(lower,lower_pose.basis.y,target-b)
    var foot_index:=skeleton.find_bone(foot)
    var local_position: Vector3=skeleton.to_local(target+vehicle.visual.global_basis.y.normalized()*.02)
    var parent_index:=skeleton.get_bone_parent(foot_index)
    if parent_index>=0:local_position=skeleton.get_bone_global_pose(parent_index).affine_inverse()*local_position
    skeleton.set_bone_pose_position(foot_index,local_position)
