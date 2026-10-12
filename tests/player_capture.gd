extends SceneTree
var game: Node3D
func _initialize() -> void:call_deferred("capture")
func frames(count: int) -> void:
    for i in count:await process_frame
func shot(name: String) -> void:
    await frames(8);await RenderingServer.frame_post_draw
    root.get_texture().get_image().save_png("C:/Users/7amad/Documents/Codex/2026-10-11/c-users-7amad-desktop-godot-erbil/outputs/"+name+".png")
func capture() -> void:
    game=load("res://scenes/main.tscn").instantiate();root.add_child(game);current_scene=game
    for connection in root.focus_exited.get_connections():root.focus_exited.disconnect(connection.callable)
    var cart: CharacterBody3D=game.get_node("GolfCart")
    var player: CharacterBody3D=game.player
    var hud: Node=game.hud
    hud.toast_time=0;hud.tutorial_time=30;hud._process(0)
    var camera:=Camera3D.new();game.add_child(camera);camera.fov=42
    camera.global_position=cart.to_global(Vector3(-2.6,1.8,-3.5));camera.look_at(cart.to_global(Vector3(-.20,1.08,0)));camera.current=true
    await create_timer(.4).timeout
    await shot("hoodie-seat")
    game.camera_rig.camera.current=true
    game.exit_vehicle();await create_timer(.2).timeout
    player.teleport_to(Vector2(cart.global_position.x,cart.global_position.z)-Vector2(4,0),cart.rotation.y)
    game.camera_rig.foot_yaw=cart.rotation.y;game.camera_rig.snap();game.park.nature.refresh()
    hud.toast_time=0;hud.tutorial_time=30;hud._process(0)
    player.weapons.select_weapon(2);await create_timer(.35).timeout
    await shot("hoodie-on-foot")
    # Front view makes the supplied character and weapon fit easy to inspect.
    camera.global_position=player.to_global(Vector3(2.8,1.6,-3.6));camera.look_at(player.to_global(Vector3(0,1,0)));camera.fov=38;camera.current=true
    await shot("hoodie-rifle")
    player.weapons.select_weapon(1);await create_timer(.25).timeout
    await shot("hoodie-pistol")
    player.weapons.select_weapon(3);await create_timer(.25).timeout
    await shot("hoodie-sniper")
    game.camera_rig.camera.current=true
    Input.action_press("aim");await create_timer(.4).timeout
    await shot("hoodie-sniper-scope")
    Input.action_release("aim");await create_timer(.2).timeout
    Input.action_press("jump")
    await create_timer(.20).timeout
    Input.action_release("jump")
    await shot("hoodie-jump")
    await create_timer(.6).timeout
    hud.set_paused(true);hud.pause_overlay.show_tab(2)
    await shot("hoodie-controls")
    print("PLAYER_CAPTURE_COMPLETE fps=",Engine.get_frames_per_second())
    quit()
