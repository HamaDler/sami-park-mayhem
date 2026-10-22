extends SceneTree
# Renders every text-heavy screen for typography review: the on-foot HUD with a wave banner and
# kill callouts, the driving HUD, toasts, every pause tab, the workshop, the world map, world
# signs and the game-over screen. Run in the actual renderer (no --headless).
# Images go to $CAPTURE_DIR or user://typography_captures.
var game: Node3D
var hud: Node
var folder: String
func _initialize() -> void:call_deferred("capture")
func frames(count: int) -> void:
    for i in count:await process_frame
func shot(name: String) -> void:
    await frames(6);await RenderingServer.frame_post_draw
    root.get_texture().get_image().save_png(folder.path_join(name+".png"))
    print("CAPTURED ",name)
func capture() -> void:
    folder=OS.get_environment("CAPTURE_DIR")
    if folder=="":folder=ProjectSettings.globalize_path("user://typography_captures")
    DirAccess.make_dir_recursive_absolute(folder)
    game=load("res://scenes/main.tscn").instantiate();root.add_child(game);current_scene=game
    for connection in root.focus_exited.get_connections():root.focus_exited.disconnect(connection.callable)
    hud=game.hud
    var survival: Node3D=game.survival
    var player: CharacterBody3D=game.player
    var rig: Node3D=game.camera_rig
    rig.set_process_unhandled_input(false)
    await create_timer(1.2).timeout
    survival.process_mode=Node.PROCESS_MODE_DISABLED
    survival.score=12450;survival.kills=87;survival.dinars=2350
    hud.tutorial_time=0;hud._process(0)
    # On foot: hints, wave banner, kill callouts and a low-ammo warning.
    var overlay: Control=hud.survival_overlay
    overlay.process_mode=Node.PROCESS_MODE_ALWAYS
    player.weapons.rounds[1]=2
    overlay.show_banner("WAVE 3","32 ZOMBIES INCOMING",GameUI.RED);overlay.banner_time=overlay.BANNER_SECONDS-.6
    overlay._on_hit_feedback("headkill",150,"HEADSHOT")
    overlay._on_hit_feedback("kill",100,"")
    overlay._on_hit_feedback("kill",50,"ROADKILL")
    for item in overlay.popups:item.time=.9
    survival.process_mode=Node.PROCESS_MODE_INHERIT;await frames(1);survival.process_mode=Node.PROCESS_MODE_DISABLED
    await shot("01-hud-on-foot")
    overlay.banner_time=0;overlay.popups.clear()
    hud.show_toast("CACHE SECURED  /  +1500 IQD  /  FULL AMMO");hud.tutorial_time=30
    await shot("02-hud-toast")
    # Driving HUD.
    game.enter_vehicle(game.get_node("GolfCart/VehicleAccess"),true)
    await frames(4)
    var cart: CharacterBody3D=game.get_node("GolfCart");cart.speed=87.0/3.6;cart.throttle_amount=.7;hud.gauge._process(1)
    hud.toast_time=0;hud.tutorial_time=0
    await shot("03-hud-driving")
    game.exit_vehicle(true);await frames(4)
    # Pause menu tabs.
    hud.set_paused(true)
    for tab in 4:
        hud.pause_overlay.show_tab(tab)
        await shot("1%d-pause-tab%d" % [tab,tab])
    hud.set_paused(false)
    # Workshop.
    var station: Node3D=survival.stations[0] if not survival.stations.is_empty() else null
    if station:
        var workshop: Control=overlay.workshop
        workshop.survival=survival;workshop.station=station;workshop.set_process(false);workshop.show();workshop.refresh()
        await shot("20-workshop")
        workshop.hide();workshop.set_process(true)
    # World map.
    hud.open_map();hud.full_map.select_point(Vector2(445,-76.47))
    await shot("30-map")
    hud.close_map()
    # World signs: look at the nearest station.
    if station:
        var target: Vector3=station.global_position+Vector3.UP*1.8
        var stand: Vector3=station.to_global(Vector3(0,0,-6.5))
        player.teleport_to(Vector2(stand.x,stand.z),0)
        await frames(3)
        var to: Vector3=target-rig.camera.global_position
        rig.foot_yaw=atan2(-to.x,-to.z);rig.pitch=atan2(to.y,Vector2(to.x,to.z).length())
        await shot("40-world-signs")
    # Game over.
    hud.show_game_over()
    await shot("50-game-over")
    print("TYPOGRAPHY_CAPTURE_COMPLETE")
    quit()
