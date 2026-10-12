extends SceneTree
var game: Node3D
var hud: Node
func _initialize() -> void:call_deferred("capture")
func frames(count: int) -> void:
    for i in count:await process_frame
func snapshot(file: String) -> void:
    await frames(8)
    await RenderingServer.frame_post_draw
    root.get_texture().get_image().save_png("C:/Users/7amad/Documents/Codex/2026-10-11/c-users-7amad-desktop-godot-erbil/outputs/"+file+".png")
func capture() -> void:
    game=load("res://scenes/main.tscn").instantiate();root.add_child(game);current_scene=game
    for connection in root.focus_exited.get_connections():root.focus_exited.disconnect(connection.callable)
    hud=game.get_node("HUD")
    hud.set_paused(false)
    await create_timer(1.5).timeout
    hud.toast_time=0;hud.tutorial_time=24;hud._process(0)
    var cart: CharacterBody3D=game.get_node("GolfCart")
    # Freeze a real game pose while drawing the live telemetry and menus.
    paused=true;hud.pause_overlay.hide()
    cart.speed=103.0/3.6;cart.throttle_amount=.75
    hud.gauge._process(1)
    await snapshot("game-hud")
    print("HUD bounds root=",hud.root.size," gauge=",hud.gauge.get_rect()," map=",hud.map.get_rect())
    hud.set_paused(true)
    await snapshot("game-pause")
    hud.pause_overlay.show_tab(2)
    await snapshot("game-controls")
    hud.pause_overlay.show_tab(1)
    await snapshot("game-options")
    hud.open_map()
    hud.full_map.select_point(Vector2(445,-76.47))
    await snapshot("game-map")
    print("MAP bounds canvas=",hud.full_map.canvas.get_rect()," side=",hud.full_map.side_panel.get_rect()," content=",hud.full_map.side_body.size," zoom=",hud.full_map.zoom_controls.get_rect())
    hud.close_map();hud.set_paused(false)
    root.size=Vector2i(1920,1080)
    await frames(8)
    paused=true;hud.pause_overlay.hide();cart.speed=200.0/3.6;cart.throttle_amount=1
    hud.gauge._process(1)
    await snapshot("game-hud-1080p")
    print("UI_CAPTURE_COMPLETE fps=",Engine.get_frames_per_second())
    quit()
