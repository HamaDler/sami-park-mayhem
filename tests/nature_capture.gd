extends SceneTree
var game: Node3D
var park: Node3D
var cart: CharacterBody3D
func _initialize() -> void:call_deferred("capture")
func capture() -> void:
    DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
    Engine.max_fps=0
    OS.low_processor_usage_mode=false
    var start:=Time.get_ticks_msec()
    game=load("res://scenes/main.tscn").instantiate()
    root.add_child(game)
    current_scene=game
    for connection in root.focus_exited.get_connections():root.focus_exited.disconnect(connection.callable)
    park=game.get_node("SamiPark")
    cart=game.get_node("GolfCart")
    game.get_node("HUD").set_paused(false)
    print("STARTUP_MS ",Time.get_ticks_msec()-start)
    await shot("nature-english-door",cart.position,cart.rotation.y)
    await shot("nature-lakeside",Vector3(445,.15,-76.47),-.22)
    await shot("nature-garden",Vector3(89,.15,-64),1.5708)
    await shot("nature-groves",Vector3(-140,.15,-450),-.75)
    var begin:=Vector2(-74.159,-481.676)
    var end:=Vector2(-42.823,-727.281)
    var direction: Vector2=(end-begin).normalized()
    var yaw:=atan2(-direction.x,-direction.y)
    cart.teleport_to(begin+direction*30,yaw)
    cart.speed=cart.settings.max_speed
    cart.travel_yaw=yaw
    cart.velocity=-cart.basis.z*cart.speed
    game.get_node("ChaseCamera").snap()
    park.nature.refresh()
    await create_timer(.5).timeout
    var timings: Array[float]=[]
    var draws: Array[int]=[]
    Input.action_press("accelerate")
    for i in 180:
        var time:=Time.get_ticks_usec()
        await process_frame
        timings.append((Time.get_ticks_usec()-time)/1000.0)
        draws.append(int(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)))
    Input.action_release("accelerate")
    print("BENCHMARK_SPEED_KMH ",cart.speed*3.6," on_path=",cart.on_path," active_trunks=",park.nature.active_bodies.size())
    timings.sort()
    draws.sort()
    print("BENCHMARK_HIGH frame_ms median=",timings[90]," p95=",timings[171]," draws_median=",draws[90]," engine_fps=",Engine.get_frames_per_second())
    print("BATCHES near=",park.nature.near_batches.size()," far=",park.nature.far_batches.size()," detail=",park.nature.detail_batches.size()," active_trunks=",park.nature.active_bodies.size())
    park.set_visible_tree_fraction(.45)
    await create_timer(.5).timeout
    timings.clear()
    for i in 120:
        var time:=Time.get_ticks_usec()
        await process_frame
        timings.append((Time.get_ticks_usec()-time)/1000.0)
    timings.sort()
    print("BENCHMARK_LOW frame_ms median=",timings[60]," p95=",timings[114]," engine_fps=",Engine.get_frames_per_second())
    park.set_visible_tree_fraction(1)
    game.get_node("HUD").hide()
    game.get_node("WorldEnvironment").environment.fog_enabled=false
    var camera:=Camera3D.new()
    game.add_child(camera)
    camera.projection=Camera3D.PROJECTION_ORTHOGONAL
    camera.size=2450
    camera.far=4000
    camera.position=Vector3(0,2200,0)
    camera.rotation_degrees=Vector3(-90,0,0)
    camera.current=true
    park.nature.refresh()
    await create_timer(.8).timeout
    await RenderingServer.frame_post_draw
    root.get_texture().get_image().save_png("C:/Users/7amad/Documents/Codex/2026-10-11/c-users-7amad-desktop-godot-erbil/outputs/nature-park-overhead.png")
    quit()
func shot(name: String, position: Vector3, yaw: float) -> void:
    var destination: Dictionary=park.resolve_map_spawn(Vector2(position.x,position.z),yaw,cart.get_rid())
    if destination.valid:cart.teleport_to(destination.position,yaw)
    else:cart.teleport_to(Vector2(position.x,position.z),yaw)
    game.get_node("ChaseCamera").snap()
    park.nature.refresh()
    await create_timer(1.2).timeout
    await RenderingServer.frame_post_draw
    root.get_texture().get_image().save_png("C:/Users/7amad/Documents/Codex/2026-10-11/c-users-7amad-desktop-godot-erbil/outputs/"+name+".png")
    print("CAPTURE ",name," fps=",Engine.get_frames_per_second())
