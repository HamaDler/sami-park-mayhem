extends Node3D
# First-person arms: the hoodie character's own arms, posed onto the visible gun every frame.
# The head, legs and feet are hidden and the torso is cut away by assets/shaders/viewmodel_arms.gdshader.
# FirstPersonWeapon calls pose() after placing the gun, with a target for each hand.
const ArmIK=preload("res://scripts/arm_ik.gd")
const ARMS_SHADER:=preload("res://assets/shaders/viewmodel_arms.gdshader")
const VIEWMODEL_LAYER: int=1<<11
# Larger than the third-person body (adult arm length) so the hands reach the long guns' front grips.
const ARM_SCALE: float=1.3
# Torso cut-away radius around the spine, before scaling.
const TORSO_RADIUS: float=.15
var arm_scale: float=ARM_SCALE
const HIDDEN_MESHES: Array[String]=["Head","Legs","Feet"]
const FINGERS: Array[String]=["Index","Middle","Ring","Pinky"]
# Open hands come from the pointing pose; closed hands from the punch clip's fists.
const OPEN_CLIP:="CharacterArmature|Idle_Gun_Pointing"
const FIST_CLIP:="CharacterArmature|Punch_Right"
var model: Node3D
var skeleton: Skeleton3D
var base_pose: Dictionary={}
var fist_pose: Dictionary={}
var finger_bones: Dictionary={"L":[],"R":[]}
var shoulder_center:=Vector3.ZERO
var hand_length: float=.2
var anchor:=Vector3(0,-.3,-.08)
var materials: Array[ShaderMaterial]=[]
func _ready() -> void:
    model=load("res://assets/characters/hoodie/hoodie.glb").instantiate();model.name="ArmsModel";add_child(model)
    skeleton=model.find_children("*","Skeleton3D",true,false)[0]
    var animations: AnimationPlayer=model.find_children("*","AnimationPlayer",true,false)[0]
    animations.callback_mode_process=AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
    animations.play(FIST_CLIP);animations.seek(.25,true);animations.advance(0)
    var fist: Dictionary={}
    for index in skeleton.get_bone_count():fist[index]=skeleton.get_bone_pose_rotation(index)
    animations.play(OPEN_CLIP);animations.seek(.3,true);animations.advance(0)
    animations.active=false
    for mesh: MeshInstance3D in model.find_children("*","MeshInstance3D",true,false):
        mesh.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF;mesh.layers=VIEWMODEL_LAYER
        # ComicStyle leaves these alone: the arms shader already has the toon lighting.
        mesh.set_meta("comic",true)
        for part in HIDDEN_MESHES:
            if str(mesh.name).contains(part):mesh.visible=false
        if not mesh.visible:continue
        for surface in mesh.mesh.get_surface_count():
            var source: Material=mesh.mesh.surface_get_material(surface)
            var material:=ShaderMaterial.new();material.shader=ARMS_SHADER;material.set_meta("comic",true)
            var color:=Color(.25,.19,.32)
            if source is BaseMaterial3D:color=source.albedo_color
            elif source is ShaderMaterial and source.get_shader_parameter("albedo")!=null:color=source.get_shader_parameter("albedo")
            material.set_shader_parameter("albedo",color)
            mesh.set_surface_override_material(surface,material);materials.append(material)
    # Remember the sampled pose so every frame starts from the same arms before IK.
    for side in ["L","R"]:
        var bones: Array[String]=["UpperArm."+side,"LowerArm."+side,"Wrist."+side]
        var hand: Array[String]=[]
        for finger in FINGERS:
            for joint in range(1,5):hand.append(finger+str(joint)+"."+side)
        for joint in range(1,4):hand.append("Thumb"+str(joint)+"."+side)
        for bone_name in bones+hand:
            var index:=skeleton.find_bone(bone_name)
            if index<0:continue
            base_pose[index]=skeleton.get_bone_pose_rotation(index)
            if bone_name in hand:fist_pose[index]=fist[index];finger_bones[side].append(index)
    var model_inverse: Transform3D=model.global_transform.affine_inverse()
    shoulder_center=model_inverse*((_world("UpperArm.L").origin+_world("UpperArm.R").origin)*.5)
    hand_length=_world("Wrist.R").origin.distance_to(_world("Middle4.R").origin)*ARM_SCALE
func _world(bone_name: String) -> Transform3D:
    return ArmIK.bone_world(skeleton,bone_name)
func _bone(bone_name: String) -> int:
    return skeleton.find_bone(bone_name)
# camera: the first-person camera. shoulders: shoulder midpoint in camera space.
# right / left: {"palm": world position the palm should hold, "fingers": world direction from the
# wrist to the knuckles, "thumb": world direction of the thumb side, "curl": 0 open .. 1 fist}.
func pose(camera: Camera3D, shoulders: Vector3, right: Dictionary, left: Dictionary, delta: float) -> void:
    anchor=anchor.lerp(shoulders,1-exp(-delta*10))
    var facing:=Basis(Vector3.UP,PI).scaled(Vector3.ONE*arm_scale)
    model.global_transform=camera.global_transform*Transform3D(facing,anchor-facing*shoulder_center)
    for index: int in base_pose:skeleton.set_bone_pose_rotation(index,base_pose[index])
    var down: Vector3=-camera.global_basis.y
    var back: Vector3=camera.global_basis.z
    var side: Vector3=camera.global_basis.x
    var hips: Vector3=_world("Hips").origin;var neck: Vector3=_world("Neck").origin
    for material in materials:
        material.set_shader_parameter("spine_bottom",hips)
        material.set_shader_parameter("spine_top",neck+(neck-hips).normalized()*.08*arm_scale)
        material.set_shader_parameter("torso_radius",TORSO_RADIUS*arm_scale)
    _hand("R",right,_world("UpperArm.R").origin+(side*.3+down*.5+back*.1)*arm_scale)
    _hand("L",left,_world("UpperArm.L").origin+(-side*.3+down*.5+back*.1)*arm_scale)
func _hand(side: String, target: Dictionary, pole: Vector3) -> void:
    var fingers: Vector3=(target.fingers as Vector3).normalized()
    var thumb: Vector3=target.thumb
    thumb=(thumb-fingers*thumb.dot(fingers)).normalized()
    # Close the fingers first (they sit in the wrist's space, so aiming the hand keeps the grip).
    var curl: float=clampf(float(target.get("curl",0.0)),0,1)
    for index: int in finger_bones[side]:
        skeleton.set_bone_pose_rotation(index,(base_pose[index] as Quaternion).slerp(fist_pose[index],curl))
    # The wrist sits behind the palm along the knuckle line.
    var wrist_target: Vector3=target.palm-fingers*hand_length*.32*arm_scale/ARM_SCALE
    ArmIK.solve_arm(skeleton,side,wrist_target,pole)
    var wrist:="Wrist."+side
    var origin: Vector3=_world(wrist).origin
    ArmIK.orient(skeleton,wrist,_world("Middle2."+side).origin-origin,fingers)
    origin=_world(wrist).origin
    var current_thumb: Vector3=_world("Thumb2."+side).origin-origin
    current_thumb-=fingers*current_thumb.dot(fingers)
    ArmIK.orient(skeleton,wrist,current_thumb,thumb)
