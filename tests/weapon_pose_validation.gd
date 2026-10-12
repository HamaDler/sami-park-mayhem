extends SceneTree
var game: Node3D
var checks: int=0
var failures: Array[String]=[]
func _initialize() -> void:call_deferred("run")
func check(condition: bool, message: String) -> void:
    checks+=1
    if condition:print("PASS: ",message)
    else:failures.append(message);push_error("FAIL: "+message)
func frames(count: int) -> void:
    for i in count:await process_frame
func run() -> void:
    game=load("res://scenes/main.tscn").instantiate();root.add_child(game);current_scene=game
    for connection in root.focus_exited.get_connections():root.focus_exited.disconnect(connection.callable)
    await frames(6)
    check(game.exit_vehicle(),"Character can exit before testing weapon poses")
    var player: CharacterBody3D=game.player
    var avatar: Node3D=player.avatar
    var weapons: Node3D=player.weapons
    player.set_physics_process(false);weapons.set_physics_process(false);avatar.set_process(false)
    var initial_scale: Array[Vector3]=[]
    for i in avatar.skeleton.get_bone_count():initial_scale.append(avatar.skeleton.get_bone_pose_scale(i))
    var initial_lengths: Array[float]=[]
    for side in ["L","R"]:
        initial_lengths.append(avatar.bone_world("UpperArm."+side).origin.distance_to(avatar.bone_world("LowerArm."+side).origin))
        initial_lengths.append(avatar.bone_world("LowerArm."+side).origin.distance_to(avatar.bone_world("Wrist."+side).origin))
    var max_scale_error: float=0
    var max_basis_scale: float=0
    var max_length_error: float=0
    var bad_pose: bool=false
    var directions: Array[Vector2]=[Vector2.ZERO,Vector2(0,-1),Vector2(1,0),Vector2(-1,0),Vector2(0,1)]
    # Accelerate several minutes of real animation/IK updates, including turns,
    # clips, weapon changes, recoil and both vertical aiming extremes.
    for step in 12000:
        var slot: int=1+(step/83 as int)%3
        avatar.set_weapon(slot)
        player.rotation.y=sin(step*.019)*PI
        avatar.move_input=directions[(step/173 as int)%directions.size()]
        avatar.set_motion(7 if avatar.move_input!=Vector2.ZERO else 0,step%251<235,step%37<20,sin(step*.027)*.8)
        if step%4==0:avatar.recoil=.06
        avatar._process(1.0/60)
        if step%40==0:
            for i in avatar.skeleton.get_bone_count():
                var pose: Transform3D=avatar.skeleton.get_bone_global_pose(i)
                bad_pose=bad_pose or not pose.origin.is_finite() or not pose.basis.is_finite()
                max_scale_error=maxf(max_scale_error,avatar.skeleton.get_bone_pose_scale(i).distance_to(initial_scale[i]))
                max_basis_scale=maxf(max_basis_scale,maxf(pose.basis.x.length(),maxf(pose.basis.y.length(),pose.basis.z.length())))
            var index:=0
            for side in ["L","R"]:
                var upper: float=avatar.bone_world("UpperArm."+side).origin.distance_to(avatar.bone_world("LowerArm."+side).origin)
                var lower: float=avatar.bone_world("LowerArm."+side).origin.distance_to(avatar.bone_world("Wrist."+side).origin)
                max_length_error=maxf(max_length_error,maxf(absf(upper-initial_lengths[index]),absf(lower-initial_lengths[index+1])))
                index+=2
        if step%200==0:await frames(1)
    check(not bad_pose,"Repeated weapon grips never create invalid skeleton transforms")
    check(max_scale_error<.001,"12,000 weapon/animation updates preserve every bone's local scale")
    check(max_basis_scale<1.002,"The skinned character cannot inflate into screen-sized geometry")
    check(max_length_error<.001,"Both arm segment lengths stay fixed through switching, aiming and recoil")
    check(avatar.get_weapon().visible and avatar.weapon_mount.scale.is_equal_approx(Vector3.ONE),"The equipped weapon remains visible at its original scale")
    # Return to normal gameplay and fire real rays with each weapon.
    avatar.set_process(true);weapons.set_physics_process(true);player.set_physics_process(true)
    for slot in range(1,4):
        weapons.select_weapon(slot);await frames(35)
        weapons.cooldown=0
        var count: int=weapons.shot_count
        weapons.shoot()
        check(weapons.shot_count==count+1,"Slot "+str(slot)+" still fires after the prolonged pose test")
    var camera: Node3D=game.camera_rig
    camera.foot_yaw=player.rotation.y;camera.pitch=-.18;camera.snap()
    game.hud.toast_time=0;game.hud.tutorial_time=30
    await frames(12);await RenderingServer.frame_post_draw
    root.get_texture().get_image().save_png("C:/Users/7amad/Documents/Codex/2026-10-11/c-users-7amad-desktop-godot-erbil/outputs/weapon-pose-fixed.png")
    game.hud.set_paused(true);await frames(3)
    check(game.hud.pause_overlay.visible and game.hud.pause_overlay.resume_button.has_focus(),"Pause controls still open and receive keyboard focus after prolonged weapon use")
    game.hud.set_paused(false)
    print("POSE_MEASUREMENTS: max_scale_error=",max_scale_error," max_basis_scale=",max_basis_scale," max_arm_length_error=",max_length_error)
    print("WEAPON_POSE_RESULT: ",checks," checks, ",failures.size()," failures")
    quit(0 if failures.is_empty() else 1)
