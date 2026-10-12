extends SceneTree
func _initialize() -> void:call_deferred("inspect")
func dump(node: Node) -> void:
    if node is Skeleton3D:
        print("SKELETON ",node.get_path()," transform=",node.global_transform)
        for i in node.get_bone_count():
            var name: String=node.get_bone_name(i)
            if name in ["Root","Body","Hips","Torso","Chest","Head","UpperLeg.L","LowerLeg.L","LowerLeg.L_end","Foot.L","UpperArm.L","LowerArm.L","Wrist.L","UpperLeg.R","LowerLeg.R","Foot.R","UpperArm.R","LowerArm.R","Wrist.R"]:
                print("BONE ",i," ",name," rest=",node.get_bone_global_rest(i)," world=",node.to_global(node.get_bone_global_pose(i).origin))
    if node is AnimationPlayer:print("ANIMATIONS ",node.get_path()," ",node.get_animation_list())
    if node is MeshInstance3D:
        print("MESH ",node.get_path()," bbox=",node.global_transform*node.get_aabb())
    for child in node.get_children():dump(child)
func inspect() -> void:
    var world:=Node3D.new();root.add_child(world)
    var model=load("res://assets/characters/hoodie/hoodie.glb").instantiate();world.add_child(model);dump(model)
    var cart=load("res://scenes/cart.tscn").instantiate();world.add_child(cart)
    print("STEERING_LOCAL ",cart.visual.to_local(cart.steering_wheel.global_position))
    for node in cart.get_node("Visual/Club90").find_children("*","MeshInstance3D",true,false):
        if str(node.name).contains("Seat") or str(node.name).contains("Roof"):print("CART_PART ",node.name," bbox=",node.global_transform*node.get_aabb())
    quit()
