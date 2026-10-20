extends SceneTree
# Renders the blood effect for visual review: body hit, headshot kill and ground splatter.
# Run windowed (not --headless): godot --path . --script res://tests/blood_capture.gd -- <output dir>
var game: Node3D
func _initialize() -> void:call_deferred("run")
func frames(count: int) -> void:
    for i in count:await process_frame
func shot(out: String, name: String) -> void:
    await RenderingServer.frame_post_draw
    root.get_texture().get_image().save_png(out+"/"+name+".png")
func run() -> void:
    var args:=OS.get_cmdline_user_args()
    var out: String=args[0] if not args.is_empty() else OS.get_user_data_dir()
    DirAccess.make_dir_recursive_absolute(out)
    var started:=Time.get_ticks_msec()
    game=load("res://scenes/main.tscn").instantiate();root.add_child(game);current_scene=game
    for connection in root.focus_exited.get_connections():root.focus_exited.disconnect(connection.callable)
    await frames(8)
    print("SCENE READY MS ",Time.get_ticks_msec()-started)
    var s: Node3D=game.survival;s.enemies.set_physics_process(false);s.wave.begin_next();s.config.powerups.drop_chance=0
    var player: CharacterBody3D=game.player
    var forward:=Vector2(-player.global_basis.z.x,-player.global_basis.z.z).normalized()
    var p:=Vector2(player.global_position.x,player.global_position.z)
    var zombie: CharacterBody3D=load("res://scenes/zombie.tscn").instantiate();s.enemies.add_child(zombie)
    zombie.build(s.enemies,s.enemies.models[0],0);s.enemies.pool.append(zombie)
    zombie.activate(p+forward*4.5,1,{"health":10000,"damage":0,"speed":0});zombie.set_physics_process(false)
    zombie.rotation.y=player.rotation.y+PI;zombie.animator.advance(.3)
    game.hud.toast_time=0;game.hud.tutorial_time=30
    game.camera_rig.foot_yaw=player.rotation.y;game.camera_rig.pitch=-.05;game.camera_rig.snap()
    await frames(20)
    # Close three-quarter view of the zombie with the shot coming from the player's side.
    game.camera_rig.set_process(false);game.hud.survival_overlay.banner_time=0
    var cam:=Camera3D.new();game.add_child(cam);cam.current=true
    var side:=Vector3(-forward.y,0,forward.x)
    var zpos: Vector3=zombie.global_position
    cam.global_position=zpos-Vector3(forward.x,0,forward.y)*2.6+side*1.4+Vector3.UP*1.55
    cam.look_at(zpos+Vector3.UP*1.2,Vector3.UP);cam.fov=55
    await frames(2)
    var effects: Node3D=player.weapons.effects
    var travel:=Vector3(forward.x,0,forward.y)
    var chest: Vector3=zombie.body_box.global_position+Vector3.UP*.15-travel*.3
    await seconds(.5);print("FPS ",Engine.get_frames_per_second())
    effects.blood_burst(chest,travel,false);await seconds(.05);await shot(out,"blood_body_a")
    await seconds(.1);await shot(out,"blood_body_b")
    await seconds(.6)
    effects.blood_burst(chest+Vector3.UP*.25,travel,false);effects.blood_burst(chest-Vector3.UP*.1+Vector3(-travel.z,0,travel.x)*.15,travel,false)
    await seconds(.08);await shot(out,"blood_rifle")
    await seconds(.6)
    s.damage_zombie(zombie,100000,true,"gun",zombie.head_box.global_position-travel*.2,travel)
    await seconds(.05);await shot(out,"blood_head_a")
    await seconds(.12);await shot(out,"blood_head_b")
    await seconds(1.5);await shot(out,"blood_splat")
    game.queue_free();await frames(2);quit()
func seconds(value: float) -> void:
    await create_timer(value).timeout
