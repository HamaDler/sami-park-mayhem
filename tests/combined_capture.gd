extends SceneTree
var game: Node3D
func _initialize() -> void:call_deferred("capture")
func capture() -> void:
    game=load("res://scenes/main.tscn").instantiate();root.add_child(game);current_scene=game
    for connection in root.focus_exited.get_connections():root.focus_exited.disconnect(connection.callable)
    var cart: CharacterBody3D=game.get_node("GolfCart")
    var rig: Node3D=game.get_node("ChaseCamera")
    var park: Node3D=game.get_node("SamiPark")
    game.get_node("HUD").set_paused(false)
    game.get_node("HUD").hide()
    var observer:=Camera3D.new();game.add_child(observer)
    observer.projection=Camera3D.PROJECTION_ORTHOGONAL
    observer.size=145
    observer.far=1800
    observer.global_position=Vector3(-494,100,725)
    observer.look_at(Vector3(-494,0,600))
    observer.current=true
    park.nature.refresh()
    await create_timer(1.5).timeout
    await RenderingServer.frame_post_draw
    root.get_texture().get_image().save_png("C:/Users/7amad/Documents/Codex/2026-10-11/c-users-7amad-desktop-godot-erbil/outputs/sports-courts.png")
    print("CAPTURE courts fps=",Engine.get_frames_per_second())
    observer.current=false;rig.camera.current=true
    game.get_node("HUD").show()
    var start:=Vector2(-74.159,-481.676)
    var end:=Vector2(-42.823,-727.281)
    var direction: Vector2=(end-start).normalized()
    var yaw:=atan2(-direction.x,-direction.y)
    cart.teleport_to(start+direction*35,yaw)
    cart.speed=95/3.6
    cart.travel_yaw=yaw
    rig.zoom_distance=6.0;rig.snap();park.nature.refresh()
    Input.action_press("accelerate")
    for i in 70:await physics_frame
    Input.action_release("accelerate")
    cart.speed=95/3.6
    Input.action_press("left");Input.action_press("brake")
    for i in 24:await physics_frame
    await RenderingServer.frame_post_draw
    root.get_texture().get_image().save_png("C:/Users/7amad/Documents/Codex/2026-10-11/c-users-7amad-desktop-godot-erbil/outputs/tire-effects.png")
    print("CAPTURE effects marks=",cart.effects.written," smoke=",cart.effects.smoke_active," fps=",Engine.get_frames_per_second())
    var dust: Image=load("res://assets/dust_puff.svg").get_image()
    dust.save_png("C:/Users/7amad/Documents/Codex/2026-10-11/c-users-7amad-desktop-godot-erbil/work/dust-texture.png")
    print("DUST_PIXEL ",dust.get_pixel(32,32)," ramp=",cart.effects.emitters[0].color_ramp.colors)
    for emitter in cart.effects.emitters:emitter.visible=false
    await RenderingServer.frame_post_draw
    root.get_texture().get_image().save_png("C:/Users/7amad/Documents/Codex/2026-10-11/c-users-7amad-desktop-godot-erbil/work/without-particles.png")
    for emitter in cart.effects.emitters:emitter.visible=true

    Input.action_release("left");Input.action_release("brake")
    cart.teleport_to(start+direction*30,yaw)
    cart.speed=cart.settings.max_speed;cart.travel_yaw=yaw
    rig.snap()
    Input.action_press("left");Input.action_press("accelerate")
    for i in 100:
        await physics_frame
        if cart.rolling:break
    for i in 120:
        await physics_frame
        if cart.global_basis.y.dot(Vector3.UP)<-.15:break
    await RenderingServer.frame_post_draw
    root.get_texture().get_image().save_png("C:/Users/7amad/Documents/Codex/2026-10-11/c-users-7amad-desktop-godot-erbil/outputs/cart-rollover.png")
    print("CAPTURE rollover rolling=",cart.rolling," up=",cart.global_basis.y.dot(Vector3.UP))
    quit()
