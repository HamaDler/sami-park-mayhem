extends SceneTree
# Renders the night scene in first person: flashlight on/off, aiming, the sniper scope, the
# driver's seat with headlights, and an outside view of the cart's lights.
# Run in the actual renderer (no --headless). Images go to $CAPTURE_DIR or user://night_captures.
var game: Node3D
var folder: String
func _initialize() -> void:call_deferred("capture")
func frames(count: int) -> void:
    for i in count:await process_frame
func shot(name: String) -> void:
    await frames(8);await RenderingServer.frame_post_draw
    root.get_texture().get_image().save_png(folder.path_join(name+".png"))
    print("CAPTURED ",name)
func look(yaw_offset: float, pitch: float) -> void:
    game.camera_rig.foot_yaw=game.player.rotation.y+yaw_offset;game.camera_rig.pitch=pitch
func capture() -> void:
    folder=OS.get_environment("CAPTURE_DIR")
    if folder=="":folder=ProjectSettings.globalize_path("user://night_captures")
    DirAccess.make_dir_recursive_absolute(folder)
    game=load("res://scenes/main.tscn").instantiate();root.add_child(game);current_scene=game
    for connection in root.focus_exited.get_connections():root.focus_exited.disconnect(connection.callable)
    game.survival.process_mode=Node.PROCESS_MODE_DISABLED
    var cart: CharacterBody3D=game.get_node("GolfCart")
    var player: CharacterBody3D=game.player
    var rig: Node3D=game.camera_rig
    var hud: Node=game.hud
    # Real mouse movement over the window would steer the view mid-capture.
    rig.set_process_unhandled_input(false)
    player.weapons.grant_weapon(2,0);player.weapons.grant_weapon(3,0)
    player.weapons.select_weapon(1)
    await create_timer(1.0).timeout
    hud.toast_time=0;hud.tutorial_time=30;hud._process(0)
    look(0,-.05);await shot("01-foot-flashlight-on")
    rig.flashlight.set_on(false);await shot("02-foot-flashlight-off")
    rig.flashlight.set_on(true)
    look(PI*.5,-.25);await shot("03-foot-look-side")
    look(0,-1.2);await shot("04-foot-look-down")
    # A (frozen) zombie a few metres ahead, flashlight on and off.
    var manager: Node=game.survival.enemies
    var zombie: CharacterBody3D=load("res://scenes/zombie.tscn").instantiate();manager.add_child(zombie)
    zombie.build(manager,manager.models[0],0)
    look(0,-.05);await frames(2)
    var ahead: Vector3=player.global_position-rig.global_basis.z*8
    zombie.activate(Vector2(ahead.x,ahead.z),999,manager.type_stats(1,manager.types.keys()[0]))
    zombie.look_at(Vector3(player.global_position.x,zombie.global_position.y,player.global_position.z),Vector3.UP)
    await shot("04b-zombie-flashlight-on")
    rig.flashlight.set_on(false);await shot("04c-zombie-flashlight-off")
    rig.flashlight.set_on(true)
    var close: Vector3=player.global_position-rig.global_basis.z*3.2
    zombie.global_position=Vector3(close.x,zombie.global_position.y,close.z)
    zombie.look_at(Vector3(player.global_position.x,zombie.global_position.y,player.global_position.z),Vector3.UP)
    await shot("04d-zombie-close")
    rig.flashlight.set_on(true);zombie.hide()
    player.weapons.select_weapon(2);await create_timer(.4).timeout
    look(0,-.05);await shot("05-rifle-hip")
    Input.action_press("aim");await create_timer(.45).timeout
    await shot("06-rifle-aim")
    Input.action_release("aim");player.weapons.select_weapon(3);await create_timer(.4).timeout
    Input.action_press("aim");await create_timer(.45).timeout
    await shot("07-sniper-scope")
    Input.action_release("aim");await create_timer(.3).timeout
    # Driver's seat.
    game.enter_vehicle(cart.get_node("VehicleAccess"),true)
    await create_timer(.5).timeout
    hud.toast_time=0;hud._process(0)
    await shot("08-car-forward")
    rig.look_yaw=1.3;rig.pitch=-.25;rig.look_idle=-10;await shot("09-car-look-left")
    rig.look_yaw=0;rig.pitch=-.75;await shot("10-car-look-down")
    rig.pitch=-.08
    cart.toggle_headlights();await shot("11-car-headlights-off")
    cart.toggle_headlights()
    # Outside view of the cart lights.
    var outside:=Camera3D.new();game.add_child(outside);outside.fov=50
    outside.global_position=cart.to_global(Vector3(3.5,2.2,-6.5));outside.look_at(cart.to_global(Vector3(0,.8,-3)));outside.current=true
    await shot("12-cart-outside-front")
    outside.global_position=cart.to_global(Vector3(-3,2.5,6));outside.look_at(cart.to_global(Vector3(0,.6,-6)));
    Input.action_press("brake");await create_timer(.2).timeout
    await shot("13-cart-outside-rear-brake")
    Input.action_release("brake")
    outside.global_position=cart.to_global(Vector3(0,30,25));outside.look_at(cart.to_global(Vector3(0,0,-20)))
    await shot("14-park-overview")
    rig.camera.current=true
    print("NIGHT_CAPTURE_COMPLETE fps=",Engine.get_frames_per_second())
    quit()
