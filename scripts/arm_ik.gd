extends RefCounted
# Two-bone arm IK shared by the third-person character, the seated driver and the
# first-person arms. Only normalized local rotations are written, so bone lengths and
# skin scale never drift (see VALIDATION.md, weapon-hand mesh distortion fix).
static func bone_world(skeleton: Skeleton3D, bone_name: String) -> Transform3D:
    return skeleton.global_transform*skeleton.get_bone_global_pose(skeleton.find_bone(bone_name))
# Rotate a bone so old_direction (world space) turns into new_direction.
static func orient(skeleton: Skeleton3D, bone_name: String, old_direction: Vector3, new_direction: Vector3) -> void:
    if old_direction.length_squared()<.0000001 or new_direction.length_squared()<.0000001:return
    var index:=skeleton.find_bone(bone_name)
    var rotation_delta:=Basis(Quaternion(old_direction.normalized(),new_direction.normalized()).normalized())
    rotate_world(skeleton,index,rotation_delta)
# Apply a world-space rotation to one bone (its children follow).
static func rotate_world(skeleton: Skeleton3D, index: int, rotation_delta: Basis) -> void:
    var current: Basis=(skeleton.global_basis*skeleton.get_bone_global_pose(index).basis).orthonormalized()
    var desired_world: Basis=rotation_delta*current
    var parent_index:=skeleton.get_bone_parent(index)
    var parent_world: Basis=skeleton.global_basis.orthonormalized()
    if parent_index>=0:
        parent_world=(skeleton.global_basis*skeleton.get_bone_global_pose(parent_index).basis).orthonormalized()
    var local_rotation: Quaternion=(parent_world.inverse()*desired_world).get_rotation_quaternion().normalized()
    skeleton.set_bone_pose_rotation(index,local_rotation)
# Elbow/knee position for a two-segment limb reaching from start towards target, bending towards pole.
static func hinge(start: Vector3, target: Vector3, pole: Vector3, first_length: float, second_length: float) -> Vector3:
    var direction: Vector3=(target-start).normalized()
    var distance:=clampf(start.distance_to(target),absf(first_length-second_length)+.001,first_length+second_length-.001)
    var along: float=(first_length*first_length-second_length*second_length+distance*distance)/(2*distance)
    var across:=sqrt(maxf(0,first_length*first_length-along*along))
    var bend: Vector3=(pole-start)-direction*(pole-start).dot(direction)
    if bend.length_squared()<.000001:bend=Vector3.UP.cross(direction)
    return start+direction*along+bend.normalized()*across
static func solve_arm(skeleton: Skeleton3D, side: String, target: Vector3, pole: Vector3) -> void:
    var upper: String="UpperArm."+side;var lower: String="LowerArm."+side;var wrist: String="Wrist."+side
    var a:=bone_world(skeleton,upper).origin;var b:=bone_world(skeleton,lower).origin;var c:=bone_world(skeleton,wrist).origin
    var elbow:=hinge(a,target,pole,a.distance_to(b),b.distance_to(c))
    orient(skeleton,upper,b-a,elbow-a)
    b=bone_world(skeleton,lower).origin;c=bone_world(skeleton,wrist).origin
    orient(skeleton,lower,c-b,target-b)
